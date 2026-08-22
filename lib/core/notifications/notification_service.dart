abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> requestPermission();
  Future<void> subscribeToOrganization(String organizationId);
  Future<void> unsubscribeFromOrganization(String organizationId);
}

/// Firebase Cloud Messaging is intentionally kept behind this interface.
/// Configure Firebase for each platform before wiring a concrete adapter.
