// Olympus Mont Systems LLC - ControlMiles
// lib/screens/trip_route_map_screen.dart
//
// Expanded dashboard map (explicit user request, 2026-10-01): the driver's
// position and the route of the ACTIVE trip, full screen and pannable.
// With no trip running it is just "where am I".

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../widgets/driver_live_map_view.dart';

class TripRouteMapScreen extends StatefulWidget {
  const TripRouteMapScreen({super.key});

  @override
  State<TripRouteMapScreen> createState() => _TripRouteMapScreenState();
}

class _TripRouteMapScreenState extends State<TripRouteMapScreen> {
  // Kept in State so a rebuild never recreates the map.
  final mapKey = GlobalKey<DriverLiveMapViewState>();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(appState.tr('trip_route'))),
      body: DriverLiveMapView(key: mapKey),
      floatingActionButton: FloatingActionButton.small(
        tooltip: appState.tr('trip_route_fit'),
        onPressed: () => mapKey.currentState?.fitRoute(),
        child: const Icon(Icons.center_focus_strong_rounded),
      ),
    );
  }
}
