import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_models.dart';

part 'notification_controller_reads.dart';
part 'notification_controller_actions.dart';
part 'notification_controller_errors.dart';

typedef NotificationAuthFailureHandler = Future<void> Function(
  ApiException error,
);

enum NotificationLoadStatus {
  idle,
  loading,
  loaded,
  empty,
  stale,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  unavailable,
  rateLimited,
  failed,
  secureStorageFailure,
}

enum NotificationReadStatus {
  idle,
  reading,
  read,
  unavailable,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.notificationRepository,
    this.onAuthFailure,
  });

  static const pollInterval = Duration(seconds: 30);
  static const maxInMemoryItems = 100;

  final NotificationRepository notificationRepository;
  final NotificationAuthFailureHandler? onAuthFailure;

  NotificationFilter filter = NotificationFilter.all;
  NotificationLoadStatus listStatus = NotificationLoadStatus.idle;
  NotificationLoadStatus countStatus = NotificationLoadStatus.idle;
  List<CourierNotification> items = const <CourierNotification>[];
  String? nextCursor;
  DateTime? generatedAt;
  int? unreadCount;
  String? listErrorMessage;
  String? countErrorMessage;
  String? loadMoreErrorMessage;
  bool isLoadingMore = false;

  final Map<String, CourierNotification> details =
      <String, CourierNotification>{};
  final Map<String, NotificationLoadStatus> detailStatuses =
      <String, NotificationLoadStatus>{};
  final Map<String, String?> detailErrors = <String, String?>{};
  final Map<String, NotificationReadStatus> readStatuses =
      <String, NotificationReadStatus>{};
  final Map<String, String?> readErrors = <String, String?>{};

  int _listEpoch = 0;
  int _countEpoch = 0;
  final Map<String, int> _detailEpochs = <String, int>{};
  final Map<String, int> _readEpochs = <String, int>{};
  Timer? _pollTimer;
  Timer? _rateLimitTimer;
  bool _authFailureNotified = false;
  bool _disposed = false;

  bool get isLoading => listStatus == NotificationLoadStatus.loading;

  bool get isCountLoading => countStatus == NotificationLoadStatus.loading;

  bool get hasStaleItems =>
      items.isNotEmpty &&
      (listStatus == NotificationLoadStatus.stale ||
          listStatus == NotificationLoadStatus.offline ||
          listStatus == NotificationLoadStatus.timeout);

  bool get canLoadMore =>
      nextCursor != null &&
      nextCursor!.isNotEmpty &&
      !isLoadingMore &&
      !isLoading;

  bool get canRetryRateLimit => _rateLimitTimer == null;

  CourierNotification? notificationById(String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  CourierNotification? detailFor(String id) => details[id];

  NotificationLoadStatus detailStatusFor(String id) {
    return detailStatuses[id] ?? NotificationLoadStatus.idle;
  }

  String? detailErrorFor(String id) => detailErrors[id];

  NotificationReadStatus readStatusFor(String id) {
    return readStatuses[id] ?? NotificationReadStatus.idle;
  }

  String? readErrorFor(String id) => readErrors[id];

  void startPolling() {
    if (_disposed || _pollTimer != null) {
      return;
    }
    unawaited(refresh(silent: true));
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    _listEpoch++;
    _countEpoch++;
    _detailEpochs.clear();
    _readEpochs.clear();
    stopPolling();
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    filter = NotificationFilter.all;
    listStatus = NotificationLoadStatus.idle;
    countStatus = NotificationLoadStatus.idle;
    items = const <CourierNotification>[];
    nextCursor = null;
    generatedAt = null;
    unreadCount = null;
    listErrorMessage = null;
    countErrorMessage = null;
    loadMoreErrorMessage = null;
    isLoadingMore = false;
    details.clear();
    detailStatuses.clear();
    detailErrors.clear();
    readStatuses.clear();
    readErrors.clear();
    _authFailureNotified = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    _rateLimitTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
