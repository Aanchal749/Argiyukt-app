import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BuyerNotificationScreen extends StatefulWidget {
  const BuyerNotificationScreen({super.key});

  @override
  State<BuyerNotificationScreen> createState() =>
      _BuyerNotificationScreenState();
}

class _BuyerNotificationScreenState extends State<BuyerNotificationScreen> {
  final _supabase = Supabase.instance.client;

  // ✅ Buyer Theme Color
  final Color _themeColor = const Color(0xFF1565C0);

  // --- 🕒 Helper: Format Time ---
  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (now.difference(date).inDays == 0) {
        return DateFormat('h:mm a').format(date);
      } else if (now.difference(date).inDays < 7) {
        return DateFormat('E, h:mm a').format(date);
      }
      return DateFormat('dd MMM').format(date);
    } catch (e) {
      return "";
    }
  }

  // --- 📩 Action: Mark Single as Read ---
  Future<void> _markAsRead(String id) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', id);
  }

  // --- 📨 Action: Mark All as Read ---
  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // --- 🗑️ Action: Delete Notification ---
  Future<void> _deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Notifications",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _themeColor, // ✅ Buyer Blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text("Mark all read",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _themeColor));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("No notifications yet",
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final bool isRead = notif['is_read'] ?? false;
              final String id = notif['id'].toString();

              return Dismissible(
                key: Key(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(id),
                child: Card(
                  elevation: 0,
                  // Unread = Blue Tint, Read = White
                  color: isRead ? Colors.white : Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: isRead
                              ? Colors.grey.shade200
                              : Colors.blue.shade100)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor:
                          isRead ? Colors.grey[200] : Colors.blue[100],
                      child: Icon(
                        isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: isRead ? Colors.grey : _themeColor,
                        size: 22,
                      ),
                    ),
                    title: Text(notif['title'] ?? 'Notification',
                        style: GoogleFonts.poppins(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif['body'] ?? '',
                            style: GoogleFonts.poppins(
                                color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(_formatTime(notif['created_at']),
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    onTap: () => _markAsRead(id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
