import 'package:flowmap/src/app/build_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// A build that cannot say which build it is makes every field report
/// unactionable — the support channel is a sentence, and *"it broke on build
/// dev"* places a finding against nothing.
void main() {
  test('a test run is unstamped, and that is correct', () {
    // `dev` is the right answer for debug and test: only packaging supplies a
    // label, and the guard below is what stops one escaping without it.
    expect(kBuildLabel, 'dev');
    expect(isStampedBuild, isFalse);
  });

  test('a release build without a label refuses to start', () {
    expect(
      () => assertBuildIsStamped(isReleaseMode: true),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('BUILD_LABEL'), contains('--dart-define')),
        ),
      ),
    );
  });

  test('debug and test builds are unaffected', () {
    // Otherwise every `flutter test` and every `flutter run` would fail, and
    // the guard would be removed within the hour.
    expect(() => assertBuildIsStamped(isReleaseMode: false), returnsNormally);
  });

  test('the message says how to fix it, not merely what is wrong', () {
    // The one machine that sees this is the one packaging a drop, and it sees
    // it at the moment the fix is cheap.
    try {
      assertBuildIsStamped(isReleaseMode: true);
      fail('expected a refusal');
    } on StateError catch (error) {
      expect(error.message, contains('BUILD_LABEL=<version>'));
    }
  });
}
