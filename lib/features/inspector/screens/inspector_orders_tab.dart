import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_order_detail_screen.dart';

class InspectorOrdersTab extends StatefulWidget {
  final int initialIndex;

  const InspectorOrdersTab({super.key, this.initialIndex = 0});

  @override
  State<InspectorOrdersTab> createState() => _InspectorOrdersTabState();
}

class _InspectorOrdersTabState extends State<InspectorOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];

  // Theme Color (Inspector Purple)
  final Color _primaryPurple = const Color(0xFF512DA8);

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
    super.dispose();
  }

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
            crops!inner(id, crop_name, image_url, inspector_id, price),
            buyer:profiles!fk_orders_buyer(first_name, last_name, phone, district, state),
            farmer:profiles!fk_orders_farmer(first_name, last_name, phone, district, state)
          ''')
          .eq('crops.inspector_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching orders: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _updateStatus(dynamic orderId, String newStatus) async {
    try {
      // ✅ LOGIC: Matches Farmer's update logic
      // This update triggers the DB function 'manage_stock_on_status' automatically.
      // - Accepted -> Deducts Stock
      // - Rejected -> Restores Stock
      await _supabase.from('orders').update({
        'status': newStatus == 'Rejected' ? 'Rejected' : 'Accepted',
        'tracking_status': newStatus == 'Accepted' ? 'Accepted' : null
      }).eq('id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order $newStatus", style: GoogleFonts.poppins()),
            backgroundColor:
                newStatus == 'Accepted' ? Colors.green : Colors.red,
            duration: const Duration(milliseconds: 800),
          ),
        );
        _fetchManagedOrders();
      }
      return true;
    } catch (e) {
      debugPrint("Error updating status: $e");
      // Optional: Show error if stock is insufficient (caught by DB trigger)
      if (mounted && e.toString().contains("Insufficient")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ Update Failed: Insufficient Stock"),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // --- FILTER LOGIC ---
  List<Map<String, dynamic>> _getPendingOrders() {
    return _allOrders.where((o) {
      final status = (o['status'] ?? 'Pending').toString();
      return status == 'Pending' || status == 'Ordered';
    }).toList();
  }

  List<Map<String, dynamic>> _getActiveOrders() {
    return _allOrders.where((o) {
      final status = (o['status'] ?? '').toString();
      final tracking = (o['tracking_status'] ?? '').toString();

      // Active if Accepted/Confirmed AND NOT Finished
      bool isAccepted = status == 'Accepted' || status == 'Confirmed';
      bool isFinished = ['Delivered', 'Completed', 'Rejected', 'Cancelled']
          .contains(tracking);

      return isAccepted && !isFinished;
    }).toList();
  }

  List<Map<String, dynamic>> _getHistoryOrders() {
    return _allOrders.where((o) {
      final status = (o['status'] ?? '').toString();
      final tracking = (o['tracking_status'] ?? '').toString();

      return ['Delivered', 'Completed'].contains(tracking) ||
          ['Rejected', 'Cancelled'].contains(status);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text("Incoming Orders",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchManagedOrders();
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryPurple,
          indicatorColor: _primaryPurple,
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryPurple))
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                  orders: _getPendingOrders(),
                  emptyMsg: "No new order requests",
                  tabType: 'pending',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
                ),
                _OrderList(
                  orders: _getActiveOrders(),
                  emptyMsg: "No active orders",
                  tabType: 'active',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
                ),
                _OrderList(
                  orders: _getHistoryOrders(),
                  emptyMsg: "No past orders",
                  tabType: 'history',
                  onStatusUpdate: _updateStatus,
                  onRefresh: _fetchManagedOrders,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
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
      color: const Color(0xFF512DA8),
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          return _InspectorOrderCard(
            order: orders[index],
            tabType: tabType,
            onStatusUpdate: onStatusUpdate,
            onRefresh: onRefresh,
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

  const _InspectorOrderCard({
    super.key,
    required this.order,
    required this.tabType,
    required this.onStatusUpdate,
    required this.onRefresh,
  });

  @override
  State<_InspectorOrderCard> createState() => _InspectorOrderCardState();
}

class _InspectorOrderCardState extends State<_InspectorOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  // ✅ CALL FUNCTION
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty || phoneNumber == "N/A") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available.")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    // --- DATA PARSING ---
    final String status =
        (order['tracking_status'] ?? order['status'] ?? 'Pending').toString();
    final String qty = "${order['quantity_kg'] ?? '0'} Kg";
    final String price = "₹${order['price_offered'] ?? 0}";

    final String dateStr = order['created_at'];
    final String orderDate =
        DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr).toLocal());

    // 1. FARMER Parsing
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

    // 2. CROP Parsing
    final crop = order['crops'];
    String cropName = "Unknown Crop";
    String? rawUrl;

    if (crop != null && crop is Map) {
      cropName = crop['crop_name'] ?? order['crop_name'] ?? 'Unknown Crop';
      rawUrl = crop['image_url'];
    }

    // 3. IMAGE Logic
    ImageProvider imgProvider;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http')) {
        imgProvider = NetworkImage(rawUrl);
      } else {
        try {
          final fullUrl = Supabase.instance.client.storage
              .from('crop_images')
              .getPublicUrl(rawUrl);
          imgProvider = NetworkImage(fullUrl);
        } catch (e) {
          imgProvider = const AssetImage('assets/images/placeholder_crop.png');
        }
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    // 4. STATUS COLOR
    Color statusColor = Colors.orange;
    if (status == 'Accepted' || status == 'Packed' || status == 'Shipped') {
      statusColor = Colors.blue;
    }
    if (status == 'Delivered' || status == 'Completed') {
      statusColor = Colors.green;
    }
    if (status == 'Rejected' || status == 'Cancelled') statusColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- HEADER & DETAILS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: imgProvider,
                      fit: BoxFit.cover,
                      onError: (e, s) {},
                    ),
                  ),
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
                            child: Text("$farmerName • $location",
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
                  // Call Button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone_in_talk,
                          color: Colors.green, size: 20),
                      onPressed: () => _makePhoneCall(farmerPhone),
                      tooltip: "Call Farmer to Verify",
                    ),
                  ),
                  // Reject Button
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
                        textStyle:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                  const SizedBox(width: 8),
                  // Accept Button
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
                        backgroundColor: const Color(0xFF512DA8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InspectorOrderDetailScreen(order: order)),
                      ).then((_) => widget.onRefresh());
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF512DA8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InspectorOrderDetailScreen(order: order)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
