import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  // ✅ SINGLETON PATTERN: Required so the subscription stays alive across screens
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 1. EXISTING DATABASE METHODS (Fetching List for Notification Screen)
  // ---------------------------------------------------------------------------

  /// Fetch Notifications for Logged-in User
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false); // Newest first

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ Error fetching notifications: $e");
      return [];
    }
  }

  /// Mark as Read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  /// Mark ALL as Read
  Future<void> markAllRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('user_id', user.id);
  }

  // ---------------------------------------------------------------------------
  // 2. REAL-TIME METHODS (For Inspector Popups)
  // ---------------------------------------------------------------------------

  RealtimeChannel? _orderSubscription;

  /// Starts listening for NEW orders in real-time
  void listenToOrders(BuildContext context) {
    // Prevent duplicate listeners
    if (_orderSubscription != null) {
      debugPrint("⚠️ NotificationService: Already listening. Skipping.");
      return;
    }

    debugPrint("🟢 NotificationService: Subscribing to 'public:orders'...");

    _orderSubscription = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, // Listen ONLY for new inserts
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            // 🛑 CRITICAL DEBUG LOG
            debugPrint(
                "🔥 REALTIME EVENT RECEIVED! Payload: ${payload.newRecord}");

            // Trigger the UI Popup
            handleNewOrder(context, payload.newRecord);
          },
        )
        .subscribe((status, error) {
      // 🛑 CRITICAL STATUS LOG
      debugPrint("🔄 Subscription Status: $status");
      if (error != null) {
        debugPrint("❌ Subscription Error: $error");
      }
    });
  }

  /// Stops listening (Call on logout or dispose)
  void stopListening() {
    if (_orderSubscription != null) {
      _supabase.removeChannel(_orderSubscription!);
      _orderSubscription = null;
      debugPrint("🔕 NotificationService: Stopped listening.");
    }
  }

  /// Handles the UI (SnackBar) when a new order arrives
  /// ✅ UPDATED LOGIC: Robust handling for price and payload structure
  void handleNewOrder(BuildContext context, Map<String, dynamic> payload) {
    try {
      debugPrint("🔔 Processing Popup Payload: $payload");

      // 1. Safe Payload Extraction
      // Supabase sometimes wraps data in 'new', sometimes sends directly.
      final data = payload.containsKey('new') ? payload['new'] : payload;

      if (data == null) {
        debugPrint("❌ Error: Payload data is null");
        return;
      }

      // 2. Safe ID Extraction
      final orderId = data['id']?.toString().substring(0, 8) ?? 'New';

      // 3. Robust Price Handling
      // Handles numeric (int/double) or string formats safely.
      final rawPrice = data['total_price'] ?? 0;
      final totalPrice = rawPrice.toString();

      // 4. Show SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade800,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("New Order Received!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("Order #$orderId • ₹$totalPrice",
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Navigate to Order Details
              debugPrint("Navigating to Order Details for $orderId");
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error showing Notification Popup: $e");
    }
  }
}
