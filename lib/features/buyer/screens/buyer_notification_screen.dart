import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ IMPORT BUYER ORDERS SCREEN
import 'package:agriyukt_app/features/buyer/screens/buyer_orders_screen.dart';

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
  String _formatTime(String? isoString) {
    if (isoString == null) return "Just now";
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";

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

  // --- 🚀 SMART NAVIGATION LOGIC ---
  void _handleTap(Map<String, dynamic> notif) {
    final String id = notif['id'].toString();
    final String type = notif['type'] ?? 'system';

    // 1. Extract Data
    final meta = notif['metadata'] ?? {};
    final String? orderId = meta['order_id']?.toString(); // To scroll
    final String rawStatus = meta['status']?.toString() ?? '';
    final String status = rawStatus.toLowerCase(); // To choose tab

    // 2. Mark as Read (Optimistic UI update)
    if (notif['is_read'] == false) {
      setState(() {
        notif['is_read'] = true;
      });
      _markAsRead(id);
    }

    // 3. Navigate based on Type & Status
    if (type == 'order' || type == 'order_update') {
      // Determine Tab Index for BuyerOrdersScreen (3 Tabs)
      // 0 = Pending
      // 1 = Active
      // 2 = Completed
      int targetTabIndex = 0; // Default Pending

      if ([
        'accepted',
        'confirmed',
        'packed',
        'shipped',
        'in transit',
        'out for delivery',
        'processing'
      ].contains(status)) {
        targetTabIndex = 1; // Active Tab
      } else if (['delivered', 'completed', 'rejected', 'cancelled']
          .contains(status)) {
        targetTabIndex = 2; // Completed Tab
      }
      // 'pending' or 'ordered' stays at 0

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyerOrdersScreen(
            initialIndex: targetTabIndex, // ✅ Smart Tab Selection
            highlightOrderId: orderId, // ✅ Triggers auto-scroll
          ),
        ),
      );
    }
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
            .order('created_at', ascending: false)
            .limit(50),
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
              return _buildNotificationCard(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final bool isRead = notif['is_read'] ?? false;
    final String id = notif['id'].toString();
    final String title = notif['title'] ?? 'Notification';
    final String body = notif['body'] ?? '';

    // ✅ EXTRACT METADATA (Image)
    final Map<String, dynamic> meta = notif['metadata'] ?? {};
    final String? imageUrl = meta['image'];

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
        margin: const EdgeInsets.only(bottom: 10),
        color: isRead ? Colors.white : Colors.blue.shade50,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: isRead ? Colors.grey.shade200 : Colors.blue.shade100)),
        child: InkWell(
          onTap: () => _handleTap(notif), // ✅ Use New Smart Handler
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ LEADING IMAGE (Crop) OR ICON
                _buildLeadingImage(imageUrl, isRead),

                const SizedBox(width: 12),

                // ✅ CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87)),
                          ),
                          Text(_formatTime(notif['created_at']),
                              style: GoogleFonts.poppins(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: 13,
                              height: 1.3)),
                    ],
                  ),
                ),

                // Unread Dot
                if (!isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 5),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Helper to show Image (Full URL) or Fallback Icon
  Widget _buildLeadingImage(String? imageUrl, bool isRead) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      String fullUrl = imageUrl;

      // If it is NOT a full link (starts with http), assume it's a storage path
      if (!imageUrl.startsWith('http')) {
        try {
          // Generate the public URL from Supabase Storage
          fullUrl = _supabase.storage
              .from('crop_images') // Ensure this matches your bucket name
              .getPublicUrl(imageUrl);
        } catch (_) {
          // Keep original if generation fails
        }
      }

      return Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade200,
          image: DecorationImage(
            image: NetworkImage(fullUrl),
            fit: BoxFit.cover,
            onError: (e, s) {}, // Handle errors silently
          ),
        ),
      );
    }

    // Fallback Icon
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: isRead ? Colors.grey[100] : Colors.blue[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.shopping_bag_outlined,
        color: isRead ? Colors.grey : _themeColor,
        size: 24,
      ),
    );
  }
}
