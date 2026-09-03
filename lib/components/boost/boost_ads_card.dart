import 'package:flutter/material.dart';
import '../../services/mining_service.dart';

class BoostAdsCard extends StatefulWidget {
  final VoidCallback onBoostUpdated;
  final double miningRate;
  final bool isMining;

  const BoostAdsCard({
    super.key,
    required this.onBoostUpdated,
    required this.miningRate,
    required this.isMining,
  });

  @override
  State<BoostAdsCard> createState() => _BoostAdsCardState();
}

class _BoostAdsCardState extends State<BoostAdsCard> {
  final MiningService _miningService = MiningService.instance;
  int _adsWatched = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    final active = await _miningService.getActiveMining();
    final startedAt = _parseDateTime(active['started_at']); // YANZU ZAI GANE SHI
    if (startedAt != null) {
      final ads = await _miningService.getAdsWatchedForSession(startedAt: startedAt);
      if (mounted) setState(() { _adsWatched = ads; });
    }
  }

  Future<void> _watchAd() async {
    if (_adsWatched >= 7) return;
    setState(() { _loading = true; });
    try {
      await _miningService.watchAd();
      setState(() { _adsWatched++; });
      widget.onBoostUpdated();
      _showMessage('Boost nasara! Rate ya tashi zuwa ${(widget.miningRate + 0.10).toStringAsFixed(2)} FAN/H');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final bool isFull = _adsWatched >= 7;
    final double bonusRate = _adsWatched * 0.10;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Boost Mining Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isFull ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                child: Text('$_adsWatched / 7', style: TextStyle(color: isFull ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text('Kowane ad +0.10 FAN/H. Bonus yanzu: +${bonusRate.toStringAsFixed(2)} FAN/H'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !widget.isMining || isFull || _loading ? null : _watchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B159B),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _loading 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(isFull ? 'An Kammala 7/7' : 'Watch Ad +0.10 FAN/H'),
            ),
          )
        ],
      ),
    );
  }
  
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  // WANNAN SHINE ABIN DA YA BACE
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
