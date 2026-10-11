// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/driver_live_map_view.dart
//
// A driver's own live-position map -- explicitly NOT the fleet-wide
// admin FleetLiveMapScreen (every vehicle + geofences). Just this
// driver's current position, moving in real time.
//
// Two position sources depending on `compact`:
//   - Full (compact: false): fed directly from TrackingController.livePosition,
//     updated from the SAME antifraud-validated GPS ticks already driving
//     the active trip -- no second location listener, no Supabase
//     round-trip. Only ever has a value DURING an active trip -- that's
//     correct for this mode, unused anywhere yet (kept for a future
//     full-screen live map).
//   - Compact (compact: true, the Dashboard Vehicle-card thumbnail):
//     BUG FIX (pedido explícito, "no quiero que se active al activar el
//     tracking, quiero que se vea visible sin el tracking") -- reusing
//     TrackingController.livePosition here meant the thumbnail only ever
//     showed the real map WHILE a trip was running, which is exactly the
//     opposite of what a "glance at where I am" dashboard widget should
//     do. Compact mode instead opens its OWN Geolocator position stream,
//     independent of trip state, started in initState and cancelled in
//     dispose -- lives only as long as this thumbnail is on screen.
//
// MIGRATION (2026-09-22): flutter_map + raw tile.openstreetmap.org ->
// MapLibre Native + the same self-hosted PMTiles basemap used everywhere
// else in the app now (see fleet_live_map_screen.dart's own header
// comment for the full OSM-policy reasoning). The rotating "you are
// here" puck stays a plain Flutter Icon + Transform.rotate overlaid at
// the map's fixed center -- NOT a MapLibre Symbol annotation -- since a
// Symbol needs a registered bitmap icon and this widget only ever shows
// one point (this driver, nowhere else), so a screen-fixed overlay that
// the map recenters under is both simpler and the standard "my location
// puck" pattern most nav UIs already use. The trip trail, which DOES
// need to track real geography as the map pans, is a real MapLibre Line
// annotation (controller.addLine), not a widget.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/tracking_controller.dart';

const String _pmtilesStyleAsset = 'assets/map/pmtiles_style.json';

/// Visible map credit (2026-10-01). OpenStreetMap data is ODbL: every map
/// showing it must credit "© OpenStreetMap contributors". Full-size maps
/// show this label; the tiny dashboard thumbnail relies on MapLibre's own
/// (i) attribution button, which OSM's guidelines allow for small maps.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: const Color(0xCCFFFFFF),
        child: const Text(
          '© OpenStreetMap contributors · Protomaps',
          style: TextStyle(fontSize: 10, color: Color(0xFF3D352A)),
        ),
      ),
    );
  }
}

class DriverLiveMapView extends StatefulWidget {
  // BUG FIX (pedido explícito, "mapa en tiempo real al lado de la card de
  // Vehicle"): esta clase ya existía pero no estaba wireada a ningún lado
  // (dead code) -- se usaba a tamaño completo, con pan/zoom del usuario.
  // `compact` la encoge para vivir como thumbnail dentro del header de
  // _buildVehicleCard en dashboard_screen.dart: desactiva los gestos del
  // mapa (el thumbnail vive dentro de su propio InkWell no-op, ver
  // dashboard_screen.dart -- un mapa interactivo ahí competiría por el
  // gesto de pan/zoom del usuario sin sentido en un cuadrito de 72px) y
  // cambia el estado vacío ("esperando GPS") de un bloque de texto
  // centrado a un ícono simple, que es lo único que cabe en ese tamaño.
  final bool compact;

  const DriverLiveMapView({super.key, this.compact = false});

  @override
  State<DriverLiveMapView> createState() => DriverLiveMapViewState();
}

class DriverLiveMapViewState extends State<DriverLiveMapView> {
  MapLibreMapController? _mapController;
  bool _didCenterOnce = false;
  Line? _trailLine;

  // Solo se usa en modo compact -- ver comentario de arriba.
  StreamSubscription<geo.Position>? _ownPositionSub;
  geo.Position? _ownPosition;

  // BUG FIX (pedido explícito, "el puntero no sigue la dirección... y que
  // ese seguimiento deje un rastro del viaje"): dos cosas separadas que el
  // marcador no hacía --
  //   1. Rotación: el ícono siempre apuntaba "hacia arriba" en el mapa sin
  //      importar hacia dónde manejaba el driver. Geolocator.Position ya
  //      trae `heading` (rumbo en grados, 0-360, desde el GPS
  //      course-over-ground) -- se usa para rotar el ícono con
  //      Transform.rotate. No disponible en modo full (TrackingController
  //      .livePosition es solo {lat,lng}, sin heading) -- ese modo sigue
  //      sin rotar, el resto de este archivo no lo toca.
  //   2. Rastro: se acumulan los fixes del propio stream de compact en
  //      _trail SOLO mientras hay un viaje activo (TrackingController
  //      .currentState != idle) -- en idle (antes/después de un viaje) el
  //      thumbnail es solo "dónde estoy ahora", sin rastro de un viaje ya
  //      terminado. Se limpia al volver a idle para que el próximo viaje
  //      arranque con un rastro vacío, no el del viaje anterior.
  double? _heading;
  final List<LatLng> _trail = [];

  // Full mode (TripRouteMapScreen, 2026-10-01): the route comes from
  // TrackingController.liveRoute (validated ticks of the ACTIVE trip), and
  // the driver's position is a MapLibre circle -- the map is pannable here,
  // so a screen-fixed puck would drift off the real position.
  Circle? _positionDot;
  bool _didFitRoute = false;

  @override
  void initState() {
    super.initState();
    // Both modes open their own GPS stream: compact for the "where am I"
    // glance, full so the expanded map also works with no trip running.
    _startOwnPositionStream();
    if (!widget.compact) {
      TrackingController.liveRoute.addListener(_onLiveRoute);
      TrackingController.livePosition.addListener(_syncPositionDot);
      _onLiveRoute();
    }
  }

  void _onLiveRoute() {
    _trail
      ..clear()
      ..addAll(TrackingController.liveRoute.value.map((p) => LatLng(p.lat, p.lng)));
    _syncTrail();
  }

  LatLng? get _currentPoint {
    final live = TrackingController.livePosition.value;
    if (live != null) return LatLng(live.lat, live.lng);
    final own = _ownPosition;
    return own == null ? null : LatLng(own.latitude, own.longitude);
  }

  // Annotations can only be added once the style is loaded (crash report
  // 2026-10-06: "This Annotation Manager has not been initialized" -- a GPS
  // fix arrived before the style). onStyleLoadedCallback syncs both.
  bool _styleLoaded = false;

  Future<void> _syncPositionDot() async {
    final controller = _mapController;
    final point = _currentPoint;
    if (widget.compact || controller == null || point == null || !_styleLoaded) return;
    if (_positionDot == null) {
      final c = Theme.of(context).colorScheme.primary.toARGB32() & 0xFFFFFF;
      _positionDot = await controller.addCircle(CircleOptions(
        geometry: point,
        circleRadius: 8,
        circleColor: '#${c.toRadixString(16).padLeft(6, '0')}',
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ));
    } else {
      await controller.updateCircle(_positionDot!, CircleOptions(geometry: point));
    }
  }

  /// Fits the whole route on screen (or centers on the driver when there is
  /// no route yet). Called once when the map loads and by the recenter button.
  Future<void> fitRoute() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_trail.length >= 2) {
      var minLat = _trail.first.latitude, maxLat = minLat;
      var minLng = _trail.first.longitude, maxLng = minLng;
      for (final p in _trail) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      await controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        left: 48, top: 48, right: 48, bottom: 48,
      ));
    } else if (_currentPoint != null) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPoint!, 16));
    }
  }

  Future<void> _startOwnPositionStream() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // No pide el permiso acá -- eso ya lo centraliza
      // PermissionRecoveryService en otro punto del flujo (onboarding,
      // arranque de viaje, el aviso pasivo del Dashboard). Si no está
      // concedido, el thumbnail simplemente se queda en el ícono
      // "buscando GPS" -- nunca lanza su propio diálogo de permisos.
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }

      // Primer fix inmediato -- no esperar al próximo tick del stream para
      // mostrar algo real. Con el vehículo detenido (el caso típico de
      // mirar el Dashboard antes de arrancar un viaje) un distanceFilter
      // puede tardar en disparar el primer evento del stream.
      final first = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _ownPosition = first);
      if (widget.compact) {
        _recenter(LatLng(first.latitude, first.longitude));
      } else {
        _syncPositionDot();
      }

      _ownPositionSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (!mounted) return;

        // BUG FIX (pedido explícito, "el mapa en coordinación con pausa/
        // reanudar... es ruido visual si está pausado el tracking y el
        // mapa sigue generando escritura"): el stream de GPS de este
        // thumbnail es independiente del ciclo de vida del viaje a
        // propósito (ver comentario de clase, "no quiero que se active
        // al activar el tracking") -- pero eso significaba que en pausa
        // el marcador seguía moviéndose y el rastro seguía creciendo,
        // como si el viaje siguiera corriendo. Ahora, en pausa, el fix
        // entrante se descarta por completo (ni posición, ni heading, ni
        // rastro se actualizan) -- el mapa queda congelado exactamente
        // donde estaba al pausar, y retoma en vivo solo al reanudar.
        if (TrackingController.currentState == TrackingState.paused) return;

        if (!widget.compact) {
          setState(() => _ownPosition = pos);
          _syncPositionDot();
          return;
        }

        setState(() {
          _ownPosition = pos;

          // heading == 0 legítimo (rumbo norte real) es indistinguible de
          // "sin dato" con esta API, pero -1 sí es un sentinel explícito de
          // "no disponible" en la mayoría de plugins de geolocalización --
          // se descarta ese caso, se acepta el resto del rango 0-360.
          if (pos.heading >= 0 && pos.heading <= 360) {
            _heading = pos.heading;
          }

          if (TrackingController.currentState == TrackingState.idle) {
            _trail.clear();
          } else {
            _trail.add(LatLng(pos.latitude, pos.longitude));
          }
        });
        _recenter(LatLng(pos.latitude, pos.longitude));
        _syncTrail();
      },
          // Crash report 2026-10-06/10-10 audit: with the phone's location
          // turned off the stream emits LocationServiceDisabledException,
          // which went uncaught. The map just keeps its last position.
          onError: (Object e) => debugPrint('[DriverLiveMapView] GPS stream: $e'));
    } catch (e) {
      debugPrint('[DriverLiveMapView] compact GPS stream error: $e');
    }
  }

  Future<void> _recenter(LatLng point) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_didCenterOnce) {
      _didCenterOnce = true;
      await controller.moveCamera(CameraUpdate.newLatLngZoom(point, 16));
    } else {
      await controller.animateCamera(CameraUpdate.newLatLng(point));
    }
  }

  Future<void> _syncTrail() async {
    final controller = _mapController;
    if (controller == null || _trail.length < 2 || !_styleLoaded) return;
    if (_trailLine == null) {
      _trailLine = await controller.addLine(
        LineOptions(geometry: _trail, lineColor: '#2C6C99', lineWidth: 3),
      );
    } else {
      await controller.updateLine(_trailLine!, LineOptions(geometry: _trail));
    }
  }

  @override
  void dispose() {
    if (!widget.compact) {
      TrackingController.liveRoute.removeListener(_onLiveRoute);
      TrackingController.livePosition.removeListener(_syncPositionDot);
    }
    _ownPositionSub?.cancel();
    super.dispose();
  }

  Widget _emptyState() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black12,
      child: widget.compact
          ? const Icon(Icons.location_searching_rounded,
              color: Colors.black38, size: 22)
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.read<AppState>().tr('waiting_for_gps'),
                style: const TextStyle(color: Colors.black54),
              ),
            ),
    );
  }

  Widget _map(LatLng point, Color primary, {double? heading}) {
    // Recentra en cada build con una posición nueva -- en modo compact ya
    // lo hace el propio listener del stream (_recenter después de cada
    // fix), pero en modo full (ValueListenableBuilder sobre
    // TrackingController.livePosition) este es el único punto donde una
    // posición nueva llega, así que el seguimiento en vivo tiene que
    // salir de acá. postFrameCallback porque el controller de un mapa
    // recién creado no está listo hasta después de este mismo build.
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.compact ? 18 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MapLibreMap(
            styleString: _pmtilesStyleAsset,
            initialCameraPosition: CameraPosition(target: point, zoom: 16),
            // Thumbnail no debe competir por el gesto con el InkWell no-op
            // que lo envuelve (ver dashboard_screen.dart) -- sin esto, un
            // drag sobre el thumbnail paneaba el mapa en vez de quedarse
            // quieto como una vista de solo lectura.
            rotateGesturesEnabled: !widget.compact,
            scrollGesturesEnabled: !widget.compact,
            tiltGesturesEnabled: !widget.compact,
            zoomGesturesEnabled: !widget.compact,
            doubleClickZoomEnabled: !widget.compact,
            // Full mode has a FAB at bottom-right; keep the (i) clear of it.
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            onMapCreated: (controller) {
              // A recreated map (first GPS fix switching the subtree) has
              // none of the previous controller's annotations.
              _trailLine = null;
              _positionDot = null;
              _didFitRoute = false;
              _styleLoaded = false;
              _mapController = controller;
              _didCenterOnce = true;
            },
            onStyleLoadedCallback: () async {
              _styleLoaded = true;
              await _syncTrail();
              if (!widget.compact) {
                await _syncPositionDot();
                if (!_didFitRoute) {
                  _didFitRoute = true;
                  await fitRoute();
                }
              }
            },
          ),
          if (!widget.compact)
            const Positioned(right: 0, top: 0, child: OsmAttribution()),
          if (widget.compact)
          IgnorePointer(
            // Rotación por rumbo (pedido explícito): sin heading (null,
            // full mode o compact antes del primer fix con rumbo real)
            // se queda apuntando hacia arriba, igual que antes.
            child: Transform.rotate(
              angle: (heading ?? 0) * math.pi / 180,
              child: Icon(Icons.navigation_rounded,
                  color: primary, size: widget.compact ? 18 : 34),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (widget.compact) {
      final pos = _ownPosition;
      if (pos == null) return _emptyState();
      return _map(LatLng(pos.latitude, pos.longitude), primary, heading: _heading);
    }

    // Full mode: built once with the first known point; after that the
    // camera is the driver's to pan, and the dot/route update in place.
    final point = _currentPoint;
    if (point == null) {
      return ValueListenableBuilder(
        valueListenable: TrackingController.livePosition,
        builder: (context, live, child) =>
            live == null ? _emptyState() : _map(LatLng(live.lat, live.lng), primary),
      );
    }
    return _map(point, primary);
  }
}
