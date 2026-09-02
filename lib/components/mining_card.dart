import 'dart:async';

import 'package:flutter/material.dart';

class MiningCard extends StatefulWidget {
  const MiningCard({
    super.key,
    this.miningRate = 0.2,
    this.fanBalance = 0.0,
    this.isMining = false,
    this.startedAt,
    this.endsAt,
    this.adsWatched = 0,
    this.maxAds = 7,
    this.onStartMining,
    this.onClaimMining,
    this.onWatchAd,
  });

  final double miningRate;
  final double fanBalance;
  final bool isMining;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final int adsWatched;
  final int maxAds;

  final VoidCallback? onStartMining;
  final VoidCallback? onClaimMining;
  final VoidCallback? onWatchAd;

  @override
  State<MiningCard> createState() => _MiningCardState();
}

class _MiningCardState extends State<MiningCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  @override
  void didUpdateWidget(covariant MiningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    if (widget.endsAt == null) {
      if (_remaining != Duration.zero && mounted) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
      return;
    }

    final now = DateTime.now();
    final difference = widget.endsAt!.difference(now);
    final next = difference.isNegative
        ? Duration.zero
        : difference;

    if (!mounted) {
      _remaining = next;
      return;
    }

    if (_remaining != next) {
      setState(() {
        _remaining = next;
      });
    }
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${_twoDigits(hours)}:'
        '${_twoDigits(minutes)}:'
        '${_twoDigits(seconds)}';
  }

  double get _progress {
    if (widget.startedAt == null ||
        widget.endsAt == null) {
      return widget.isMining ? 1.0 : 0.0;
    }

    final total =
        widget.endsAt!.difference(widget.startedAt!).inSeconds;

    if (total <= 0) return 0.0;

    final remaining = _remaining.inSeconds;

    final completed = total - remaining;

    final value = completed / total;

    return value.clamp(0.0, 1.0);
  }

  bool get _sessionFinished {
    return widget.isMining &&
        widget.endsAt != null &&
        _remaining == Duration.zero;
  }

  Color get _purple => const Color(0xFF3B159B);
  Color get _deepPurple => const Color(0xFF241064);
  Color get _green => const Color(0xFF159B61);

  @override
  Widget build(BuildContext context) {
    final canWatchAd =
        widget.isMining &&
        !_sessionFinished &&
        widget.adsWatched < widget.maxAds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _deepPurple,
            _purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAN Mining',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isMining
                          ? 'Mining is active'
                          : 'Ready to start mining',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isMining
                      ? _green.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isMining ? 'MINING' : 'READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            'FAN Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${widget.fanBalance.toStringAsFixed(4)} FAN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  title: 'Mining Rate',
                  value:
                      '${widget.miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoBox(
                  title: 'Session',
                  value: widget.isMining
                      ? _formatDuration(_remaining)
                      : '24 HOURS',
                ),
              ),
            ],
          ),

          if (widget.isMining) ...[
            const SizedBox(height: 18),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 7,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.14),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 9),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '24-hour mining session',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.68,
                    ),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_sessionFinished)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _purple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: widget.onClaimMining,
                  child: const Text(
                    'CLAIM MINING REWARD',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _purple,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                      ),
                      onPressed:
                          canWatchAd ? widget.onWatchAd : null,
                      child: Text(
                        widget.adsWatched >= widget.maxAds
                            ? 'AD BOOST MAXED'
                            : 'WATCH AD +0.10 FAN/H',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Ads watched this session: '
                    '${widget.adsWatched} / ${widget.maxAds}',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.76,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ] else ...[
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _purple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                onPressed: widget.onStartMining,
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 23,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'START MINING',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'New mining session: 24 hours • Ads reset to 0 / 7',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.68,
                ),
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
