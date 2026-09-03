import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class DailySocialTask {
  final String id;
  final String title;
  final String description;
  final bool claimed;
  final int rewardFan;

  DailySocialTask({
    required this.id,
    required this.title,
    required this.description,
    required this.claimed,
    this.rewardFan = 10,
  });
}

class SocialTaskService {
  SocialTaskService._();
  static final SocialTaskService instance = SocialTaskService._();
  final SupabaseClient _client = SupabaseService.client;

  Future<List<DailySocialTask>> getDailyTasksForCard() async {
    return SupabaseService.safeCall(() async {
      final userId = _client.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final res = await _client.from('daily_social_tasks').select().eq('date', today);
      final userTasks = await _client.from('user_social_tasks').select().eq('user_id', userId).eq('date', today);

      return (res as List).map((task) {
        final claimed = (userTasks as List).any((ut) => ut['task_id'] == task['id'] && ut['claimed'] == true);
        return DailySocialTask(
          id: task['id'],
          title: task['title'],
          description: task['description'],
          claimed: claimed,
        );
      }).toList();
    });
  }

  // WANNAN SHINE MAFI MUHIMMI - YANA HANA NINKAWA
  Future<Map<String, dynamic>> verifyAndClaim({required String taskId}) async {
    final userId = _client.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];

    return SupabaseService.safeCall(() async {
      // 1. DUBA DA FARKO: Ko an riga an claim?
      final existing = await _client.from('user_social_tasks')
         .select()
         .eq('user_id', userId)
         .eq('task_id', taskId)
         .eq('date', today)
         .maybeSingle();

      if (existing!= null && existing['claimed'] == true) {
        throw Exception('An riga an karbi wannan reward na yau');
      }

      // 2. IDAN BA A CLAIM BA: Yi transaction guda 1
      final result = await _client.rpc('claim_social_task', params: {
        'p_user_id': userId,
        'p_task_id': taskId,
        'p_reward': 10
      });

      return result;
    });
  }
}
