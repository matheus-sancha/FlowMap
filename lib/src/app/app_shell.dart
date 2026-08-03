import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';

/// The persistent left rail around the top-level destinations (DESIGN.md §12.1).
///
/// Windows-only app with a 1100px minimum window, so this is always a rail —
/// there is no width at which a bottom bar would be the right answer. Branch
/// state is preserved across switches by go_router's [StatefulNavigationShell],
/// which is what lets a user glance at Resources mid-study and come back to the
/// same place.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      ),
      _Destination(Icons.settings_outlined, Icons.settings, l10n.navSettings),
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
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
