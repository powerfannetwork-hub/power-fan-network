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

  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_daily_social_tasks',
        params: {
          'p_user_id': _userId,
        },
      );

      if (result == null) {
        return <DailySocialTask>[];
      }

      final rows = result is List
          ? result
          : <dynamic>[result];

      return rows
          .whereType<Map>()
          .map(
            (task) => DailySocialTask(
              id: task['id']?.toString() ?? '',
              title: task['title']?.toString() ?? '',
              description:
                  task['description']?.toString() ?? '',
              claimed:
                  task['claimed'] == true ||
                  task['is_claimed'] == true ||
                  task['completed'] == true,
              rewardFan: _toInt(
                task['reward_fan'] ??
                    task['reward'] ??
                    10,
              ),
              url: task['url']?.toString() ?? '',
              platform:
                  task['platform']?.toString() ?? 'link',
            ),
          )
          .where((task) => task.id.isNotEmpty)
          .toList();
    });
  }

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
          'p_task_id': taskId,
        },
      );
    });
  }

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
          'p_task_id': taskId,
        },
      );

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
    });
  }

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
          'p_task_id': taskId,
        },
      );

      if (result == null) {
        return <String, dynamic>{
          'success': true,
          'reward': 10,
        };
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return <String, dynamic>{
        'success': true,
        'reward': _toInt(result),
      };
    });
  }

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

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
