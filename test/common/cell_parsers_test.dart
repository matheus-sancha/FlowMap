import 'package:flowmap/src/common/cell_parsers.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a typed cell accepts (DESIGN.md §9.2).
void main() {
  group('takt units', () {
    test('every language, and the abbreviations people actually type', () {
      // The whole point: a block pasted out of an English spreadsheet has to
      // land in a Portuguese UI, so the parser is language-independent even
      // though the display is not.
      for (final word in ['d', 'day', 'days', 'dia', 'dias', 'día', 'días']) {
        expect(parseTaktUnit(word), TaktUnit.days, reason: word);
      }
      for (final word in ['h', 'hr', 'hour', 'hours', 'hora', 'horas']) {
        expect(parseTaktUnit(word), TaktUnit.hours, reason: word);
      }
      for (final word in ['m', 'min', 'minutes', 'minutos']) {
        expect(parseTaktUnit(word), TaktUnit.minutes, reason: word);
      }
      for (final word in ['s', 'sec', 'seconds', 'segundos']) {
        expect(parseTaktUnit(word), TaktUnit.seconds, reason: word);
      }
    });

    test('case and accents do not decide the answer', () {
      // A Spanish keyboard is not a given on a shop floor, so `dias` has to
      // reach the same place as `días`.
      expect(parseTaktUnit('DAYS'), TaktUnit.days);
      expect(parseTaktUnit('Días'), TaktUnit.days);
      expect(parseTaktUnit('dias'), TaktUnit.days);
      expect(parseTaktUnit('  Horas '), TaktUnit.hours);
    });

    test('a word it does not know is refused, not guessed', () {
      // §9.2's rule: forgiving is not the same as guessing. `w` could be weeks,
      // which this app has no concept of, and inventing one silently is how a
      // figure ends up wrong by a factor of seven.
      for (final word in ['', 'w', 'weeks', 'jours', 'x', '3']) {
        expect(parseTaktUnit(word), isNull, reason: word);
      }
    });
  });

  group('fractions', () {
    test('a percentage, a bare number and a fraction all land', () {
      expect(parseFraction('74%'), closeTo(0.74, 1e-9));
      expect(parseFraction('74'), closeTo(0.74, 1e-9));
      expect(parseFraction('0.74'), closeTo(0.74, 1e-9));
      // Both other languages write the decimal with a comma, and rejecting it
      // would leave the parser wrong in two of the three locales shipped.
      expect(parseFraction('0,74'), closeTo(0.74, 1e-9));
      expect(parseFraction('3,7 %'), closeTo(0.037, 1e-9));
    });

    test('1 and 100 are both 100 %', () {
      // The one place the ranges touch. A station at 1 % is not what anyone
      // means, so `1` reads as the whole of it.
      expect(parseFraction('1'), 1.0);
      expect(parseFraction('100'), 1.0);
      expect(parseFraction('100%'), 1.0);
    });

    test('an explicit sign is believed even when it is unlikely', () {
      // `0.5%` is half a percent because the user wrote the symbol. Without it,
      // `0.5` is half. The sign is the whole difference and it is honoured.
      expect(parseFraction('0.5%'), closeTo(0.005, 1e-9));
      expect(parseFraction('0.5'), closeTo(0.5, 1e-9));
    });

    test('nonsense and out-of-range are refused', () {
      for (final text in ['', 'abc', '-5', '101', '250%', '%']) {
        expect(parseFraction(text), isNull, reason: text);
      }
    });

    test('what goes in comes back out canonically', () {
      expect(formatFraction(0.74), '74 %');
      expect(formatFraction(1), '100 %');
      // One decimal only when there is one, so a column scanned for the odd
      // value out is not a wall of `.0`.
      expect(formatFraction(0.037), '3.7 %');
      expect(formatFraction(0), '0 %');
    });

    test('round trips through the format it displays', () {
      for (final fraction in [0.0, 0.037, 0.5, 0.74, 1.0]) {
        expect(
          parseFraction(formatFraction(fraction)),
          closeTo(fraction, 1e-9),
          reason: '$fraction',
        );
      }
    });
  });

  group('numbers', () {
    test('positive only, comma accepted', () {
      expect(parsePositive('3'), 3);
      expect(parsePositive('2,5'), 2.5);
      expect(parsePositive('0'), isNull);
      expect(parsePositive('-1'), isNull);
      expect(parsePositive('abc'), isNull);
    });

    test('a whole number is written the way it is spoken', () {
      expect(formatNumber(3), '3');
      expect(formatNumber(2.5), '2.5');
    });
  });
}
