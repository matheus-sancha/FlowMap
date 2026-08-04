import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The one directory every piece of on-device state lives under: the Drift
/// database, the diagnostics log, the window geometry file, and the base that a
/// `.flowmap` export's relative paths resolve against. They all must agree on
/// it, so they all resolve it through here rather than each calling
/// `path_provider` directly.
///
/// **Windows deliberately does not use the documents directory.**
/// `getApplicationDocumentsDirectory()` returns the *redirected* Documents
/// folder, and OneDrive's Known Folder Move — on by default in most Microsoft
/// 365 setups, which is exactly the environment a manufacturing engineer's PC
/// is in — places that inside a sync root. A sync client that uploads a live
/// SQLite file and its `-wal` sidecar mid-write can corrupt the database, and
/// can hold a lock while the app has the file open. Application Support
/// (`%APPDATA%\Roaming\com.sancha\flowmap`) is never redirected.
Future<Directory> appDataDirectory() {
  if (Platform.isWindows) return getApplicationSupportDirectory();
  return getApplicationDocumentsDirectory();
}
