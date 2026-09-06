import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  static const String _channelId = 'power_fan_general';
  static const String _channelName = 'POWER FAN NETWORK';
  static const String _channelDescription =
      'POWER FAN NETWORK app notifications';

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      return;
    }

    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    await initialize();

    if (_permissionRequested) {
      return true;
    }

    _permissionRequested = true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted =
        await androidPlugin?.requestNotificationsPermission();

    return granted ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? enabled = await androidPlugin?.areNotificationsEnabled();

    return enabled ?? false;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    final bool enabled = await areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showMiningStarted({
    String? payload,
  }) async {
    await show(
      id: 1001,
      title: 'Mining Started',
      body: 'Your FAN mining session has started successfully.',
      payload: payload ?? 'mining_started',
    );
  }

  Future<void> showMiningEnded({
    String? payload,
  }) async {
    await show(
      id: 1002,
      title: 'Mining Session Ended',
      body: 'Your mining session has ended. Start a new session to continue mining FAN.',
      payload: payload ?? 'mining_ended',
    );
  }

  Future<void> showReferralReminder({
    String? payload,
  }) async {
    await show(
      id: 1003,
      title: 'Referral Reminder',
      body: 'Your referral is not active yet. Invite them to start mining.',
      payload: payload ?? 'referral_reminder',
    );
  }

  Future<void> showDailyTaskReminder({
    String? payload,
  }) async {
    await show(
      id: 1004,
      title: 'Daily Task',
      body: 'Your daily social task is available. Complete it and claim your FAN reward.',
      payload: payload ?? 'daily_task',
    );
  }

  Future<void> showKycUnlocked({
    String? payload,
  }) async {
    await show(
      id: 1005,
      title: 'KYC Ready',
      body: 'Your KYC progress is complete. Face verification is now available when the verification provider is connected.',
      payload: payload ?? 'kyc_unlocked',
    );
  }

  Future<void> showGeneral({
    required String title,
    required String body,
    String? payload,
  }) async {
    await show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      payload: payload ?? 'general',
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return <PendingNotificationRequest>[];
    }

    await initialize();

    return _plugin.pendingNotificationRequests();
  }

  void _onNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;

    if (kDebugMode) {
      debugPrint(
        'POWER FAN notification tapped: ${payload ?? 'no_payload'}',
      );
    }
  }
}
