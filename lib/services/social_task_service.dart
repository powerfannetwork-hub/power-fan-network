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
  final bool joinVerified;
  final bool subscribeVerified;

  final bool requiresFollow;
  final bool requiresLike;
  final bool requiresComment;
  final bool requiresShare;
  final bool requiresJoin;
  final bool requiresSubscribe;

  // Kept for compatibility with the existing UI/code.
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
    required this.joinVerified,
    required this.subscribeVerified,
    required this.requiresFollow,
    required this.requiresLike,
    required this.requiresComment,
    required this.requiresShare,
    required this.requiresJoin,
    required this.requiresSubscribe,
    required this.taskDate,
    required this.postExternalId,
    required this.postPublishedAt,
  });

  factory DailySocialTask.fromMap(
    Map<String, dynamic> map,
  ) {
    return DailySocialTask(
      id: (map['id'] ?? '').toString(),

      title: (map['title'] ?? '').toString(),

      description: (map['description'] ?? '').toString(),

      url: (
        map['task_url'] ??
        map['url'] ??
        ''
      ).toString(),

      platform: (
        map['platform'] ??
        ''
      ).toString(),

      rewardFan: _toDouble(
        map['reward_fan'],
      ),

      claimed: _toBool(
        map['claimed'],
      ),

      canClaim: _toBool(
        map['can_claim'],
      ),

      followVerified: _toBool(
        map['follow_verified'],
      ),

      likeVerified: _toBool(
        map['like_verified'],
      ),

      commentVerified: _toBool(
        map['comment_verified'],
      ),

      shareVerified: _toBool(
        map['share_verified'],
      ),

      joinVerified: _toBool(
        map['join_verified'],
      ),

      subscribeVerified: _toBool(
        map['subscribe_verified'],
      ),

      requiresFollow: _toBool(
        map['requires_follow'],
      ),

      requiresLike: _toBool(
        map['requires_like'],
      ),

      requiresComment: _toBool(
        map['requires_comment'],
      ),

      requiresShare: _toBool(
        map['requires_share'],
      ),

      requiresJoin: _toBool(
        map['requires_join'],
      ),

      requiresSubscribe: _toBool(
        map['requires_subscribe'],
      ),

      taskDate: _toDate(
        map['task_date'],
      ),

      postExternalId: _toNullableString(
        map['post_external_id'],
      ),

      postPublishedAt: _toDate(
        map['post_published_at'],
      ),
    );
  }

  static double _toDouble(
    dynamic value,
  ) {
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

  static bool _toBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString().toLowerCase().trim();

    return text == 'true' || text == '1';
  }

  static DateTime? _toDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String? _toNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

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

  /// Whether all configured actions for this task
  /// have been verified.
  bool get allRequiredActionsVerified {
    if (requiresFollow && !followVerified) {
      return false;
    }

    if (requiresLike && !likeVerified) {
      return false;
    }

    if (requiresComment && !commentVerified) {
      return false;
    }

    if (requiresShare && !shareVerified) {
      return false;
    }

    if (requiresJoin && !joinVerified) {
      return false;
    }

    if (requiresSubscribe && !subscribeVerified) {
      return false;
    }

    return true;
  }

  /// Whether the user has completed the three
  /// mandatory actions for a post reward.
  bool get postActionsVerified {
    return likeVerified &&
        commentVerified &&
        shareVerified;
  }
}

class SocialTaskService {
  final SupabaseClient _client =
      Supabase.instance.client;

  /// Gets currently available official social-post tasks
  /// for the logged-in user.
  Future<List<DailySocialTask>>
      getDailyTasksForCard() async {
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
                Map<String, dynamic>.from(
                  item,
                ),
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

  /// Starts one specific official social task.
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

  /// Opens the official social-media task URL.
  Future<bool> openTaskUrl(
    String url,
  ) async {
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

  /// Claims the reward for a verified social task.
  ///
  /// Verification is performed by the trusted backend.
  Future<Map<String, dynamic>> verifyAndClaim({
    required String taskId,
  }) async {
    return claimReward(
      taskId: taskId,
    );
  }

  /// Claims a verified social-task reward.
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

  /// Reloads currently available social tasks.
  Future<List<DailySocialTask>>
      refreshTasks() async {
    return getDailyTasksForCard();
  }
}
