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

  DailySocialTask({
    required this.id,
    required this.title,
    required this.description,
    required this.claimed,
    this.rewardFan = 10,
    required this.url,
    required this.platform,
  });
}

class SocialTaskService {
  SocialTaskService._();
  static final SocialTaskService instance = SocialTaskService._();
  final SupabaseClient _client = SupabaseService.client;

  // 1. WANNAN ZAI DAWO DA TASKS 6 DIN KA
  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    return SupabaseService.safeCall(() async {
      final userId = _client.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Idan babu tasks na yau, mu kirkira su
      await _createTasksIfNotExist(today);

      final res = await _client.from('daily_social_tasks').select().eq('date', today);
      final userTasks = await _client.from('user_social_tasks').select().eq('user_id', userId).eq('date', today);

      return (res as List).map((task) {
        final claimed = (userTasks as List).any((ut) => ut['task_id'] == task['id'] && ut['claimed'] == true);
        return DailySocialTask(
          id: task['id'],
          title: task['title'],
          description: task['description'],
          claimed: claimed,
          url: task['url']?? '',
          platform: task['platform']?? 'link',
        );
      }).toList();
    });
  }

  // 2. WANNAN ZAI KIRKIRO TASKS 6 DIN KA KOWANE RANA
  Future<void> _createTasksIfNotExist(String today) async {
    final existing = await _client.from('daily_social_tasks').select().eq('date', today);
    if((existing as List).isNotEmpty) return;

    final tasks = [
      {
        'title': 'Follow Facebook',
        'description': 'Bi shafinmu na Facebook',
        'reward_fan': 10,
        'url': 'https://www.facebook.com/share/18ipQKYcCV/',
        'platform': 'facebook',
        'date': today
      },
      {
        'title': 'Subscribe YouTube',
        'description': 'Yi subscribing channel namu',
        'reward_fan': 10,
        'url': 'https://youtube.com/@powerfannetwork?si=yHAa0uXznTHB4SfN',
        'platform': 'youtube',
        'date': today
      },
      {
        'title': 'Follow TikTok',
        'description': 'Bi mu a TikTok',
        'reward_fan': 10,
        'url': 'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZP-98wsX6qxjV0',
        'platform': 'tiktok',
        'date': today
      },
      {
        'title': 'Follow X Twitter',
        'description': 'Bi mu a X',
        'reward_fan': 10,
        'url': 'https://x.com/Powerfannetwork',
        'platform': 'twitter',
        'date': today
      },
      {
        'title': 'Join Telegram',
        'description': 'Shiga group namu',
        'reward_fan': 10,
        'url': 'https://t.me/PowerFannetwork',
        'platform': 'telegram',
        'date': today
      },
      {
        'title': 'Follow Instagram',
        'description': 'Bi mu a Instagram',
        'reward_fan': 10,
        'url': 'https://www.instagram.com/powerfannetwok/',
        'platform': 'instagram',
        'date': today
      },
    ];
    await _client.from('daily_social_tasks').insert(tasks);
  }

  // 3. WANNAN YANA HANA NINKAWA SAU 2
  Future<Map<String, dynamic>> verifyAndClaim({required String taskId}) async {
    final userId = _client.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];

    return SupabaseService.safeCall(() async {
      final existing = await _client.from('user_social_tasks')
        .select()
        .eq('user_id', userId)
        .eq('task_id', taskId)
        .eq('date', today)
        .maybeSingle();

      if (existing!= null && existing['claimed'] == true) {
        throw Exception('An riga an karbi wannan reward na yau');
      }

      final result = await _client.rpc('claim_social_task', params: {
        'p_user_id': userId,
        'p_task_id': taskId,
        'p_reward': 10
      });

      return result;
    });
  }
}
