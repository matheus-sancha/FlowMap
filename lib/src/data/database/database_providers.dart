import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database.dart';

part 'database_providers.g.dart';

/// The one database connection, open for the life of the process.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
