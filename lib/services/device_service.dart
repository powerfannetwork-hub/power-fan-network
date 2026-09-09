import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const String _deviceIdKey = 'power_fan_device_id';
  static const String _deviceRegisteredKey = 'device_registered';

  static const MethodChannel _deviceChannel =
      MethodChannel('power_fan/device');

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    /*
     * Android:
     * Android ANDROID_ID -> SHA-256 -> Supabase
     *
     * We intentionally do not generate a new random/timestamp
     * identity on Android because that would weaken device binding.
     */
    if (!kIsWeb && Platform.isAndroid) {
      final androidId = await _getAndroidId();

      final hashedDeviceId = sha256
          .convert(utf8.encode(androidId))
          .toString();

      final deviceId = 'ANDROID-$hashedDeviceId';

      await prefs.setString(_deviceIdKey, deviceId);

      return deviceId;
    }

    /*
     * Non-Android fallback.
     *
     * Android uses the native ANDROID_ID above.
     */
    final savedDeviceId = prefs.getString(_deviceIdKey);

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    final platform = _getPlatformName();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final deviceId = 'PFN-$platform-$timestamp';

    await prefs.setString(
      _deviceIdKey,
      deviceId,
    );

    return deviceId;
  }

  Future<String> _getAndroidId() async {
    try {
      final androidId =
          await _deviceChannel.invokeMethod<String>(
        'getAndroidId',
      );

      if (androidId == null || androidId.trim().isEmpty) {
        throw Exception(
          'Android device ID is unavailable.',
        );
      }

      return androidId.trim();
    } on PlatformException catch (e) {
      throw Exception(
        'Unable to read Android device ID: ${e.message ?? e.code}',
      );
    }
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

    /*
     * IMPORTANT:
     * We only clear the local registration flag.
     *
     * We DO NOT delete the actual device ID.
     * This preserves the one-device-one-account binding
     * even after logout.
     */
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
