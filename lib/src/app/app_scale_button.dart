import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import 'app_scale.dart';
import 'app_scale_setting.dart';

/// The one control for the app-wide scale (#51), at the foot of the rail.
///
/// **Under the rail because the scale belongs to the window, not to a screen.**
/// That is #37's argument for putting `SaveIndicator` here, and it applies
/// unchanged: the rail is the only chrome present on every screen, so this is
/// reachable from Projects and Settings as well as from a study. It also keeps
/// it off the bottom-right corner, where the VSM canvas's own zoom card already
/// lives — two zoom controls stacked in one corner is how someone comes to zoom
/// the wrong thing.
///
/// **The percentage alone, with no icon.** The rail already carries six
/// destinations and a save line; a glyph beside the number would be decoration.
/// The cost is that it sits under a timestamp and is the only bare figure in
/// the chrome, which the tooltip answers on hover rather than a permanent icon
/// answering it for everyone forever.
///
/// **Always visible, including at 100 %.** §12 says a permanently dead control
/// is worse than an absent one, and this resolves the other way for the reason
/// that rule exists: there is no keyboard shortcut and no Settings row (#48), so
/// hiding this at 100 % would make the scale unreachable rather than merely
/// tidy. It is never dead — every step is always takeable.
///
/// **There is no Reset item**, because 100 % is one of the steps and the check
/// mark shows where you are (#49).
///
/// *Its layout does not change with the scale.* Everything scales uniformly, so
/// in the tree this is always the same number of logical pixels inside the same
/// rail; only its physical size moves, which is what #49's walk judged.
class AppScaleButton extends ConsumerWidget {
  const AppScaleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(appScaleSettingProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // Locale-formatted rather than '$n %': en writes 80%, pt and es write 80 %
    // with a non-breaking space, and inventing a convention here would make the
    // one number in the chrome the one that ignores §12.4.
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );

    return MenuAnchor(
      menuChildren: [
        for (final step in AppScale.steps)
          MenuItemButton(
            // A blank of the same size when unselected, so the numbers stay in
            // one column instead of shifting by a tick.
            leadingIcon: SizedBox.square(
              dimension: 18,
              child: step == scale
                  ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                  : null,
            ),
            onPressed: () =>
                ref.read(appScaleSettingProvider.notifier).set(step),
            child: Text(percent.format(step)),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: l10n.navScaleTooltip,
        child: TextButton(
          // Sized and padded to match `SaveIndicator`'s `_Line` above it, so
          // the foot of the rail reads as two rows of one thing rather than a
          // label and a button.
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: muted,
            textStyle: theme.textTheme.labelSmall,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Text(percent.format(scale)),
        ),
      ),
    );
  }
}
