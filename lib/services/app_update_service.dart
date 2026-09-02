import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.minimumSupportedVersion,
    required this.updateRequired,
  });

  final String currentVersion;
  final String minimumSupportedVersion;
  final bool updateRequired;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String minimumVersionKey =
      'minimum_supported_version';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.fanmining.app';

  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    return packageInfo.version.trim();
  }

  Future<String> getMinimumSupportedVersion() async {
    final response = await _supabase
        .from('app_settings')
        .select('value')
        .eq('key', minimumVersionKey)
        .maybeSingle();

    if (response == null) {
      return '1.0.0';
    }

    final value = response['value'];

    if (value == null) {
      return '1.0.0';
    }

    return value.toString().trim();
  }

  Future<AppUpdateInfo> checkForUpdate() async {
    final currentVersion = await getCurrentVersion();

    final minimumVersion =
        await getMinimumSupportedVersion();

    final required =
        _compareVersions(
          currentVersion,
          minimumVersion,
        ) <
        0;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      minimumSupportedVersion: minimumVersion,
      updateRequired: required,
    );
  }

  int _compareVersions(
    String current,
    String minimum,
  ) {
    final currentParts =
        _versionParts(current);

    final minimumParts =
        _versionParts(minimum);

    final length =
        currentParts.length > minimumParts.length
            ? currentParts.length
            : minimumParts.length;

    for (var i = 0; i < length; i++) {
      final currentValue =
          i < currentParts.length
              ? currentParts[i]
              : 0;

      final minimumValue =
          i < minimumParts.length
              ? minimumParts[i]
              : 0;

      if (currentValue > minimumValue) {
        return 1;
      }

      if (currentValue < minimumValue) {
        return -1;
      }
    }

    return 0;
  }

  List<int> _versionParts(String version) {
    return version
        .split('.')
        .map((part) {
          final clean =
              part.replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );

          return int.tryParse(clean) ?? 0;
        })
        .toList();
  }

  Future<bool> openPlayStore() async {
    final uri = Uri.parse(playStoreUrl);

    if (Platform.isAndroid) {
      final launched =
          await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return true;
      }
    }

    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}
