import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/daily_spin_service.dart';

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
  final DailySpinService _spinService =
      DailySpinService.instance;

  bool _loading = true;
  bool _spinning = false;

  Map<String, dynamic> _status =
      <String, dynamic>{};

  Map<String, dynamic>? _result;

  String? _error;

  double _rotation = 0;

  late final AnimationController _controller;

  Animation<double>? _rotationAnimation;

  static const List<_SpinReward> _rewards = [
    _SpinReward(
      code: 'fan_1',
      label: '+1 FAN',
      color: Color(0xFF6A1B9A),
    ),
    _SpinReward(
      code: 'fan_2',
      label: '+2 FAN',
      color: Color(0xFF1565C0),
    ),
    _SpinReward(
      code: 'fan_3',
      label: '+3 FAN',
      color: Color(0xFFE65100),
    ),
    _SpinReward(
      code: 'boost_1h',
      label: '+0.10 FAN/H\n1 HOUR',
      color: Color(0xFF00897B),
    ),
    _SpinReward(
      code: 'boost_2h',
      label: '+0.10 FAN/H\n2 HOURS',
      color: Color(0xFF2E7D32),
    ),
    _SpinReward(
      code: 'streak',
      label: 'STREAK\nBOOST',
      color: Color(0xFFC62828),
    ),
    _SpinReward(
      code: 'task_bonus',
      label: 'TASK BONUS\n+2 FAN',
      color: Color(0xFFAD1457),
    ),
    _SpinReward(
      code: 'try_again',
      label: 'TRY\nAGAIN',
      color: Color(0xFF455A64),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 4200,
      ),
    );

    _controller.addListener(() {
      if (!mounted) {
        return;
      }

      if (_rotationAnimation != null) {
        setState(() {});
      }
    });

    _loadStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status =
          await _spinService.getStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _spin() async {
    if (_spinning) {
      return;
    }

    if (!_spinService.isSignedIn) {
      _showMessage(
        'Please sign in first.',
        isError: true,
      );
      return;
    }

    if (!_spinService.canSpin(_status)) {
      _showMessage(
        'You have already used your Daily Spin today.',
        isError: false,
      );
      return;
    }

    setState(() {
      _spinning = true;
      _error = null;
      _result = null;
    });

    try {
      /*
       * IMPORTANT:
       * The reward is selected by Supabase.
       * Flutter does NOT select the reward.
       */
      final result =
          await _spinService.spin();

      if (!mounted) {
        return;
      }

      final success =
          _spinService.isSuccess(result);

      if (!success) {
        setState(() {
          _spinning = false;
          _error =
              _spinService.message(result).isEmpty
                  ? 'Spin could not be completed.'
                  : _spinService.message(result);
        });

        return;
      }

      final rewardCode =
          _spinService.rewardCode(result);

      final rewardIndex =
          _rewardIndex(rewardCode);

      if (rewardIndex < 0) {
        setState(() {
          _spinning = false;
          _result = result;
          _status = result;
        });

        _showMessage(
          'Reward received, but its wheel position is unknown.',
          isError: true,
        );

        return;
      }

      await _animateToReward(
        rewardIndex,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _status = result;
        _spinning = false;
      });

      _showReward(result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _spinning = false;
        _error = _cleanError(e);
      });

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    }
  }

  Future<void> _animateToReward(
    int rewardIndex,
  ) async {
    const segmentAngle =
        (2 * math.pi) / 8;

    /*
     * Each segment starts with its CENTER
     * aligned to the top arrow.
     *
     * We add 5 full rotations so the wheel
     * visibly spins several times before
     * stopping on the server-selected reward.
     */
    final targetRotation =
        _rotation +
        (5 * 2 * math.pi) -
        (rewardIndex * segmentAngle);

    _rotationAnimation =
        Tween<double>(
      begin: _rotation,
      end: targetRotation,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.reset();

    await _controller.forward();

    if (!mounted) {
      return;
    }

    setState(() {
      _rotation = targetRotation;
      _rotationAnimation = null;
    });
  }

  int _rewardIndex(String code) {
    for (int i = 0;
        i < _rewards.length;
        i++) {
      if (_rewards[i].code == code) {
        return i;
      }
    }

    return -1;
  }

  double get _currentRotation {
    return _rotationAnimation?.value ??
        _rotation;
  }

  void _showReward(
    Map<String, dynamic> result,
  ) {
    final title =
        _spinService.rewardTitle(result);

    final amount =
        _spinService.fanAmount(result);

    final type =
        _spinService.rewardType(result);

    String message;

    if (amount > 0) {
      message =
          '+${_formatFan(amount)} FAN';
    } else if (type == 'mining_boost') {
      final duration =
          _spinService.boostDurationMinutes(
        result,
      );

      final rate =
          _spinService.boostRatePerHour(
        result,
      );

      message =
          '+${rate.toStringAsFixed(2)} FAN/H '
          'for $duration minutes';
    } else {
      message = title.isEmpty
          ? 'Reward received!'
          : title;
    }

    _showMessage(
      message,
      isError: false,
    );
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 3),
          backgroundColor: isError
              ? Colors.red.shade700
              : const Color(0xFF6A1B9A),
        ),
      );
  }

  String _cleanError(Object error) {
    final text = error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );

    return text.isEmpty
        ? 'Something went wrong.'
        : text;
  }

  String _formatFan(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value
        .toStringAsFixed(8)
        .replaceFirst(
          RegExp(r'0+$'),
          '',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F1FF),
      appBar: AppBar(
        title: const Text(
          'Daily Spin',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            const Color(0xFFF5F1FF),
        foregroundColor:
            const Color(0xFF35136B),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadStatus,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    30,
                  ),
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 20),

                    _buildWheel(),

                    const SizedBox(height: 20),

                    _buildSpinButton(),

                    const SizedBox(height: 20),

                    _buildRewardResult(),

                    const SizedBox(height: 18),

                    _buildStatusCard(),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorCard(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'DAILY SPIN',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF35136B),
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Spin once every day and win a reward.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildWheel() {
    return Center(
      child: SizedBox(
        width: 330,
        height: 365,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              child: _buildPointer(),
            ),

            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controller,
                builder:
                    (
                  context,
                  child,
                ) {
                  return Transform.rotate(
                    angle:
                        _currentRotation,
                    child: CustomPaint(
                      size:
                          const Size(
                        330,
                        330,
                      ),
                      painter:
                          _SpinWheelPainter(
                        rewards: _rewards,
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              top: 143,
              child: _buildWheelCenter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointer() {
    return Container(
      width: 0,
      height: 0,
      decoration: const BoxDecoration(),
      child: CustomPaint(
        size: const Size(
          46,
          54,
        ),
        painter: _PointerPainter(),
      ),
    );
  }

  Widget _buildWheelCenter() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: const Color(
            0xFF35136B,
          ),
          width: 5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.20),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.casino_rounded,
          size: 42,
          color: Color(0xFF6A1B9A),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    final canSpin =
        _spinService.canSpin(_status);

    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed:
            _spinning || !canSpin
                ? null
                : _spin,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF6A1B9A),
          disabledBackgroundColor:
              Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: 6,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),
        child: _spinning
            ? const SizedBox(
                width: 26,
                height: 26,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Text(
                canSpin
                    ? 'SPIN NOW'
                    : 'SPIN USED TODAY',
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildRewardResult() {
    if (_result == null) {
      return Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF6A1B9A),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap SPIN NOW and let the wheel choose your reward.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final title =
        _spinService.rewardTitle(
      _result!,
    );

    final amount =
        _spinService.fanAmount(
      _result!,
    );

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF6A1B9A),
            Color(0xFF9C27B0),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple
                .withValues(alpha: 0.20),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _spinning
                ? 'SPINNING...'
                : 'YOU WON',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.isEmpty
                ? 'Reward'
                : title,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          if (amount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '+${_formatFan(amount)} FAN',
              style:
                  const TextStyle(
                color:
                    Color(0xFFFFD54F),
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final alreadySpun =
        _spinService.alreadySpun(
      _status,
    );

    final balance =
        _spinService.fanBalance(
      _status,
    );

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.deepPurple.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .account_balance_wallet_rounded,
                color:
                    Color(0xFF6A1B9A),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'FAN Balance',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_formatFan(balance)} FAN',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xFF6A1B9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                alreadySpun
                    ? Icons.check_circle
                    : Icons.access_time,
                color: alreadySpun
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadySpun
                      ? 'Daily Spin completed today'
                      : 'Daily Spin is available',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color:
                Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color:
                    Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinReward {
  final String code;
  final String label;
  final Color color;

  const _SpinReward({
    required this.code,
    required this.label,
    required this.color,
  });
}

class _SpinWheelPainter
    extends CustomPainter {
  final List<_SpinReward> rewards;

  const _SpinWheelPainter({
    required this.rewards,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(
          size.width,
          size.height,
        ) /
        2;

    final segmentAngle =
        (2 * math.pi) /
        rewards.length;

    final rect =
        Rect.fromCircle(
      center: center,
      radius: radius - 5,
    );

    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0;
        i < rewards.length;
        i++) {
      /*
       * Segment 0 is centered at the top.
       * The wheel itself is then rotated during
       * the real spin.
       */
      final startAngle =
          -math.pi / 2 -
              (segmentAngle / 2) +
              (i * segmentAngle);

      paint.color =
          rewards[i].color;

      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      final textAngle =
          startAngle +
              (segmentAngle / 2);

      final textRadius =
          radius * 0.66;

      final textCenter =
          Offset(
        center.dx +
            math.cos(textAngle) *
                textRadius,
        center.dy +
            math.sin(textAngle) *
                textRadius,
      );

      _drawRewardText(
        canvas,
        rewards[i].label,
        textCenter,
        textAngle,
      );
    }

    final outerPaint = Paint()
      ..color = Colors.white
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 7;

    canvas.drawCircle(
      center,
      radius - 4,
      outerPaint,
    );
  }

  void _drawRewardText(
    Canvas canvas,
    String text,
    Offset center,
    double angle,
  ) {
    final textPainter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight:
              FontWeight.w900,
          height: 1.15,
        ),
      ),
      textDirection:
          TextDirection.ltr,
      textAlign:
          TextAlign.center,
    );

    textPainter.layout(
      maxWidth: 82,
    );

    canvas.save();

    canvas.translate(
      center.dx,
      center.dy,
    );

    /*
     * Rotate text so each reward follows
     * the wheel segment.
     */
    canvas.rotate(
      angle + math.pi / 2,
    );

    textPainter.paint(
      canvas,
      Offset(
        -textPainter.width / 2,
        -textPainter.height / 2,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _SpinWheelPainter oldDelegate,
  ) {
    return oldDelegate.rewards !=
        rewards;
  }
}

class _PointerPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = Path();

    path.moveTo(
      size.width / 2,
      size.height,
    );

    path.lineTo(
      3,
      4,
    );

    path.quadraticBezierTo(
      size.width / 2,
      -4,
      size.width - 3,
      4,
    );

    path.close();

    final paint = Paint()
      ..color =
          const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      path,
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(
      path,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PointerPainter
        oldDelegate,
  ) {
    return false;
  }
}
