part of 'notification_controller.dart';

extension NotificationControllerActions on NotificationController {
  Future<bool> markRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) {
      return false;
    }

    final current = details[id] ?? notificationById(id);
    if (current?.isRead == true) {
      return true;
    }

    final epoch = (_readEpochs[id] ?? 0) + 1;
    _readEpochs[id] = epoch;
    readStatuses[id] = NotificationReadStatus.reading;
    readErrors[id] = null;
    _notify();

    try {
      final updated = await notificationRepository.markRead(id);
      if (_readEpochs[id] != epoch) {
        return false;
      }
      details[id] = updated;
      _replaceItem(updated);
      readStatuses[id] = NotificationReadStatus.read;
      readErrors[id] = null;
      _authFailureNotified = false;
      _notify();
      unawaited(refreshUnreadCount());
      return true;
    } catch (error) {
      if (_readEpochs[id] != epoch) {
        return false;
      }
      await _applyReadFailure(id, error);
      return false;
    }
  }
}
