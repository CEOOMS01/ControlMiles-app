// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/trip_edits.dart
//
// What the driver can change on a finished trip, shared by the pop-up over the
// Dashboard and the trips list: the category, the two street addresses and the
// note. Miles, times and coordinates are never touched (the server freezes them).
// Each call changes the [TripData] in place and returns true when something was saved.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';
import '../logic/app_state.dart';
import 'trip_card.dart';

class TripEdits {
  TripEdits._();

  static void showError(BuildContext context, Object e) {
    debugPrint('[TripEdits] $e');
    if (!context.mounted) return;
    final appState = context.read<AppState>();
    final err = AppError.from(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err.display(appState.tr(err.messageKey))), backgroundColor: Colors.red.shade700),
    );
  }

  /// Sets the category on every General section of the trip.
  static Future<bool> setPurpose(BuildContext context, TripData trip, String purpose) async {
    final ids = [for (final s in trip.sections) if (s.gigApp == 'custom') s.id];
    if (ids.isEmpty) return false;
    try {
      await Supabase.instance.client.from('session_sections').update({'irs_purpose': purpose}).inFilter('id', ids);
      for (var i = 0; i < trip.sections.length; i++) {
        if (trip.sections[i].gigApp == 'custom') trip.sections[i] = trip.sections[i].copyWith(irsPurpose: purpose);
      }
      return true;
    } catch (e) {
      if (context.mounted) showError(context, e);
      return false;
    }
  }

  /// Fixes where the trip started (first section) and ended (last section).
  static Future<bool> editAddresses(BuildContext context, TripData trip) async {
    if (trip.sections.isEmpty) return false;
    final appState = context.read<AppState>();
    final from = TextEditingController(text: trip.fromAddress ?? '');
    final to = TextEditingController(text: trip.toAddress ?? '');
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
    if (save != true) return false;
    final start = from.text.trim().isEmpty ? null : from.text.trim();
    final end = to.text.trim().isEmpty ? null : to.text.trim();
    try {
      final client = Supabase.instance.client;
      await client
          .from('session_sections')
          .update({'start_address': start, 'address_edited': true}).eq('id', trip.sections.first.id);
      await client
          .from('session_sections')
          .update({'end_address': end, 'address_edited': true}).eq('id', trip.sections.last.id);
      trip.sections[0] = trip.sections.first.copyWith(startAddress: start, addressEdited: true);
      final last = trip.sections.length - 1;
      trip.sections[last] = trip.sections.last.copyWith(endAddress: end, addressEdited: true);
      return true;
    } catch (e) {
      if (context.mounted) showError(context, e);
      return false;
    }
  }

  /// A short free-text note (never changes miles).
  static Future<bool> editNote(BuildContext context, TripData trip) async {
    if (trip.sections.isEmpty) return false;
    final appState = context.read<AppState>();
    final section = trip.sections.first;
    final controller = TextEditingController(text: section.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr((section.notes ?? '').isEmpty ? 'add_note' : 'edit_note')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          autofocus: true,
          decoration: InputDecoration(hintText: appState.tr('trip_note_hint'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(appState.tr('save'))),
        ],
      ),
    );
    if (result == null) return false;
    try {
      await Supabase.instance.client
          .from('session_sections')
          .update({'notes': result.isEmpty ? null : result}).eq('id', section.id);
      trip.sections[0] = result.isEmpty ? section.copyWith(clearNotes: true) : section.copyWith(notes: result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.tr('note_saved_success'))));
      }
      return true;
    } catch (e) {
      if (context.mounted) showError(context, e);
      return false;
    }
  }
}
