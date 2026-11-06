// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/trip_address_editor.dart
//
// "Fix the addresses" for one trip, from the place the driver is already in
// (right after End trip, or the uncategorized list). Only the street text
// changes; miles, times and coordinates stay as recorded.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';

class TripAddressEditor {
  TripAddressEditor._();

  static Future<void> edit(BuildContext context, String sectionId) async {
    final appState = context.read<AppState>();
    final client = Supabase.instance.client;
    try {
      final row = await client
          .from('session_sections')
          .select('start_address, end_address')
          .eq('id', sectionId)
          .maybeSingle();
      if (!context.mounted) return;
      final from = TextEditingController(text: (row?['start_address'] as String?) ?? '');
      final to = TextEditingController(text: (row?['end_address'] as String?) ?? '');
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.tr('address_edit_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: from, maxLength: 300, decoration: InputDecoration(labelText: appState.tr('address_from'))),
              TextField(controller: to, maxLength: 300, decoration: InputDecoration(labelText: appState.tr('address_to'))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(appState.tr('address_save'))),
          ],
        ),
      );
      if (save != true) return;
      await client.from('session_sections').update({
        'start_address': from.text.trim().isEmpty ? null : from.text.trim(),
        'end_address': to.text.trim().isEmpty ? null : to.text.trim(),
        'address_edited': true,
      }).eq('id', sectionId);
    } catch (e) {
      debugPrint('Address edit failed: $e');
    }
  }
}
