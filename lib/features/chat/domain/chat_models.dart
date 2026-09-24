import '../../../core/networking/api_contract_exception.dart';

const chatRoles = <String>{'logistics', 'seller', 'customer'};
const chatLegs = <String>{'first_mile', 'final_mile'};

class ChatThread {
  const ChatThread({
    required this.id,
    required this.kind,
    required this.leg,
    required this.taskId,
    required this.counterpartyRole,
    required this.unreadCount,
    required this.lastSequence,
    required this.lastReadSequence,
    this.taskReference,
    this.orderReference,
    this.counterpartyLabel,
    this.sendAllowed,
    this.readOnlyReason,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String kind;
  final String leg;
  final String taskId;
  final String counterpartyRole;
  final int unreadCount;
  final int? lastSequence;
  final int? lastReadSequence;
  final String? taskReference;
  final String? orderReference;
  final String? counterpartyLabel;
  final bool? sendAllowed;
  final String? readOnlyReason;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final leg = _requiredString(json['leg'], 'chat.thread.leg');
    final role = _requiredString(
      json['counterparty_role'],
      'chat.thread.counterparty_role',
    );
    if (!chatLegs.contains(leg) || !chatRoles.contains(role)) {
      throw const ApiContractException('chat.thread.context');
    }
    final unread = _requiredNonnegativeInt(
      json['unread_count'],
      'chat.thread.unread_count',
    );
    final sendAllowed = json['send_allowed'];
    if (sendAllowed != null && sendAllowed is! bool) {
      throw const ApiContractException('chat.thread.send_allowed');
    }
    return ChatThread(
      id: _requiredString(json['id'], 'chat.thread.id'),
      kind: _requiredString(json['kind'], 'chat.thread.kind'),
      leg: leg,
      taskId: _requiredString(json['task_id'], 'chat.thread.task_id'),
      counterpartyRole: role,
      unreadCount: unread,
      lastSequence: _nullableNonnegativeInt(
        json['last_sequence'],
        'chat.thread.last_sequence',
      ),
      lastReadSequence: _nullableNonnegativeInt(
        json['last_read_sequence'],
        'chat.thread.last_read_sequence',
      ),
      taskReference: _nullableString(
        json['task_reference'],
        'chat.thread.task_reference',
      ),
      orderReference: _nullableString(
        json['order_reference'],
        'chat.thread.order_reference',
      ),
      counterpartyLabel: _nullableString(
        json['counterparty_label'],
        'chat.thread.counterparty_label',
      ),
      sendAllowed: sendAllowed as bool?,
      readOnlyReason: _nullableString(
        json['read_only_reason'],
        'chat.thread.read_only_reason',
      ),
      lastMessagePreview: _nullableString(
        json['last_message_preview'],
        'chat.thread.last_message_preview',
      ),
      lastMessageAt: _nullableDateTime(
        json['last_message_at'],
        'chat.thread.last_message_at',
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sequence,
    required this.senderRole,
    required this.mine,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final int sequence;
  final String senderRole;
  final bool mine;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final mine = json['mine'];
    if (mine is! bool) throw const ApiContractException('chat.message.mine');
    final sequence = _requiredNonnegativeInt(
      json['sequence'],
      'chat.message.sequence',
    );
    if (sequence == 0) {
      throw const ApiContractException('chat.message.sequence');
    }
    return ChatMessage(
      id: _requiredString(json['id'], 'chat.message.id'),
      conversationId: _requiredString(
        json['conversation_id'],
        'chat.message.conversation_id',
      ),
      sequence: sequence,
      senderRole: _requiredString(
        json['sender_role'],
        'chat.message.sender_role',
      ),
      mine: mine,
      body: _requiredString(json['body'], 'chat.message.body'),
      createdAt: _requiredDateTime(
        json['created_at'],
        'chat.message.created_at',
      ),
    );
  }
}

class ChatPage<T> {
  const ChatPage({
    required this.items,
    required this.nextCursor,
    this.unreadCount,
  });

  final List<T> items;
  final String? nextCursor;
  final int? unreadCount;
}

class ChatSendResult {
  const ChatSendResult({required this.thread, required this.message});

  final ChatThread thread;
  final ChatMessage message;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value;
}

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw ApiContractException(field);
  return value;
}

int _requiredNonnegativeInt(Object? value, String field) {
  if (value is! int || value < 0) throw ApiContractException(field);
  return value;
}

int? _nullableNonnegativeInt(Object? value, String field) {
  if (value == null) return null;
  return _requiredNonnegativeInt(value, field);
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is! String) throw ApiContractException(field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw ApiContractException(field);
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) return null;
  return _requiredDateTime(value, field);
}
