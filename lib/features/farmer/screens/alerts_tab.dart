import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';

// SCREEN IMPORTS
import 'package:agriyukt_app/features/farmer/screens/profile_tab.dart';
import 'package:agriyukt_app/features/common/screens/wallet_screen.dart';

// ✅ NEW IMPORT: Points to the Farmer's Command Center
import 'package:agriyukt_app/features/farmer/screens/farmer_order_detail_screen.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  final _supabase = Supabase.instance.client;
  final Color _primaryGreen = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _markAllAsRead);
  }

  // ✅ Helper for Localized Text
  String _text(String key) => FarmerText.get(context, key);

  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint("Error marking notifications read: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ UPDATED LOGIC: Direct "Fetch & Navigate" (Like Inspector)
  // ---------------------------------------------------------------------------
  Future<void> _handleNotificationTap(Map<String, dynamic> notif) async {
    final type = notif['type'] ?? 'system';

    // 1. Extract Metadata
    final meta = notif['metadata'] ?? {};
    final String? orderId = meta['order_id']?.toString();

    // Optimistic read update
    if (notif['is_read'] == false) {
      setState(() {
        notif['is_read'] = true;
      });
      _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notif['id']);
    }

    // ✅ LOGIC 1: Orders AND Money (Direct Navigation)
    if ((type == 'order' || type == 'order_update' || type == 'money') &&
        orderId != null) {
      // Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Fetch full order data needed for the Farmer Screen
        // We include 'buyer' details so the screen can populate properly
        final orderData = await _supabase.from('orders').select('''
              *,
              crops!inner(*),
              buyer:profiles!fk_orders_buyer(first_name, last_name, phone, district, state)
            ''').eq('id', orderId).single();

        if (mounted) {
          Navigator.pop(context); // Close loading spinner

          // Navigate directly to the Detail Screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FarmerOrderDetailScreen(order: orderData),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading spinner
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Could not open order details: $e")));
        }
      }
    }
    // ✅ LOGIC 2: Generic Payment (Wallet)
    else if (type == 'payment' || type == 'wallet') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => WalletScreen(themeColor: _primaryGreen)));
    }
    // ✅ LOGIC 3: Profile
    else if (type == 'profile') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfileTab()));
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return _text('just_now');
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return _text('just_now');
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m ${_text('ago')}";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h ${_text('ago')}";
      } else {
        return DateFormat('dd MMM').format(date);
      }
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Center(child: Text(_text('login_required')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(_text('notifications'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(_text('error_loading')));
          }
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: _primaryGreen));
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationItem(notif, langCode);
            },
          );
        },
      ),
    );
  }

  // ✅ RICH CARD DESIGN (UI Kept Exact)
  Widget _buildNotificationItem(Map<String, dynamic> notif, String langCode) {
    final bool isRead = notif['is_read'] ?? false;
    final String type = notif['type'] ?? 'system';

    // Extract Metadata
    final Map<String, dynamic> meta = notif['metadata'] ?? {};
    final String? imageUrl = meta['image'];
    final String personName =
        meta['person_name'] ?? (type == 'money' ? 'Payment' : 'System');
    final String location = meta['location'] ?? '';
    final String cropName = meta['crop_name'] ?? '';
    final String qty = meta['qty']?.toString() ?? '';
    final String price = meta['price']?.toString() ?? '';

    // Status Badge Logic
    String status = (meta['status'] ?? '').toString();
    if (status.isEmpty && type == 'money') status = 'Paid';
    if (status.isEmpty) status = "Alert";

    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'pending') statusColor = Colors.orange;
    if (['accepted', 'shipped', 'confirmed', 'packed', 'active']
        .contains(status.toLowerCase())) statusColor = Colors.blue;
    if (['delivered', 'completed', 'history', 'paid']
        .contains(status.toLowerCase())) statusColor = Colors.green;
    if (['rejected', 'cancelled'].contains(status.toLowerCase()))
      statusColor = Colors.red;

    final String rawBody = notif['body'] ?? "";

    // ✅ Special Icon for Money
    IconData? typeIcon;
    if (type == 'money') typeIcon = Icons.account_balance_wallet;

    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : const Color(0xFF1B5E20).withOpacity(0.3),
              width: isRead ? 1 : 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BIGGER CROP IMAGE
            typeIcon != null
                ? _buildIconBox(typeIcon, statusColor)
                : _buildBigImage(imageUrl),

            const SizedBox(width: 14),

            // 2. ORGANIZED DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name & Read Dot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          personName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        )
                    ],
                  ),

                  // Row 2: Location
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Row 3: Order Details or Body
                  if (cropName.isNotEmpty && qty.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200)),
                      child: RichText(
                        text: TextSpan(
                            style: GoogleFonts.poppins(
                                color: Colors.black87, fontSize: 13),
                            children: [
                              TextSpan(
                                  text: "$cropName  ",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              TextSpan(
                                  text: "•  $qty kg",
                                  style: TextStyle(color: Colors.grey[700])),
                              if (price.isNotEmpty && price != '0')
                                TextSpan(
                                    text: "  •  ₹$price",
                                    style: const TextStyle(
                                        color: Color(0xFF1B5E20),
                                        fontWeight: FontWeight.bold)),
                            ]),
                      ),
                    )
                  else
                    // Fallback for simple/money notifications
                    FutureBuilder<String>(
                      future: TranslationService.toLocal(rawBody, langCode),
                      initialData: rawBody,
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? rawBody,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey[800]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),

                  const SizedBox(height: 8),

                  // Row 4: Status & Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(status.toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        _formatTime(notif['created_at']),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
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

  Widget _buildBigImage(String? imageUrl) {
    ImageProvider imgProvider;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        imgProvider = NetworkImage(imageUrl);
      } else {
        try {
          final fullUrl = Supabase.instance.client.storage
              .from('crop_images')
              .getPublicUrl(imageUrl);
          imgProvider = NetworkImage(fullUrl);
        } catch (_) {
          imgProvider = const AssetImage('assets/images/placeholder_crop.png');
        }
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: imgProvider, fit: BoxFit.cover),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ]),
    );
  }

  // ✅ New helper for Money Icon
  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 32),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.notifications_off_outlined,
                size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(_text('no_notifications'),
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
