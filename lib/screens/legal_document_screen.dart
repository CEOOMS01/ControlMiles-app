// Olympus Mont Systems LLC - ControlMiles
// lib/screens/legal_document_screen.dart
//
// Generic viewer for a legal document (Privacy Policy / Terms of Service).
// Body text is deliberately English-only -- see lib/legal/legal_documents.dart
// for why -- only the AppBar title routes through appState.tr().

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String titleKey;
  final String body;

  const LegalDocumentScreen({
    super.key,
    required this.titleKey,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          appState.tr(titleKey).toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          body,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
