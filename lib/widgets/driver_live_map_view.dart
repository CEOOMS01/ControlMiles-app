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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/tracking_controller.dart';

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
  State<DriverLiveMapView> createState() => _DriverLiveMapViewState();
}

class _DriverLiveMapViewState extends State<DriverLiveMapView> {
  final _mapController = MapController();
  bool _didCenterOnce = false;

  // Solo se usa en modo compact -- ver comentario de arriba.
  StreamSubscription<geo.Position>? _ownPositionSub;
  geo.Position? _ownPosition;

  @override
  void initState() {
    super.initState();
    if (widget.compact) {
      _startOwnPositionStream();
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

      _ownPositionSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (mounted) setState(() => _ownPosition = pos);
      });
    } catch (e) {
      debugPrint('[DriverLiveMapView] compact GPS stream error: $e');
    }
  }

  @override
  void dispose() {
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

  Widget _map(LatLng point, Color primary) {
    // Re-center only once the map is actually built (mapController isn't
    // ready before the first frame) and then follow live --
    // WidgetsBinding.addPostFrameCallback avoids calling .move() during
    // this same build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, _didCenterOnce ? _mapController.camera.zoom : 16);
      _didCenterOnce = true;
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16,
          // Thumbnail no debe competir por el gesto con el InkWell no-op
          // que lo envuelve (ver dashboard_screen.dart) -- sin esto, un
          // drag sobre el thumbnail paneaba el mapa en vez de quedarse
          // quieto como una vista de solo lectura.
          interactionOptions: widget.compact
              ? const InteractionOptions(flags: InteractiveFlag.none)
              : const InteractionOptions(),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.olympusmont.controlmiles',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: widget.compact ? 22 : 40,
                height: widget.compact ? 22 : 40,
                child: Icon(Icons.navigation_rounded,
                    color: primary, size: widget.compact ? 18 : 34),
              ),
            ],
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
      return _map(LatLng(pos.latitude, pos.longitude), primary);
    }

    return ValueListenableBuilder(
      valueListenable: TrackingController.livePosition,
      builder: (context, position, _) {
        if (position == null) return _emptyState();
        return _map(LatLng(position.lat, position.lng), primary);
      },
    );
  }
}
