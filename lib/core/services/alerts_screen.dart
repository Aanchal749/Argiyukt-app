import 'package:flutter/material.dart';
import 'package:agriyukt_app/core/services/notification_service.dart';
import 'package:intl/intl.dart'; // Add intl package for date formatting if needed

class AlertsScreen extends StatefulWidget {
  final Color
      themeColor; // Passed from parent (Farmer Green, Buyer Orange, etc.)
  const AlertsScreen({super.key, required this.themeColor});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final NotificationService _service = NotificationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    final data = await _service.getNotifications();
    if (mounted) {
      setState(() {
        _alerts = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    _fetchAlerts(); // Refresh UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: widget.themeColor),
            tooltip: "Mark all as read",
            onPressed: _alerts.isEmpty ? null : _markAllRead,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : _alerts.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: widget.themeColor,
                  onRefresh: _fetchAlerts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _alerts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _alerts[index];
                      return _alertTile(item);
                    },
                  ),
                ),
    );
  }

  Widget _alertTile(Map<String, dynamic> item) {
    final bool isRead = item['is_read'] ?? false;
    final String type = item['type'] ?? 'General'; // 'Order', 'Crop', 'System'

    // Icon Logic
    IconData icon;
    Color color;

    switch (type) {
      case 'Order':
        icon = Icons.shopping_bag;
        color = Colors.blue;
        break;
      case 'Crop':
        icon = Icons.grass;
        color = Colors.green;
        break;
      case 'Inspector':
        icon = Icons.verified_user;
        color = Colors.orange;
        break;
      case 'Alert':
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    // Timestamp formatting (Simple)
    final date = DateTime.parse(item['created_at']);
    final timeStr = "${date.day}/${date.month} ${date.hour}:${date.minute}";

    return Container(
      color: isRead
          ? Colors.white
          : widget.themeColor.withOpacity(0.05), // Highlight unread
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          item['title'] ?? "Notification",
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(item['body'] ?? "",
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ),
        trailing: Text(timeStr,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        onTap: () async {
          if (!isRead) {
            await _service.markAsRead(item['id']);
            _fetchAlerts(); // Refresh locally
          }
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No notifications yet",
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}
