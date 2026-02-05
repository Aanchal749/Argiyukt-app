import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/core/services/translation_service.dart'; // ✅ Added for dynamic translation

// SCREEN IMPORTS
import 'package:agriyukt_app/features/farmer/screens/profile_tab.dart';
import 'package:agriyukt_app/features/farmer/screens/orders_screen.dart';
import 'package:agriyukt_app/features/common/screens/wallet_screen.dart';

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

  void _handleNotificationTap(Map<String, dynamic> notif) {
    final type = notif['type'] ?? 'system';

    if (type == 'order' || type == 'order_update') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
    } else if (type == 'payment') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => WalletScreen(themeColor: _primaryGreen)));
    } else if (type == 'profile') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfileTab()));
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'order_update':
        return Icons.local_shipping_outlined;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'profile':
        return Icons.person_outline;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'order':
      case 'order_update':
        return Colors.blue;
      case 'payment':
        return Colors.green;
      case 'alert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return _text('just_now');
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
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final bool isRead = notif['is_read'] ?? false;
              final String type = notif['type'] ?? 'system';

              // Prepare raw strings
              final String rawTitle = notif['title'] ?? "";
              final String rawBody = notif['body'] ?? "";

              return InkWell(
                onTap: () => _handleNotificationTap(notif),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isRead
                            ? Colors.grey.withOpacity(0.1)
                            : Colors.green.withOpacity(0.3)),
                    boxShadow: [
                      if (!isRead)
                        BoxShadow(
                            color: Colors.green.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorForType(type).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getIconForType(type),
                            size: 20, color: _getColorForType(type)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  // ✅ DYNAMIC TRANSLATION for Title
                                  child: FutureBuilder<String>(
                                    future: TranslationService.toLocal(
                                        rawTitle.isNotEmpty
                                            ? rawTitle
                                            : _text('notifications'),
                                        langCode),
                                    initialData: rawTitle.isNotEmpty
                                        ? rawTitle
                                        : _text('notifications'),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? rawTitle,
                                        style: GoogleFonts.poppins(
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black87),
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  _formatTime(notif['created_at']),
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // ✅ DYNAMIC TRANSLATION for Body
                            FutureBuilder<String>(
                              future:
                                  TranslationService.toLocal(rawBody, langCode),
                              initialData: rawBody,
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? rawBody,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 5),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        )
                    ],
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
