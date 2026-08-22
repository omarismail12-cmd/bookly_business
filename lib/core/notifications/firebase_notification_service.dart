import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Concrete FCM adapter for [NotificationService].
///
/// Without a configured Firebase project (google-services.json /
/// GoogleService-Info.plist / firebase_options.dart), `Firebase.initializeApp`
/// throws immediately. Every method here catches that and becomes a safe
/// no-op instead of crashing the app, so this class is wired in and ready
/// the moment real Firebase config is added to the platform projects.
class FirebaseNotificationService implements NotificationService {
  bool _available = false;
  StreamSubscription<String>? _refreshSub;

  @override
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      _available = false;
      debugPrint(
        'FCM unavailable: no Firebase project is configured for this platform ($e).',
      );
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }
  }

  @override
  Future<void> subscribeToOrganization(String organizationId) async {
    if (!_available) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(organizationId, uid, token);
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (t) => _saveToken(organizationId, uid, t),
      );
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _saveToken(
    String organizationId,
    String uid,
    String token,
  ) async {
    // device_tokens RLS (0005/0008) already restricts writes to the
    // caller's own organization membership, so this upsert cannot touch
    // another tenant's rows even if organizationId were tampered with.
    await Supabase.instance.client.from('device_tokens').upsert({
      'organization_id': organizationId,
      'user_id': uid,
      'token': token,
      'platform': defaultTargetPlatform.name,
    }, onConflict: 'token');
  }

  @override
  Future<void> unsubscribeFromOrganization(String organizationId) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('organization_id', organizationId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('FCM token cleanup failed: $e');
    }
  }
}
