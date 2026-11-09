// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/trip_route_image.dart
//
// A trip's route map inside the History list (2026-11-04): the same image the
// PDF report uses (/api/trip-map, our own basemap), loaded only when the driver
// asks for it so a long list does not download dozens of images.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import 'brand_loader.dart';

/// The route picture of a trip, or of one segment of it. `v` is the drawing's
/// version: closed trips are cached for a year, so a new drawing needs a new address.
String tripMapUrl(String sessionId, String mapToken, {String? sectionId}) =>
    'https://controlmiles.com/api/trip-map/$sessionId/$mapToken?${sectionId == null ? '' : 'section=$sectionId&'}lite=1&v=2';

class TripRouteImage extends StatefulWidget {
  final String sessionId;
  final String mapToken;
  const TripRouteImage({super.key, required this.sessionId, required this.mapToken});

  @override
  State<TripRouteImage> createState() => _TripRouteImageState();
}

class _TripRouteImageState extends State<TripRouteImage> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          child: Text(
            appState.tr(_open ? 'route_map_hide' : 'route_map_show'),
            style: TextStyle(color: primary, fontWeight: FontWeight.w600),
          ),
        ),
        if (_open)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 640 / 360,
              child: SvgPicture.network(
                tripMapUrl(widget.sessionId, widget.mapToken),
                fit: BoxFit.cover,
                placeholderBuilder: (_) => const Center(child: BrandLoader(size: 36)),
              ),
            ),
          ),
      ],
    );
  }
}
