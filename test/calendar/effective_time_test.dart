import 'package:flowmap/src/features/calendar/application/effective_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveProcessTime', () {
    test('the worked example from the design: 10 h at 74 % / 3.7 %', () {
      // 10 × 1.037 ÷ 0.74 = 14.0135… h = 14 h 00 m 48.6 s
      final effective = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 10),
        batchSize: 1,
        availability: 0.74,
        rework: 0.037,
      );
      expect(effective.inSeconds, closeTo(50448, 1));
    });

    test('scales linearly with batch size', () {
      final one = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 2),
        batchSize: 1,
        availability: 0.8,
      );
      final ten = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 2),
        batchSize: 10,
        availability: 0.8,
      );
      expect(ten.inMicroseconds, one.inMicroseconds * 10);
    });

    test('perfect availability and no rework is the process time itself', () {
      expect(
        effectiveProcessTime(
          processTimePerPiece: const Duration(hours: 3),
          batchSize: 1,
          availability: 1,
        ),
        const Duration(hours: 3),
      );
    });

    test('rework inflates, availability inflates', () {
      const base = Duration(hours: 1);
      expect(
        effectiveProcessTime(
          processTimePerPiece: base,
          batchSize: 1,
          availability: 1,
          rework: 0.5,
        ).inMinutes,
        90,
      );
      expect(
        effectiveProcessTime(
          processTimePerPiece: base,
          batchSize: 1,
          availability: 0.5,
        ).inMinutes,
        120,
      );
    });

    test(
      'rejects impossible inputs rather than producing a plausible number',
      () {
        const base = Duration(hours: 1);
        expect(
          () => effectiveProcessTime(
            processTimePerPiece: base,
            batchSize: 0,
            availability: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => effectiveProcessTime(
            processTimePerPiece: base,
            batchSize: 1,
            availability: 0,
          ),
          throwsArgumentError,
        );
        expect(
          () => effectiveProcessTime(
            processTimePerPiece: base,
            batchSize: 1,
            availability: 1.2,
          ),
          throwsArgumentError,
        );
        expect(
          () => effectiveProcessTime(
            processTimePerPiece: base,
            batchSize: 1,
            availability: 1,
            rework: -0.1,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('a crew divides the work at a labour-paced station (v30)', () {
    test('three operators do one operators work in a third of the time', () {
      // A process time is one operator's labour content, so this is the whole
      // of the model: three people on one part is the same part, sooner.
      final alone = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 12),
        batchSize: 1,
        availability: 1,
      );
      final crewed = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 12),
        batchSize: 1,
        availability: 1,
        operators: 3,
      );

      expect(alone, const Duration(hours: 12));
      expect(crewed, const Duration(hours: 4));
    });

    test('one operator is what every station did before the flag existed', () {
      // The default has to be exactly the old arithmetic, or v30 would repace
      // the whole plant on the day it shipped.
      for (final hours in const [1, 7, 12]) {
        expect(
          effectiveProcessTime(
            processTimePerPiece: Duration(hours: hours),
            batchSize: 2,
            availability: 0.74,
            rework: 0.037,
            operators: 1,
          ),
          effectiveProcessTime(
            processTimePerPiece: Duration(hours: hours),
            batchSize: 2,
            availability: 0.74,
            rework: 0.037,
          ),
        );
      }
    });

    test('it composes with availability and rework rather than replacing them',
        () {
      // All four terms are one division, so the order they are applied in
      // cannot matter and no pair of them can be double-counted.
      final full = effectiveProcessTime(
        processTimePerPiece: const Duration(hours: 10),
        batchSize: 1,
        availability: 0.5,
        rework: 1,
        operators: 4,
      );

      // 10h x (1 + 1) / 0.5 / 4 = 10h
      expect(full, const Duration(hours: 10));
    });

    test('a crew of zero is refused rather than dividing by nothing', () {
      // Unreachable from the app - a shift with no operators is closed, so no
      // work starts in it - but the function is total or it is not.
      expect(
        () => effectiveProcessTime(
          processTimePerPiece: const Duration(hours: 1),
          batchSize: 1,
          availability: 1,
          operators: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
