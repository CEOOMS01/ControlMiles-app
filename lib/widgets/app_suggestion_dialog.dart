// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/app_suggestion_dialog.dart
//
// "Don't see your app? Suggest it" (1.3.18). Drivers type the name of a gig
// app we do not list; the name is saved in gig_app_suggestions so the next
// catalog update can add the most requested ones.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';

class AppSuggestionDialog {
  AppSuggestionDialog._();

  /// A tile for the end of an app picker list.
  static Widget tile(BuildContext context, {Color? color}) {
    final appState = context.read<AppState>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.add_circle_outline_rounded, color: color),
      title: Text(appState.tr('suggest_app_tile'), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: () => show(context),
    );
  }

  static Future<void> show(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('suggest_app_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: appState.tr('suggest_app_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(appState.tr('suggest_app_send')),
          ),
        ],
      ),
    );
    if (name == null || name.length < 2) return;
    try {
      await Supabase.instance.client.from('gig_app_suggestions').insert({'app_name': name});
      messenger.showSnackBar(SnackBar(content: Text(appState.tr('suggest_app_thanks'))));
    } catch (e) {
      debugPrint('App suggestion failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(appState.tr('suggest_app_failed'))));
    }
  }
}
