import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals/app_constants.dart';

class SocialTask {
  final String id;
  final String platform;
  final String title;
  final String taskUrl;
  final double rewardFan;
  final bool requiresFollow;
  final bool requiresComment;
  final bool requiresShare;

  final bool followVerified;
  final bool commentVerified;
  final bool shareVerified;

  final bool canClaim;
  final bool claimed;

  const SocialTask({
    required this.id,
    required this.platform,
    required this.title,
    required this.taskUrl,
    required this.rewardFan,
    required this.requiresFollow,
    required this.requiresComment,
    required this.requiresShare,
    required this.followVerified,
    required this.commentVerified,
    required this.shareVerified,
    required this.canClaim,
    required this.claimed,
  });

  factory SocialTask.fromMap(Map<String, dynamic> map) {
    return SocialTask(
      id: (map['id'] ?? '').toString(),
      platform: (map['platform'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      taskUrl: (map['task_url'] ?? '').toString(),
      rewardFan: _toDouble(map['reward_fan']),
      requiresFollow: _toBool(map['requires_follow']),
      requiresComment: _toBool(map['requires_comment']),
      requiresShare: _toBool(map['requires_share']),
      followVerified: _toBool(map['follow_verified']),
      commentVerified: _toBool(map['comment_verified']),
      shareVerified: _toBool(map['share_verified']),
      canClaim: _toBool(map['can_claim']),
      claimed: _toBool(map['claimed']),
    );
  }

  bool get fullyVerified =>
      (!requiresFollow || followVerified) &&
      (!requiresComment || commentVerified) &&
      (!requiresShare || shareVerified);

  bool get hasRequiredActions =>
      requiresFollow || requiresComment || requiresShare;

  bool get isReadyToClaim =>
      canClaim && fullyVerified && !claimed;

  bool get isComplete => claimed;

  int get verifiedActionCount {
    var count = 0;

    if (!requiresFollow || followVerified) {
      count++;
    }

    if (!requiresComment || commentVerified) {
      count++;
    }

    if (!requiresShare || shareVerified) {
      count++;
    }

    return count;
  }

  int get requiredActionCount {
    var count = 0;

    if (requiresFollow) {
      count++;
    }

    if (requiresComment) {
      count++;
    }

    if (requiresShare) {
      count++;
    }

    return count;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final text = value?.toString().toLowerCase().trim();

    return text == 'true' || text == '1';
  }
}

class SocialTaskClaimResult {
  final bool success;
  final String taskId;
  final double rewardFan;
  final double fanBalance;
  final bool claimed;
  final String message;

  const SocialTaskClaimResult({
    required this.success,
    required this.taskId,
    required this.rewardFan,
    required this.fanBalance,
    required this.claimed,
    required this.message,
  });

  factory SocialTaskClaimResult.fromMap(Map<String, dynamic> map) {
    return SocialTaskClaimResult(
      success: map['success'] == true,
      taskId: (map['task_id'] ?? '').toString(),
      rewardFan: _toDouble(map['reward_fan']),
      fanBalance: _toDouble(map['fan_balance']),
      claimed: map['claimed'] == true,
      message: (map['message'] ?? '').toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class SocialTaskStartResult {
  final bool success;
  final String taskId;
  final String platform;
  final String taskUrl;
  final double rewardFan;

  final bool followVerified;
  final bool commentVerified;
  final bool shareVerified;

  final bool canClaim;
  final bool claimed;

  final String message;

  const SocialTaskStartResult({
    required this.success,
    required this.taskId,
    required this.platform,
    required this.taskUrl,
    required this.rewardFan,
    required this.followVerified,
    required this.commentVerified,
    required this.shareVerified,
    required this.canClaim,
    required this.claimed,
    required this.message,
  });

  factory SocialTaskStartResult.fromMap(Map<String, dynamic> map) {
    return SocialTaskStartResult(
      success: map['success'] == true,
      taskId: (map['task_id'] ?? '').toString(),
      platform: (map['platform'] ?? '').toString(),
      taskUrl: (map['task_url'] ?? '').toString(),
      rewardFan: _toDouble(map['reward_fan']),
      followVerified: map['follow_verified'] == true,
      commentVerified: map['comment_verified'] == true,
      shareVerified: map['share_verified'] == true,
      canClaim: map['can_claim'] == true,
      claimed: map['claimed'] == true,
      message: (map['message'] ?? '').toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class SocialTaskService {
  SocialTaskService._();

  static final SocialTaskService instance = SocialTaskService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  void _requireUser() {
    final user = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;

    if (user == null || session == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  Exception _formatError(
    Object error, {
    required String action,
  }) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      final details = error.details?.toString().trim() ?? '';
      final hint = error.hint?.trim() ?? '';

      final parts = <String>[
        if (message.isNotEmpty) message,
        if (details.isNotEmpty && details != 'Bad Request')
          details,
        if (hint.isNotEmpty) hint,
      ];

      return Exception(
        parts.isEmpty
            ? 'Unable to $action.'
            : parts.join('\n'),
      );
    }

    if (error is AuthException) {
      return Exception(error.message);
    }

    return Exception(
      'Unable to $action.\n$error',
    );
  }

  // ============================================================
  // GET TODAY'S TASKS
  // ============================================================

  Future<List<SocialTask>> getDailyTasks() async {
    try {
      _requireUser();

      final result = await _supabase.rpc(
        'get_daily_social_tasks',
      );

      if (result is! List) {
        return <SocialTask>[];
      }

      return result
          .whereType<Map>()
          .map(
            (item) => SocialTask.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      throw _formatError(
        error,
        action: 'load daily social tasks',
      );
    }
  }

  // ============================================================
  // START TASK
  // ============================================================

  Future<SocialTaskStartResult> startTask({
    required String taskId,
  }) async {
    try {
      _requireUser();

      if (taskId.trim().isEmpty) {
        throw Exception('Invalid social task.');
      }

      final result = await _supabase.rpc(
        'start_social_task',
        params: <String, dynamic>{
          'p_task_id': taskId,
        },
      );

      final map = _mapResult(result);

      return SocialTaskStartResult.fromMap(map);
    } catch (error) {
      throw _formatError(
        error,
        action: 'start social task',
      );
    }
  }

  // ============================================================
  // OPEN TASK LINK
  // ============================================================

  Future<bool> openTask({
    required SocialTask task,
  }) async {
    if (task.taskUrl.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.tryParse(task.taskUrl);

      if (uri == null) {
        return false;
      }

      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint(
        'SocialTaskService.openTask error: $error',
      );

      return false;
    }
  }

  // ============================================================
  // OPEN TASK AND REGISTER IT
  // ============================================================

  Future<SocialTaskStartResult> openAndStartTask({
    required SocialTask task,
  }) async {
    final started = await startTask(
      taskId: task.id,
    );

    if (!started.success) {
      return started;
    }

    final opened = await openTask(
      task: task,
    );

    if (!opened) {
      return SocialTaskStartResult(
        success: false,
        taskId: started.taskId,
        platform: started.platform,
        taskUrl: started.taskUrl,
        rewardFan: started.rewardFan,
        followVerified: started.followVerified,
        commentVerified: started.commentVerified,
        shareVerified: started.shareVerified,
        canClaim: started.canClaim,
        claimed: started.claimed,
        message:
            'Unable to open the social-media task.',
      );
    }

    return started;
  }

  // ============================================================
  // REFRESH TASK
  // ============================================================

  Future<SocialTask?> getTask({
    required String taskId,
  }) async {
    final tasks = await getDailyTasks();

    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  // ============================================================
  // CHECK IF CLAIM IS ALLOWED
  // ============================================================

  bool canClaim({
    required SocialTask task,
  }) {
    if (task.claimed) {
      return false;
    }

    if (!task.canClaim) {
      return false;
    }

    if (!task.fullyVerified) {
      return false;
    }

    return true;
  }

  // ============================================================
  // CLAIM REWARD
  // ============================================================

  Future<SocialTaskClaimResult> claimReward({
    required String taskId,
  }) async {
    try {
      _requireUser();

      if (taskId.trim().isEmpty) {
        throw Exception('Invalid social task.');
      }

      // ----------------------------------------------------------
      // IMPORTANT SECURITY RULE
      // ----------------------------------------------------------
      //
      // We do NOT add FAN here ourselves.
      //
      // The database function:
      //
      // claim_daily_social_reward()
      //
      // checks:
      //
      // follow_verified
      // comment_verified
      // share_verified
      // can_claim
      // claimed
      //
      // and ONLY THEN adds the configured reward.
      //
      // Therefore the Flutter client cannot simply give itself
      // FAN by changing a local variable.
      // ----------------------------------------------------------

      final result = await _supabase.rpc(
        'claim_daily_social_reward',
        params: <String, dynamic>{
          'p_task_id': taskId,
        },
      );

      final map = _mapResult(result);

      return SocialTaskClaimResult.fromMap(map);
    } catch (error) {
      throw _formatError(
        error,
        action: 'claim social task reward',
      );
    }
  }

  // ============================================================
  // CLAIM ONLY AFTER FRESH BACKEND CHECK
  // ============================================================

  Future<SocialTaskClaimResult> verifyAndClaim({
    required String taskId,
  }) async {
    try {
      _requireUser();

      final task = await getTask(
        taskId: taskId,
      );

      if (task == null) {
        throw Exception(
          'This social task is no longer available.',
        );
      }

      if (task.claimed) {
        throw Exception(
          'This reward has already been claimed.',
        );
      }

      if (!task.canClaim || !task.fullyVerified) {
        throw Exception(
          'Your Follow, Comment and Share actions have not been fully verified yet.',
        );
      }

      return await claimReward(
        taskId: taskId,
      );
    } catch (error) {
      throw _formatError(
        error,
        action: 'verify and claim social task',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _mapResult(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return <String, dynamic>{
      'success': false,
      'message': 'Invalid response from the service.',
    };
  }

  // ============================================================
  // PLATFORM DISPLAY NAME
  // ============================================================

  String platformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return 'Facebook';

      case 'youtube':
        return 'YouTube';

      case 'tiktok':
        return 'TikTok';

      case 'x':
        return 'X';

      case 'telegram':
        return 'Telegram';

      case 'instagram':
        return 'Instagram';

      default:
        return platform;
    }
  }

  // ============================================================
  // REQUIRED ACTION DESCRIPTION
  // ============================================================

  String actionDescription(SocialTask task) {
    final actions = <String>[];

    if (task.requiresFollow) {
      actions.add(
        task.platform.toLowerCase() == 'youtube'
            ? 'Subscribe'
            : 'Follow',
      );
    }

    if (task.requiresComment) {
      actions.add('Comment');
    }

    if (task.requiresShare) {
      actions.add('Share');
    }

    if (actions.isEmpty) {
      return 'Complete the task.';
    }

    if (actions.length == 1) {
      return actions.first;
    }

    if (actions.length == 2) {
      return '${actions[0]} and ${actions[1]}';
    }

    return '${actions[0]}, ${actions[1]} and ${actions[2]}';
  }

  // ============================================================
  // REWARD TEXT
  // ============================================================

  String rewardText(SocialTask task) {
    return '${task.rewardFan.toStringAsFixed(0)} ${AppConfig.miningCoinName}';
  }

  // ============================================================
  // VERIFICATION TEXT
  // ============================================================

  String verificationText(SocialTask task) {
    if (task.claimed) {
      return 'Reward claimed';
    }

    if (task.isReadyToClaim) {
      return 'Verified — ready to claim';
    }

    if (!task.fullyVerified) {
      return 'Complete and verify all required actions';
    }

    return 'Waiting for verification';
  }
}
