import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../data/studies_repository.dart';

part 'studies_providers.g.dart';

@riverpod
StudiesRepository studiesRepository(Ref ref) =>
    StudiesRepository(ref.watch(appDatabaseProvider));

// Hand-written, not generated: riverpod_generator cannot emit a provider whose
// return type is a Drift class from the same build pass.

final studiesProvider = StreamProvider.family<List<Study>, String>(
  (ref, projectId) =>
      ref.watch(studiesRepositoryProvider).watchStudies(projectId),
);

final studyProvider = StreamProvider.family<Study?, String>(
  (ref, studyId) => ref.watch(studiesRepositoryProvider).watchStudy(studyId),
);

final flowNodesProvider = StreamProvider.family<List<FlowNode>, String>(
  (ref, studyId) => ref.watch(studiesRepositoryProvider).watchNodes(studyId),
);

final flowAnnotationsProvider =
    StreamProvider.family<List<FlowAnnotation>, String>(
      (ref, studyId) =>
          ref.watch(studiesRepositoryProvider).watchAnnotations(studyId),
    );
