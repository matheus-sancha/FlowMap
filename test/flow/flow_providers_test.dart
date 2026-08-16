import 'package:flowmap/src/features/flow/application/flow_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which lot the map costs a box for, when nobody has typed one (§7.6).
void main() {
  test('the most common batch wins, not the first and not the mean', () {
    // A part ordered in tens with one sample of one should read ten: the map is
    // stating what a station is usually occupied for, and a mean would state a
    // lot nobody orders.
    expect(modalBatchSize([10, 10, 1, 10]), 10);
    expect(modalBatchSize([1, 10, 10]), 10);
  });

  test('a tie breaks to the larger lot', () {
    // The more conservative statement of what a station is occupied for.
    expect(modalBatchSize([4, 9]), 9);
  });

  test('no orders is one piece, and so is a nonsense lot', () {
    // One piece is the only honest answer with nothing to read, and it is what
    // the flow equivalent uses anyway.
    expect(modalBatchSize(const []), 1);
    expect(modalBatchSize([0, -3]), 1);
  });
}
