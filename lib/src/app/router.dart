import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../common/placeholder_screen.dart';
import '../features/diagnostics/application/diagnostics.dart';
import '../features/projects/presentation/project_workspace_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/resources/presentation/resources_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_shell.dart';

part 'router.g.dart';

/// The app router (DESIGN.md §12.1). Four top-level branches live inside a
/// stateful shell so each keeps its own navigation stack.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: '/projects',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':projectId',
                    builder: (context, state) => ProjectWorkspaceScreen(
                      projectId: state.pathParameters['projectId']!,
                    ),
                    routes: [
                      // The open study is part of the location, so the window
                      // reopens where the user left off and a study is
                      // linkable.
                      GoRoute(
                        path: 'studies/:studyId',
                        builder: (context, state) => ProjectWorkspaceScreen(
                          projectId: state.pathParameters['projectId']!,
                          studyId: state.pathParameters['studyId'],
                        ),
                      ),
                      // The **only** place a run is read (§12.1), and a place
                      // rather than an overlay, so it is linkable and the
                      // window reopens on it.
                      //
                      // `?study=` is how a study reaches its own slice now that
                      // its Simulation tab is gone: one optional param, so
                      // arriving from a study pre-selects that study's filter
                      // and the one-click path survives. Only the study is in
                      // the location — the other three filters stay view state,
                      // which is a smaller thing than moving a date range into
                      // a URL and is the one filter you navigate *from*.
                      GoRoute(
                        path: 'simulation',
                        builder: (context, state) => ProjectWorkspaceScreen(
                          projectId: state.pathParameters['projectId']!,
                          showSimulation: true,
                          simulationStudyId:
                              state.uri.queryParameters['study'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/templates',
                builder: (context, state) => PlaceholderScreen(
                  title: AppLocalizations.of(context).navTemplates,
                  icon: Icons.dashboard_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                builder: (context, state) => const ResourcesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Route breadcrumbs (DESIGN.md §15). Taken from the route information
  // provider rather than a NavigatorObserver, because that yields the actual
  // location string — go_router does not guarantee a `Route.settings.name`.
  // Locations carry ids, never plant or part names, per the ids-only rule.
  final routes = router.routeInformationProvider;
  // The initial location is logged explicitly: `addListener` only fires on
  // change, so without this the session's first screen — the one the user was
  // looking at when something went wrong on launch — is the one route missing.
  Diag.event('route', routes.value.uri.path);
  routes.addListener(() => Diag.event('route', routes.value.uri.path));

  return router;
}
