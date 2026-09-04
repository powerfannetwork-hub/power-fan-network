import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class DailySocialTask {
  final String id;
  final String title;
  final String description;
  final bool claimed;
  final int rewardFan;
  final String url;
  final String platform;

  const DailySocialTask({
    required this.id,
    required this.title,
    required this.description,
    required this.claimed,
    required this.rewardFan,
    required this.url,
    required this.platform,
  });
}

class SocialTaskService {
  SocialTaskService._();

  static final SocialTaskService instance = SocialTaskService._();

  final SupabaseClient _client = SupabaseService.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.id;
  }

  /// Gets the active social-media tasks from Supabase.
  ///
  /// The social_tasks table uses:
  /// id, platform, title, task_url, reward_fan, active, task_date
  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    return SupabaseService.safeCall(() async {
      final result = await _client
          .from('social_tasks')
          .select(
            'id, platform, title, task_url, reward_fan, active, task_date',
          )
          .eq('active', true)
          .order('created_at', ascending: true);

      if (result.isEmpty) {
        return <DailySocialTask>[];
      }

      return result
          .whereType<Map<String, dynamic>>()
          .map(
            (task) {
              final platform =
                  task['platform']?.toString().trim() ?? 'link';

              final title =
                  task['title']?.toString().trim() ?? '';

              final url =
                  task['task_url']?.toString().trim() ?? '';

              final reward = _toInt(
                task['reward_fan'] ?? 10,
              );

              return DailySocialTask(
                id: task['id']?.toString() ?? '',
                title: title.isNotEmpty
                    ? title
                    : _defaultTitle(platform),
                description: _defaultDescription(platform),
                claimed: false,
                rewardFan: reward > 0 ? reward : 10,
                url: url,
                platform: platform,
              );
            },
          )
          .where(
            (task) =>
                task.id.isNotEmpty &&
                task.url.isNotEmpty,
          )
          .toList();
    });
  }

  /// Starts/tracks a social task.
  Future<void> startTask({
    required String taskId,
  }) async {
    if (taskId.trim().isEmpty) {
      throw Exception('Invalid task.');
    }

    await SupabaseService.safeCall(() async {
      await _client.rpc(
        'start_social_task',
        params: {
          'p_user_id': _userId,
          'p_task_id': taskId.trim(),
        },
      );
    });
  }

  /// Verifies whether the user completed the social task.
  Future<bool> verifyTask({
    required String taskId,
  }) async {
    if (taskId.trim().isEmpty) {
      throw Exception('Invalid task.');
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'verify_social_task_actions',
        params: {
          'p_user_id': _userId,
          'p_task_id': taskId.trim(),
        },
      );

      return _parseBoolResult(result);
    });
  }

  /// Claims the social reward.
  ///
  /// The actual reward amount comes from the Supabase function.
  /// This prevents the Flutter app from creating its own FAN balance.
  Future<Map<String, dynamic>> verifyAndClaim({
    required String taskId,
  }) async {
    if (taskId.trim().isEmpty) {
      throw Exception('Invalid task.');
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'claim_daily_social_reward',
        params: {
          'p_user_id': _userId,
          'p_task_id': taskId.trim(),
        },
      );

      return _parseMapResult(result);
    });
  }

  /// Refreshes the claim state on the server.
  Future<void> refreshClaimStatus() async {
    await SupabaseService.safeCall(() async {
      await _client.rpc(
        'refresh_social_task_claim_status',
        params: {
          'p_user_id': _userId,
        },
      );
    });
  }

  bool _parseBoolResult(dynamic result) {
    if (result is bool) {
      return result;
    }

    if (result is Map) {
      return result['verified'] == true ||
          result['success'] == true ||
          result['is_verified'] == true;
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is bool) {
        return first;
      }

      if (first is Map) {
        return first['verified'] == true ||
            first['success'] == true ||
            first['is_verified'] == true;
      }
    }

    return false;
  }

  Map<String, dynamic> _parseMapResult(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List &&
        result.isNotEmpty &&
        result.first is Map) {
      return Map<String, dynamic>.from(result.first);
    }

    if (result is bool) {
      return {
        'success': result,
      };
    }

    if (result is num) {
      return {
        'success': true,
        'reward': result.toInt(),
      };
    }

    return {
      'success': false,
    };
  }

  String _defaultTitle(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return 'Follow, Comment and Share';

      case 'youtube':
        return 'Subscribe, Comment and Share';

      case 'tiktok':
        return 'Follow, Comment and Share';

      case 'x':
      case 'twitter':
        return 'Follow, Comment and Share';

      case 'telegram':
        return 'Join, Comment and Share';

      case 'instagram':
        return 'Follow, Comment and Share';

      default:
        return 'Complete Social Task';
    }
  }

  String _defaultDescription(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return 'Visit our Facebook page and complete the task.';

      case 'youtube':
        return 'Visit our YouTube channel and complete the task.';

      case 'tiktok':
        return 'Visit our TikTok page and complete the task.';

      case 'x':
      case 'twitter':
        return 'Visit our X page and complete the task.';

      case 'telegram':
        return 'Join our Telegram community and complete the task.';

      case 'instagram':
        return 'Visit our Instagram page and complete the task.';

      default:
        return 'Complete this social media task.';
    }
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
