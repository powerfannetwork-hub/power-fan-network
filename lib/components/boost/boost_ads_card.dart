import 'package:flutter/material.dart';

import '../../globals/app_constants.dart';
import '../../services/boost_ads_service.dart';

class BoostAdsCard extends StatefulWidget {
  const BoostAdsCard({
    super.key,
    required this.isMining,
    required this.sessionFinished,
    required this.startedAt,
    required this.endsAt,
    this.onMessage,
    this.onBoostUpdated,
  });

  final bool isMining;
  final bool sessionFinished;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final void Function(String message)? onMessage;
  final Future<void> Function()? onBoostUpdated;

  @override
  State<BoostAdsCard> createState() => _BoostAdsCardState();
}

class _BoostAdsCardState extends State<BoostAdsCard> {
  final BoostAdsService _boostAdsService = BoostAdsService.instance;

  int _adsWatched = 0;
  bool _loading = true;
  bool _busy = false;

  int get _maxAds => AppConfig.maxAdsPerSession;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant BoostAdsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sessionChanged =
        oldWidget.startedAt != widget.startedAt ||
        oldWidget.endsAt != widget.endsAt ||
        oldWidget.isMining != widget.isMining ||
        oldWidget.sessionFinished != widget.sessionFinished;

    if (sessionChanged) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    if (!widget.isMining || widget.startedAt == null) {
      if (!mounted) return;

      setState(() {
        _adsWatched = 0;
        _loading = false;
      });

      return;
    }

    try {
      final count = await _boostAdsService.getAdsWatchedForSession(
        startedAt: widget.startedAt!,
        endsAt: widget.endsAt,
      );

      if (!mounted) return;

      setState(() {
        _adsWatched = _clampAds(count);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _adsWatched = 0;
        _loading = false;
      });

      _showMessage(_cleanError(error));
    }
  }

  int _clampAds(dynamic value) {
    final count = _toInt(value);

    if (count < 0) {
      return 0;
    }

    if (count > _maxAds) {
      return _maxAds;
    }

    return count;
  }

  bool get _canWatchAd {
    return _boostAdsService.canWatchAd(
      adsWatched: _adsWatched,
      isMining: widget.isMining,
      sessionFinished: widget.sessionFinished,
    );
  }

  double get _boost {
    return _boostAdsService.calculateBoost(_adsWatched);
  }

  double get _progress {
    if (_maxAds <= 0) {
      return 0.0;
    }

    return (_adsWatched / _maxAds).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _watchAd() async {
    if (_busy) return;

    if (!widget.isMining) {
      _showMessage(
        'Start mining before watching boost ads.',
      );
      return;
    }

    if (widget.sessionFinished) {
      _showMessage(
        'Mining session is complete. Claim your reward and start a new session before watching more ads.',
      );
      return;
    }

    if (widget.startedAt == null) {
      _showMessage(
        'Mining session information is not available yet.',
      );
      return;
    }

    if (_adsWatched >= _maxAds) {
      _showMessage(
        'You have reached the $_maxAds ads limit for this mining session.',
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      final result = await _boostAdsService.watchAdAndRecord(
        startedAt: widget.startedAt!,
        endsAt: widget.endsAt,
      );

      if (!mounted) return;

      final success = result['success'] == true;

      if (!success) {
        final message = result['message']?.toString();

        if (message != null && message.trim().isNotEmpty) {
          _showMessage(message);
        } else {
          _showMessage(
            'The rewarded ad was not completed. No mining boost was added.',
          );
        }

        return;
      }

      final count = _clampAds(result['ads_watched']);

      setState(() {
        _adsWatched = count;
      });

      if (widget.onBoostUpdated != null) {
        await widget.onBoostUpdated!();
      }

      if (!mounted) return;

      _showMessage(
        'Ad completed successfully. +${AppConfig.adBoostPerAd.toStringAsFixed(1)} FAN/H boost added.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }

    if (text.startsWith('PostgrestException: ')) {
      text = text.substring('PostgrestException: '.length);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }

  void _showMessage(String message) {
    if (widget.onMessage != null) {
      widget.onMessage!(message);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }

  Widget _buildCard() {
    final buttonDisabled =
        _loading || _busy || !_canWatchAd;

    final buttonText = _busy ? 'WATCHING' : 'WATCH AD';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _circleIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 49,
                child: ElevatedButton.icon(
                  onPressed:
                      buttonDisabled ? null : _watchAd,
                  icon: Icon(
                    _busy
                        ? Icons.hourglass_top_rounded
                        : Icons.video_collection_rounded,
                    size: 20,
                  ),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4A20B9),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF8D76CF),
                    disabledForegroundColor:
                        Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            'Ads watched this session: $_adsWatched / $_maxAds',
            style: const TextStyle(
              color: Color(0xFF35148F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _loading ? 0.0 : _progress,
              minHeight: 9,
              backgroundColor:
                  const Color(0xFFE9E4FA),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Color(0xFF5A2AD0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '+${_boost.toStringAsFixed(1)} FAN/H',
              style: const TextStyle(
                color: Color(0xFF35148F),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon() {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFFF0EBFF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.rocket_launch_rounded,
        color: Color(0xFFE64949),
        size: 31,
      ),
    );
  }
}
