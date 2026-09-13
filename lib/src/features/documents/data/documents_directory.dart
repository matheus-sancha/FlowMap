import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where documents go when nobody has said otherwise.
///
/// **Documents, not Application Support.** The database deliberately lives in
/// `%APPDATA%` because a sync client can corrupt a live SQLite file and its
/// `-wal` sidecar mid-write (`app_directory.dart`). A `.flowmap` is the
/// opposite case: it is written whole and renamed atomically, it is ~29 KB, and
/// the entire point of #37 is that people keep it where their other work is and
/// hand it to each other. Hiding it under `%APPDATA%` would make the one thing
/// the user is supposed to own the one thing they cannot find.
///
/// This is only the **default**. Open and Save As go wherever the user says,
/// including a network share or a OneDrive folder, which is what the document
/// model is for.
Future<Directory> documentsDirectory() async {
  final base = await getApplicationDocumentsDirectory();
  return Directory(p.join(base.path, 'FlowMap'));
}
