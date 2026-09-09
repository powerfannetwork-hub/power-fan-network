import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const String _deviceIdKey = 'power_fan_device_id';

  final SupabaseClient _supabase =
      Supabase.instance.client;

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

  Future<Map<String, dynamic>> registerDevice() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Authentication required');
    }

    final deviceId = await getDeviceId();

    final result = await _supabase.rpc(
      'register_device',
      params: {
        'p_device_id': deviceId,
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

  Future<bool> isDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('device_registered') ?? false;
  }

  Future<void> markDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'device_registered',
      true,
    );
  }

  Future<void> clearDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('device_registered');
  }

  Future<Map<String, dynamic>> registerAndSave() async {
    final result = await registerDevice();

    final success = result['success'] == true;

    if (success) {
      await markDeviceRegistered();
    }

    return result;
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
