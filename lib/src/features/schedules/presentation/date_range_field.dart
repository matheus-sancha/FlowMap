import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The start/end pair every schedule period carries.
///
/// Dates are picked, not typed: a period boundary is the one field where a
/// typo silently produces a gap or an overlap rather than a visible error, and
/// the picker cannot produce 31 February.
class DateRangeField extends StatelessWidget {
  const DateRangeField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final DateTime start;
  final DateTime end;
  final void Function(DateTime start, DateTime end) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _DateButton(
            label: l10n.fieldStart,
            value: start,
            onPicked: (picked) => onChanged(
              picked,
              // Keeping end ≥ start here means the "ends before it starts"
              // error can only be reached deliberately.
              end.isBefore(picked) ? picked : end,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateButton(
            label: l10n.fieldEnd,
            value: end,
            onPicked: (picked) => onChanged(start, picked),
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            // Wide enough for a study that reaches back a year and forward a
            // decade; narrow enough that a mis-scroll cannot land in 1970.
            firstDate: DateTime(value.year - 5),
            lastDate: DateTime(value.year + 10, 12, 31),
          );
          if (picked != null) {
            onPicked(DateTime(picked.year, picked.month, picked.day));
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dates.format(value)),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
