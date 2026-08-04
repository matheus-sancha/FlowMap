import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../data/projects_repository.dart';

part 'projects_providers.g.dart';

@riverpod
ProjectsRepository projectsRepository(Ref ref) =>
    ProjectsRepository(ref.watch(appDatabaseProvider));

// Hand-written, not generated: riverpod_generator cannot emit a provider whose
// return type is a Drift class from the same build pass.

final projectsListProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchProjects(),
);

final projectProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectsRepositoryProvider).watchProject(id),
);
