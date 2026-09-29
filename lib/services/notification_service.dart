import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;
  bool _timezoneInitialized = false;

  static const String _channelId =
      'power_fan_mining';

  static const String _channelName =
      'POWER FAN NETWORK';

  static const String _channelDescription =
      'POWER FAN NETWORK mining and activity notifications';

  static const int _miningEndedNotificationId =
      2001;

  static const int _inactiveReminderBaseId =
      2100;

  /*
   * We prepare 56 reminders:
   *
   * 56 × 6 hours = 336 hours
   * 336 hours = 14 days
   *
   * When the user opens the app again, the schedule
   * is refreshed from the real server state.
   */
  static const int _inactiveReminderCount =
      56;

  static const Duration _inactiveReminderInterval =
      Duration(hours: 6);

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

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      return;
    }

    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    _initializeTimezone();

    const AndroidInitializationSettings
        androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const InitializationSettings settings =
        InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse:
          _onNotificationResponse,
    );

    final AndroidFlutterLocalNotificationsPlugin?
        androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      _channel,
    );

    _initialized = true;
  }

  void _initializeTimezone() {
    if (_timezoneInitialized) {
      return;
    }

    tz.initializeTimeZones();

    /*
     * For relative scheduling we only need the
     * correct absolute instant.
     *
     * UTC is deliberately used here so the
     * server-provided remaining time is not
     * changed by the phone's timezone.
     */
    tz.setLocalLocation(tz.UTC);

    _timezoneInitialized = true;
  }

  // ============================================================
  // PERMISSION
  // ============================================================

  Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    await initialize();

    if (_permissionRequested) {
      return areNotificationsEnabled();
    }

    _permissionRequested = true;

    final AndroidFlutterLocalNotificationsPlugin?
        androidPlugin =
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

    final AndroidFlutterLocalNotificationsPlugin?
        androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? enabled =
        await androidPlugin?.areNotificationsEnabled();

    return enabled ?? false;
  }

  // ============================================================
  // COMMON NOTIFICATION DETAILS
  // ============================================================

  static const AndroidNotificationDetails
      _androidDetails =
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

  static const NotificationDetails _details =
      NotificationDetails(
    android: _androidDetails,
  );

  // ============================================================
  // IMMEDIATE NOTIFICATION
  // ============================================================

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

    final bool enabled =
        await areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    await _plugin.show(
      id,
      title,
      body,
      _details,
      payload: payload,
    );
  }

  // ============================================================
  // MINING NOTIFICATION CONTROL
  //
  // THIS IS THE MAIN METHOD HOME SCREEN WILL CALL.
  //
  // If mining is active:
  //   1. Cancel old inactive reminders.
  //   2. Schedule mining-end notification.
  //   3. Schedule 6-hour reminders AFTER mining ends.
  //
  // If mining is NOT active:
  //   1. Cancel mining-end notification.
  //   2. Schedule reminders every 6 hours.
  // ============================================================

  Future<void> syncMiningNotifications({
    required bool isMining,
    required int remainingSeconds,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    final bool enabled =
        await areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    if (isMining &&
        remainingSeconds > 0) {
      await cancelMiningEndNotification();
      await cancelInactiveReminders();

      await scheduleMiningEndNotification(
        remainingSeconds:
            remainingSeconds,
      );

      await scheduleInactiveReminders(
        firstReminderAfter:
            Duration(
          seconds: remainingSeconds,
        ) +
                _inactiveReminderInterval,
      );

      return;
    }

    await cancelMiningEndNotification();

    await scheduleInactiveReminders(
      firstReminderAfter:
          _inactiveReminderInterval,
    );
  }

  // ============================================================
  // MINING END
  // ============================================================

  Future<void> scheduleMiningEndNotification({
    required int remainingSeconds,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    if (remainingSeconds <= 0) {
      return;
    }

    await initialize();

    final scheduledAt =
        DateTime.now().add(
      Duration(
        seconds: remainingSeconds,
      ),
    );

    await _schedule(
      id: _miningEndedNotificationId,
      title: 'Mining Session Ended',
      body:
          'Your 24-hour mining session has ended. Open POWER FAN NETWORK to claim your FAN and start a new session.',
      scheduledAt: scheduledAt,
      payload: 'mining_ended',
    );
  }

  Future<void> cancelMiningEndNotification() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    await _plugin.cancel(
      _miningEndedNotificationId,
    );
  }

  // ============================================================
  // INACTIVE REMINDERS
  //
  // Every 6 hours.
  //
  // The reminders are scheduled in advance so they can
  // appear even while the app is closed.
  // ============================================================

  Future<void> scheduleInactiveReminders({
    required Duration firstReminderAfter,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    await cancelInactiveReminders();

    for (
      int index = 0;
      index < _inactiveReminderCount;
      index++
    ) {
      final delay =
          firstReminderAfter +
              (_inactiveReminderInterval *
                  index);

      final scheduledAt =
          DateTime.now().add(delay);

      /*
       * Do not schedule something that is already
       * in the past.
       */
      if (!scheduledAt.isAfter(
        DateTime.now(),
      )) {
        continue;
      }

      await _schedule(
        id:
            _inactiveReminderBaseId +
                index,
        title:
            'Your FAN Miner Needs You',
        body:
            'You are not actively mining. Open POWER FAN NETWORK and start your next mining session.',
        scheduledAt:
            scheduledAt,
        payload:
            'inactive_mining_reminder',
      );
    }
  }

  Future<void> cancelInactiveReminders() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    for (
      int index = 0;
      index < _inactiveReminderCount;
      index++
    ) {
      await _plugin.cancel(
        _inactiveReminderBaseId +
            index,
      );
    }
  }

  // ============================================================
  // SCHEDULE ONE NOTIFICATION
  // ============================================================

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    await initialize();

    final bool enabled =
        await areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    if (!scheduledAt.isAfter(
      DateTime.now(),
    )) {
      return;
    }

    _initializeTimezone();

    final tz.TZDateTime tzScheduledAt =
        tz.TZDateTime.from(
      scheduledAt,
      tz.local,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledAt,
      _details,
      androidScheduleMode:
          AndroidScheduleMode
              .inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime,
      payload: payload,
    );
  }

  // ============================================================
  // MINING STARTED
  // ============================================================

  Future<void> showMiningStarted({
    String? payload,
  }) async {
    await show(
      id: 1001,
      title: 'Mining Started',
      body:
          'Your FAN mining session has started successfully.',
      payload:
          payload ?? 'mining_started',
    );
  }

  // ============================================================
  // MINING ENDED — IMMEDIATE VERSION
  //
  // This can be used if the app discovers that the
  // server session has already ended.
  // ============================================================

  Future<void> showMiningEnded({
    String? payload,
  }) async {
    await show(
      id: 1002,
      title: 'Mining Session Ended',
      body:
          'Your mining session has ended. Open POWER FAN NETWORK to claim your FAN and start a new session.',
      payload:
          payload ?? 'mining_ended',
    );
  }

  // ============================================================
  // REFERRAL
  // ============================================================

  Future<void> showReferralReminder({
    String? payload,
  }) async {
    await show(
      id: 1003,
      title: 'Referral Reminder',
      body:
          'Your referral is not active yet. Invite them to start mining.',
      payload:
          payload ?? 'referral_reminder',
    );
  }

  // ============================================================
  // DAILY TASK
  // ============================================================

  Future<void> showDailyTaskReminder({
    String? payload,
  }) async {
    await show(
      id: 1004,
      title: 'Daily Task',
      body:
          'Your daily social task is available. Complete it and claim your FAN reward.',
      payload:
          payload ?? 'daily_task',
    );
  }

  // ============================================================
  // KYC
  // ============================================================

  Future<void> showKycUnlocked({
    String? payload,
  }) async {
    await show(
      id: 1005,
      title: 'KYC Ready',
      body:
          'Your KYC progress is complete. Face verification is now available when the verification provider is connected.',
      payload:
          payload ?? 'kyc_unlocked',
    );
  }

  // ============================================================
  // GENERAL
  // ============================================================

  Future<void> showGeneral({
    required String title,
    required String body,
    String? payload,
  }) async {
    await show(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .remainder(2147483647),
      title: title,
      body: body,
      payload:
          payload ?? 'general',
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

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

  Future<List<PendingNotificationRequest>>
      pendingNotifications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return <PendingNotificationRequest>[];
    }

    await initialize();

    return _plugin.pendingNotificationRequests();
  }

  // ============================================================
  // NOTIFICATION TAP
  // ============================================================

  void _onNotificationResponse(
    NotificationResponse response,
  ) {
    final String? payload =
        response.payload;

    if (kDebugMode) {
      debugPrint(
        'POWER FAN notification tapped: '
        '${payload ?? 'no_payload'}',
      );
    }
  }
}
