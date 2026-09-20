part of 'notification_controller.dart';

extension NotificationControllerReads on NotificationController {
  Future<void> refresh({bool silent = false}) async {
    final listEpoch = ++_listEpoch;
    final countEpoch = ++_countEpoch;

    if (!silent) {
      if (items.isEmpty) {
        listStatus = NotificationLoadStatus.loading;
      }
      countStatus = NotificationLoadStatus.loading;
      listErrorMessage = null;
      countErrorMessage = null;
      loadMoreErrorMessage = null;
      _notify();
    }

    await Future.wait<void>(<Future<void>>[
      _loadList(listEpoch: listEpoch, silent: silent),
      _loadCount(countEpoch: countEpoch, silent: silent),
    ]);
  }

  Future<void> refreshUnreadCount() async {
    final countEpoch = ++_countEpoch;
    countStatus = NotificationLoadStatus.loading;
    countErrorMessage = null;
    _notify();
    await _loadCount(countEpoch: countEpoch, silent: false);
  }

  Future<void> loadMore() async {
    if (!canLoadMore) {
      return;
    }

    final cursor = nextCursor;
    if (cursor == null || cursor.isEmpty) {
      return;
    }

    final listEpoch = ++_listEpoch;
    isLoadingMore = true;
    loadMoreErrorMessage = null;
    _notify();

    try {
      final page = await notificationRepository.fetchNotifications(
        filter: filter,
        limit: 20,
        cursor: cursor,
      );
      if (listEpoch != _listEpoch) {
        isLoadingMore = false;
        return;
      }

      items = _mergeItems(items, page.items);
      nextCursor = page.nextCursor;
      generatedAt = page.generatedAt ?? generatedAt;
      listStatus = items.isEmpty
          ? NotificationLoadStatus.empty
          : NotificationLoadStatus.loaded;
      isLoadingMore = false;
      listErrorMessage = null;
      _notify();
    } catch (error) {
      if (listEpoch != _listEpoch) {
        isLoadingMore = false;
        return;
      }
      isLoadingMore = false;
      await _applyListFailure(error, forLoadMore: true);
    }
  }

  Future<CourierNotification?> loadDetail(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) {
      return null;
    }

    final epoch = (_detailEpochs[id] ?? 0) + 1;
    _detailEpochs[id] = epoch;
    detailStatuses[id] = NotificationLoadStatus.loading;
    detailErrors[id] = null;
    _notify();

    try {
      final notification = await notificationRepository.fetchDetail(id);
      if (_detailEpochs[id] != epoch) {
        return details[id];
      }
      details[id] = notification;
      detailStatuses[id] = NotificationLoadStatus.loaded;
      detailErrors[id] = null;
      _replaceItem(notification);
      _authFailureNotified = false;
      _notify();
      return notification;
    } catch (error) {
      if (_detailEpochs[id] != epoch) {
        return details[id];
      }
      await _applyDetailFailure(id, error);
      return details[id];
    }
  }

  Future<void> setFilter(NotificationFilter value) async {
    if (filter == value) {
      return;
    }
    filter = value;
    nextCursor = null;
    items = const <CourierNotification>[];
    generatedAt = null;
    await refresh();
  }

  Future<void> _loadList({required int listEpoch, required bool silent}) async {
    if (!silent || items.isEmpty) {
      listStatus = NotificationLoadStatus.loading;
      _notify();
    }

    try {
      final page = await notificationRepository.fetchNotifications(
        filter: filter,
        limit: 20,
      );
      if (listEpoch != _listEpoch) {
        return;
      }

      items = _mergeItems(const <CourierNotification>[], page.items);
      nextCursor = page.nextCursor;
      generatedAt = page.generatedAt;
      listStatus = items.isEmpty
          ? NotificationLoadStatus.empty
          : NotificationLoadStatus.loaded;
      listErrorMessage = null;
      loadMoreErrorMessage = null;
      _authFailureNotified = false;
      _notify();
    } catch (error) {
      if (listEpoch != _listEpoch) {
        return;
      }
      await _applyListFailure(error);
    }
  }

  Future<void> _loadCount({
    required int countEpoch,
    required bool silent,
  }) async {
    if (!silent || unreadCount == null) {
      countStatus = NotificationLoadStatus.loading;
      _notify();
    }

    try {
      final count = await notificationRepository.fetchUnreadCount();
      if (countEpoch != _countEpoch) {
        return;
      }
      unreadCount = count;
      countStatus = NotificationLoadStatus.loaded;
      countErrorMessage = null;
      _authFailureNotified = false;
      _notify();
    } catch (error) {
      if (countEpoch != _countEpoch) {
        return;
      }
      await _applyCountFailure(error);
    }
  }

  List<CourierNotification> _mergeItems(
    List<CourierNotification> current,
    List<CourierNotification> incoming,
  ) {
    final byId = <String, CourierNotification>{
      for (final item in current) item.id: item,
    };
    for (final item in incoming) {
      byId[item.id] = item;
    }
    final values = byId.values.toList(growable: false);
    final bounded = values.length > NotificationController.maxInMemoryItems
        ? values.take(NotificationController.maxInMemoryItems)
        : values;
    return List<CourierNotification>.unmodifiable(bounded);
  }

  void _replaceItem(CourierNotification notification) {
    final index = items.indexWhere((item) => item.id == notification.id);
    if (index < 0) {
      return;
    }
    final updated = List<CourierNotification>.from(items);
    updated[index] = notification;
    items = List<CourierNotification>.unmodifiable(updated);
  }
}
