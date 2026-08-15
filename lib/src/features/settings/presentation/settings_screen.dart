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
                  Row(
                    children: [
                      Text(
                        l10n.settingsDateFormat,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(width: 6),
                      // The paragraph that stood here is a tooltip now. It
                      // defines what `Locale` means, which the label does not —
                      // so it keeps an affordance rather than being deleted
                      // with the help that only restated its field.
                      Tooltip(
                        message: l10n.settingsDateFormatHelp,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // One control rather than four rows for four values. **The
                  // sample rides inside each item** — `Day/month/year ·
                  // 15/08/2026` — so the preview that made the radio list worth
                  // reading survives the collapse, including in the closed
                  // state, where it describes the current choice.
                  DropdownButtonFormField<DateFormatSetting>(
                    initialValue: setting,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in DateFormatSetting.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text('${label(value)} · ${sample(value)}'),
                        ),
                    ],
                    onChanged: (chosen) {
                      if (chosen == null) return;
                      ref
                          .read(settingsRepositoryProvider)
                          .setDateFormat(chosen);
                    },
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
