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
  final bool likeVerified;
  final bool commentVerified;
  final bool shareVerified;

  final bool requiresFollow;
  final bool requiresComment;
  final bool requiresShare;

  // Kept for compatibility with the existing UI/code.
  // The new social system does NOT use taskDate
  // to decide whether a task is available.
  final DateTime? taskDate;

  // New-post system fields.
  final String? postExternalId;
  final DateTime? postPublishedAt;

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
    required this.likeVerified,
    required this.commentVerified,
    required this.shareVerified,
    required this.requiresFollow,
    required this.requiresComment,
    required this.requiresShare,
    required this.taskDate,
    required this.postExternalId,
    required this.postPublishedAt,
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

      likeVerified: _toBool(map['like_verified']),

      commentVerified: _toBool(map['comment_verified']),

      shareVerified: _toBool(map['share_verified']),

      requiresFollow: _toBool(map['requires_follow']),

      requiresComment: _toBool(map['requires_comment']),

      requiresShare: _toBool(map['requires_share']),

      taskDate: _toDate(map['task_date']),

      postExternalId: _toNullableString(
        map['post_external_id'],
      ),

      postPublishedAt: _toDate(
        map['post_published_at'],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().toLowerCase().trim();

    return text == 'true' || text == '1';
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  /// Whether this task has a valid official post reference.
  bool get isNewPostTask {
    return postExternalId != null &&
        postExternalId!.trim().isNotEmpty;
  }

  /// Whether the user has completed the three actions
  /// required for a post reward.
  bool get postActionsVerified {
    return likeVerified &&
        commentVerified &&
        shareVerified;
  }
}

class SocialTaskService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Gets currently available official social-post tasks
  /// for the logged-in user.
  ///
  /// IMPORTANT:
  /// The Supabase RPC keeps the existing name
  /// `get_daily_social_tasks()` for compatibility.
  ///
  /// The database function no longer uses:
  ///     task_date = current_date
  ///
  /// It now returns active official posts that have
  /// a post_external_id.
  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    try {
      final response = await _client.rpc(
        'get_daily_social_tasks',
      );

      if (response == null) {
        return [];
      }

      if (response is! List) {
        throw Exception(
          'Invalid social tasks response.',
        );
      }

      return response
          .map(
            (item) {
              if (item is! Map) {
                throw Exception(
                  'Invalid social task item.',
                );
              }

              return DailySocialTask.fromMap(
                Map<String, dynamic>.from(item),
              );
            },
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

  /// Starts one specific official social post task.
  ///
  /// Supabase function:
  /// public.start_social_task(p_task_id uuid)
  ///
  /// The user ID is NOT sent from Flutter.
  /// Supabase uses auth.uid().
  Future<Map<String, dynamic>> startTask({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception(
        'Invalid social task ID.',
      );
    }

    try {
      final response = await _client.rpc(
        'start_social_task',
        params: {
          'p_task_id': cleanTaskId,
        },
      );

      if (response == null) {
        throw Exception(
          'Unable to start social task.',
        );
      }

      if (response is! Map) {
        throw Exception(
          'Invalid start social task response.',
        );
      }

      return Map<String, dynamic>.from(
        response,
      );
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

  /// Opens the official social-media post URL.
  Future<bool> openTaskUrl(String url) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return false;
    }

    Uri uri;

    try {
      uri = Uri.parse(cleanUrl);
    } catch (_) {
      return false;
    }

    if (!uri.hasScheme ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
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

  /// Claims the reward for a verified social post.
  ///
  /// IMPORTANT:
  /// This method DOES NOT perform fake verification.
  ///
  /// Verification must already have been completed by the
  /// trusted backend/server process.
  ///
  /// Required post actions:
  ///   Like + Comment + Share
  ///
  /// Follow/Subscribe/Join is handled separately through
  /// user_social_follows and is not repeated for every post.
  ///
  /// Supabase function:
  /// public.claim_daily_social_reward(p_task_id uuid)
  Future<Map<String, dynamic>> verifyAndClaim({
    required String taskId,
  }) async {
    return claimReward(
      taskId: taskId,
    );
  }

  /// Claims a verified social-post reward.
  ///
  /// This is the preferred method name for new code.
  /// `verifyAndClaim()` is kept above for compatibility
  /// with existing HomeScreen code.
  Future<Map<String, dynamic>> claimReward({
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception(
        'Invalid social task ID.',
      );
    }

    try {
      final response = await _client.rpc(
        'claim_daily_social_reward',
        params: {
          'p_task_id': cleanTaskId,
        },
      );

      if (response == null) {
        throw Exception(
          'Unable to claim social reward.',
        );
      }

      if (response is! Map) {
        throw Exception(
          'Invalid social reward response.',
        );
      }

      return Map<String, dynamic>.from(
        response,
      );
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

  /// Reloads currently available social-post tasks.
  ///
  /// The method name is kept for compatibility with
  /// existing HomeScreen code.
  Future<List<DailySocialTask>> refreshTasks() async {
    return getDailyTasksForCard();
  }
}
