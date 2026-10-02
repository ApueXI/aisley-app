import '../../pickup/domain/pickup_models.dart';

class ChatTaskContext {
  const ChatTaskContext({
    required this.leg,
    required this.taskId,
    this.counterpartyRole = 'logistics',
    this.reference,
  });

  final String leg;
  final String taskId;
  final String counterpartyRole;
  final String? reference;

  bool get canCompose =>
      (counterpartyRole == 'logistics' &&
          (leg == 'first_mile' || leg == 'final_mile')) ||
      (counterpartyRole == 'seller' && leg == 'first_mile') ||
      (counterpartyRole == 'customer' && leg == 'final_mile');

  static bool canMessageBuyer(PickupTask task) =>
      task.isFinalMile &&
      const <PickupTaskStatus>{
        PickupTaskStatus.deliveryAccepted,
        PickupTaskStatus.pickedUpFromHub,
        PickupTaskStatus.inTransit,
        PickupTaskStatus.outForDelivery,
      }.contains(task.status);
}
