import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ CORRECT IMPORT: Points to the consolidated "Command Center" screen
import 'package:agriyukt_app/features/inspector/screens/inspector_order_detail_screen.dart';

class InspectorNotificationScreen extends StatefulWidget {
  const InspectorNotificationScreen({super.key});

  @override
  State<InspectorNotificationScreen> createState() =>
      _InspectorNotificationScreenState();
}

class _InspectorNotificationScreenState
    extends State<InspectorNotificationScreen> {
  final _supabase = Supabase.instance.client;

  // ✅ Theme: Deep Purple (Inspector Identity)
  final Color _primaryColor = const Color(0xFF512DA8);

  @override
  void initState() {
    super.initState();
    // Mark unread notifications as read after a slight delay
    Future.delayed(const Duration(seconds: 2), _markAllAsRead);
  }

  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // ✅ NAVIGATION LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _handleTap(Map<String, dynamic> notif) async {
    final String id = notif['id'].toString();
    final meta = notif['metadata'] ?? {};
    final String? orderId = meta['order_id']?.toString();

    // 1. Optimistic Read Update
    if (notif['is_read'] == false) {
      setState(() => notif['is_read'] = true);
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true}).eq('id', id);
      } catch (_) {}
    }

    // 2. Fetch & Navigate
    if (orderId != null) {
      // Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Fetch full order data needed for the screen
        final orderData = await _supabase.from('orders').select('''
              *,
              crops!inner(*),
              buyer:profiles!fk_orders_buyer(first_name, last_name, phone, district, state),
              farmer:profiles!fk_orders_farmer!inner(*)
            ''').eq('id', orderId).single();

        if (mounted) {
          Navigator.pop(context); // Close loading spinner

          // Navigate to the Order Screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InspectorOrderDetailScreen(order: orderData),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading spinner
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Could not open order: $e")));
        }
      }
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return "Now";
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return DateFormat('dd MMM').format(date);
    } catch (_) {
      return "Recent";
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text("Login Required")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Notifications",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
            return Center(
                child: CircularProgressIndicator(color: _primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No notifications yet",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              // ✅ FEATURE: Switch between Money Card and Standard Card
              if (notif['type'] == 'money') {
                return _buildMoneyCard(notif);
              }
              return _buildStandardCard(notif);
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 💰 MONEY CARD UI (For Payment Notifications)
  // ---------------------------------------------------------------------------
  Widget _buildMoneyCard(Map<String, dynamic> notif) {
    final meta = notif['metadata'] ?? {};
    final amount = meta['amount'] ?? 0;
    final bool isRead = notif['is_read'] ?? false;

    return InkWell(
      onTap: () => _handleTap(notif),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // ✅ VISUAL: Green Border for Money
          border: Border.all(color: Colors.green.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Payment Received",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // ✅ VISUAL: Big Price Text
                      Text("₹${NumberFormat('#,##0').format(amount)}",
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text("CREDITED",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif['body'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_formatTime(notif['created_at']),
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey[400])),
                ],
              ),
            ),
            if (!isRead)
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle))
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📝 STANDARD CARD UI (For Orders & Alerts)
  // ---------------------------------------------------------------------------
  Widget _buildStandardCard(Map<String, dynamic> notif) {
    final bool isRead = notif['is_read'] ?? false;
    final meta = notif['metadata'] ?? {};
    final String type = notif['type'] ?? 'system';

    final String title = notif['title'] ?? 'Alert';
    final String body = notif['body'] ?? '...';
    final String status = (meta['status'] ?? '').toString();

    IconData iconData = Icons.notifications_active;
    Color iconColor = _primaryColor;
    Color bgIconColor = Colors.grey.shade100;

    if (type == 'order_update' || type == 'order') {
      iconData = Icons.local_shipping;
      iconColor = Colors.orange;
      bgIconColor = Colors.orange.shade50;
    }

    return InkWell(
      onTap: () => _handleTap(notif),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : _primaryColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                  color: bgIconColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            const SizedBox(width: 12),
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
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      if (!isRead)
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _primaryColor, shape: BoxShape.circle))
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status.toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700)),
                        ),
                      Text(_formatTime(notif['created_at']),
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
