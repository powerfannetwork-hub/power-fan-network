// lib/pages/home_page.dart

import 'dart:async';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '00:00:00';
    }

    final hours =
        duration.inHours.toString().padLeft(2, '0');

    final minutes =
        (duration.inMinutes % 60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        (duration.inSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  Future<void> _startMining(
    AuthService auth,
  ) async {
    final result = await auth.startMining();

    if (!mounted) return;

    if (result == null) {
      _showMessage(
        auth.error ?? 'Could not start mining.',
      );
      return;
    }

    _showMessage('Mining started successfully.');
  }

  Future<void> _claimMining(
    AuthService auth,
  ) async {
    final result = await auth.claimMining();

    if (!mounted) return;

    if (result == null) {
      _showMessage(
        auth.error ?? 'Could not claim mining reward.',
      );
      return;
    }

    _showMessage(
      'Mining reward claimed successfully.',
    );
  }

  Future<void> _watchAd(
    AuthService auth,
  ) async {
    final result =
        await auth.watchRewardedAd();

    if (!mounted) return;

    if (result == null) {
      _showMessage(
        auth.error ?? 'Could not apply ad reward.',
      );
      return;
    }

    _showMessage(
      'Ad boost applied successfully.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, AppState>(
      builder: (
        context,
        auth,
        appState,
        child,
      ) {
        final user = auth.user;

        final fanBalance =
            auth.fanBalance;

        final afamBalance =
            auth.afamBalance;

        final miningRate =
            auth.miningRate;

        final activeReferrals =
            auth.activeReferrals;

        final adsWatched =
            auth.dailyAdsWatched;

        final adBoost =
            auth.adBoost;

        final miningActive =
            auth.miningActive;

        DateTime? endsAt;

        final rawEnds =
            user?['miningEndsAt'];

        if (rawEnds != null) {
          endsAt =
              DateTime.tryParse(
            rawEnds.toString(),
          );
        }

        final remaining =
            endsAt == null
                ? Duration.zero
                : endsAt.difference(
                    DateTime.now(),
                  );

        final miningFinished =
            miningActive &&
            endsAt != null &&
            !remaining.isNegative &&
            remaining == Duration.zero;

        return Scaffold(
          backgroundColor:
              const Color(
            AppConstants.lightBackgroundColor,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await auth.refreshUser();
              },
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  30,
                ),
                children: [
                  _buildHeader(
                    auth,
                  ),

                  const SizedBox(height: 18),

                  _buildBalanceCard(
                    fanBalance,
                    afamBalance,
                  ),

                  const SizedBox(height: 16),

                  _buildMiningCard(
                    auth,
                    miningRate,
                    miningActive,
                    endsAt,
                    remaining,
                    miningFinished,
                  ),

                  const SizedBox(height: 16),

                  _buildAdCard(
                    auth,
                    adsWatched,
                    adBoost,
                  ),

                  const SizedBox(height: 16),

                  _buildReferralCard(
                    activeReferrals,
                    miningRate,
                  ),

                  const SizedBox(height: 16),

                  _buildSocialCard(),

                  const SizedBox(height: 16),

                  _buildKycCard(
                    auth,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    AuthService auth,
  ) {
    final name =
        auth.name.trim().isEmpty
            ? 'Miner'
            : auth.name.trim();

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration:
              const BoxDecoration(
            color:
                Color(
              AppConstants.purpleColor,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'POWER FAN NETWORK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(
                    AppConstants.purpleColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome, $name',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(
                    AppConstants.deepPurpleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            auth.refreshUser();
          },
          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    double fanBalance,
    double afamBalance,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(
              AppConstants.purpleColor,
            ),
            Color(
              AppConstants.deepPurpleColor,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black
                .withValues(alpha: 0.12),
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
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'FAN Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fanBalance.toStringAsFixed(4)} FAN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AFAM Balance',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${afamBalance.toStringAsFixed(4)} AFAM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard(
    AuthService auth,
    double miningRate,
    bool miningActive,
    DateTime? endsAt,
    Duration remaining,
    bool miningFinished,
  ) {
    final canClaim =
        miningActive &&
        endsAt != null &&
        !remaining.isNegative &&
        remaining == Duration.zero;

    final actualFinished =
        miningActive &&
        endsAt != null &&
        DateTime.now()
            .isAfter(endsAt);

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.bolt_rounded,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mining',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '24-hour FAN mining session',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(
                miningActive
                    ? 'ACTIVE'
                    : 'STOPPED',
                miningActive,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _statItem(
                  'Mining rate',
                  '${miningRate.toStringAsFixed(2)} FAN/H',
                  Icons.speed_rounded,
                ),
              ),
              Expanded(
                child: _statItem(
                  'Ad boost',
                  '+${auth.adBoost.toStringAsFixed(1)} FAN/H',
                  Icons.play_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (miningActive &&
              endsAt != null) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(
                  AppConstants.lightBackgroundColor,
                ),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Mining session',
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actualFinished ||
                            miningFinished
                        ? 'READY TO CLAIM'
                        : _formatDuration(
                            remaining,
                          ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                      color: Color(
                        AppConstants.purpleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: auth.loading
                  ? null
                  : (!miningActive
                      ? () =>
                          _startMining(auth)
                      : (actualFinished
                          ? () =>
                              _claimMining(
                                auth,
                              )
                          : null)),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  AppConstants.purpleColor,
                ),
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: auth.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      !miningActive
                          ? 'START MINING'
                          : actualFinished
                              ? 'CLAIM MINING REWARD'
                              : 'MINING IN PROGRESS',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(
    AuthService auth,
    int adsWatched,
    double adBoost,
  ) {
    final maxReached =
        adsWatched >=
            AppConstants.maxDailyAds;

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.ondemand_video_rounded,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ad Boost',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Optional rewarded ads',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$adsWatched/${AppConstants.maxDailyAds}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(
                    AppConstants.purpleColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            '+${adBoost.toStringAsFixed(1)} FAN/H',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            '+0.1 FAN/H for each completed rewarded ad.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 14),

          LinearProgressIndicator(
            value:
                adsWatched /
                    AppConstants.maxDailyAds,
            minHeight: 8,
            borderRadius:
                BorderRadius.circular(10),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  auth.loading ||
                          maxReached
                      ? null
                      : () =>
                          _watchAd(auth),
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: Text(
                maxReached
                    ? 'DAILY LIMIT REACHED'
                    : 'WATCH REWARDED AD',
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  AppConstants.purpleColor,
                ),
                side:
                    const BorderSide(
                  color: Color(
                    AppConstants.purpleColor,
                  ),
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(
    int activeReferrals,
    double miningRate,
  ) {
    final referralBoost =
        activeReferrals *
            AppConstants.referralMiningBoost;

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.people_alt_outlined,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Referral Network',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  'Active referrals',
                  '$activeReferrals',
                  Icons.people_outline,
                ),
              ),
              Expanded(
                child: _statItem(
                  'Referral boost',
                  '+${referralBoost.toStringAsFixed(2)} FAN/H',
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.public_rounded,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Daily Social Task',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                '+10 FAN',
                style: TextStyle(
                  color: Color(
                    AppConstants.greenColor,
                  ),
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Visit the official social page, follow, like and comment to complete the daily task.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                _showMessage(
                  'Social task is available from the official task section.',
                );
              },
              child: const Text(
                'VIEW DAILY TASK',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycCard(
    AuthService auth,
  ) {
    final days =
        auth.user?[
              'consecutiveCheckIns',
            ] ??
            0;

    final kyc1Eligible =
        auth.user?[
              'kyc1Eligible',
            ] ==
            true;

    final kyc1Verified =
        auth.user?[
              'kyc1Verified',
            ] ==
            true;

    final kyc2Eligible =
        auth.user?[
              'kyc2Eligible',
            ] ==
            true;

    final kyc2Verified =
        auth.user?[
              'kyc2Verified',
            ] ==
            true;

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.verified_user_outlined,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'KYC Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _kycRow(
            'KYC 1',
            kyc1Verified
                ? 'Verified'
                : kyc1Eligible
                    ? 'Eligible'
                    : '$days/${AppConstants.kyc1RequiredDays} days',
            kyc1Verified,
            kyc1Eligible,
          ),

          const Divider(height: 22),

          _kycRow(
            'KYC 2',
            kyc2Verified
                ? 'Verified'
                : kyc2Eligible
                    ? 'Eligible'
                    : '${auth.activeReferrals}/${AppConstants.kyc2RequiredReferrals} referrals • $days/${AppConstants.kyc2RequiredDays} days',
            kyc2Verified,
            kyc2Eligible,
          ),

          const Divider(height: 22),

          _kycRow(
            'KYC 3',
            'Community stage',
            false,
            false,
          ),
        ],
      ),
    );
  }

  Widget _kycRow(
    String title,
    String subtitle,
    bool verified,
    bool eligible,
  ) {
    return Row(
      children: [
        Icon(
          verified
              ? Icons.check_circle
              : eligible
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline,
          color: verified
              ? const Color(
                  AppConstants.greenColor,
                )
              : eligible
                  ? const Color(
                      AppConstants.purpleColor,
                    )
                  : Colors.black38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 5),
            color: Colors.black
                .withValues(alpha: 0.05),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(
    IconData icon,
  ) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(
          AppConstants.purpleColor,
        ).withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: const Color(
          AppConstants.purpleColor,
        ),
      ),
    );
  }

  Widget _statusBadge(
    String text,
    bool active,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(
                AppConstants.greenColor,
              ).withValues(alpha: 0.10)
            : Colors.black
                .withValues(alpha: 0.06),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active
              ? const Color(
                  AppConstants.greenColor,
                )
              : Colors.black54,
        ),
      ),
    );
  }

  Widget _statItem(
    String title,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(
            AppConstants.purpleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
