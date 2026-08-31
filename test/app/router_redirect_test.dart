import 'package:flowmap/src/features/projects/presentation/workspace_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// **The bug this file exists for: a route-level redirect fires for the route's
/// own sub-routes, not only for the route itself.**
///
/// #7 gave `/studies/:s` and `/simulation` a redirect apiece so a bare location
/// resolves to its first tab. Unguarded, each one also caught every *child* on
/// the way past — `/studies/:s/settings` was sent back to `/flow`, and all five
/// results tabs back to `/overview`. Every tab in the app appeared dead: the URL
/// changed and snapped back within the same frame.
///
/// **It survived a drive**, because §15's breadcrumbs log
/// `routeInformationProvider.value`, which is the location that was *asked for*
/// rather than the one that was resolved. The log showed five results tabs being
/// reached while one was ever shown — so the trace that looked like evidence
/// was recording the request, not the arrival.
///
/// The shape is reproduced here rather than the app's own router mounted,
/// because the real one needs a database, a shell and six providers to build —
/// none of which is what this is about. What must match is the *nesting*: a
/// parent with a builder, a redirecting child, and a `:tab` under that.
void main() {
  /// The guard both real redirects use: redirect only when the location is the
  /// bare path itself.
  GoRouter buildRouter({required bool guarded}) => GoRouter(
    initialLocation: '/projects/p1/studies/s1/${StudyTab.flow.slug}',
    routes: [
      GoRoute(
        path: '/projects/:projectId',
        builder: (context, state) => const _Body(tab: 'project'),
        routes: [
          GoRoute(
            path: 'studies/:studyId',
            redirect: (context, state) {
              final bare =
                  '/projects/${state.pathParameters['projectId']}'
                  '/studies/${state.pathParameters['studyId']}';
              if (guarded && state.uri.path != bare) return null;
              return '$bare/${StudyTab.flow.slug}';
            },
            routes: [
              GoRoute(
                path: ':tab',
                builder: (context, state) =>
                    _Body(tab: state.pathParameters['tab']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  testWidgets('an unguarded redirect swallows every sibling tab', (
    tester,
  ) async {
    // The regression itself, asserted so the reason for the guard is on the
    // record rather than only in a comment.
    final router = buildRouter(guarded: false);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/projects/p1/studies/s1/${StudyTab.settings.slug}');
    await tester.pumpAndSettle();

    expect(
      router.state.uri.path,
      '/projects/p1/studies/s1/${StudyTab.flow.slug}',
      reason: 'this is the defect: the child match is redirected away',
    );
    expect(find.text('body:${StudyTab.settings.slug}'), findsNothing);
  });

  testWidgets('guarded, a sibling tab is reached and rendered', (tester) async {
    final router = buildRouter(guarded: true);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('body:${StudyTab.flow.slug}'), findsOne);

    for (final tab in StudyTab.values) {
      router.go('/projects/p1/studies/s1/${tab.slug}');
      await tester.pumpAndSettle();

      expect(
        router.state.uri.path,
        '/projects/p1/studies/s1/${tab.slug}',
        reason: '${tab.slug} must survive the parent redirect',
      );
      // **And the body actually changed.** Asserting the location alone is what
      // the drive did, and the location was the one thing that looked right.
      expect(find.text('body:${tab.slug}'), findsOne);
    }
  });

  testWidgets('guarded, the bare location still resolves to the first tab', (
    tester,
  ) async {
    // The guard must not cost the redirect its actual job: the sidebar's study
    // link and every location stored before #7 point at the bare path.
    final router = buildRouter(guarded: true);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/projects/p1/studies/s1/${StudyTab.demand.slug}');
    await tester.pumpAndSettle();
    expect(find.text('body:${StudyTab.demand.slug}'), findsOne);

    router.go('/projects/p1/studies/s1');
    await tester.pumpAndSettle();

    expect(
      router.state.uri.path,
      '/projects/p1/studies/s1/${StudyTab.flow.slug}',
    );
    expect(find.text('body:${StudyTab.flow.slug}'), findsOne);
  });
}

class _Body extends StatelessWidget {
  const _Body({required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('body:$tab')));
}
