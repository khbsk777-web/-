import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../audio/snore_detector.dart';

const notificationChannelId = 'sleep_ai_recording';
const notificationId = 999;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const androidConfig = AndroidConfiguration(
    onStart: onStart,
    autoStart: false,
    isForegroundMode: true,
    notificationChannelId: notificationChannelId,
    initialNotificationTitle: 'Sleep AI',
    initialNotificationContent: '睡眠を記録中...',
    foregroundServiceNotificationId: notificationId,
  );

  const iosConfig = IosConfiguration(
    autoStart: false,
    onForeground: onStart,
    onBackground: onIosBackground,
  );

  await service.configure(
    androidConfiguration: androidConfig,
    iosConfiguration: iosConfig,
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Update notification every minute with elapsed time
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        notifications.show(
          notificationId,
          'Sleep AI - 記録中',
          '睡眠を記録しています...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              '睡眠記録',
              icon: '@mipmap/ic_launcher',
              ongoing: true,
            ),
          ),
        );
      }
    }

    service.invoke('update', {'timestamp': DateTime.now().toIso8601String()});
  });
}

class BackgroundServiceManager {
  static final _service = FlutterBackgroundService();

  static Future<bool> isRunning() => _service.isRunning();

  static Future<void> startService() async {
    await _service.startService();
    _service.invoke('setAsForeground');
  }

  static Future<void> stopService() async {
    _service.invoke('stopService');
  }

  static Stream<Map<String, dynamic>?> get updateStream =>
      _service.on('update');
}
