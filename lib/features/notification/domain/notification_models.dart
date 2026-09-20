import '../../../core/networking/api_contract_exception.dart';

enum NotificationFilter {
  all('all'),
  unread('unread'),
  read('read');

  const NotificationFilter(this.apiValue);

  final String apiValue;

  String get label => switch (this) {
    NotificationFilter.all => 'All',
    NotificationFilter.unread => 'Unread',
    NotificationFilter.read => 'Read',
  };
}

class CourierNotification {
  const CourierNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.resourceType,
    required this.createdAt,
    this.readAt,
    this.resourceId,
    this.destination,
  });

  final String id;
  final String type;
  final String title;
  final String summary;
  final DateTime createdAt;
  final DateTime? readAt;
  final String resourceType;
  final String? resourceId;
  final String? destination;

  bool get isRead => readAt != null;

  bool get hasDestination => destination != null && destination!.isNotEmpty;

  String get typeLabel => switch (type) {
    'pickup-schedule.assigned' => 'Pickup assigned',
    'pickup-schedule.revised' => 'Pickup updated',
    'pickup-schedule.cancelled' => 'Pickup cancelled',
    'pickup-schedule.reminder' => 'Pickup reminder',
    'courier-task.final-mile-offered' => 'Delivery offered',
    _ => 'Courier update',
  };

  CourierNotification copyWith({DateTime? readAt}) {
    return CourierNotification(
      id: id,
      type: type,
      title: title,
      summary: summary,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      resourceType: resourceType,
      resourceId: resourceId,
      destination: destination,
    );
  }

  factory CourierNotification.fromJson(Map<String, dynamic> json) {
    return CourierNotification(
      id: _requiredString(json['id'], 'notification.id'),
      type: _requiredString(json['type'], 'notification.type'),
      title: _requiredString(json['title'], 'notification.title'),
      summary: _requiredString(json['summary'], 'notification.summary'),
      readAt: _nullableDateTime(json['read_at'], 'notification.read_at'),
      createdAt: _requiredDateTime(
        json['created_at'],
        'notification.created_at',
      ),
      resourceType: _requiredString(
        json['resource_type'],
        'notification.resource_type',
      ),
      resourceId: _nullableString(
        json['resource_id'],
        'notification.resource_id',
      ),
      destination: _nullableString(
        json['destination'],
        'notification.destination',
      ),
    );
  }
}

class CourierNotificationPage {
  const CourierNotificationPage({
    required this.items,
    this.nextCursor,
    this.generatedAt,
  });

  final List<CourierNotification> items;
  final String? nextCursor;
  final DateTime? generatedAt;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is! String) {
    throw ApiContractException(field);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiContractException(field);
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredDateTime(value, field);
}
