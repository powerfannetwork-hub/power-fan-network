import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/mining_service.dart';
import '../../services/social_task_service.dart';
import '../../components/boost_ads_card.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final MiningService _miningService = MiningService.instance;
  final SocialTaskService _socialTaskService = SocialTaskService.instance;
  double _fanBalance = 0.0; double _miningRate = 0.20; bool _isMining = false;
  List<DailySocialTask> _socialTasks = []; bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState((){_loading = true;});
    try {
      final profile = await _miningService.getProfile();
      final mining = await _miningService.getActiveMining();
      final tasks = await _socialTaskService.getDailyTasksForCard();
      final rate = await _miningService.getUserMiningRate();
      if(mounted) setState(() {
        _fanBalance = (profile['fan_balance']?? 0).toDouble();
        _isMining = mining['is_active']?? false; _miningRate = rate; _socialTasks = tasks; _loading = false;
      });
    } catch (e) { if(mounted) setState((){_loading = false;}); }
  }

  Future<void> _openLinkAndClaim(DailySocialTask task) async {
    final uri = Uri.parse(task.url);
    if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    try { await _socialTaskService.verifyAndClaim(taskId: task.id); _loadData(); } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if(_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('Balance: ${_fanBalance.toStringAsFixed(2)} FAN')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        BoostAdsCard(onBoostUpdated: _loadData, miningRate: _miningRate, isMining: _isMining),
        const SizedBox(height: 20), const Text('Daily Social Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._socialTasks.map((task) => ListTile(
          title: Text(task.title), subtitle: Text(task.description),
          trailing: task.claimed ? const Icon(Icons.check, color: Colors.green) : ElevatedButton(child: const Text('Claim'), onPressed: () => _openLinkAndClaim(task)),
        )),
      ]),
    );
  }
}
