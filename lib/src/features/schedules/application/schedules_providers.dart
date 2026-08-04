import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../resources/application/resources_providers.dart';
import '../data/schedules_repository.dart';

part 'schedules_providers.g.dart';

@riverpod
SchedulesRepository schedulesRepository(Ref ref) => SchedulesRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(resourcesRepositoryProvider),
);

/// The (project, production line) a takt schedule belongs to.
typedef LineScope = ({String projectId, String productionLineId});

/// The (project, workcenter) a workcenter schedule belongs to.
typedef WorkcenterScope = ({String projectId, String workcenterId});

// Hand-written, not generated: riverpod_generator cannot emit a provider whose
// return type is a Drift class from the same build pass.

final taktPeriodsProvider = StreamProvider.family<List<TaktPeriod>, LineScope>(
  (ref, scope) => ref
      .watch(schedulesRepositoryProvider)
      .watchTaktPeriods(scope.projectId, scope.productionLineId),
);

final workcenterScheduleProvider =
    StreamProvider.family<List<WorkcenterSchedulePeriod>, WorkcenterScope>(
      (ref, scope) => ref
          .watch(schedulesRepositoryProvider)
          .watchWorkcenterSchedule(scope.projectId, scope.workcenterId),
    );

final projectSchedulesProvider =
    StreamProvider.family<List<WorkcenterSchedulePeriod>, String>(
      (ref, projectId) => ref
          .watch(schedulesRepositoryProvider)
          .watchProjectSchedules(projectId),
    );

final calendarExceptionsProvider =
    StreamProvider.family<List<CalendarException>, String>(
      (ref, projectId) =>
          ref.watch(schedulesRepositoryProvider).watchExceptions(projectId),
    );
