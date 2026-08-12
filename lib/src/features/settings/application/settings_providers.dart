import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
