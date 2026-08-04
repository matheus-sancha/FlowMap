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
}
