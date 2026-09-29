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

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

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
      await _controller.forward(
        from: 0,
      );

      final result =
          await _spinService.spin();

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _status = result;
        _spinning = false;
      });

      final success =
          _spinService.isSuccess(result);

      if (!success) {
        _showMessage(
          _spinService.message(result).isEmpty
              ? 'Spin could not be completed.'
              : _spinService.message(result),
          isError: true,
        );

        return;
      }

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
          behavior: SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 3),
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
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadStatus,
                child: ListView(
                  padding:
                      const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 10),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildWheel(),
                    const SizedBox(height: 28),
                    _buildRewardResult(),
                    const SizedBox(height: 24),
                    _buildSpinButton(),
                    const SizedBox(height: 20),
                    _buildStatusCard(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorCard(),
                    ],
                    const SizedBox(height: 30),
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
        SizedBox(height: 8),
        Text(
          'Spin once every day and receive a real reward.',
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
      child: RotationTransition(
        turns: Tween<double>(
          begin: 0,
          end: 6,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFF7B2FF7),
                Color(0xFFFFC107),
                Color(0xFFFF5F6D),
                Color(0xFF00C6FF),
                Color(0xFF7B2FF7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple
                    .withValues(alpha: 0.25),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Center(
              child: Icon(
                Icons.casino_rounded,
                size: 90,
                color: Color(0xFF6A1B9A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardResult() {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: const Text(
          'Your reward will appear here after the spin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
      );
    }

    final title =
        _spinService.rewardTitle(_result!);

    final amount =
        _spinService.fanAmount(_result!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOU WON',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.isEmpty
                ? 'Reward'
                : title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (amount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '+${_formatFan(amount)} FAN',
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
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
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),
        child: _spinning
            ? const SizedBox(
                width: 25,
                height: 25,
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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
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
      padding: const EdgeInsets.all(18),
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
                Icons.account_balance_wallet,
                color: Color(0xFF6A1B9A),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
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
                  style: const TextStyle(
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
      padding: const EdgeInsets.all(16),
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
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
