import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/support_ticket_models.dart';

abstract interface class SupportTicketRepository {
  Future<SupportTicketPage> list({
    SupportTicketStatusFilter status,
    SupportTicketCategoryFilter category,
    String? cursor,
    int limit,
  });

  Future<SupportTicketMutation> create({
    required String subject,
    required String category,
    required String body,
    required String idempotencyKey,
  });

  Future<SupportTicketDetailPage> detail(
    String ticketId, {
    String? cursor,
    int limit,
  });

  Future<SupportTicketMutation> reply({
    required String ticketId,
    required String body,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<SupportTicketSummary> markRead({
    required String ticketId,
    required int lastReadSequence,
  });
}

class ApiSupportTicketRepository implements SupportTicketRepository {
  ApiSupportTicketRepository({required this.client});

  static const _base = '/courier/support-tickets';
  final ApiClient client;

  @override
  Future<SupportTicketPage> list({
    SupportTicketStatusFilter status = SupportTicketStatusFilter.all,
    SupportTicketCategoryFilter category = SupportTicketCategoryFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    _checkLimit(limit);
    final response = await client.get(
      _base,
      authenticated: true,
      queryParameters: <String, String>{
        'limit': '$limit',
        'status': ?status.apiValue,
        'category': ?category.apiValue,
        'cursor': ?_normalizedCursor(cursor),
      },
    );
    final payload = _decode(response.body, 'support.list');
    final rawItems = payload['items'];
    if (rawItems is! List || !payload.containsKey('next_cursor')) {
      throw const ApiContractException('support.list');
    }
    final items = <SupportTicketSummary>[];
    for (final item in rawItems) {
      if (item is! Map) {
        throw const ApiContractException('support.list.item');
      }
      items.add(SupportTicketSummary.fromJson(Map<String, dynamic>.from(item)));
    }
    return SupportTicketPage(
      items: List<SupportTicketSummary>.unmodifiable(items),
      nextCursor: _cursor(payload['next_cursor'], 'support.list.next_cursor'),
    );
  }

  @override
  Future<SupportTicketMutation> create({
    required String subject,
    required String category,
    required String body,
    required String idempotencyKey,
  }) async {
    final response = await client.postJson(
      _base,
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'subject': subject,
        'category': category,
        'body': body,
      },
    );
    return _mutation(response.body, 'support.create');
  }

  @override
  Future<SupportTicketDetailPage> detail(
    String ticketId, {
    String? cursor,
    int limit = 20,
  }) async {
    _checkLimit(limit);
    final response = await client.get(
      '$_base/${_segment(ticketId)}',
      authenticated: true,
      queryParameters: <String, String>{
        'limit': '$limit',
        'cursor': ?_normalizedCursor(cursor),
      },
    );
    final payload = _decode(response.body, 'support.detail');
    final data = payload['data'];
    final rawEvents = payload['events'];
    if (data is! Map ||
        rawEvents is! List ||
        !payload.containsKey('next_cursor')) {
      throw const ApiContractException('support.detail');
    }
    final events = <SupportTicketEvent>[];
    for (final item in rawEvents) {
      if (item is! Map) {
        throw const ApiContractException('support.detail.event');
      }
      events.add(SupportTicketEvent.fromJson(Map<String, dynamic>.from(item)));
    }
    return SupportTicketDetailPage(
      ticket: SupportTicketDetailRecord.fromJson(
        Map<String, dynamic>.from(data),
      ),
      events: List<SupportTicketEvent>.unmodifiable(events),
      nextCursor: _cursor(payload['next_cursor'], 'support.detail.next_cursor'),
    );
  }

  @override
  Future<SupportTicketMutation> reply({
    required String ticketId,
    required String body,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = await client.postJson(
      '$_base/${_segment(ticketId)}/replies',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'body': body,
        'expected_revision': expectedRevision,
      },
    );
    return _mutation(response.body, 'support.reply');
  }

  @override
  Future<SupportTicketSummary> markRead({
    required String ticketId,
    required int lastReadSequence,
  }) async {
    final response = await client.postJson(
      '$_base/${_segment(ticketId)}/read',
      authenticated: true,
      body: <String, Object?>{'last_read_sequence': lastReadSequence},
    );
    final payload = _decode(response.body, 'support.read');
    final data = payload['data'];
    if (data is! Map) throw const ApiContractException('support.read.data');
    return SupportTicketSummary.fromJson(Map<String, dynamic>.from(data));
  }
}

SupportTicketMutation _mutation(String body, String field) {
  final payload = _decode(body, field);
  final data = payload['data'];
  final event = payload['event'];
  if (data is! Map || event is! Map) throw ApiContractException(field);
  return SupportTicketMutation(
    ticket: SupportTicketSummary.fromJson(Map<String, dynamic>.from(data)),
    event: SupportTicketEvent.fromJson(Map<String, dynamic>.from(event)),
  );
}

Map<String, dynamic> _decode(String body, String field) {
  try {
    final value = jsonDecode(body);
    if (value is Map) return Map<String, dynamic>.from(value);
  } on FormatException {
    // Successful responses still have to match the documented JSON contract.
  }
  throw ApiContractException(field);
}

String _segment(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, 'value');
  return Uri.encodeComponent(normalized);
}

String? _normalizedCursor(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _cursor(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) throw ApiContractException(field);
  return value;
}

void _checkLimit(int value) {
  if (value < 1 || value > 50) throw ArgumentError.value(value, 'limit');
}
