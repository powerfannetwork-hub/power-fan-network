import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const String _deviceIdKey = 'power_fan_device_id';
  static const String _deviceRegisteredKey = 'device_registered';

  static const MethodChannel _deviceChannel =
      MethodChannel('power_fan_network/device');

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Returns a stable device identifier.
  ///
  /// Android:
  ///   Uses Settings.Secure.ANDROID_ID obtained from native Android.
  ///
  /// Other platforms:
  ///   Uses a locally persisted random identifier.
  ///
  /// The Android identifier is hashed before being sent to Supabase.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // ------------------------------------------------------------
    // ANDROID
    // ------------------------------------------------------------
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidId = await _deviceChannel.invokeMethod<String>(
          'getAndroidId',
        );

        if (androidId != null &&
            androidId.trim().isNotEmpty &&
            androidId != 'unknown') {
          final normalized = androidId.trim().toLowerCase();

          final hash = sha256.convert(
            utf8.encode(
              'POWER_FAN_NETWORK_DEVICE:$normalized',
            ),
          );

          final deviceId = 'PFN-A-$hash';

          // Cache only as a performance fallback.
          await prefs.setString(
            _deviceIdKey,
            deviceId,
          );

          return deviceId;
        }
      } catch (_) {
        // Continue to cached/fallback identifier.
      }
    }

    // ------------------------------------------------------------
    // CACHED IDENTIFIER
    // ------------------------------------------------------------
    final savedDeviceId = prefs.getString(_deviceIdKey);

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    // ------------------------------------------------------------
    // FALLBACK
    // ------------------------------------------------------------
    //
    // This is only used when the native stable identifier cannot
    // be obtained.
    //
    // Android normally reaches the ANDROID_ID branch above.
    //
    final randomSource = DateTime.now().microsecondsSinceEpoch.toString();

    final hash = sha256.convert(
      utf8.encode(
        'POWER_FAN_NETWORK_FALLBACK:$randomSource',
      ),
    );

    final deviceId = 'PFN-F-$hash';

    await prefs.setString(
      _deviceIdKey,
      deviceId,
    );

    return deviceId;
  }

  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (packageInfo.version.isEmpty) {
      return 'unknown';
    }

    if (packageInfo.buildNumber.isEmpty) {
      return packageInfo.version;
    }

    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<Map<String, dynamic>> registerDevice() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return {
        'success': false,
        'message': 'Authentication required',
      };
    }

    final deviceId = await getDeviceId();
    final platform = _getPlatformName();
    final appVersion = await getAppVersion();

    final result = await _supabase.rpc(
      'register_device',
      params: {
        'p_device_id': deviceId,
        'p_platform': platform,
        'p_app_version': appVersion,
      },
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception(
      'Invalid response from register_device',
    );
  }

  Future<Map<String, dynamic>> registerAndSave() async {
    final result = await registerDevice();

    final success = result['success'] == true;

    if (success) {
      await markDeviceRegistered();
    }

    return result;
  }

  Future<bool> isDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_deviceRegisteredKey) ?? false;
  }

  Future<void> markDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _deviceRegisteredKey,
      true,
    );
  }

  Future<void> clearDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    // IMPORTANT:
    // We intentionally DO NOT delete _deviceIdKey.
    //
    // Logging out or clearing registration state must not create
    // a new device identity.
    await prefs.remove(_deviceRegisteredKey);
  }

  String _getPlatformName() {
    if (kIsWeb) {
      return 'web';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    if (Platform.isWindows) {
      return 'windows';
    }

    if (Platform.isMacOS) {
      return 'macos';
    }

    if (Platform.isLinux) {
      return 'linux';
    }

    return 'unknown';
  }
}
