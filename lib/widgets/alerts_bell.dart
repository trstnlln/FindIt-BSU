import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../screens/community/alerts_screen.dart';

class AlertsBell extends StatelessWidget {
  const AlertsBell({super.key});
  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final count = activity.unreadCount;
    return IconButton(
      tooltip: count == 0 ? 'Your alerts' : 'Your alerts: $count unread',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AlertsScreen()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
