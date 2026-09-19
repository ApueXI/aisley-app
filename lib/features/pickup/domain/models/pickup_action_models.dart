part of '../pickup_models.dart';

class WaybillResolution {
  const WaybillResolution({
    this.taskId,
    this.orderId,
    this.orderReference,
    this.waybillReference,
    this.taskStatus,
  });

  final String? taskId;
  final String? orderId;
  final String? orderReference;
  final String? waybillReference;
  final String? taskStatus;

  factory WaybillResolution.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.resolve.data');
    final task = data['task'] is Map
        ? Map<String, dynamic>.from(data['task'] as Map)
        : const <String, dynamic>{};
    final rawOrder = data['order'] ?? task['order'];
    final order = rawOrder is Map
        ? PickupOrderReference.fromJson(rawOrder)
        : PickupOrderReference(
            id: _nullableString(data['order_id']),
            reference: _nullableString(data['order_reference']),
          );
    final rawWaybill = data['waybill'] ?? task['waybill'];
    final waybill = rawWaybill is Map
        ? PickupWaybillReference.fromJson(rawWaybill)
        : PickupWaybillReference(
            reference: _nullableString(data['waybill_reference']),
          );
    final taskId = _nullableString(data['task_id'] ?? task['id']);
    final taskStatus = _nullableString(data['task_status'] ?? task['status']);

    if (taskId == null && order.id == null && order.reference == null) {
      throw const ApiContractException('pickup.resolve.match');
    }

    return WaybillResolution(
      taskId: taskId,
      orderId: order.id,
      orderReference: order.reference,
      waybillReference: waybill.reference,
      taskStatus: taskStatus,
    );
  }
}

class FirstMilePickupResult {
  const FirstMilePickupResult({
    required this.taskId,
    required this.taskStatus,
    required this.orderStatus,
    this.order,
    this.waybill,
    this.pickedUpAt,
    this.nextStep,
    this.idempotent = false,
  });

  final String taskId;
  final String taskStatus;
  final String orderStatus;
  final PickupOrderReference? order;
  final PickupWaybillReference? waybill;
  final DateTime? pickedUpAt;
  final String? nextStep;
  final bool idempotent;

  factory FirstMilePickupResult.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.confirm.data');
    final taskId = _requiredString(
      data['task_id'] ?? data['id'],
      'pickup.confirm.task_id',
    );
    final taskStatus = _requiredString(
      data['task_status'] ?? data['status'],
      'pickup.confirm.task_status',
    );
    final orderStatus = _requiredString(
      data['order_status'],
      'pickup.confirm.order_status',
    );
    if (taskStatus != 'picked_up_from_seller' || orderStatus != 'picked_up') {
      throw const ApiContractException('pickup.confirm.committed_state');
    }

    return FirstMilePickupResult(
      taskId: taskId,
      taskStatus: taskStatus,
      orderStatus: orderStatus,
      order: data.containsKey('order')
          ? PickupOrderReference.fromJson(data['order'])
          : null,
      waybill: data.containsKey('waybill')
          ? PickupWaybillReference.fromJson(data['waybill'])
          : null,
      pickedUpAt: _nullableUtc(data['picked_up_at']),
      nextStep: _nullableString(data['next_step']),
      idempotent: data['idempotent'] == true,
    );
  }
}

class FinalMilePickupSubmission {
  const FinalMilePickupSubmission({
    required this.taskId,
    required this.evidenceId,
    required this.evidenceStatus,
    required this.custodyState,
    this.submittedAt,
  });

  final String taskId;
  final String evidenceId;
  final String evidenceStatus;
  final String custodyState;
  final DateTime? submittedAt;

  factory FinalMilePickupSubmission.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.final_mile.data');
    final evidenceStatus = _requiredString(
      data['evidence_status'],
      'pickup.final_mile.evidence_status',
    );
    if (evidenceStatus != 'awaiting_validation') {
      throw const ApiContractException('pickup.final_mile.pending_state');
    }

    return FinalMilePickupSubmission(
      taskId: _requiredString(data['task_id'], 'pickup.final_mile.task_id'),
      evidenceId: _requiredString(
        data['evidence_id'],
        'pickup.final_mile.evidence_id',
      ),
      evidenceStatus: evidenceStatus,
      custodyState: _requiredString(
        data['custody_state'],
        'pickup.final_mile.custody_state',
      ),
      submittedAt: _nullableUtc(data['submitted_at']),
    );
  }
}

class FinalMileRejectionResult {
  const FinalMileRejectionResult({
    required this.taskId,
    required this.status,
    this.rejectionReason,
    this.respondedAt,
  });

  final String taskId;
  final String status;
  final String? rejectionReason;
  final DateTime? respondedAt;

  factory FinalMileRejectionResult.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.final_mile.reject.data');
    final status = _requiredString(
      data['status'],
      'pickup.final_mile.reject.status',
    );
    if (status != 'rejected') {
      throw const ApiContractException('pickup.final_mile.reject.state');
    }
    final rawOffer = data['offer'];
    final offer = rawOffer is Map
        ? Map<String, dynamic>.from(rawOffer)
        : const <String, dynamic>{};
    return FinalMileRejectionResult(
      taskId: _requiredString(
        data['task_id'],
        'pickup.final_mile.reject.task_id',
      ),
      status: status,
      rejectionReason: _nullableString(
        data['rejection_reason'] ?? offer['rejection_reason'],
      ),
      respondedAt: _nullableUtc(data['responded_at'] ?? offer['responded_at']),
    );
  }
}
