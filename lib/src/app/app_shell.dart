import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/application/documents_providers.dart';
import '../features/documents/presentation/save_indicator.dart';
import '../l10n/generated/app_localizations.dart';

/// The persistent left rail around the top-level destinations (DESIGN.md §12.1).
///
/// Windows-only app with a 1100px minimum window, so this is always a rail —
/// there is no width at which a bottom bar would be the right answer. Branch
/// state is preserved across switches by go_router's [StatefulNavigationShell],
/// which is what lets a user glance at Resources mid-study and come back to the
/// same place.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // **Resources belongs to the open document** (#37). The plant *is* the
    // document, so with nothing open there is no plant to show — and what used
    // to be shown was the last document's, left behind and belonging to
    // nothing. Settings stays reachable because the theme, the language and
    // About are genuinely the machine's.
    final hasDocument = ref.watch(openDocumentProvider) != null;
    final destinations = <_Destination>[
      _Destination(Icons.folder_outlined, Icons.folder, l10n.navProjects),
      _Destination(
        Icons.dashboard_outlined,
        Icons.dashboard,
        l10n.navTemplates,
      ),
      _Destination(
        Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing,
        l10n.navResources,
        enabled: hasDocument,
        disabledTooltip: l10n.resourcesNeedDocument,
      ),
      _Destination(Icons.settings_outlined, Icons.settings, l10n.navSettings),
      // §12 reserved this slot and it was never filled (#32).
      _Destination(Icons.info_outline, Icons.info, l10n.navAbout),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            // Tapping the current destination returns it to its root, which is
            // the escape hatch from a deep study workspace.
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Tooltip(
                    message: d.enabled ? '' : d.disabledTooltip ?? '',
                    child: Icon(d.icon),
                  ),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                  disabled: !d.enabled,
                ),
            ],
            // Under the rail, where it is always visible and never in the way:
            // the save state belongs to the window rather than to any one
            // screen, because every screen can change the document (#37).
            trailing: const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SaveIndicator(),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(
    this.icon,
    this.selectedIcon,
    this.label, {
    this.enabled = true,
    this.disabledTooltip,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool enabled;

  /// Says *why* rather than just refusing — a greyed rail entry with no
  /// explanation is the shape of §12.7's complaint.
  final String? disabledTooltip;
}
