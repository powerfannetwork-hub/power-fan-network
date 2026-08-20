
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PowerFanApp());
}

class PowerFanApp extends StatelessWidget {
  const PowerFanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Power Fan Network',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F18B8),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final Color primaryPurple = const Color(0xFF3F18B8);
  final Color darkPurple = const Color(0xFF24105F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            HomeContent(),
            ReferralPage(),
            WalletPage(),
            SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'HOME',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'REFERRAL',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'WALLET',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginRequired();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            double balance = 0;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data();

              if (data != null) {
                final value = data['balance'];

                if (value is num) {
                  balance = value.toDouble();
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 30,
              ),
              children: [
                _Header(),
                const SizedBox(height: 15),
                _BalanceCard(balance: balance),
                const SizedBox(height: 18),
                const MiningCard(),
                const SizedBox(height: 18),
                const AdsCard(),
                const SizedBox(height: 18),
                const DailyTaskCard(),
                const SizedBox(height: 18),
                const KycCard(),
              ],
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AFAM',
                style: TextStyle(
                  color: Color(0xFF28127E),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'POWER FAN NETWORK',
                style: TextStyle(
                  color: Color(0xFF28127E),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Mine FAN. Earn More',
                style: TextStyle(
                  color: Color(0xFF28127E),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bolt,
            color: Colors.cyanAccent,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          children: [
            const Icon(
              Icons.notifications_none,
              size: 35,
              color: Color(0xFF28127E),
            ),
            Positioned(
              right: 1,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;

  const _BalanceCard({
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF31108F),
            Color(0xFF5120C7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.22),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BALANCE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(width: 15),
              Text(
                balance.toStringAsFixed(4),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'FAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Points balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class MiningCard extends StatefulWidget {
  const MiningCard({super.key});

  @override
  State<MiningCard> createState() => _MiningCardState();
}

class _MiningCardState extends State<MiningCard> {
  bool mining = false;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              _CircleIcon(
                icon: Icons.hardware,
                background: const Color(0xFFECE8FF),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS: READY',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Start earning FAN points',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF514B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Expanded(
                child: _InfoColumn(
                  icon: Icons.speed,
                  title: 'EARNING RATE',
                  value: '0.4 FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
              ),
              const Expanded(
                child: _InfoColumn(
                  icon: Icons.access_time,
                  title: 'SESSION TIME',
                  value: '00:00:00 / 24:00:00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  mining = !mining;
                });
              },
              icon: Icon(
                mining ? Icons.stop : Icons.hardware,
              ),
              label: Text(
                mining ? 'STOP SESSION' : 'START EARNING',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4314BD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdsCard extends StatelessWidget {
  const AdsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              _CircleIcon(
                icon: Icons.rocket_launch,
                background: const Color(0xFFF0EDFF),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOST',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Watch eligible ads to boost your rate',
                      style: TextStyle(
                        color: Color(0xFF514B6B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4314BD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('WATCH AD'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ads watched today: 0 / 7',
              style: TextStyle(
                color: Color(0xFF28127E),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class DailyTaskCard extends StatefulWidget {
  const DailyTaskCard({super.key});

  @override
  State<DailyTaskCard> createState() => _DailyTaskCardState();
}

class _DailyTaskCardState extends State<DailyTaskCard> {
  final List<String> tasks = [
    'Follow us on X',
    'Join our Telegram',
    'Follow us on Instagram',
    'Subscribe on YouTube',
  ];

  final Set<String> completed = {};

  bool get allCompleted {
    return completed.length == tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIcon(
                icon: Icons.task_alt,
                background: const Color(0xFFE5F8EC),
                iconColor: Colors.green.shade800,
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY TASK',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete tasks to unlock your reward',
                      style: TextStyle(
                        color: Color(0xFF514B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...tasks.map(
            (task) {
              final done = completed.contains(task);

              return CheckboxListTile(
                value: done,
                contentPadding: EdgeInsets.zero,
                title: Text(task),
                secondary: Icon(
                  done
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.grey,
                ),
                onChanged: (value) {
                  if (value == true) {
                    setState(() {
                      completed.add(task);
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: allCompleted
                  ? () {
                      _requestReward(context);
                    }
                  : null,
              icon: Icon(
                allCompleted
                    ? Icons.card_giftcard
                    : Icons.lock,
              ),
              label: Text(
                allCompleted
                    ? 'CLAIM 50 FAN'
                    : 'COMPLETE ALL TASKS FIRST',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4314BD),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              allCompleted
                  ? 'All tasks completed. Reward unlocked.'
                  : 'Reward is locked until all tasks are completed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF625B7B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestReward(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tasks completed. Server verification is required before reward is granted.',
        ),
      ),
    );
  }
}

class KycCard extends StatelessWidget {
  const KycCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: [
          _CircleIcon(
            icon: Icons.verified_user,
            background: const Color(0xFFECE8FF),
            iconColor: const Color(0xFF4314BD),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC VERIFICATION',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style: TextStyle(
                    color: Color(0xFF514B6B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            child: const Text('COMPLETE KYC'),
          ),
        ],
      ),
    );
  }
}

class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'REFERRAL',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'WALLET',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'SETTINGS',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class LoginRequired extends StatelessWidget {
  const LoginRequired({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signInAnonymously();
        },
        child: const Text('START'),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;

  const _CircleIcon({
    required this.icon,
    required this.background,
    this.iconColor = const Color(0xFF4314BD),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 30,
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoColumn({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF4314BD),
          size: 30,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF4314BD),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
