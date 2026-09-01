// lib/pages/notifications_page.dart

import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          30,
        ),
        children: [
          _notificationCard(
            icon: Icons.notifications_active_rounded,
            title: 'Mining notifications',
            message:
                'You will be notified when your mining session ends and your next mining session can be started.',
          ),
          const SizedBox(height: 12),
          _notificationCard(
            icon: Icons.people_alt_rounded,
            title: 'Referral notifications',
            message:
                'You can receive notifications when referral activity requires your attention.',
          ),
          const SizedBox(height: 12),
          _notificationCard(
            icon: Icons.verified_user_rounded,
            title: 'KYC notifications',
            message:
                'Important verification and account-status notifications will appear here.',
          ),
          const SizedBox(height: 12),
          _notificationCard(
            icon: Icons.campaign_rounded,
            title: 'POWER FAN NETWORK',
            message:
                'Important announcements and updates from POWER FAN NETWORK will appear here.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3B159B),
                  size: 24,
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Notifications require permission on your device. Server notifications may also depend on your device notification settings.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B)
                  .withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3B159B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
