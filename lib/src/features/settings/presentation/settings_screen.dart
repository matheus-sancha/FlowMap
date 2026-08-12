/// App-wide preferences (DESIGN.md §12.4).
///
/// A `PlaceholderScreen` since M1. The date format is the first thing to earn a
/// place on it, and the shape it establishes — a titled group of rows, each a
/// control with its own help text — is what the next setting should follow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/date_input.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final setting = ref
        .watch(dateFormatSettingProvider)
        .maybeWhen(data: (s) => s, orElse: () => DateFormatSetting.locale);

    String label(DateFormatSetting value) => switch (value) {
      DateFormatSetting.locale => l10n.dateFormatLocale,
      DateFormatSetting.dayMonthYear => l10n.dateFormatDayMonthYear,
      DateFormatSetting.monthDayYear => l10n.dateFormatMonthDayYear,
      DateFormatSetting.isoDate => l10n.dateFormatIso,
    };

    // Today, in each format. A picker that offers `Day/month/year` and an
    // example of it is answering the question the user actually has, which is
    // what their own dates will look like rather than what the option is
    // called.
    final today = DateTime.now();
    String sample(DateFormatSetting value) =>
        DateStyle(locale: locale, setting: value).format(today);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.settingsDisplay, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsDateFormat,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.settingsDateFormatHelp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<DateFormatSetting>(
                    groupValue: setting,
                    onChanged: (chosen) {
                      if (chosen == null) return;
                      ref
                          .read(settingsRepositoryProvider)
                          .setDateFormat(chosen);
                    },
                    child: Column(
                      children: [
                        for (final value in DateFormatSetting.values)
                          RadioListTile<DateFormatSetting>(
                            value: value,
                            contentPadding: EdgeInsets.zero,
                            title: Text(label(value)),
                            subtitle: Text(sample(value)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
