/// The chosen date format, reachable from any widget (DESIGN.md §12.4).
///
/// **An `InheritedWidget` rather than a provider read at each site**, because
/// almost nothing that renders a date is a `Consumer` — the hover card, the run
/// header and the plan table are all plain widgets deep inside painted or
/// scrolled trees, and making each one a consumer to look up a display
/// preference would be a lot of plumbing for a value that never varies within a
/// frame. One `Consumer` at the root feeds this; everything below reads it the
/// way it already reads `Theme` and `Localizations`.
///
/// It also gets the invalidation right for free: changing the setting rebuilds
/// exactly the widgets that asked for it.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_providers.dart';
import 'date_input.dart';

class DateStyleScope extends InheritedWidget {
  const DateStyleScope({super.key, required this.style, required super.child});

  final DateStyle style;

  /// The style in force here.
  ///
  /// Falls back to the locale's own format when no scope is above — which is
  /// what a widget test that mounts one screen gets, and is the same format the
  /// app used before there was a setting. A test asserting a *chosen* format
  /// installs the scope; nothing else has to know it exists.
  static DateStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DateStyleScope>()?.style ??
      DateStyle(locale: Localizations.localeOf(context).toString());

  @override
  bool updateShouldNotify(DateStyleScope old) => old.style != style;
}

/// Installs [DateStyleScope] from the stored setting and the ambient locale.
///
/// Wraps the app below `MaterialApp`'s localizations, because the locale is
/// half of what it carries.
class DateStyleProvider extends ConsumerWidget {
  const DateStyleProvider({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DateStyleScope(
    style: dateStyleOf(ref, context),
    child: child,
  );
}
