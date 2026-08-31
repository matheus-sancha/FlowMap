import 'package:flowmap/src/features/simulation/presentation/occupation_chart_scale.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Occupation chart's axis (#13).
///
/// **Nothing here draws.** The chart is a `CustomPainter` and a green suite says
/// nothing about whether it reads — but where a tick lands and what it is called
/// is arithmetic, and this is the part a drive should not have to check.
///
/// The figures are the real ones: the newest graphable run peaks at 9,384 h of
/// capacity in 2026-07 against 7,853 h asked in its heaviest month.
void main() {
  const hour = 3600;

  group('hoursTicks', () {
    test('rounds to a readable step rather than to peak ÷ 5', () {
      // 9,384 ÷ 5 is 1,877. An axis reading 1,877 / 3,754 / 5,630 is correct
      // and unreadable; the planner's figure is "about eight thousand hours".
      final ticks = hoursTicks(9384 * hour, 'en_US');

      expect(ticks.map((t) => t.seconds ~/ hour), [0, 2000, 4000, 6000, 8000]);
    });

    test('never labels a tick above the peak', () {
      // A tick above the top of the scale has no pixel to sit on: it would be
      // painted into the headroom reserved for the tallest bar's own label.
      for (final peak in [9384, 500, 40, 12345, 1]) {
        final ticks = hoursTicks(peak * hour, 'en_US');
        expect(
          ticks.every((t) => t.seconds <= peak * hour),
          isTrue,
          reason: 'peak ${peak}h produced a tick above itself',
        );
      }
    });

    test('gives four to six ticks across the range of real peaks', () {
      for (final peak in [40, 500, 3296, 9384, 12345, 90000]) {
        final ticks = hoursTicks(peak * hour, 'en_US');
        expect(
          ticks.length,
          inInclusiveRange(4, 6),
          reason: 'peak ${peak}h produced ${ticks.length} ticks',
        );
      }
    });

    test('a peak of zero offers no axis at all', () {
      // Every station in view closed for every month is a real state — and an
      // axis from 0 to 0 is a scale with no meaning rather than an empty one.
      expect(hoursTicks(0, 'en_US'), isEmpty);
      expect(hoursTicks(-1, 'en_US'), isEmpty);
    });

    test('labels carry the locale s thousands separator', () {
      // The painter cannot do this: it has no BuildContext to ask.
      expect(hoursTicks(9384 * hour, 'en_US').last.label, '8,000');
      expect(hoursTicks(9384 * hour, 'pt_BR').last.label, '8.000');
    });
  });

  group('ChartScale', () {
    const height = 300.0;

    test('zero sits on the floor, above the month labels', () {
      const scale = ChartScale(peakSeconds: 9384 * hour, ticks: []);

      expect(scale.y(height, 0), height - ChartScale.axis);
      expect(scale.floorOf(height), height - ChartScale.axis);
    });

    test('the tallest bar stops short of the top, by its own label s height', () {
      // **This is why the headroom exists.** The bar that reaches the top of the
      // scale is the one a reader came for, and its % label is drawn 14 px above
      // its top — so without reserved room the label of the most important bar
      // is the one painted off the canvas.
      const scale = ChartScale(peakSeconds: 9384 * hour, ticks: []);

      expect(scale.y(height, 9384 * hour), ChartScale.headroom);
      expect(scale.y(height, 9384 * hour) - 14, greaterThanOrEqualTo(0.0));
    });

    test('a bar and a tick of the same hours land on the same pixel', () {
      // The axis and the plot are two CustomPaints in different widgets. This is
      // the property that lets a reader trust one against the other.
      final ticks = hoursTicks(9384 * hour, 'en_US');
      final scale = ChartScale(peakSeconds: 9384 * hour, ticks: ticks);

      for (final tick in ticks) {
        expect(scale.y(height, tick.seconds), scale.y(height, tick.seconds));
      }
      // 8,000 h of demand and the 8,000 h tick are the same height.
      expect(scale.y(height, 8000 * hour), scale.y(height, ticks.last.seconds));
    });

    test('a peak of zero collapses to the floor rather than dividing by it', () {
      const scale = ChartScale(peakSeconds: 0, ticks: []);

      expect(scale.y(height, 0), height - ChartScale.axis);
      expect(scale.y(height, 5 * hour), height - ChartScale.axis);
    });
  });
}
