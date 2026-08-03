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
