// Olympus Mont Systems LLC - ControlMiles
// lib/views/work_type_screen.dart
//
// "How do you work?" (2026-11-04, Started / Basic accounts). One question, one
// tap: apps (then pick which ones) or general trips. What they answer decides
// what the carousel shows, so a driver who only works DoorDash sees General and
// DoorDash and nothing else. Text only, no icons. Premium keeps its own shift
// selector and never sees this screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../theme/cm_colors.dart';

class WorkTypeScreen extends StatefulWidget {
  /// Opened from Settings: can be closed without answering.
  final bool dismissible;
  const WorkTypeScreen({super.key, this.dismissible = false});

  @override
  State<WorkTypeScreen> createState() => _WorkTypeScreenState();
}

class _WorkTypeScreenState extends State<WorkTypeScreen> {
  bool _pickingApps = false;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<AppState>().selectedGigAppIds.where((id) => id != 'custom').toSet();
  }

  Future<void> _chooseGeneral(AppState appState) async {
    await appState.setWorkMode('general');
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _saveApps(AppState appState) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.tr('work_type_pick_one'))));
      return;
    }
    await appState.setSelectedGigAppIds(_selected.toList());
    await appState.setWorkMode('gig');
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _later(AppState appState) async {
    await appState.setWorkMode('all');
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final textColor = isDark ? Colors.white : CmColors.ink;
    final subColor = isDark ? Colors.white70 : CmColors.inkDim;
    final border = isDark ? CmColors.ink : CmColors.sand;
    final card = isDark ? CmColors.nightCard : Colors.white;

    Widget option(String titleKey, String hintKey, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appState.tr(titleKey),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 6),
                    Text(appState.tr(hintKey), style: TextStyle(fontSize: 14, height: 1.35, color: subColor)),
                  ],
                ),
              ),
            ),
          ),
        );

    final apps = GigAppCatalog.all.where((a) => a.id != 'custom').toList();

    return PopScope(
      canPop: widget.dismissible || _pickingApps,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pickingApps) setState(() => _pickingApps = false);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: _pickingApps
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appState.tr('work_type_pick_apps'),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
                      const SizedBox(height: 8),
                      Text(appState.tr('work_type_pick_apps_hint'),
                          style: TextStyle(fontSize: 14, height: 1.35, color: subColor)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final a in apps)
                              CheckboxListTile(
                                value: _selected.contains(a.id),
                                onChanged: (v) => setState(() => v == true ? _selected.add(a.id) : _selected.remove(a.id)),
                                title: Text(a.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                                activeColor: primary,
                                controlAffinity: ListTileControlAffinity.trailing,
                                contentPadding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => _saveApps(appState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(appState.tr('work_type_continue').toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appState.tr('work_type_title'),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, color: textColor)),
                      const SizedBox(height: 10),
                      Text(appState.tr('work_type_sub'),
                          style: TextStyle(fontSize: 15, height: 1.4, color: subColor)),
                      const SizedBox(height: 28),
                      option('work_type_gig', 'work_type_gig_hint', () => setState(() => _pickingApps = true)),
                      option('work_type_general', 'work_type_general_hint', () => _chooseGeneral(appState)),
                      const Spacer(),
                      Center(
                        child: TextButton(
                          onPressed: () => _later(appState),
                          child: Text(appState.tr('work_type_later'), style: TextStyle(color: subColor)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
