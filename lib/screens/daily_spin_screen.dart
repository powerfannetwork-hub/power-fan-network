import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/power_fan_growth_system.dart';

class DailySpinScreen extends StatefulWidget {
  const DailySpinScreen({
    super.key,
  });

  @override
  State<DailySpinScreen> createState() =>
      _DailySpinScreenState();
}

class _DailySpinScreenState
    extends State<DailySpinScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();

  late final AnimationController _spinController;

  bool _isSpinning = false;
  bool _hasSpunToday = false;

  DailySpinReward? _selectedReward;
  double _displayRotation = 0;

  Timer? _resultTimer;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3600,
      ),
    );
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || _hasSpunToday) {
      return;
    }

    setState(() {
      _isSpinning = true;
      _selectedReward = null;
    });

    final rewards =
        PowerFanGrowthSystem.dailySpinRewards;

    final reward = _pickWeightedReward(rewards);

    final rewardIndex = rewards.indexOf(reward);

    final segmentAngle =
        (2 * pi) / rewards.length;

    final targetAngle =
        (2 * pi * 5) +
        ((2 * pi) -
            (rewardIndex * segmentAngle) -
            (segmentAngle / 2));

    _displayRotation += targetAngle;

    _spinController
        .forward(from: 0)
        .whenComplete(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSpinning = false;
        _hasSpunToday = true;
        _selectedReward = reward;
      });
    });
  }

  DailySpinReward _pickWeightedReward(
    List<DailySpinReward> rewards,
  ) {
    final totalWeight =
        PowerFanGrowthSystem
            .calculateWeightedSpinTotal();

    var randomValue =
        _random.nextDouble() * totalWeight;

    for (final reward in rewards) {
      randomValue -= reward.weight;

      if (randomValue <= 0) {
        return reward;
      }
    }

    return rewards.last;
  }

  void _resetDemoSpin() {
    setState(() {
      _hasSpunToday = false;
      _selectedReward = null;
      _displayRotation = 0;
    });
  }

  String _rewardDescription(
    DailySpinReward reward,
  ) {
    switch (reward.type) {
      case DailySpinRewardType.fan:
        return '+${reward.fanAmount.toStringAsFixed(0)} FAN';

      case DailySpinRewardType.miningBoost:
        return '+${reward.boostRatePerHour.toStringAsFixed(2)} FAN/H '
            'for ${reward.boostDurationMinutes} minutes';

      case DailySpinRewardType.streakBoost:
        return 'Streak boost for '
            '${reward.boostDurationMinutes} minutes';

      case DailySpinRewardType.taskBonus:
        return '+${reward.fanAmount.toStringAsFixed(0)} FAN task bonus';

      case DailySpinRewardType.tryAgain:
        return 'Try again tomorrow';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards =
        PowerFanGrowthSystem.dailySpinRewards;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F3FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Daily Spin',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 8),

              _buildHeaderCard(),

              const SizedBox(height: 22),

              _buildWheel(rewards),

              const SizedBox(height: 18),

              _buildSpinButton(),

              const SizedBox(height: 20),

              if (_selectedReward != null)
                _buildResultCard(
                  _selectedReward!,
                ),

              const SizedBox(height: 20),

              _buildRewardsCard(rewards),

              const SizedBox(height: 20),

              _buildRulesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6A1B9A),
            Color(0xFF8E24AA),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.purple
                .withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.casino_rounded,
            size: 48,
            color: Color(0xFFFFD54F),
          ),
          SizedBox(height: 10),
          Text(
            'DAILY LUCKY SPIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Spin once every day and win FAN or boosts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel(
    List<DailySpinReward> rewards,
  ) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedRotation(
            turns: _displayRotation /
                (2 * pi),
            duration: const Duration(
              milliseconds: 3600,
            ),
            curve: Curves.easeOutCubic,
            child: CustomPaint(
              size: const Size(
                290,
                290,
              ),
              painter: _SpinWheelPainter(
                rewards: rewards,
              ),
            ),
          ),

          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFFFD54F),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFB300),
              size: 38,
            ),
          ),

          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(30, 34),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    final disabled =
        _isSpinning || _hasSpunToday;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed:
            disabled ? null : _spin,
        icon: Icon(
          _isSpinning
              ? Icons.autorenew
              : Icons.casino,
        ),
        label: Text(
          _isSpinning
              ? 'SPINNING...'
              : _hasSpunToday
                  ? 'SPIN USED TODAY'
                  : 'SPIN NOW',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Colors.grey.shade400,
          disabledForegroundColor:
              Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    DailySpinReward reward,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFC107),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFB300),
            size: 46,
          ),
          const SizedBox(height: 8),
          const Text(
            'YOU WON!',
            style: TextStyle(
              color: Color(0xFF6A1B9A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reward.title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _rewardDescription(reward),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsCard(
    List<DailySpinReward> rewards,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Spin Rewards',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...rewards.map(
            (reward) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF3E5F5,
                      ),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _rewardIcon(reward),
                      color:
                          const Color(0xFF6A1B9A),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reward.title,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${reward.weight}%',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: TextStyle(
              color: Color(0xFF6A1B9A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          _RuleRow(
            icon: Icons.looks_one_rounded,
            text: 'You get 1 free spin every day.',
          ),
          _RuleRow(
            icon: Icons.looks_two_rounded,
            text: 'Spin to receive a reward.',
          ),
          _RuleRow(
            icon: Icons.looks_3_rounded,
            text: 'Your next free spin is tomorrow.',
          ),
        ],
      ),
    );
  }

  IconData _rewardIcon(
    DailySpinReward reward,
  ) {
    switch (reward.type) {
      case DailySpinRewardType.fan:
        return Icons.monetization_on_rounded;

      case DailySpinRewardType.miningBoost:
        return Icons.bolt_rounded;

      case DailySpinRewardType.streakBoost:
        return Icons.local_fire_department_rounded;

      case DailySpinRewardType.taskBonus:
        return Icons.task_alt_rounded;

      case DailySpinRewardType.tryAgain:
        return Icons.refresh_rounded;
    }
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF6A1B9A),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinWheelPainter
    extends CustomPainter {
  _SpinWheelPainter({
    required this.rewards,
  });

  final List<DailySpinReward> rewards;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center =
        Offset(size.width / 2, size.height / 2);

    final radius =
        min(size.width, size.height) / 2;

    final totalWeight =
        rewards.fold<int>(
      0,
      (sum, reward) => sum + reward.weight,
    );

    double startAngle = -pi / 2;

    for (var i = 0; i < rewards.length; i++) {
      final reward = rewards[i];

      final sweepAngle =
          (reward.weight / totalWeight) *
              2 *
              pi;

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _segmentColor(i);

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white;

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      final textAngle =
          startAngle + sweepAngle / 2;

      final textRadius =
          radius * 0.67;

      final textPosition = Offset(
        center.dx +
            cos(textAngle) *
                textRadius,
        center.dy +
            sin(textAngle) *
                textRadius,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: reward.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(
        maxWidth: 72,
      );

      textPainter.paint(
        canvas,
        Offset(
          textPosition.dx -
              textPainter.width / 2,
          textPosition.dy -
              textPainter.height / 2,
        ),
      );

      startAngle += sweepAngle;
    }

    final outerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white;

    canvas.drawCircle(
      center,
      radius,
      outerBorder,
    );
  }

  Color _segmentColor(int index) {
    const colors = [
      Color(0xFF7B1FA2),
      Color(0xFF9C27B0),
      Color(0xFFBA68C8),
      Color(0xFF6A1B9A),
      Color(0xFF8E24AA),
      Color(0xFFAB47BC),
      Color(0xFFCE93D8),
      Color(0xFF4A148C),
    ];

    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(
    covariant _SpinWheelPainter oldDelegate,
  ) {
    return oldDelegate.rewards != rewards;
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    final paint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
