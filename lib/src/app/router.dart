import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../common/placeholder_screen.dart';
import '../features/diagnostics/application/diagnostics.dart';
import '../features/projects/presentation/project_workspace_screen.dart';
import '../features/projects/presentation/workspace_tabs.dart';
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
                      // The open study **and the open tab** are part of the
                      // location, so the window reopens where the user left off
                      // and one tab is linkable (#7). Five tabs that had no URL
                      // now have one each.
                      GoRoute(
                        path: 'studies/:studyId',
                        // **Redirected, not built.** A bare study is not a
                        // screen — it is whichever tab the reader was on — so
                        // it resolves to the first rather than rendering a
                        // sixth thing. The `RunBanner`, the sidebar and every
                        // stored location from before #7 point here, and all of
                        // them keep working.
                        //
                        // **Guarded on the bare path, and this was a defect.**
                        // A route-level redirect fires for the route's *own*
                        // sub-routes as well as for itself, so an unguarded one
                        // here caught `/studies/:s/settings` on its way past and
                        // sent it back to `/flow` — every study tab bounced to
                        // the first one. The URL changed and snapped back, which
                        // is why §15's breadcrumbs recorded five tabs being
                        // *asked for* while one was ever shown: the log holds
                        // the requested location, not the resolved one.
                        redirect: (context, state) {
                          final bare =
                              '/projects/'
                              '${state.pathParameters['projectId']}'
                              '/studies/'
                              '${state.pathParameters['studyId']}';
                          if (state.uri.path != bare) return null;
                          return '$bare/${StudyTab.flow.slug}';
                        },
                        routes: [
                          GoRoute(
                            path: ':tab',
                            builder: (context, state) => ProjectWorkspaceScreen(
                              projectId: state.pathParameters['projectId']!,
                              studyId: state.pathParameters['studyId'],
                              studyTab: StudyTab.fromSlug(
                                state.pathParameters['tab'],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Everything about the project that is not one of its
                      // studies — its fields, and the calendar that was never
                      // the study's (§4.3, §12.1). A destination rather than a
                      // dialog, for the same reason the run is one: it spans
                      // every study in the project, and a calendar is browsed
                      // rather than filled in and dismissed.
                      GoRoute(
                        path: 'settings',
                        builder: (context, state) => ProjectWorkspaceScreen(
                          projectId: state.pathParameters['projectId']!,
                          showSettings: true,
                        ),
                      ),
                      // **Redirected rather than deleted.** The window reopens
                      // where it was left (§12.1), so a session closed on the
                      // exceptions route would otherwise open on a 404 after
                      // an update — and the calendar is one section down.
                      GoRoute(
                        path: 'exceptions',
                        redirect: (context, state) =>
                            '/projects/${state.pathParameters['projectId']}'
                            '/settings',
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
                      //
                      // **And each of its five views is a location too** (#7).
                      // The run was one `setState` segmented button over three
                      // views; it is five tabs over five URLs, so a chart can
                      // be linked to and the window reopens on the one that was
                      // being read.
                      GoRoute(
                        path: 'simulation',
                        // The bare destination resolves to its first tab, the
                        // same shape a bare study takes — and **`?study=` is
                        // carried across**, or arriving from a study would drop
                        // the filter on the way in.
                        // Guarded on the bare path for the reason the study
                        // redirect above is: unguarded, this caught all five
                        // results tabs on the way past and sent every one of
                        // them back to the overview.
                        redirect: (context, state) {
                          final bare =
                              '/projects/'
                              '${state.pathParameters['projectId']}'
                              '/simulation';
                          if (state.uri.path != bare) return null;
                          final study = state.uri.queryParameters['study'];
                          return '$bare/${SimulationTab.overview.slug}'
                              '${study == null ? '' : '?study=$study'}';
                        },
                        routes: [
                          GoRoute(
                            path: ':tab',
                            builder: (context, state) => ProjectWorkspaceScreen(
                              projectId: state.pathParameters['projectId']!,
                              showSimulation: true,
                              simulationTab: SimulationTab.fromSlug(
                                state.pathParameters['tab'],
                              ),
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
