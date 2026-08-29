import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/date_style_scope.dart';
import '../features/settings/application/settings_providers.dart';
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
      // **Null until somebody chooses**, which is what this had instead of a
      // setting: `MaterialApp` resolves the platform's locale against the list
      // above (§8.7). es and pt were translated and unreachable for as long as
      // that was the only path to them.
      locale: ref
          .watch(languageSettingProvider)
          .maybeWhen(data: (l) => l.locale, orElse: () => null),
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
