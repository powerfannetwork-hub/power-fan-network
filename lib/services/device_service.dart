import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const String _deviceIdKey = 'power_fan_device_id';
  static const String _deviceRegisteredKey = 'device_registered';

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDeviceId = prefs.getString(_deviceIdKey);

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    final platform = _getPlatformName();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final deviceId = 'PFN-$platform-$timestamp';

    await prefs.setString(_deviceIdKey, deviceId);

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
