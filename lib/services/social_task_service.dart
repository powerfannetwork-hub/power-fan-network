import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DailySocialTask {
  final String id;
  final String title;
  final String description;
  final String url;
  final String platform;
  final double rewardFan;

  final bool claimed;
  final bool canClaim;

  final bool followVerified;
  final bool commentVerified;
  final bool shareVerified;

  final bool requiresFollow;
  final bool requiresComment;
  final bool requiresShare;

  final DateTime? taskDate;

  const DailySocialTask({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.platform,
    required this.rewardFan,
    required this.claimed,
    required this.canClaim,
    required this.followVerified,
    required this.commentVerified,
    required this.shareVerified,
    required this.requiresFollow,
    required this.requiresComment,
    required this.requiresShare,
    required this.taskDate,
  });

  factory DailySocialTask.fromMap(Map<String, dynamic> map) {
    return DailySocialTask(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      url: (map['task_url'] ?? map['url'] ?? '').toString(),
      platform: (map['platform'] ?? '').toString(),
      rewardFan: _toDouble(map['reward_fan']),
      claimed: _toBool(map['claimed']),
      canClaim: _toBool(map['can_claim']),
      followVerified: _toBool(map['follow_verified']),
      commentVerified: _toBool(map['comment_verified']),
      shareVerified: _toBool(map['share_verified']),
      requiresFollow: _toBool(map['requires_follow']),
      requiresComment: _toBool(map['requires_comment']),
      requiresShare: _toBool(map['requires_share']),
      taskDate: _toDate(map['task_date']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1';
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class SocialTaskService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Gets today's active social-media tasks for the logged-in user.
  ///
  /// Supabase function:
  /// public.get_daily_social_tasks()
  ///
  /// IMPORTANT:
  /// This RPC takes NO parameters.
  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    try {
      final response = await _client.rpc('get_daily_social_tasks');

      if (response == null) {
        return [];
      }

      final data = response as List;

      return data
          .map(
            (item) => DailySocialTask.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to load social tasks: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Failed to load social tasks: $e',
      );
    }
  }

  /// Starts a social task.
  ///
  /// Supabase function:
  /// public.start_social_task(p_task_id uuid)
  ///
  /// IMPORTANT:
  /// User ID is NOT sent because the database gets auth.uid()
  /// automatically from the logged-in Supabase session.
  Future<Map<String, dynamic>> startTask({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Invalid social task ID.');
    }

    try {
      final response = await _client.rpc(
        'start_social_task',
        params: {
          'p_task_id': cleanTaskId,
        },
      );

      if (response == null) {
        throw Exception('Unable to start social task.');
      }

      return Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to start social task: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Failed to start social task: $e',
      );
    }
  }

  /// Opens the social-media task URL.
  Future<bool> openTaskUrl(String url) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return false;
    }

    Uri? uri;

    try {
      uri = Uri.parse(cleanUrl);
    } catch (_) {
      return false;
    }

    if (!uri.hasScheme) {
      return false;
    }

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Claims today's social reward.
  ///
  /// Supabase function:
  /// public.claim_daily_social_reward(p_task_id uuid)
  ///
  /// The server decides whether the task can actually be claimed.
  /// We do NOT fake verification from the Flutter app.
  Future<Map<String, dynamic>> verifyAndClaim({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Invalid social task ID.');
    }

    try {
      final response = await _client.rpc(
        'claim_daily_social_reward',
        params: {
          'p_task_id': cleanTaskId,
        },
      );

      if (response == null) {
        throw Exception('Unable to claim social reward.');
      }

      return Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to claim social reward: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Failed to claim social reward: $e',
      );
    }
  }

  /// Convenience method:
  /// Reloads today's tasks from Supabase.
  ///
  /// This is preferable to calling refresh_social_task_claim_status
  /// because the public daily-task function already returns the
  /// current can_claim/claimed/verification status.
  Future<List<DailySocialTask>> refreshTasks() async {
    return getDailyTasksForCard();
  }
}
