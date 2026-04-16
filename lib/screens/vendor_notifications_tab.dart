import 'package:flutter/material.dart';
import 'package:swm_vendor/theme/app_theme.dart';

class VendorNotificationsTab extends StatelessWidget {
  const VendorNotificationsTab({super.key});

  // Mock notification data
  static final List<_MockNotification> _notifications = [
    _MockNotification(
      icon: Icons.local_shipping_rounded,
      iconColor: Colors.blue[600]!,
      iconBg: Colors.blue[50]!,
      title: 'Driver Assigned',
      subtitle: 'Rajesh Kumar has been assigned to your pickup request.',
      time: '10 min ago',
      isUnread: true,
    ),
    _MockNotification(
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green[600]!,
      iconBg: Colors.green[50]!,
      title: 'Pickup Completed',
      subtitle: 'Your waste pickup of 15 kg (Organic) has been collected successfully.',
      time: '2 hours ago',
      isUnread: true,
    ),
    _MockNotification(
      icon: Icons.description_rounded,
      iconColor: Colors.orange[600]!,
      iconBg: Colors.orange[50]!,
      title: 'Declaration Confirmed',
      subtitle: 'Your new waste declaration of 8 kg (Plastic) has been registered.',
      time: '5 hours ago',
      isUnread: false,
    ),
    _MockNotification(
      icon: Icons.schedule_rounded,
      iconColor: Colors.purple[600]!,
      iconBg: Colors.purple[50]!,
      title: 'Pickup Scheduled',
      subtitle: 'Your waste pickup is scheduled for tomorrow between 9:00-11:00 AM.',
      time: 'Yesterday',
      isUnread: false,
    ),
    _MockNotification(
      icon: Icons.star_rounded,
      iconColor: Colors.amber[700]!,
      iconBg: Colors.amber[50]!,
      title: 'Great Compliance!',
      subtitle: 'You\'ve maintained 100% compliance for the past week. Keep it up!',
      time: '2 days ago',
      isUnread: false,
    ),
    _MockNotification(
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red[600]!,
      iconBg: Colors.red[50]!,
      title: 'Missed Pickup',
      subtitle: 'A pickup was missed on Oct 20. Please declare waste again.',
      time: '3 days ago',
      isUnread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n.isUnread).length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notifications',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    if (unreadCount > 0)
                      Text('$unreadCount unread',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.done_all_rounded,
                      size: 18, color: AppTheme.primary),
                  label: Text('Mark all read',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Notification List ─────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return _NotificationCard(notification: n);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MockNotification {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;

  const _MockNotification({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
  });
}

class _NotificationCard extends StatelessWidget {
  final _MockNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isUnread
            ? AppTheme.primary.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.isUnread
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notification.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notification.icon,
                color: notification.iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (notification.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.subtitle,
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.time,
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
