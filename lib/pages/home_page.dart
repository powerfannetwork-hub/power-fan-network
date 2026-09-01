import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals/app_constants.dart';
import '../globals/app_state.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _processing = false;

  Future<void> _startMining() async {
    if (_processing) return;

    setState(() => _processing = true);

    final state = context.read<AppState>();

    final success = await state.startMining();

    if (!mounted) return;

    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Mining started successfully.'
              : state.error ?? 'Could not start mining.',
        ),
      ),
    );
  }

  Future<void> _claimMining() async {
    if (_processing) return;

    setState(() => _processing = true);

    final state = context.read<AppState>();

    final success = await state.claimMining();

    if (!mounted) return;

    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Mining reward claimed successfully.'
              : state.error ?? 'Could not claim mining reward.',
        ),
      ),
    );
  }

  Future<void> _watchAd() async {
    if (_processing) return;

    final state = context.read<AppState>();

    if (!state.canWatchAd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have reached the maximum of 7 rewarded ads today.',
          ),
        ),
      );
      return;
    }

    setState(() => _processing = true);

    final success = await state.watchRewardedAd();

    if (!mounted) return;

    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Ad boost applied successfully.'
              : state.error ?? 'Could not apply ad reward.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, AuthService>(
      builder: (context, state, auth, _) {
        final name = auth.name.trim().isEmpty
            ? 'Miner'
            : auth.name.trim();

        return RefreshIndicator(
          onRefresh: state.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Color(
                              AppConstants.deepPurpleColorValue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: state.loading
                        ? null
                        : state.refresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==================================================
              // FAN BALANCE
              // ==================================================

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(
                        AppConstants.deepPurpleColorValue,
                      ),
                      Color(
                        AppConstants.primaryColorValue,
                      ),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 8),
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'FAN Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${state.fanBalance.toStringAsFixed(4)} FAN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceItem(
                            title: 'AFAM Balance',
                            value:
                                '${state.afamBalance.toStringAsFixed(4)} AFAM',
                          ),
                        ),
                        Expanded(
                          child: _BalanceItem(
                            title: 'Mining Rate',
                            value:
                                '${state.miningRate.toStringAsFixed(2)} FAN/H',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // MINING SESSION
              // ==================================================

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                AppConstants.primaryColorValue,
                              ).withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Color(
                                AppConstants.primaryColorValue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mining Session',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '24-hour mining cycle',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(
                            active: state.miningActive,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      if (state.miningActive) ...[
                        Center(
                          child: Text(
                            state.remainingText,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Color(
                                AppConstants.primaryColorValue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Time remaining',
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                state.remaining == Duration.zero &&
                                        !_processing
                                    ? _claimMining
                                    : null,
                            child: Text(
                              state.remaining ==
                                      Duration.zero
                                  ? 'CLAIM MINING REWARD'
                                  : 'MINING IN PROGRESS',
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Start your 24-hour FAN mining session.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                _processing
                                    ? null
                                    : _startMining,
                            icon: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_arrow_rounded,
                                  ),
                            label: const Text(
                              'START MINING',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // AD BOOST
              // ==================================================

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.ondemand_video_rounded,
                            color: Color(
                              AppConstants.primaryColorValue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Mining Ad Boost',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${state.dailyAdsWatched}/${AppConstants.maxDailyAds}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '+${state.adBoost.toStringAsFixed(1)} FAN/H ad boost',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed:
                              state.miningActive &&
                                      state.canWatchAd &&
                                      !_processing
                                  ? _watchAd
                                  : null,
                          icon: const Icon(
                            Icons.play_circle_outline,
                          ),
                          label: Text(
                            state.canWatchAd
                                ? 'WATCH REWARDED AD'
                                : 'DAILY AD LIMIT REACHED',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Each completed ad adds +0.1 FAN/H, up to 7 ads per day.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // REFERRAL BOOST
              // ==================================================

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(
                            AppConstants.greenColorValue,
                          ).withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Color(
                            AppConstants.greenColorValue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Referrals',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.activeReferrals} active referral${state.activeReferrals == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${state.referralBoost.toStringAsFixed(2)} FAN/H',
                        style: const TextStyle(
                          color: Color(
                            AppConstants.greenColorValue,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // DAILY SOCIAL TASK
              // ==================================================

              Card(
                elevation: 0,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(
                        AppConstants.primaryColorValue,
                      ).withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Color(
                        AppConstants.primaryColorValue,
                      ),
                    ),
                  ),
                  title: const Text(
                    'Daily Social Task',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Complete today’s social task to earn 10 FAN.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                ),
              ),

              if (state.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(
                      alpha: 0.07,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String title;
  final String value;

  const _BalanceItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(
                AppConstants.greenColorValue,
              ).withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: active
              ? const Color(
                  AppConstants.greenColorValue,
                )
              : Colors.black54,
        ),
      ),
    );
  }
}
