import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';

import 'package:agriyukt_app/features/farmer/screens/farmer_order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialIndex;

  const OrdersScreen({super.key, this.initialIndex = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  int _refreshTrigger = 0; // ✅ Added for Refresh Logic

  // Theme Color
  final Color _primaryGreen = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _text(String key) => FarmerText.get(context, key);

  // ✅ FORCE REFRESH FUNCTION
  void _triggerRefresh() {
    if (mounted) {
      setState(() => _refreshTrigger++);
    }
  }

  // ✅ INSTANT UPDATE LOGIC
  Future<bool> _updateStatus(dynamic orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus, 'tracking_status': newStatus}).eq(
              'id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order $newStatus", style: GoogleFonts.poppins()),
            backgroundColor:
                newStatus == 'Accepted' ? Colors.green : Colors.red,
            duration: const Duration(milliseconds: 800),
          ),
        );
        _triggerRefresh(); // ✅ Refresh immediately after update
      }
      return true;
    } catch (e) {
      debugPrint("Error updating status: $e");
      return false;
    }
  }

  // --- FILTER LOGIC ---
  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> allOrders, String tabType) {
    return allOrders.where((o) {
      final status = (o['status'] ?? 'Pending').toString();
      final tracking = (o['tracking_status'] ?? '').toString();

      if (tabType == 'pending') {
        return status == 'Pending';
      } else if (tabType == 'active') {
        bool isAccepted = [
          'Accepted',
          'Confirmed',
          'Packed',
          'Shipped',
          'Out for Delivery'
        ].contains(status);
        bool isFinished = ['Delivered', 'Completed', 'Rejected', 'Cancelled']
            .contains(tracking);
        return isAccepted && !isFinished;
      } else {
        return ['Delivered', 'Completed'].contains(tracking) ||
            ['Rejected', 'Cancelled'].contains(status);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context);
    final myId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text("Incoming Orders",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryGreen,
          indicatorColor: _primaryGreen,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Requests"),
            Tab(text: "Active"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: myId == null
          ? const Center(child: Text("Login Required"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              // ✅ Key forces refresh when triggered
              key: ValueKey(_refreshTrigger),
              stream: _supabase
                  .from('orders')
                  .stream(primaryKey: ['id'])
                  .eq('farmer_id', myId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: _primaryGreen));
                }

                final allOrders = snapshot.data ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderList(
                      orders: _filterOrders(allOrders, 'pending'),
                      emptyMsg: "No new order requests",
                      tabType: 'pending',
                      onStatusUpdate: _updateStatus,
                      onRefresh: _triggerRefresh, // Pass refresh callback
                    ),
                    _OrderList(
                      orders: _filterOrders(allOrders, 'active'),
                      emptyMsg: "No active orders",
                      tabType: 'active',
                      onStatusUpdate: _updateStatus,
                      onRefresh: _triggerRefresh,
                    ),
                    _OrderList(
                      orders: _filterOrders(allOrders, 'history'),
                      emptyMsg: "No past orders",
                      tabType: 'history',
                      onStatusUpdate: _updateStatus,
                      onRefresh: _triggerRefresh,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final String emptyMsg;
  final String tabType;
  final Future<bool> Function(dynamic, String) onStatusUpdate;
  final VoidCallback onRefresh;

  const _OrderList({
    required this.orders,
    required this.emptyMsg,
    required this.tabType,
    required this.onStatusUpdate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          onRefresh();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(
                        tabType == 'pending'
                            ? Icons.inbox
                            : (tabType == 'active'
                                ? Icons.local_shipping
                                : Icons.history),
                        size: 40,
                        color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 15),
                  Text(emptyMsg,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          return _FarmerOrderCard(
            order: orders[index],
            tabType: tabType,
            onStatusUpdate: onStatusUpdate,
            onNavigateBack: onRefresh, // ✅ Refresh on return
          );
        },
      ),
    );
  }
}

class _FarmerOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String tabType;
  final Future<bool> Function(dynamic, String) onStatusUpdate;
  final VoidCallback onNavigateBack;

  const _FarmerOrderCard({
    super.key,
    required this.order,
    required this.tabType,
    required this.onStatusUpdate,
    required this.onNavigateBack,
  });

  @override
  State<_FarmerOrderCard> createState() => _FarmerOrderCardState();
}

class _FarmerOrderCardState extends State<_FarmerOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  // ✅ New Fetcher to get Image URL since Stream doesn't include it
  Future<String?> _fetchCropImage(String cropId) async {
    try {
      final response = await Supabase.instance.client
          .from('crops')
          .select('image_url')
          .eq('id', cropId)
          .single();
      return response['image_url'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status =
        (order['tracking_status'] ?? order['status'] ?? 'Pending').toString();
    final qty = "${order['quantity_kg'] ?? order['quantity'] ?? '0'} Kg";
    final price = "₹${order['price_offered'] ?? 0}";
    final orderDate = DateFormat('MMM d, yyyy')
        .format(DateTime.parse(order['created_at']).toLocal());
    final buyerName = order['buyer_name'] ?? "Buyer";

    // ✅ Fix: Get crop_id to fetch image
    final cropId = order['crop_id'].toString();
    final cropName = order['crop_name'] ?? "Crop";

    Color statusColor = Colors.orange;
    if (['Accepted', 'Packed', 'Shipped', 'Confirmed'].contains(status))
      statusColor = Colors.blue;
    if (['Delivered', 'Completed'].contains(status)) statusColor = Colors.green;
    if (['Rejected', 'Cancelled'].contains(status)) statusColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ IMAGE FIX: Bigger Images (90x90)
                FutureBuilder<String?>(
                  future: _fetchCropImage(cropId),
                  builder: (context, snapshot) {
                    final rawUrl = snapshot.data;
                    ImageProvider imgProvider;

                    if (snapshot.hasData &&
                        rawUrl != null &&
                        rawUrl.isNotEmpty) {
                      if (rawUrl.startsWith('http')) {
                        imgProvider = NetworkImage(rawUrl);
                      } else {
                        final fullUrl = Supabase.instance.client.storage
                            .from('crop_images')
                            .getPublicUrl(rawUrl);
                        imgProvider = NetworkImage(fullUrl);
                      }
                    } else {
                      imgProvider = const AssetImage(
                          'assets/images/placeholder_crop.png');
                    }

                    return Container(
                      height: 90, // ✅ Increased Size
                      width: 90, // ✅ Increased Size
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                            image: imgProvider, fit: BoxFit.cover),
                      ),
                    );
                  },
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
                            child: Text(cropName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          Text(price,
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B5E20))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Qty: $qty",
                          style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(buyerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Ordered: $orderDate",
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 16),

            // --- ACTION BUTTONS ---
            if (widget.tabType == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_isAccepting || _isRejecting)
                          ? null
                          : () async {
                              setState(() => _isRejecting = true);
                              await widget.onStatusUpdate(
                                  order['id'], 'Rejected');
                              if (mounted) setState(() => _isRejecting = false);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isRejecting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red))
                          : const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isAccepting || _isRejecting)
                          ? null
                          : () async {
                              setState(() => _isAccepting = true);
                              await widget.onStatusUpdate(
                                  order['id'], 'Accepted');
                              if (mounted) setState(() => _isAccepting = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("Accept",
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              )
            else if (widget.tabType == 'active')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: statusColor.withOpacity(0.3))),
                    child: Text(status.toUpperCase(),
                        style: GoogleFonts.poppins(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FarmerOrderDetailScreen(
                                  orderId: order['id'].toString())));
                      widget.onNavigateBack(); // ✅ Refresh list on return
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text("Manage Status",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Status: $status",
                      style: GoogleFonts.poppins(
                          color: statusColor, fontWeight: FontWeight.bold)),
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FarmerOrderDetailScreen(
                                  orderId: order['id'].toString())));
                      widget.onNavigateBack(); // ✅ Refresh on return
                    },
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text("View Details"),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }
}
