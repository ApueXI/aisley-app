import '../../../core/networking/api_contract_exception.dart';

enum SupportTicketStatusFilter {
  all(null, 'All statuses'),
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  waitingForRequester('waiting_for_requester', 'Waiting for you'),
  resolved('resolved', 'Resolved');

  const SupportTicketStatusFilter(this.apiValue, this.label);

  final String? apiValue;
  final String label;
}

enum SupportTicketCategoryFilter {
  all(null, 'All categories'),
  general('general', 'General'),
  account('account', 'Account'),
  order('order', 'Order'),
  delivery('delivery', 'Delivery');

  const SupportTicketCategoryFilter(this.apiValue, this.label);

  final String? apiValue;
  final String label;
}

const supportTicketCategories = <String>{
  'general',
  'account',
  'order',
  'delivery',
};

String supportTicketStatusLabel(String value) => switch (value) {
  'open' => 'Open',
  'in_progress' => 'In progress',
  'waiting_for_requester' => 'Waiting for you',
  'resolved' => 'Resolved',
  _ => 'Status unavailable',
};

String supportTicketCategoryLabel(String value) => switch (value) {
  'general' => 'General',
  'account' => 'Account',
  'order' => 'Order',
  'delivery' => 'Delivery',
  _ => 'Other',
};

String supportTicketEventLabel(String value) => switch (value) {
  'reply' => 'Reply',
  'status_changed' || 'status_change' => 'Status changed',
  'assigned' || 'assignment_changed' => 'Assignment changed',
  _ => 'Ticket update',
};

class SupportTicketSummary {
  const SupportTicketSummary({
    required this.id,
    required this.reference,
    required this.subject,
    required this.category,
    required this.status,
    required this.revision,
    required this.requesterRole,
    required this.unreadCount,
    this.assigneeName,
    this.lastActivityAt,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String reference;
  final String subject;
  final String category;
  final String status;
  final int revision;
  final String requesterRole;
  final int unreadCount;
  final String? assigneeName;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  String get statusLabel => supportTicketStatusLabel(status);
  String get categoryLabel => supportTicketCategoryLabel(category);

  SupportTicketSummary copyWith({int? unreadCount}) {
    return SupportTicketSummary(
      id: id,
      reference: reference,
      subject: subject,
      category: category,
      status: status,
      revision: revision,
      requesterRole: requesterRole,
      unreadCount: unreadCount ?? this.unreadCount,
      assigneeName: assigneeName,
      lastActivityAt: lastActivityAt,
      createdAt: createdAt,
      resolvedAt: resolvedAt,
    );
  }

  factory SupportTicketSummary.fromJson(Map<String, dynamic> json) {
    if (json['requester_name'] != null || json['assignee_id'] != null) {
      throw const ApiContractException('support.ticket.private_identity');
    }
    final requesterRole = _requiredString(
      json['requester_role'],
      'support.ticket.requester_role',
    );
    if (requesterRole != 'courier') {
      throw const ApiContractException('support.ticket.requester_role');
    }
    return SupportTicketSummary(
      id: _requiredString(json['id'], 'support.ticket.id'),
      reference: _requiredString(json['reference'], 'support.ticket.reference'),
      subject: _requiredString(json['subject'], 'support.ticket.subject'),
      category: _requiredString(json['category'], 'support.ticket.category'),
      status: _requiredString(json['status'], 'support.ticket.status'),
      revision: _nonnegativeInt(json['revision'], 'support.ticket.revision'),
      requesterRole: requesterRole,
      unreadCount: _nonnegativeInt(
        json['unread_count'],
        'support.ticket.unread_count',
      ),
      assigneeName: _nullableString(
        json['assignee_name'],
        'support.ticket.assignee_name',
      ),
      lastActivityAt: _nullableDateTime(
        json['last_activity_at'],
        'support.ticket.last_activity_at',
      ),
      createdAt: _nullableDateTime(
        json['created_at'],
        'support.ticket.created_at',
      ),
      resolvedAt: _nullableDateTime(
        json['resolved_at'],
        'support.ticket.resolved_at',
      ),
    );
  }
}

class SupportTicketEvent {
  const SupportTicketEvent({
    required this.id,
    required this.sequence,
    required this.type,
    required this.actorRole,
    required this.isMine,
    required this.assignmentChanged,
    this.body,
    this.fromStatus,
    this.toStatus,
    this.createdAt,
  });

  final String id;
  final int sequence;
  final String type;
  final String actorRole;
  final bool isMine;
  final String? body;
  final String? fromStatus;
  final String? toStatus;
  final bool assignmentChanged;
  final DateTime? createdAt;

  String get typeLabel => supportTicketEventLabel(type);

  factory SupportTicketEvent.fromJson(Map<String, dynamic> json) {
    final isMine = json['is_mine'];
    final assignmentChanged = json['assignment_changed'];
    if (isMine is! bool) {
      throw const ApiContractException('support.event.is_mine');
    }
    if (assignmentChanged is! bool) {
      throw const ApiContractException('support.event.assignment_changed');
    }
    return SupportTicketEvent(
      id: _requiredString(json['id'], 'support.event.id'),
      sequence: _nonnegativeInt(json['sequence'], 'support.event.sequence'),
      type: _requiredString(json['type'], 'support.event.type'),
      actorRole: _requiredString(
        json['actor_role'],
        'support.event.actor_role',
      ),
      isMine: isMine,
      body: _nullableString(json['body'], 'support.event.body'),
      fromStatus: _nullableString(
        json['from_status'],
        'support.event.from_status',
      ),
      toStatus: _nullableString(json['to_status'], 'support.event.to_status'),
      assignmentChanged: assignmentChanged,
      createdAt: _nullableDateTime(
        json['created_at'],
        'support.event.created_at',
      ),
    );
  }
}

class SupportTicketDetailRecord {
  const SupportTicketDetailRecord({
    required this.id,
    required this.reference,
    required this.status,
    required this.revision,
    this.subject,
    this.category,
    this.requesterRole,
    this.unreadCount,
    this.assigneeName,
    this.lastActivityAt,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String reference;
  final String status;
  final int revision;
  final String? subject;
  final String? category;
  final String? requesterRole;
  final int? unreadCount;
  final String? assigneeName;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  SupportTicketSummary mergeWith(SupportTicketSummary? known) {
    return SupportTicketSummary(
      id: id,
      reference: reference,
      subject: subject ?? known?.subject ?? 'Subject unavailable',
      category: category ?? known?.category ?? 'unknown',
      status: status,
      revision: revision,
      requesterRole: requesterRole ?? known?.requesterRole ?? 'courier',
      unreadCount: unreadCount ?? known?.unreadCount ?? 0,
      assigneeName: assigneeName ?? known?.assigneeName,
      lastActivityAt: lastActivityAt ?? known?.lastActivityAt,
      createdAt: createdAt ?? known?.createdAt,
      resolvedAt: resolvedAt ?? known?.resolvedAt,
    );
  }

  factory SupportTicketDetailRecord.fromJson(Map<String, dynamic> json) {
    if (json['requester_name'] != null || json['assignee_id'] != null) {
      throw const ApiContractException('support.ticket.private_identity');
    }
    final requesterRole = _nullableString(
      json['requester_role'],
      'support.ticket.requester_role',
    );
    if (requesterRole != null && requesterRole != 'courier') {
      throw const ApiContractException('support.ticket.requester_role');
    }
    final unreadCount = json.containsKey('unread_count')
        ? _nonnegativeInt(json['unread_count'], 'support.ticket.unread_count')
        : null;
    return SupportTicketDetailRecord(
      id: _requiredString(json['id'], 'support.ticket.id'),
      reference: _requiredString(json['reference'], 'support.ticket.reference'),
      status: _requiredString(json['status'], 'support.ticket.status'),
      revision: _nonnegativeInt(json['revision'], 'support.ticket.revision'),
      subject: _nullableString(json['subject'], 'support.ticket.subject'),
      category: _nullableString(json['category'], 'support.ticket.category'),
      requesterRole: requesterRole,
      unreadCount: unreadCount,
      assigneeName: _nullableString(
        json['assignee_name'],
        'support.ticket.assignee_name',
      ),
      lastActivityAt: _nullableDateTime(
        json['last_activity_at'],
        'support.ticket.last_activity_at',
      ),
      createdAt: _nullableDateTime(
        json['created_at'],
        'support.ticket.created_at',
      ),
      resolvedAt: _nullableDateTime(
        json['resolved_at'],
        'support.ticket.resolved_at',
      ),
    );
  }
}

class SupportTicketPage {
  const SupportTicketPage({required this.items, required this.nextCursor});

  final List<SupportTicketSummary> items;
  final String? nextCursor;
}

class SupportTicketDetailPage {
  const SupportTicketDetailPage({
    required this.ticket,
    required this.events,
    required this.nextCursor,
  });

  final SupportTicketDetailRecord ticket;
  final List<SupportTicketEvent> events;
  final String? nextCursor;
}

class SupportTicketMutation {
  const SupportTicketMutation({required this.ticket, required this.event});

  final SupportTicketSummary ticket;
  final SupportTicketEvent event;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw ApiContractException(field);
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _nonnegativeInt(Object? value, String field) {
  if (value is! int || value < 0) throw ApiContractException(field);
  return value;
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw ApiContractException(field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw ApiContractException(field);
  return parsed.toUtc();
}
