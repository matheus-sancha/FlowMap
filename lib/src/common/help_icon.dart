/// The one way a field explains itself (DESIGN.md §12.7).
///
/// Field feedback, 2026-08-15: *"dial back with the explaining text for each
/// feature. It's too much, when needed add a mouse hover tooltip instead."*
///
/// The app had two conventions and this unifies them. The flow footer's metrics
/// were already help-on-hover with no visual affordance at all; every form field
/// carried a permanent `helperText` two or three lines deep, and a dialog of six
/// fields was mostly prose.
///
/// **The rule is about what the text does, not where it goes.** Help that
/// restates its own label was deleted rather than moved — moving it to a tooltip
/// only hides the fact that it was never earning the space. Help that carries a
/// *definition a wrong answer depends on* keeps an affordance and comes here:
/// what `days` means on a step, that a project's plant cannot be changed later,
/// that availability is applied once and to process time only.
///
/// _Rejected: every `helperText` to a bare `Tooltip` on the field, matching the
/// footer._ One convention everywhere and maximum quiet — but with no affordance
/// nobody hovers, so the definitions would be gone rather than moved, and the
/// `days` ambiguity §17.4 exists to prevent would be discoverable only by
/// accident.
/// _Rejected: deleting all of it._ It forces every label to stand alone, which
/// is a real discipline. But no label can make `days` unambiguous.
library;

import 'package:flutter/material.dart';

/// A tappable `ⓘ` carrying [message], for a field's `suffixIcon`.
///
/// Null when there is nothing to say, so a caller can pass an optional string
/// straight through without a conditional at every site.
///
/// **Tap as well as hover.** `TooltipTriggerMode.tap` costs nothing on a desktop
/// mouse and is the difference between discoverable and not for anyone driving
/// this on a touchscreen at the line side, which is where a current-state walk
/// actually happens.
Widget? helpIcon(BuildContext context, String? message) {
  if (message == null) return null;
  return Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    child: Icon(
      Icons.info_outline,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
