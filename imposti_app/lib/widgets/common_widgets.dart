import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';

String formatIsoDate(String? iso, {bool withTime = false}) {
  if (iso == null || iso.isEmpty) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return withTime
        ? DateFormat('dd.MM.yyyy HH:mm').format(dt)
        : DateFormat('dd.MM.yyyy').format(dt);
  } catch (_) {
    return iso;
  }
}

Future<void> openReportUrl(
  BuildContext context,
  String path, {
  bool downloadPdf = false,
}) async {
  final urlStr = ApiService.buildReportUrl(path, downloadPdf: downloadPdf);
  final uri = Uri.parse(urlStr);
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ბმულის გახსნა ვერ მოხერხდა: $urlStr')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('შეცდომა ბმულის გახსნისას: $e')),
      );
    }
  }
}

class ImpostiLogo extends StatelessWidget {
  final double height;
  final bool showText;
  final Color textColor;

  const ImpostiLogo({
    super.key,
    this.height = 38,
    this.showText = true,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = ApiService.resolveMediaUrl('/static/images/logo.png');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            logoUrl,
            height: height,
            width: height,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              height: height,
              width: height,
              decoration: BoxDecoration(
                color: ImpostiColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.engineering, color: Colors.white),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Text(
            'IMPOSTI',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: height * 0.52,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final color = ImpostiColors.statusColor(status);
    final text = label != null && label!.isNotEmpty
        ? label!
        : ImpostiColors.statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: status == 'in_progress'
              ? const Color(0xFF856404)
              : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EquipmentStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const EquipmentStatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final color = ImpostiColors.equipmentStatusColor(status);
    final text = label != null && label!.isNotEmpty
        ? label!
        : ImpostiColors.equipmentStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: status == 'maintenance' ? Colors.black87 : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class NotificationsBellButton extends StatelessWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return IconButton(
      tooltip: 'შეტყობინებები',
      onPressed: () {
        appState.refreshNotifications();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (appState.unreadNotifications > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: ImpostiColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${appState.unreadNotifications}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshNotifications();
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_approved':
        return Icons.thumb_up_alt_outlined;
      case 'task_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'task_assigned':
        return ImpostiColors.primary;
      case 'task_completed':
        return ImpostiColors.success;
      case 'task_approved':
        return ImpostiColors.info;
      case 'task_rejected':
        return ImpostiColors.danger;
      default:
        return ImpostiColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = appState.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('შეტყობინებები'),
        actions: [
          if (appState.unreadNotifications > 0)
            TextButton.icon(
              onPressed: () => appState.markAllRead(),
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'ყველას წაკითხულად მონიშვნა',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => appState.refreshNotifications(),
        child: items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'შეტყობინებები არ არის',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final n = items[idx];
                  final color = _colorForType(n.type);
                  return Card(
                    color: n.isRead ? Colors.white : const Color(0xFFF0F7FF),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(_iconForType(n.type), color: color),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.w500 : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(n.message),
                          const SizedBox(height: 4),
                          Text(
                            n.createdAt,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!n.isRead)
                            IconButton(
                              tooltip: 'წაკითხულად მონიშვნა',
                              icon: const Icon(
                                Icons.check,
                                color: ImpostiColors.primary,
                              ),
                              onPressed: () => appState.markRead(n.id),
                            ),
                          IconButton(
                            tooltip: 'წაშლა',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: ImpostiColors.danger,
                            ),
                            onPressed: () => appState.deleteNotification(n.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

void showPhotoLightbox(BuildContext context, String imageUrl) {
  final resolved = ApiService.resolveMediaUrl(imageUrl);
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(
                resolved,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    ),
  );
}
