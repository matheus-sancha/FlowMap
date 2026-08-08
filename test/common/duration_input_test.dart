import 'package:flowmap/src/common/duration_input.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The forms DESIGN.md §12.4 promises a user can type, and the ones that must
/// be refused rather than guessed at.
void main() {
  group('parseDurationInput accepts', () {
    test('the clock form, with hours running past 24', () {
      expect(parseDurationInput('30:00:00'), const Duration(hours: 30));
      expect(parseDurationInput('1:30'), const Duration(minutes: 90));
      expect(parseDurationInput('0:00:45'), const Duration(seconds: 45));
    });

    test('a suffixed number', () {
      expect(parseDurationInput('1.5h'), const Duration(minutes: 90));
      expect(parseDurationInput('90min'), const Duration(minutes: 90));
      expect(parseDurationInput('90m'), const Duration(minutes: 90));
      expect(parseDurationInput('2d'), const Duration(hours: 48));
      expect(parseDurationInput('45s'), const Duration(seconds: 45));
    });

    test('a decimal comma, as a Portuguese or Spanish keyboard types it', () {
      expect(parseDurationInput('1,5h'), const Duration(minutes: 90));
    });

    test('a bare number, in the unit the caller names', () {
      expect(parseDurationInput('30'), const Duration(hours: 30));
      expect(
        parseDurationInput('30', bareUnit: DurationUnit.minutes),
        const Duration(minutes: 30),
      );
    });

    test('surrounding space and mixed case', () {
      expect(parseDurationInput('  1.5 H '), const Duration(minutes: 90));
    });
  });

  group('parseDurationInput refuses', () {
    test('a negative time, rather than clamping it', () {
      // §9 lists negative times among the import failures to report; a silent
      // clamp would put a number nobody typed into the table.
      expect(parseDurationInput('-5h'), isNull);
    });

    test('minutes and seconds past 59 in the clock form', () {
      expect(parseDurationInput('1:75'), isNull);
      expect(parseDurationInput('1:00:75'), isNull);
    });

    test('anything it cannot read', () {
      expect(parseDurationInput(''), isNull);
      expect(parseDurationInput('n/a'), isNull);
      expect(parseDurationInput('5 hours'), isNull);
      expect(parseDurationInput('1:2:3:4'), isNull);
    });
  });

  test('formatDurationInput round-trips through the parser', () {
    for (final duration in const [
      Duration(hours: 30),
      Duration(minutes: 90),
      Duration(seconds: 45),
      Duration(hours: 55, minutes: 2, seconds: 6),
      Duration.zero,
    ]) {
      expect(parseDurationInput(formatDurationInput(duration)), duration);
    }
  });

  test('formatDurationInput keeps hours past 24 as hours', () {
    // `30:00:00`, the way a VSM process box writes it — not `1 d 6 h`.
    expect(formatDurationInput(const Duration(hours: 30)), '30:00:00');
  });
}
