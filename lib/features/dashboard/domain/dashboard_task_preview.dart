import '../../pickup/domain/pickup_models.dart';

class DashboardTaskPreview {
  const DashboardTaskPreview({
    required this.id,
    required this.leg,
    required this.rawStatus,
    this.revision,
    this.orderReference,
    this.waybillReference,
    this.originName,
    this.destinationArea,
    this.distanceKm,
    this.estimatedDurationMinutes,
  });

  final String id;
  final PickupTaskLeg leg;
  final String rawStatus;
  final int? revision;
  final String? orderReference;
  final String? waybillReference;
  final String? originName;
  final String? destinationArea;
  final double? distanceKm;
  final int? estimatedDurationMinutes;

  PickupTaskStatus get status => parsePickupTaskStatus(rawStatus);

  factory DashboardTaskPreview.fromTask(PickupTask task) {
    final area = task.destinationArea?.areaSummary;
    return DashboardTaskPreview(
      id: task.id,
      leg: task.leg,
      rawStatus: task.rawStatus,
      revision: task.revision,
      orderReference: task.order?.reference,
      waybillReference: task.waybill?.reference,
      originName: task.pickup?.name,
      destinationArea: area == 'Location unavailable' ? null : area,
      distanceKm: task.distanceKm,
      estimatedDurationMinutes: task.estimatedDurationMinutes,
    );
  }
}

enum DashboardTaskClass {
  offered('Offered'),
  active('Active'),
  other('Not active'),
  unclassified('Status unavailable');

  const DashboardTaskClass(this.label);

  final String label;
}

DashboardTaskClass dashboardTaskClassification(
  DashboardTaskPreview task,
  PickupTaskLeg expectedLeg,
) {
  if (task.leg != expectedLeg) return DashboardTaskClass.unclassified;
  return switch ((expectedLeg, task.status)) {
    (PickupTaskLeg.firstMile, PickupTaskStatus.assigned) =>
      DashboardTaskClass.offered,
    (PickupTaskLeg.firstMile, PickupTaskStatus.accepted) =>
      DashboardTaskClass.active,
    (PickupTaskLeg.firstMile, PickupTaskStatus.pickedUpFromSeller) =>
      DashboardTaskClass.other,
    (PickupTaskLeg.finalMile, PickupTaskStatus.deliveryAssigned) =>
      DashboardTaskClass.offered,
    (
      PickupTaskLeg.finalMile,
      PickupTaskStatus.deliveryAccepted ||
          PickupTaskStatus.pickedUpFromHub ||
          PickupTaskStatus.inTransit ||
          PickupTaskStatus.outForDelivery,
    ) =>
      DashboardTaskClass.active,
    (
      PickupTaskLeg.finalMile,
      PickupTaskStatus.delivered || PickupTaskStatus.rejected,
    ) =>
      DashboardTaskClass.other,
    _ => DashboardTaskClass.unclassified,
  };
}

String dashboardTaskStatusLabel(
  DashboardTaskPreview task,
) => switch (task.status) {
  PickupTaskStatus.assigned || PickupTaskStatus.deliveryAssigned => 'Assigned',
  PickupTaskStatus.accepted || PickupTaskStatus.deliveryAccepted => 'Accepted',
  PickupTaskStatus.pickedUpFromSeller => 'Picked up from Seller',
  PickupTaskStatus.pickedUpFromHub => 'Picked up from hub',
  PickupTaskStatus.inTransit => 'In transit',
  PickupTaskStatus.outForDelivery => 'Out for delivery',
  PickupTaskStatus.delivered => 'Delivered',
  PickupTaskStatus.rejected => 'Rejected',
  _ => 'Status unavailable',
};
