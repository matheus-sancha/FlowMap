import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/date_style_scope.dart';
import '../features/settings/application/settings_providers.dart';
import '../l10n/generated/app_localizations.dart';
import 'close_guard.dart';
import 'router.dart';
import 'startup_gate.dart';
import 'theme.dart';

class FlowMapApp extends ConsumerWidget {
  const FlowMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: FlowMapTheme.light(),
      darkTheme: FlowMapTheme.dark(),
      // **Both themes existed and neither was reachable.** Without a
      // `themeMode:` this followed Windows, so seeing the light palette meant
      // changing an OS-wide setting and changing it back — which is most of
      // why it went unlooked-at through four drive sittings.
      themeMode: ref
          .watch(themeModeSettingProvider)
          .maybeWhen(data: (m) => m.themeMode, orElse: () => ThemeMode.system),
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
      //
      // The startup gate sits inside it for the same reason: its sentences are
      // localized, and it is the first thing that can go wrong (#33).
      //
      // The close guard wraps the gate rather than sitting inside it: the window
      // refuses to close until the guard lets it, so a guard that failed to
      // mount behind a failed start would leave a window nobody can close.
      builder: (context, child) => CloseGuard(
        child: StartupGate(
          child: DateStyleProvider(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
