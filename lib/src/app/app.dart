import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/date_style_scope.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class FlowMapApp extends ConsumerWidget {
  const FlowMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: FlowMapTheme.light(),
      darkTheme: FlowMapTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // Inside the app rather than around it: the scope needs the locale, and
      // the locale is only decided once `MaterialApp` has resolved it against
      // `supportedLocales`. Above this, `Localizations.localeOf` is the
      // platform's answer rather than the app's.
      builder: (context, child) =>
          DateStyleProvider(child: child ?? const SizedBox.shrink()),
    );
  }
}
