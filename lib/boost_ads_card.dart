import 'package:flutter/material.dart';

class BoostAdsCard extends StatelessWidget {
  final bool isMining;
  final VoidCallback? onRewarded;
  final Future<void> Function()? onWatchAd;

  const BoostAdsCard({
    super.key,
    required this.isMining,
    this.onRewarded,
    this.onWatchAd,
  });

  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: primaryPurple,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Boost Mining',
                  style: TextStyle(
                    color: deepPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rewarded Ads',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'SOON',
              style: TextStyle(
                color: primaryPurple,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
