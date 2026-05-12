import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api_client.dart';

/// Manejador de mensajes en segundo plano (debe ser función top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // El sistema operativo muestra la notificación automáticamente.
}

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _androidChannel = AndroidNotificationChannel(
    'upbvote_channel',
    'UPBVote',
    description: 'Notificaciones de UPBVote',
    importance: Importance.high,
  );

  /// Inicializa Firebase y configura FCM. Llamar desde main().
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Canal de notificaciones local (Android)
      if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      }

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Mensajes en primer plano
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        final android = message.notification?.android;
        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      });
    } catch (_) {
      // Firebase no configurado: se ignoran las notificaciones push.
    }
  }

  /// Obtiene el token FCM y lo registra en el backend.
  static Future<void> registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Pedir permisos (iOS / web)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null) return;

      await ApiClient.post('/notifications/device-token/', {
        'token': token,
        'platform': Platform.operatingSystem,
      }, requiresAuth: true);

      // Si el token se renueva, re-registrar automáticamente
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient.post('/notifications/device-token/', {
            'token': newToken,
            'platform': Platform.operatingSystem,
          });
        } catch (_) {}
      });
    } catch (_) {
      // Firebase no configurado o error de red: se ignora.
    }
  }

  /// Desactiva el token FCM en el backend. Llamar antes del logout.
  static Future<void> deactivateToken() async {
    try {
      await ApiClient.delete('/notifications/device-token/deactivate/');
    } catch (_) {
      // Si falla, el servidor lo limpiará eventualmente.
    }
  }
}
