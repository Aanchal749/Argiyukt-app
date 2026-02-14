import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ CORRECT IMPORT: Points to the new consolidated screen
import 'package:agriyukt_app/features/inspector/screens/inspector_order_detail_screen.dart';

class InspectorOrdersTab extends StatefulWidget {
  final int initialIndex;
  final String? highlightOrderId;

  const InspectorOrdersTab({
    super.key,
    this.initialIndex = 0,
    this.highlightOrderId,
  });

  @override
  State<InspectorOrdersTab> createState() => _InspectorOrdersTabState();
}

class _InspectorOrdersTabState extends State<InspectorOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];

  // ✅ Theme Color: Deep Purple
  final Color _primaryPurple = const Color(0xFF512DA8);

  final ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialIndex);
    _fetchManagedOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1️⃣ FETCH DATA
  // ---------------------------------------------------------------------------
  Future<void> _fetchManagedOrders() async {
    try {
      if (!mounted) return;
      if (_allOrders.isEmpty) setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            crops!inner(id, crop_name, image_url, price),
            buyer:profiles!fk_orders_buyer(first_name, last_name, phone, district, state),
            farmer:profiles!fk_orders_farmer!inner(id, first_name, last_name, phone, district, state, inspector_id, latitude, longitude)
          ''')
          .eq('farmer.inspector_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        if (widget.highlightOrderId != null && !_hasScrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToOrder());
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 2️⃣ UPDATE STATUS
  // ---------------------------------------------------------------------------
  Future<bool> _updateStatus(dynamic orderId, String newStatus) async {
    try {
      String mainStatus = (newStatus == 'Packed' || newStatus == 'Shipped')
          ? 'Accepted'
          : (newStatus == 'Delivered' ? 'Completed' : newStatus);

      await _supabase
          .from('orders')
          .update({'status': mainStatus, 'tracking_status': newStatus}).eq(
              'id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order $newStatus", style: GoogleFonts.poppins()),
            backgroundColor:
                (newStatus == 'Accepted' || newStatus == 'Completed')
                    ? Colors.green
                    : Colors.red,
            duration: const Duration(milliseconds: 800),
          ),
        );
        await _fetchManagedOrders();
      }
      return true;
    } catch (e) {
      debugPrint("Error updating status: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 3️⃣ FILTERS
  // ---------------------------------------------------------------------------

  bool _isHistory(Map<String, dynamic> o) {
    final status = (o['status'] ?? '').toString().trim().toLowerCase();
    final tracking =
        (o['tracking_status'] ?? '').toString().trim().toLowerCase();

    final historyList = [
      'delivered',
      'completed',
      'rejected',
      'cancelled',
      'declined'
    ];

    return historyList.contains(tracking) || historyList.contains(status);
  }

  bool _isPending(Map<String, dynamic> o) {
    if (_isHistory(o)) return false;
    final status = (o['status'] ?? '').toString().trim().toLowerCase();
    return (status == 'pending' || status == 'ordered');
  }

  List<Map<String, dynamic>> _getPendingOrders() {
    return _allOrders.where((o) => _isPending(o)).toList();
  }

  List<Map<String, dynamic>> _getHistoryOrders() {
    return _allOrders.where((o) => _isHistory(o)).toList();
  }

  List<Map<String, dynamic>> _getActiveOrders() {
    return _allOrders.where((o) => !_isPending(o) && !_isHistory(o)).toList();
  }

  void _scrollToOrder() {
    List<Map<String, dynamic>> targetList = [];
    if (widget.initialIndex == 0) {
      targetList = _getPendingOrders();
    } else if (widget.initialIndex == 1) {
      targetList = _getActiveOrders();
    } else {
      targetList = _getHistoryOrders();
    }

    final index = targetList
        .indexWhere((o) => o['id'].toString() == widget.highlightOrderId);

    if (index != -1 && _scrollController.hasClients) {
      _hasScrolled = true;
      _scrollController.animateTo(
        index * 280.0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text("Managed Orders",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchManagedOrders();
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Requests"),
            Tab(text: "Active"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryPurple))
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                  controller:
                      widget.initialIndex == 0 ? _scrollController : null,
                  orders: _getPendingOrders(),
                  emptyMsg: "No new order requests",
                  tabType: 'pending',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
                  themeColor: _primaryPurple,
                ),
                _OrderList(
                  controller:
                      widget.initialIndex == 1 ? _scrollController : null,
                  orders: _getActiveOrders(),
                  emptyMsg: "No active orders",
                  tabType: 'active',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
                  themeColor: _primaryPurple,
                ),
                _OrderList(
                  controller:
                      widget.initialIndex == 2 ? _scrollController : null,
                  orders: _getHistoryOrders(),
                  emptyMsg: "No past orders",
                  tabType: 'history',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
                  themeColor: _primaryPurple,
                ),
              ],
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
  final ScrollController? controller;
  final Color themeColor;

  const _OrderList({
    required this.orders,
    required this.emptyMsg,
    required this.tabType,
    required this.onStatusUpdate,
    required this.onRefresh,
    this.controller,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
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
                    color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20), // More space
        itemBuilder: (context, index) {
          return _InspectorOrderCard(
            order: orders[index],
            tabType: tabType,
            onStatusUpdate: onStatusUpdate,
            onRefresh: onRefresh,
            themeColor: themeColor,
          );
        },
      ),
    );
  }
}

class _InspectorOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String tabType;
  final Future<bool> Function(dynamic, String) onStatusUpdate;
  final VoidCallback onRefresh;
  final Color themeColor;

  const _InspectorOrderCard({
    super.key,
    required this.order,
    required this.tabType,
    required this.onStatusUpdate,
    required this.onRefresh,
    required this.themeColor,
  });

  @override
  State<_InspectorOrderCard> createState() => _InspectorOrderCardState();
}

class _InspectorOrderCardState extends State<_InspectorOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty || phoneNumber == "N/A") {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number not available.")));
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
    } catch (_) {}
  }

  // ✅ UPDATED: Open InspectorOrderDetailScreen
  void _openOrderInspector() {
    Navigator.push(
      context,
      MaterialPageRoute(
          // Updated Class Name Here
          builder: (_) => InspectorOrderDetailScreen(order: widget.order)),
    ).then((_) => widget.onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status =
        (order['tracking_status'] ?? order['status'] ?? 'Pending').toString();
    final qty = "${order['quantity_kg'] ?? '0'} Kg";
    final price = "₹${order['price_offered'] ?? 0}";

    // ✅ ID FORMATTING
    final String orderId = order['id'].toString();
    final String shortId =
        orderId.length > 5 ? orderId.substring(0, 5).toUpperCase() : orderId;

    String orderDate = "Unknown Date";
    if (order['created_at'] != null) {
      orderDate = DateFormat('MMM d, yyyy')
          .format(DateTime.parse(order['created_at']).toLocal());
    }

    final farmer = order['farmer'];
    String farmerName = "Farmer";
    String location = "India";
    String farmerPhone = "";

    if (farmer != null && farmer is Map) {
      farmerName =
          "${farmer['first_name'] ?? 'Farmer'} ${farmer['last_name'] ?? ''}"
              .trim();
      farmerPhone = farmer['phone'] ?? "";
      List<String> locParts = [];
      if (farmer['district'] != null) locParts.add(farmer['district']);
      if (farmer['state'] != null) locParts.add(farmer['state']);
      if (locParts.isNotEmpty) location = locParts.join(", ");
    }

    final crop = order['crops'];
    String cropName =
        crop != null ? (crop['crop_name'] ?? 'Unknown') : 'Unknown';
    String? rawUrl = crop?['image_url'];

    ImageProvider imgProvider =
        const AssetImage('assets/images/placeholder_crop.png');
    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http')) {
        imgProvider = NetworkImage(rawUrl);
      } else {
        try {
          final fullUrl = Supabase.instance.client.storage
              .from('crop_images')
              .getPublicUrl(rawUrl);
          imgProvider = NetworkImage(fullUrl);
        } catch (_) {}
      }
    }

    Color statusColor = Colors.orange;
    String lowerStatus = status.toLowerCase();

    if (['accepted', 'packed', 'shipped', 'confirmed', 'verified']
        .contains(lowerStatus)) {
      statusColor = Colors.blue;
    } else if (['delivered', 'completed'].contains(lowerStatus)) {
      statusColor = Colors.green;
    } else if (['rejected', 'cancelled', 'declined'].contains(lowerStatus)) {
      statusColor = Colors.red;
    }

    // ✅ BIGGER CARD LAYOUT
    return InkWell(
      onTap: _openOrderInspector,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Rounded corners
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20), // Increased Padding
          child: Column(
            children: [
              // Header Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ BIGGER IMAGE (110x110)
                  Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                          image: imgProvider, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 20), // More spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: ID & Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text("#$shortId",
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[700])),
                            ),
                            Text(price,
                                style: GoogleFonts.poppins(
                                    fontSize: 18, // Bigger Font
                                    fontWeight: FontWeight.bold,
                                    color: widget.themeColor)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Row 2: Crop Name (Bigger)
                        Text(cropName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 18, // Bigger Font
                                fontWeight: FontWeight.bold)),

                        const SizedBox(height: 6),

                        // Row 3: Farmer
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(farmerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: Colors.grey[700])),
                            ),
                          ],
                        ),

                        // Row 4: Qty & Date
                        const SizedBox(height: 4),
                        Text("Qty: $qty • $orderDate",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // More vertical space
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 20),

              // Buttons Section
              if (widget.tabType == 'pending')
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone_in_talk,
                            color: Colors.green, size: 24),
                        onPressed: () => _makePhoneCall(farmerPhone),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_isAccepting || _isRejecting)
                            ? null
                            : () async {
                                setState(() => _isRejecting = true);
                                await widget.onStatusUpdate(
                                    order['id'], 'Rejected');
                                if (mounted)
                                  setState(() => _isRejecting = false);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                                if (mounted)
                                  setState(() => _isAccepting = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: statusColor.withOpacity(0.3))),
                      child: Text(status.toUpperCase(),
                          style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    // ✅ UPDATED: Open InspectorOrderDetailScreen
                    ElevatedButton(
                      onPressed: _openOrderInspector,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text("Manage Status",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Status: $status",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: statusColor,
                            fontWeight: FontWeight.bold)),
                    // ✅ UPDATED: Open InspectorOrderDetailScreen
                    OutlinedButton(
                      onPressed: _openOrderInspector,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text("View Details"),
                    )
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
