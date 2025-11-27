/**
 * SAARTHI Flutter App - Device Status Card Widget
 */

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class DeviceStatusCard extends StatelessWidget {
  final bool? isConnected;
  final String? lastEvent;
  final DateTime? lastEventTime;

  const DeviceStatusCard({
    super.key,
    this.isConnected,
    this.lastEvent,
    this.lastEventTime,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connected = isConnected ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connected ? Icons.check_circle : Icons.error,
                  color: connected ? AppTheme.secondaryColor : AppTheme.dangerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.deviceStatus,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              connected ? l10n.connected : l10n.disconnected,
              style: TextStyle(
                color: connected ? AppTheme.secondaryColor : AppTheme.dangerColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (lastEvent != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                l10n.lastEvent,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                lastEvent!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (lastEventTime != null)
                Text(
                  _formatTime(lastEventTime!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

