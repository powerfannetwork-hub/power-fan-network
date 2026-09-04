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

  /// Gets today's active social-media tasks.
  ///
  /// This uses the Supabase RPC:
  /// get_daily_social_tasks()
  ///
  /// The RPC is responsible for returning the user's current
  /// verification/claim status for today's tasks.
  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_daily_social_tasks',
      );

      if (result == null) {
        return <DailySocialTask>[];
      }

      if (result is! List) {
        return <DailySocialTask>[];
      }

      final tasks = <DailySocialTask>[];

      for (final item in result) {
        if (item is! Map) {
          continue;
        }

        final task = Map<String, dynamic>.from(item);

        final id = task['id']?.toString().trim() ?? '';

        final platform =
            task['platform']?.toString().trim().toLowerCase() ?? '';

        final title =
            task['title']?.toString().trim() ?? '';

        final url =
            task['task_url']?.toString().trim() ?? '';

        final reward = _toInt(
          task['reward_fan'] ?? 10,
        );

        final claimed =
            task['claimed'] == true;

        if (id.isEmpty || url.isEmpty) {
          continue;
        }

        tasks.add(
          DailySocialTask(
            id: id,
            title: title.isNotEmpty
                ? title
                : _defaultTitle(platform),
            description: _defaultDescription(platform),
            claimed: claimed,
            rewardFan: reward > 0 ? reward : 10,
            url: url,
            platform: platform,
          ),
        );
      }

      return tasks;
    });
  }

  /// Starts/tracks a social task.
  ///
  /// Supabase handles the actual server-side task tracking.
  Future<void> startTask({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Invalid task.');
    }

    await SupabaseService.safeCall(() async {
      await _client.rpc(
        'start_social_task',
        params: {
          'p_user_id': _userId,
          'p_task_id': cleanTaskId,
        },
      );
    });
  }

  /// Verifies whether the user completed the required
  /// social-media actions.
  Future<bool> verifyTask({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Invalid task.');
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'verify_social_task_actions',
        params: {
          'p_user_id': _userId,
          'p_task_id': cleanTaskId,
        },
      );

      return _parseBoolResult(result);
    });
  }

  /// Claims the daily social reward.
  ///
  /// The reward is created server-side by Supabase.
  /// Flutter does NOT directly modify the FAN balance.
  Future<Map<String, dynamic>> verifyAndClaim({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Invalid task.');
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'claim_daily_social_reward',
        params: {
          'p_user_id': _userId,
          'p_task_id': cleanTaskId,
        },
      );

      return _parseMapResult(result);
    });
  }

  /// Refreshes today's social-task claim status.
  ///
  /// This asks Supabase to recalculate the user's task status.
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

  /// Converts different Supabase RPC return formats
  /// into a boolean.
  bool _parseBoolResult(dynamic result) {
    if (result is bool) {
      return result;
    }

    if (result is Map) {
      return result['verified'] == true ||
          result['success'] == true ||
          result['is_verified'] == true ||
          result['can_claim'] == true;
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is bool) {
        return first;
      }

      if (first is Map) {
        return first['verified'] == true ||
            first['success'] == true ||
            first['is_verified'] == true ||
            first['can_claim'] == true;
      }
    }

    return false;
  }

  /// Converts the Supabase claim RPC result
  /// into a predictable Map.
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
