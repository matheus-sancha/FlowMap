import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/app_language.dart';
import '../../../common/date_input.dart';
import '../../../data/database/database_providers.dart';
import '../data/settings_repository.dart';

part 'settings_providers.g.dart';

@riverpod
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

/// The stored date format, defaulting to the locale before it has loaded.
///
/// **Never in a loading state to its readers.** Every date on every screen is
/// drawn through this, and a spinner where a need date should be — for the one
/// frame a key/value read takes — would be worse than a date in the format the
/// app used before there was a setting. The default is that same format, so
/// the frame before the value arrives is not wrong, only not yet personal.
final dateFormatSettingProvider = StreamProvider<DateFormatSetting>(
  (ref) => ref.watch(settingsRepositoryProvider).watchDateFormat(),
);

/// The stored language, defaulting to the platform before it has loaded.
///
/// **Never in a loading state to its readers**, on the same argument the date
/// format makes and with more at stake: this decides which strings the whole
/// tree is built from, and a spinner in place of the app for the one frame a
/// key/value read takes would be worse than one frame in the language the
/// platform would have chosen anyway — which is what the app did before §8.7.
final languageSettingProvider = StreamProvider<AppLanguage>(
  (ref) => ref.watch(settingsRepositoryProvider).watchLanguage(),
);

/// How this build should write and read dates: the setting, over the locale.
///
/// Reads the locale from [context] rather than from a provider, because
/// `Localizations` is the authority on it and a second copy in the provider
/// graph could disagree with what the widgets around it are rendering in.
DateStyle dateStyleOf(WidgetRef ref, BuildContext context) => DateStyle(
  locale: Localizations.localeOf(context).toString(),
  setting: ref
      .watch(dateFormatSettingProvider)
      .maybeWhen(data: (s) => s, orElse: () => DateFormatSetting.locale),
);
