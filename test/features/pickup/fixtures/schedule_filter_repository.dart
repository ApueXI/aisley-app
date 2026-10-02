import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

const scheduleTaskA = PickupTask(
  id: 'first-task-a',
  leg: PickupTaskLeg.firstMile,
  rawStatus: 'assigned',
  pickupScheduleId: 'schedule-a',
  schedule: PickupSchedule(id: 'schedule-a', reference: 'SCH-A'),
  order: PickupOrderReference(reference: 'ORD-A'),
);
const scheduleTaskB = PickupTask(
  id: 'first-task-b',
  leg: PickupTaskLeg.firstMile,
  rawStatus: 'accepted',
  // The nested schedule ID is an authorized fallback, not the task UUID.
  schedule: PickupSchedule(id: 'schedule-b', reference: 'SCH-B'),
  order: PickupOrderReference(reference: 'ORD-B'),
);
const scheduleHubTask = PickupTask(
  id: 'hub-task',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'delivery_accepted',
  order: PickupOrderReference(reference: 'ORD-HUB'),
);

class ScheduleFilterRepository implements PickupRepository {
  final queries = <String?>[];
  int finalMileReads = 0;
  Future<FirstMileTaskPage> Function(String?)? onRead;
  Future<List<PickupTask>> Function()? onFinalRead;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    queries.add(pickupScheduleId);
    if (onRead != null) return onRead!(pickupScheduleId);
    return FirstMileTaskPage(
      tasks: pickupScheduleId == null
          ? const [scheduleTaskA, scheduleTaskB]
          : pickupScheduleId == 'schedule-a'
          ? const [scheduleTaskA]
          : const [scheduleTaskB],
      currentPage: 1,
      lastPage: 2,
      perPage: perPage,
      total: 60,
    );
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    finalMileReads++;
    if (onFinalRead != null) return onFinalRead!();
    return const [scheduleHubTask];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
