import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added Google Fonts
import 'package:agriyukt_app/features/buyer/screens/buyer_order_detail_screen.dart';

class BuyerOrdersScreen extends StatefulWidget {
  final int initialIndex;

  const BuyerOrdersScreen({super.key, this.initialIndex = 0});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];

  // ✅ Buyer Theme Blue
  final Color _primaryBlue = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialIndex);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      if (mounted) setState(() => _isLoading = true); // Ensure loading state

      final response = await _supabase.from('orders').select('''
            *,
            farmer:profiles!fk_orders_farmer(first_name, last_name, district, state),
            crop:crops!crop_id(image_url, crop_name, crop_type) 
          ''').eq('buyer_id', user.id).order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTER LOGIC (UPDATED FOR FIX) ---

  List<Map<String, dynamic>> _getPendingOrders() {
    return _allOrders.where((o) {
      final s = (o['status'] ?? 'Pending').toString().toLowerCase();
      // Check for pending or ordered
      return s == 'pending' || s == 'ordered';
    }).toList();
  }

  List<Map<String, dynamic>> _getActiveOrders() {
    return _allOrders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      // ✅ FIX: Explicitly include 'accepted' and other progress states
      return [
        'accepted',
        'confirmed',
        'packed',
        'shipped',
        'in transit',
        'out for delivery',
        'processing'
      ].contains(s);
    }).toList();
  }

  List<Map<String, dynamic>> _getCompletedOrders() {
    return _allOrders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      // ✅ FIX: Robust check for completion states
      return ['delivered', 'completed', 'rejected', 'cancelled'].contains(s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("My Orders",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white)), // ✅ Changed to Poppins
        backgroundColor: _primaryBlue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchOrders();
            },
          )
        ],
        // --- TABS ---
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold), // ✅ Changed to Poppins
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Active"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                    orders: _getPendingOrders(),
                    emptyMsg: "No pending requests"),
                _OrderList(
                    orders: _getActiveOrders(), emptyMsg: "No active orders"),
                _OrderList(
                    orders: _getCompletedOrders(),
                    emptyMsg: "No order history"),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final String emptyMsg;

  const _OrderList({required this.orders, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(emptyMsg,
                style: GoogleFonts.poppins(
                    color: Colors.grey[600])), // ✅ Changed to Poppins
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _BuyerOrderCard(order: orders[index]);
      },
    );
  }
}

class _BuyerOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _BuyerOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    // --- DATA PARSING ---
    final rawStatus = order['status'] ?? 'Pending';
    final trackingStatus = order['tracking_status'] ?? 'Ordered';

    // Status Logic for UI
    String displayStatus = rawStatus;
    Color statusColor = Colors.orange;
    Color statusBg = const Color(0xFFFFF3E0);

    // Normalize for comparison
    final statusLower = rawStatus.toString().toLowerCase();

    if (statusLower == 'pending') {
      displayStatus = "Approval Pending";
      statusColor = Colors.orange;
      statusBg = Colors.orange.shade50;
    } else if (['accepted', 'packed', 'shipped', 'in transit']
        .contains(statusLower)) {
      displayStatus =
          trackingStatus.isNotEmpty ? trackingStatus : rawStatus.toUpperCase();
      statusColor = const Color(0xFF1565C0);
      statusBg = Colors.blue.shade50;
    } else if (['rejected', 'cancelled'].contains(statusLower)) {
      displayStatus = "Rejected";
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
    } else if (['delivered', 'completed'].contains(statusLower)) {
      displayStatus = "Delivered";
      statusColor = Colors.green;
      statusBg = Colors.green.shade50;
    }

    final String orderIdDisplay =
        "#${order['id'].toString().substring(0, 5).toUpperCase()}";

    // Farmer Details
    final farmer = order['farmer'];
    String farmerName = "AgriYukt Farmer";
    String location = "India";

    if (farmer != null && farmer is Map) {
      farmerName =
          "${farmer['first_name'] ?? 'Farmer'} ${farmer['last_name'] ?? ''}"
              .trim();
      List<String> locParts = [];
      if (farmer['district'] != null) locParts.add(farmer['district']);
      if (farmer['state'] != null) locParts.add(farmer['state']);
      if (locParts.isNotEmpty) location = locParts.join(", ");
    }

    // Crop Details
    final crop = order['crop'];
    String cropName = order['crop_name'] ?? "Unknown Crop";
    String? imgUrl;

    if (crop != null && crop is Map) {
      cropName = crop['crop_name'] ?? order['crop_name'] ?? "Crop";
      imgUrl = crop['image_url'];
    }

    final String price =
        "₹${NumberFormat('#,##0').format(order['price_offered'] ?? 0)}";
    final String quantity = "${order['quantity_kg'] ?? 0} kg";

    final String dateStr = order['created_at'];
    final String orderDate =
        DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr).toLocal());

    ImageProvider imgProvider;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http')) {
        imgProvider = NetworkImage(imgUrl);
      } else {
        try {
          final fullUrl = Supabase.instance.client.storage
              .from('crop_images')
              .getPublicUrl(imgUrl);
          imgProvider = NetworkImage(fullUrl);
        } catch (e) {
          imgProvider = const AssetImage('assets/images/placeholder_crop.png');
        }
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuyerOrderDetailScreen(
              orderId: order['id'].toString(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            // 1. HEADER: Farmer Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(farmerName.isNotEmpty ? farmerName[0] : "F",
                        style: GoogleFonts.poppins(
                            color: Colors.blue.shade900,
                            fontWeight:
                                FontWeight.bold)), // ✅ Changed to Poppins
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(farmerName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)), // ✅ Changed to Poppins
                        Text(location,
                            style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12), // ✅ Changed to Poppins
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(orderIdDisplay,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500)), // ✅ Changed to Poppins
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // 2. BODY: Crop Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 85,
                      width: 85,
                      child: Image(
                        image: imgProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey)),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight
                                          .bold)), // ✅ Changed to Poppins
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(displayStatus.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          statusColor)), // ✅ Changed to Poppins
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("$quantity • $price",
                            style: GoogleFonts.poppins(
                                color: Colors.grey[800],
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w500)), // ✅ Changed to Poppins
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0), // Buyer Blue
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("View Details",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight
                                            .w600)), // ✅ Changed to Poppins
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 10, color: Colors.white)
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

            // 3. FOOTER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text("Ordered on: $orderDate",
                  style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 12)), // ✅ Changed to Poppins
            ),
          ],
        ),
      ),
    );
  }
}
