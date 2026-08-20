import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color primaryPurple = Color(0xFF35129B);

  // Real notifications will be loaded from the backend.
  // No fake notification is inserted here.
  final List<NotificationItem> _notifications = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryPurple,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const _EmptyNotifications()
          : RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24,
                ),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];

                  return _NotificationCard(
                    notification: notification,
                    onTap: () => _openNotification(
                      notification,
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _refreshNotifications() async {
    // Backend notification loading will be connected here.
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    if (!mounted) return;

    setState(() {});
  }

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _openNotification(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
    });

    // Navigation/action for each backend notification
    // will be connected here.
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });
}

enum NotificationType {
  mining,
  referral,
  reward,
  security,
  system,
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  static const Color primaryPurple = Color(0xFF35129B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: primaryPurple.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: primaryPurple,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your important Power Fan Network '
              'notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  static const Color primaryPurple = Color(0xFF35129B);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.white
            : const Color(0xFFF0EBFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryPurple.withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _notificationIcon(notification.type),
            color: primaryPurple,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: primaryPurple,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            notification.message,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.mining:
        return Icons.bolt_rounded;

      case NotificationType.referral:
        return Icons.people_alt_rounded;

      case NotificationType.reward:
        return Icons.card_giftcard_rounded;

      case NotificationType.security:
        return Icons.security_rounded;

      case NotificationType.system:
        return Icons.info_outline_rounded;
    }
  }
}
