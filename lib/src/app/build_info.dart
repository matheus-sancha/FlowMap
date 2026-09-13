/// Identifies the build that is running, for the diagnostics session header and
/// the About screen.
///
/// Supplied at compile time by the packaging script:
/// ```
/// flutter build windows --release --dart-define=BUILD_LABEL=0.1.0-2026-08-03
/// ```
///
/// _Rejected: `package_info_plus` reading `pubspec.yaml`._ Its version is a
/// semver that would have to start claiming something untrue about a
/// pre-release drop, and it cannot carry the build date a field report needs to
/// place a bug against a specific zip.
const String kBuildLabel = String.fromEnvironment(
  'BUILD_LABEL',
  defaultValue: 'dev',
);

/// Whether this build carries a label, as opposed to falling back to `dev`.
bool get isStampedBuild => kBuildLabel != 'dev';

/// Refuses to run a **release** build that was packaged without a label.
///
/// **The failure has to land on the machine that can read it.** A forgotten
/// `--dart-define` ships a build that calls itself `dev` in About, in the
/// diagnostics header, and on every PDF and Excel that leaves the building —
/// and a field report reading *"build dev"* places a finding against nothing.
/// The drive sheets name builds as `0.1.0-2026-09-07a` precisely so a finding
/// can be placed against a specific zip.
///
/// Debug and test builds keep `dev` and are unaffected, which is why this is
/// guarded on [kReleaseMode] rather than on the label alone.
void assertBuildIsStamped({required bool isReleaseMode}) {
  if (isReleaseMode && !isStampedBuild) {
    throw StateError(
      'BUILD_LABEL is unset. A release build must carry a label: exports and '
      'the diagnostics log are stamped with it, and a report naming "dev" '
      'cannot be traced to a release. Build with '
      '--dart-define=BUILD_LABEL=<version>.',
    );
  }
}
