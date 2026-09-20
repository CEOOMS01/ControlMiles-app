// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/driver_live_map_view.dart
//
// A driver's own live-position map -- explicitly NOT the fleet-wide
// admin FleetLiveMapScreen (every vehicle + geofences). Just this
// driver's current position, moving in real time. Fed directly from
// TrackingController.livePosition, which is updated from the SAME
// antifraud-validated GPS ticks already driving the active trip -- no
// second location listener, no Supabase round-trip, genuinely
// real-time rather than polling.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  // mapa (el thumbnail vive dentro del InkWell de toda la card, que navega
  // a VehicleScreen -- un mapa interactivo ahí competiría por el gesto y
  // "atraparía" el tap en vez de dejarlo navegar) y cambia el estado vacío
  // ("esperando GPS") de un bloque de texto centrado a un ícono simple,
  // que es lo único que cabe en un cuadrito de ~64px.
  final bool compact;

  const DriverLiveMapView({super.key, this.compact = false});

  @override
  State<DriverLiveMapView> createState() => _DriverLiveMapViewState();
}

class _DriverLiveMapViewState extends State<DriverLiveMapView> {
  final _mapController = MapController();
  bool _didCenterOnce = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder(
      valueListenable: TrackingController.livePosition,
      builder: (context, position, _) {
        if (position == null) {
          return Container(
            alignment: Alignment.center,
            color: Colors.black12,
            child: widget.compact
                ? const Icon(Icons.location_searching_rounded,
                    color: Colors.black38, size: 22)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      appState.tr('waiting_for_gps'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
          );
        }

        final point = LatLng(position.lat, position.lng);

        // Re-center only once the map is actually built (mapController
        // isn't ready before the first frame) and then follow live --
        // WidgetsBinding.addPostFrameCallback avoids calling .move()
        // during this same build.
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
              // Thumbnail no debe competir por el gesto con el InkWell de
              // la card que lo envuelve (ver comentario en `compact` arriba)
              // -- sin esto, un drag sobre el thumbnail paneaba el mapa en
              // vez de activar el tap de navegación de la card.
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
      },
    );
  }
}
