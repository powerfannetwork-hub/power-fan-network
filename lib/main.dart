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
      debugShowCheckedModeBanner: false,
      title: 'Power Fan Network',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0B14),
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

      if (miningTimeLeft.inSeconds <= 1) {
        timer.cancel();

        setState(() {
          isMining = false;
          miningTimeLeft = Duration.zero;
          balance += 2.4;
        });

        showMessage('Mining complete! +2.40 FAN');
        return;
      }

      setState(() {
        miningTimeLeft -= const Duration(seconds: 1);
      });
    });

    showMessage('Mining started!');
  }

  void checkIn() {
    if (checkedInToday) {
      showMessage('You already checked in today.');
      return;
    }

    setState(() {
      checkedInToday = true;
      balance += 1.0;
    });

    showMessage('Daily check-in complete! +1.00 FAN');
  }

  void addReferral() {
    setState(() {
      referrals.add('Fan User ${referrals.length + 1}');
      balance += 5.0;
    });

    showMessage('Referral added! +5.00 FAN');
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String formatTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      buildMining(),
      buildReferralPage(),
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
            label: 'Referrals',
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
          const SizedBox(height: 15),

          const Text(
            'Power Fan Network',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Welcome to your FAN dashboard',
            style: TextStyle(
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 25),

          balanceCard(),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: statCard(
                  Icons.bolt,
                  'Mining Rate',
                  '${miningRate.toStringAsFixed(2)} FAN/h',
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

          actionCard(
            Icons.bolt,
            'Start Mining',
            isMining
                ? 'Mining • ${formatTime(miningTimeLeft)}'
                : 'Mine FAN every 24 hours',
            startMining,
          ),

          actionCard(
            Icons.calendar_today,
            'Daily Check-in',
            checkedInToday ? 'Completed today' : 'Get your daily reward',
            checkIn,
          ),

          actionCard(
            Icons.person_add,
            'Invite Friends',
            'Earn 5 FAN for each referral',
            addReferral,
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
            'Mining',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Mine FAN points every 24 hours',
            style: TextStyle(color: Colors.grey.shade400),
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
                  color: Colors.orange.withValues(alpha: 0.2),
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
                    size: 65,
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    isMining ? formatTime(miningTimeLeft) : '24:00:00',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isMining ? 'MINING' : 'READY',
                    style: TextStyle(
                      color: isMining
                          ? Colors.orange
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 35),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isMining ? null : startMining,
              icon: const Icon(Icons.bolt),
              label: Text(
                isMining ? 'MINING...' : 'START MINING',
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Mining rate: ${miningRate.toStringAsFixed(2)} FAN per hour',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget buildReferralPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),

          const Text(
            'Referrals',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Invite friends and earn FAN',
            style: TextStyle(color: Colors.grey.shade400),
          ),

          const SizedBox(height: 25),

          balanceCard(),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: addReferral,
              icon: const Icon(Icons.person_add),
              label: const Text('ADD REFERRAL'),
            ),
          ),

          const SizedBox(height: 25),

          if (referrals.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No referrals yet.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            ...referrals.map(
              (name) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Colors.orange.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(name),
                  subtitle: const Text('+5.00 FAN'),
                  trailing: const Icon(Icons.check_circle),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(18),
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
          'Manage your profile',
        ),

        settingTile(
          Icons.notifications,
          'Notifications',
          'Mining and reward notifications',
        ),

        settingTile(
          Icons.security,
          'Security',
          'Protect your account',
        ),

        settingTile(
          Icons.info,
          'About',
          'Power Fan Network',
        ),
      ],
    );
  }

  Widget balanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAN Balance',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              balance.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'FAN',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
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
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
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
}
