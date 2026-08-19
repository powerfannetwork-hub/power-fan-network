import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const PowerFanNetworkApp());
}

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Fan Network',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA726),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentPage = 0;

  double balance = 100.0;
  double miningRate = 0.10;

  bool isMining = false;
  bool checkedInToday = false;

  Duration miningTimeLeft = const Duration(hours: 24);
  Timer? miningTimer;

  final List<String> referrals = [];

  @override
  void dispose() {
    miningTimer?.cancel();
    super.dispose();
  }

  void startMining() {
    if (isMining) return;

    setState(() {
      isMining = true;
      miningTimeLeft = const Duration(hours: 24);
    });

    miningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (miningTimeLeft.inSeconds <= 0) {
        timer.cancel();

        setState(() {
          isMining = false;
          balance += 2.4;
        });

        showMessage('Mining complete! +2.40 FAN');
        return;
      }

      setState(() {
        miningTimeLeft -= const Duration(seconds: 1);
        balance += miningRate / 3600;
      });
    });

    showMessage('Mining started for 24 hours');
  }

  void stopMining() {
    miningTimer?.cancel();

    setState(() {
      isMining = false;
    });

    showMessage('Mining stopped');
  }

  void dailyCheckIn() {
    if (checkedInToday) {
      showMessage('You already checked in today');
      return;
    }

    setState(() {
      checkedInToday = true;
      balance += 0.50;
    });

    showMessage('Daily check-in claimed! +0.50 FAN');
  }

  void watchAd() {
    setState(() {
      miningRate += 0.10;
    });

    showMessage('Mining boost activated! +0.10 FAN/H');
  }

  void claimReferral() {
    setState(() {
      balance += 50.0;
      referrals.add('New referral #${referrals.length + 1}');
    });

    showMessage('Referral bonus claimed! +50 FAN');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String formatTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      buildMining(),
      buildReferral(),
      buildRanking(),
      buildSettings(),
    ];

    return Scaffold(
      body: SafeArea(
        child: pages[currentPage],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPage,
        onDestinationSelected: (index) {
          setState(() {
            currentPage = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Mining',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Referral',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POWER FAN',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'NETWORK',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 4,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orange,
                child: const Icon(
                  Icons.bolt,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9800),
                  Color(0xFFFF5722),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text(
                  'YOUR FAN BALANCE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${balance.toStringAsFixed(2)} FAN',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMining
                      ? 'Mining is active'
                      : 'Mining is not active',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: statCard(
                  Icons.bolt,
                  'Mining Rate',
                  '${miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: statCard(
                  Icons.people,
                  'Referrals',
                  '${referrals.length}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          actionCard(
            Icons.calendar_today,
            'Daily Check-in',
            checkedInToday
                ? 'Already claimed'
                : 'Claim +0.50 FAN',
            checkedInToday ? null : dailyCheckIn,
          ),

          actionCard(
            Icons.play_circle_outline,
            'Watch Ad',
            'Increase mining rate',
            watchAd,
          ),

          actionCard(
            Icons.people_outline,
            'Invite Friends',
            '+50 FAN per referral',
            claimReferral,
          ),
        ],
      ),
    );
  }

  Widget buildMining() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 15),

          const Text(
            'Mining Center',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Mine FAN points every 24 hours',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 35),

          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.orange,
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt,
                    size: 60,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatTime(miningTimeLeft),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isMining ? 'MINING' : 'READY',
                    style: TextStyle(
                      color:
                          isMining ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 35),

          Text(
            'Balance: ${balance.toStringAsFixed(4)} FAN',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Mining rate: ${miningRate.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isMining ? stopMining : startMining,
              icon: Icon(
                isMining ? Icons.stop : Icons.play_arrow,
              ),
              label: Text(
                isMining ? 'STOP MINING' : 'START MINING',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReferral() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),

          const Text(
            'Referral Program',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Invite friends and earn FAN rewards.',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 25),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF151B23),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.card_giftcard,
                  size: 55,
                  color: Colors.orange,
                ),
                const SizedBox(height: 15),
                const Text(
                  '50 FAN',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Referral reward',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PFN-2026-POWER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.copy),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: claimReferral,
              child: const Text('ADD REFERRAL'),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Your Referrals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          if (referrals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No referrals yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...referrals.map(
              (name) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(name),
                trailing: const Text(
                  '+50 FAN',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildRanking() {
    final miners = [
      ['PowerMiner01', '125,430 FAN'],
      ['FanMaster', '98,210 FAN'],
      ['CryptoFan', '76,850 FAN'],
      ['PFN_User', '54,320 FAN'],
      ['NewMiner', '32,100 FAN'],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),

          const Text(
            'Top Miners',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Top 100 Power Fan Network miners',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 25),

          ...List.generate(miners.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      index == 0 ? Colors.orange : Colors.grey,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  miners[index][0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  miners[index][1],
                  style: const TextStyle(
                    color: Colors.orange,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),

          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          settingTile(
            Icons.person,
            'Profile',
            'Manage your account',
          ),

          settingTile(
            Icons.notifications,
            'Notifications',
            'Mining and reward alerts',
          ),

          settingTile(
            Icons.security,
            'Security',
            'Password and account security',
          ),

          settingTile(
            Icons.help,
            'Help Center',
            'Get support',
          ),

          settingTile(
            Icons.info,
            'About',
            'Power Fan Network v1.0.0',
          ),

          const SizedBox(height: 30),

          const Center(
            child: Text(
              'POWER FAN NETWORK',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B23),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.15),
          child: Icon(
            icon,
            color: Colors.orange,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget settingTile(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
