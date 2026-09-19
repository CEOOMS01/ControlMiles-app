// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/gig_app_shift_selector_sheet.dart
//
// Premium-exclusive "select gig apps for working shift" (explicit user
// request, 2026-09-18): lets a Premium Gig driver narrow auto-detect down
// to a subset of GigAppCatalog.all instead of watching every platform in
// the carousel. The actual filtering lives in
// AutoTripDetectionService._isFilteredOutByShiftSelection -- this sheet is
// only the UI for choosing/persisting that subset via
// AppState.setSelectedGigAppIds. 'custom' is deliberately left out of the
// list: auto-detect can never resolve to it anyway (see
// AutoTripDetectionService's own 'custom' guards), so offering it here
// would just be a checkbox that can never do anything.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';

Future<void> showGigAppShiftSelectorSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _GigAppShiftSelectorSheet(),
  );
}

class _GigAppShiftSelectorSheet extends StatefulWidget {
  const _GigAppShiftSelectorSheet();

  @override
  State<_GigAppShiftSelectorSheet> createState() =>
      _GigAppShiftSelectorSheetState();
}

class _GigAppShiftSelectorSheetState
    extends State<_GigAppShiftSelectorSheet> {
  late Set<String> _selected;

  static final List<GigApp> _selectableApps =
      GigAppCatalog.all.where((app) => app.id != 'custom').toList();

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _selected = appState.selectedGigAppIds.toSet();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    await appState.setSelectedGigAppIds(_selected.toList());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appState.tr('shift_apps_picker_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selected.clear()),
                      child: Text(appState.tr('shift_apps_picker_clear')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  appState.tr('shift_apps_picker_body'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _selectableApps.length,
                itemBuilder: (ctx, i) {
                  final app = _selectableApps[i];
                  final checked = _selected.contains(app.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (_) => _toggle(app.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: CircleAvatar(
                      backgroundColor: app.color,
                      child: Icon(app.icon, color: Colors.white, size: 18),
                    ),
                    title: Text(app.name),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(appState.tr('shift_apps_picker_save')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
