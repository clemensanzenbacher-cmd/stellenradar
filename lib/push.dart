/// Push-Benachrichtigungen über Firebase Cloud Messaging.
/// Der Wächter sendet an das Thema „stellen“; die App meldet sich beim Start dafür an.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Push {
  static const thema = 'stellen';

  final GlobalKey<ScaffoldMessengerState> messenger;
  final void Function(String id, String url) oeffnen;

  Push({required this.messenger, required this.oeffnen});

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  Future<void> starte() async {
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);
      await _fm.subscribeToTopic(thema);
    } catch (e) {
      debugPrint('Push nicht verfügbar: $e');
    }
    FirebaseMessaging.onMessage.listen(_imVordergrund);
    FirebaseMessaging.onMessageOpenedApp.listen(_geoeffnet);
    try {
      final start = await _fm.getInitialMessage();
      if (start != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _geoeffnet(start));
      }
    } catch (e) {
      debugPrint('Startnachricht nicht lesbar: $e');
    }
  }

  void _geoeffnet(RemoteMessage m) =>
      oeffnen(m.data['id']?.toString() ?? '', m.data['url']?.toString() ?? '');

  /// Ist die App offen, zeigt Android keine Systemmeldung – dann ein Hinweis in der App.
  void _imVordergrund(RemoteMessage m) {
    HapticFeedback.heavyImpact();
    final titel = m.notification?.title ?? 'Neue Stelle';
    final text = m.notification?.body ?? '';
    messenger.currentState?.showSnackBar(SnackBar(
      content: Text(text.isEmpty ? titel : '$titel\n$text'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: 'Öffnen', onPressed: () => _geoeffnet(m)),
    ));
  }

  Future<bool> erlaubt() async {
    try {
      final s = await _fm.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<bool> erneutAnfragen() async {
    try {
      final s = await _fm.requestPermission(alert: true, badge: true, sound: true);
      await _fm.subscribeToTopic(thema);
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }
}
