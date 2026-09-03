import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/daily_social_card.dart';
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

  factory SocialTask.fromMap(
    Map<String, dynamic> map,
  ) {
    return SocialTask(
      id: _string(map['id']),
      platform: _string(map['platform']),
      title: _string(map['title']),
      taskUrl: _string(
        map['task_url'] ?? map['url'],
      ),
      rewardFan: _double(
        map['reward_fan'] ?? map['reward'],
      ),
      requiresFollow:
          _bool(map['requires_follow']),
      requiresComment:
          _bool(map['requires_comment']),
      requiresShare:
          _bool(map['requires_share']),
      followVerified:
          _bool(map['follow_verified']),
      commentVerified:
          _bool(map['comment_verified']),
      shareVerified:
          _bool(map['share_verified']),
      canClaim:
          _bool(map['can_claim']),
      claimed:
          _bool(map['claimed']),
    );
  }

  bool get fullyVerified {
    final followOk =
        !requiresFollow || followVerified;

    final commentOk =
        !requiresComment || commentVerified;

    final shareOk =
        !requiresShare || shareVerified;

    return followOk &&
        commentOk &&
        shareOk;
  }

  bool get isReadyToClaim {
    return canClaim &&
        fullyVerified &&
        !claimed;
  }

  static String _string(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
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

  factory SocialTaskClaimResult.fromMap(
    Map<String, dynamic> map,
  ) {
    return SocialTaskClaimResult(
      success: _bool(map['success']),
      taskId: _string(map['task_id']),
      rewardFan: _double(
        map['reward_fan'],
      ),
      fanBalance: _double(
        map['fan_balance'],
      ),
      claimed: _bool(map['claimed']),
      message: _string(
        map['message'],
      ),
    );
  }

  static String _string(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() ==
        'true';
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

  factory SocialTaskStartResult.fromMap(
    Map<String, dynamic> map,
  ) {
    return SocialTaskStartResult(
      success: _bool(map['success']),
      taskId: _string(map['task_id']),
      platform: _string(map['platform']),
      taskUrl: _string(
        map['task_url'],
      ),
      rewardFan: _double(
        map['reward_fan'],
      ),
      followVerified:
          _bool(map['follow_verified']),
      commentVerified:
          _bool(map['comment_verified']),
      shareVerified:
          _bool(map['share_verified']),
      canClaim:
          _bool(map['can_claim']),
      claimed:
          _bool(map['claimed']),
      message:
          _string(map['message']),
    );
  }

  static String _string(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() ==
        'true';
  }
}

class SocialTaskService {
  SocialTaskService._();

  static final SocialTaskService instance =
      SocialTaskService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  void _requireUser() {
    final user =
        _supabase.auth.currentUser;

    final session =
        _supabase.auth.currentSession;

    if (user == null || session == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  Exception _formatError(
    Object error, {
    required String action,
  }) {
    if (error is PostgrestException) {
      final message =
          error.message.trim();

      final details =
          error.details?.toString().trim() ?? '';

      final hint =
          error.hint?.trim() ?? '';

      final parts = <String>[
        if (message.isNotEmpty) message,
        if (details.isNotEmpty &&
            details != 'Bad Request')
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
      'Unable to $action.',
    );
  }

  Future<List<SocialTask>>
      getDailyTasks() async {
    try {
      _requireUser();

      final result =
          await _supabase.rpc(
        'get_daily_social_tasks',
      );

      if (result is! List) {
        return <SocialTask>[];
      }

      return result
          .whereType<Map>()
          .map(
            (item) =>
                SocialTask.fromMap(
              Map<String, dynamic>.from(
                item,
              ),
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

  Future<List<DailySocialTask>>
      getDailyTasksForCard() async {
    final tasks =
        await getDailyTasks();

    return tasks.map((task) {
      final platform =
          _normalizePlatform(
        task.platform,
      );

      final officialUrl =
          _officialLinks[platform];

      final url =
          officialUrl ??
          task.taskUrl;

      final description =
          _descriptionForPlatform(
        task.platform,
      );

      return DailySocialTask(
        id: task.id,
        platform: task.platform,
        title: task.title.isEmpty
            ? 'Follow on ${task.platform}'
            : task.title,
        description:
            description.isEmpty
                ? 'Complete the required social-media actions.'
                : description,
        url: url,
        reward:
            task.rewardFan <= 0
                ? AppConfig.dailySocialReward
                : task.rewardFan,
        completed:
            task.claimed,
      );
    }).toList();
  }

  Future<SocialTaskStartResult>
      startTask({
    required String taskId,
  }) async {
    try {
      _requireUser();

      final cleanId =
          taskId.trim();

      if (cleanId.isEmpty) {
        throw Exception(
          'Invalid social task.',
        );
      }

      final result =
          await _supabase.rpc(
        'start_social_task',
        params: <String, dynamic>{
          'p_task_id': cleanId,
        },
      );

      return SocialTaskStartResult
          .fromMap(
        _mapResult(result),
      );
    } catch (error) {
      throw _formatError(
        error,
        action: 'start social task',
      );
    }
  }

  Future<bool> openTask({
    required SocialTask task,
  }) async {
    final url =
        task.taskUrl.trim();

    if (url.isEmpty) {
      return false;
    }

    try {
      final uri =
          Uri.tryParse(url);

      if (uri == null) {
        return false;
      }

      return await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint(
        'SocialTaskService.openTask: $error',
      );

      return false;
    }
  }

  Future<SocialTaskStartResult>
      openAndStartTask({
    required SocialTask task,
  }) async {
    final started =
        await startTask(
      taskId: task.id,
    );

    if (!started.success) {
      return started;
    }

    final opened =
        await openTask(
      task: task,
    );

    if (!opened) {
      return SocialTaskStartResult(
        success: false,
        taskId: started.taskId,
        platform: started.platform,
        taskUrl: started.taskUrl,
        rewardFan: started.rewardFan,
        followVerified:
            started.followVerified,
        commentVerified:
            started.commentVerified,
        shareVerified:
            started.shareVerified,
        canClaim:
            started.canClaim,
        claimed:
            started.claimed,
        message:
            'Unable to open the social-media task.',
      );
    }

    return started;
  }

  Future<SocialTask?> getTask({
    required String taskId,
  }) async {
    final cleanId =
        taskId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    final tasks =
        await getDailyTasks();

    for (final task in tasks) {
      if (task.id == cleanId) {
        return task;
      }
    }

    return null;
  }

  Future<SocialTask?> findTask(
    String taskId,
  ) async {
    return getTask(
      taskId: taskId,
    );
  }

  bool canClaim({
    required SocialTask task,
  }) {
    return task.canClaim &&
        task.fullyVerified &&
        !task.claimed;
  }

  Future<SocialTaskClaimResult>
      claimReward({
    required String taskId,
  }) async {
    try {
      _requireUser();

      final cleanId =
          taskId.trim();

      if (cleanId.isEmpty) {
        throw Exception(
          'Invalid social task.',
        );
      }

      final result =
          await _supabase.rpc(
        'claim_daily_social_reward',
        params: <String, dynamic>{
          'p_task_id': cleanId,
        },
      );

      return SocialTaskClaimResult
          .fromMap(
        _mapResult(result),
      );
    } catch (error) {
      throw _formatError(
        error,
        action:
            'claim social task reward',
      );
    }
  }

  Future<SocialTaskClaimResult>
      verifyAndClaim({
    required String taskId,
  }) async {
    try {
      _requireUser();

      final task =
          await getTask(
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

      if (!task.canClaim) {
        throw Exception(
          'This task is not ready to claim.',
        );
      }

      if (!task.fullyVerified) {
        throw Exception(
          'Your Follow, Comment and Share actions have not been fully verified yet.',
        );
      }

      return claimReward(
        taskId: taskId,
      );
    } catch (error) {
      throw _formatError(
        error,
        action:
            'verify and claim social task',
      );
    }
  }

  Future<bool> openDailyTask(
    DailySocialTask task,
  ) async {
    final uri =
        Uri.tryParse(
      task.url,
    );

    if (uri == null) {
      return false;
    }

    try {
      return await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint(
        'SocialTaskService.openDailyTask: $error',
      );

      return false;
    }
  }

  String platformName(
    String platform,
  ) {
    switch (
        _normalizePlatform(platform)) {
      case 'facebook':
        return 'Facebook';

      case 'youtube':
        return 'YouTube';

      case 'tiktok':
        return 'TikTok';

      case 'x':
      case 'twitter':
        return 'X';

      case 'telegram':
        return 'Telegram';

      case 'instagram':
        return 'Instagram';

      default:
        return platform;
    }
  }

  String actionDescription(
    SocialTask task,
  ) {
    final actions =
        <String>[];

    if (task.requiresFollow) {
      actions.add(
        _normalizePlatform(
                  task.platform,
                ) ==
                'youtube'
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

  String rewardText(
    SocialTask task,
  ) {
    return '${task.rewardFan.toStringAsFixed(0)} ${AppConfig.miningCoinName}';
  }

  String verificationText(
    SocialTask task,
  ) {
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

  Map<String, dynamic> _mapResult(
    dynamic result,
  ) {
    if (result is Map) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    if (result is List &&
        result.isNotEmpty) {
      final first =
          result.first;

      if (first is Map) {
        return Map<String, dynamic>.from(
          first,
        );
      }
    }

    return <String, dynamic>{
      'success': false,
      'message':
          'Invalid response from the service.',
    };
  }

  String _normalizePlatform(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  String _descriptionForPlatform(
    String platform,
  ) {
    switch (
        _normalizePlatform(platform)) {
      case 'facebook':
        return 'Follow POWER FAN NETWORK on Facebook, then complete the required actions.';

      case 'youtube':
        return 'Subscribe to POWER FAN NETWORK on YouTube, then complete the required actions.';

      case 'tiktok':
        return 'Follow POWER FAN NETWORK on TikTok, then complete the required actions.';

      case 'x':
      case 'twitter':
        return 'Follow POWER FAN NETWORK on X, then complete the required actions.';

      case 'telegram':
        return 'Join the official POWER FAN NETWORK Telegram, then complete the required actions.';

      case 'instagram':
        return 'Follow POWER FAN NETWORK on Instagram, then complete the required actions.';

      default:
        return '';
    }
  }

  static const Map<String, String>
      _officialLinks = {
    'facebook':
        'https://www.facebook.com/share/18ipQKYcCV/',
    'youtube':
        'https://youtube.com/@powerfannetwork?si=yHAa0uXznTHB4SfN',
    'tiktok':
        'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZP-98wsX6qxjV0',
    'x':
        'https://x.com/Powerfannetwork',
    'telegram':
        'https://t.me/PowerFannetwork',
    'instagram':
        'https://www.instagram.com/powerfannetwok/',
  };
}
