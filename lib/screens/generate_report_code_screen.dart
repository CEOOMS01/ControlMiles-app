// Olympus Mont Systems LLC - ControlMiles
// lib/screens/generate_report_code_screen.dart
//
// Explicit user requirement (2026-09-09): the Report Portal's whole pitch
// is "your tax preparer never needs to log in" -- but generating the code
// itself only ever lived on controlmiles-web's /portal/generate, which
// means the DRIVER had to log into the web to use it. Now that
// controlmiles.com is explicitly fleet-admin-only going forward (a gig
// driver should never need to touch the web at all), that's a real gap,
// not a minor inconvenience -- the feature's own marketing claim was
// broken for exactly the audience it's for. Calls the SAME
// generate_report_access_code RPC the web's /portal/generate already
// uses (see controlmiles-web/src/app/portal/generate/actions.ts) --
// same server-side logic, just a second real caller, not a re-implementation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../errors/app_error.dart';

class GenerateReportCodeScreen extends StatefulWidget {
  const GenerateReportCodeScreen({super.key});

  @override
  State<GenerateReportCodeScreen> createState() => _GenerateReportCodeScreenState();
}

class _GenerateReportCodeScreenState extends State<GenerateReportCodeScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isGenerating = false;
  String? _code;
  String? _error;
  Timer? _countdownTimer;
  int? _secondsLeft;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    void tick() {
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      if (mounted) setState(() => _secondsLeft = remaining < 0 ? 0 : remaining);
    }
    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) setState(() => _dateRange = picked);
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _code = null;
    });

    try {
      final result = await Supabase.instance.client.rpc(
        'generate_report_access_code',
        params: {
          'p_start_date': _dateRange.start.toIso8601String().split('T')[0],
          'p_end_date': _dateRange.end.toIso8601String().split('T')[0],
          'p_vehicle_id': null,
        },
      );

      final row = (result as List).isNotEmpty ? result.first as Map<String, dynamic> : null;
      if (row == null) throw Exception('empty_result');

      final expiresAt = DateTime.tryParse(row['expires_at'] as String? ?? '');
      if (mounted) {
        setState(() => _code = row['code'] as String);
        if (expiresAt != null) _startCountdown(expiresAt.toLocal());
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        final appState = context.read<AppState>();
        setState(() => _error = appError.display(appState.tr(appError.messageKey)));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    final appState = context.read<AppState>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appState.tr('copied_to_clipboard'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primary = Theme.of(context).colorScheme.primary;
    final dateFmt = DateFormat.yMMMd(appState.currentLanguage.code);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('generate_report_code_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              appState.tr('generate_report_code_body'),
              style: TextStyle(fontSize: 13.5, color: subTextColor, height: 1.4),
            ),
            const SizedBox(height: 24),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range_rounded, color: primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${dateFmt.format(_dateRange.start)} — ${dateFmt.format(_dateRange.end)}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: subTextColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        appState.tr('generate_report_code_button').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            if (_code != null) ...[
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      appState.tr('generate_report_code_your_code'),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _code!,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copyCode,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(appState.tr('copy')),
                    ),
                    if (_secondsLeft != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _secondsLeft! <= 0
                            ? appState.tr('generate_report_code_expired')
                            : appState.tr('generate_report_code_expires_in').replaceFirst(
                                '{mmss}',
                                '${_secondsLeft! ~/ 60}:${(_secondsLeft! % 60).toString().padLeft(2, '0')}',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: _secondsLeft! <= 0 ? Colors.red : subTextColor,
                          fontWeight: _secondsLeft! <= 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                appState.tr('generate_report_code_disclaimer'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: subTextColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
