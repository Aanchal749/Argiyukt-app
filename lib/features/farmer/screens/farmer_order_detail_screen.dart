import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

// ✅ Logic Imports
import 'package:agriyukt_app/features/common/screens/chat_screen.dart';
import 'full_screen_tracking.dart';

// ✅ Localization
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class FarmerOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? order;
  final String? orderId;

  const FarmerOrderDetailScreen({super.key, this.order, this.orderId});

  @override
  State<FarmerOrderDetailScreen> createState() =>
      _FarmerOrderDetailScreenState();
}

class _FarmerOrderDetailScreenState extends State<FarmerOrderDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _order;

  // ✅ VISUALS: Exact Colors from Buyer Screen
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _bgGrey = const Color(0xFFF4F7F6);
  final Color _textDark = const Color(0xFF1A1A1A);
  final Color _textGrey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  String _text(String key) => FarmerText.get(context, key);

  Future<void> _fetchOrderDetails() async {
    final idToFetch = widget.orderId ?? widget.order?['id'];
    if (idToFetch == null) return;

    try {
      final data = await _supabase.from('orders').select('''
              *,
              buyer:profiles!buyer_id(id, first_name, last_name, phone, district, state),
              farmer:profiles!farmer_id(latitude, longitude),
              crop:crops!crop_id(image_url, crop_name, variety, harvest_date, unit, grade, price) 
          ''').eq('id', idToFetch).single();

      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    String mainStatus = (newStatus == 'Rejected')
        ? 'Rejected'
        : (newStatus == 'Completed' ? 'Completed' : 'Accepted');

    setState(() => _isUpdating = true);

    try {
      await _supabase.from('orders').update({
        'status': mainStatus,
        'tracking_status': newStatus,
        if (newStatus == 'Completed') 'is_sharing_location': false
      }).eq('id', _order!['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${_text('status_updated')}: $newStatus"),
            backgroundColor: _primaryGreen));
        _fetchOrderDetails();
      }
    } catch (e) {
      if (mounted) _fetchOrderDetails();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          backgroundColor: _bgGrey,
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return const Scaffold(body: Center(child: Text("Order Not Found")));
    }

    // Parsing Data
    final buyer = _order!['buyer'] ?? {};
    final farmer = _order!['farmer'] ?? {};
    final crop = _order!['crop'] ?? {};

    // ✅ Buyer Info logic
    final String buyerName =
        "${buyer['first_name'] ?? 'Buyer'} ${buyer['last_name'] ?? ''}".trim();

    String dist = buyer['district'] ?? '';
    String st = buyer['state'] ?? '';
    String buyerLoc = "";
    if (dist.isNotEmpty && st.isNotEmpty) {
      buyerLoc = "$dist, $st";
    } else if (dist.isNotEmpty) {
      buyerLoc = dist;
    } else {
      buyerLoc = "Location N/A";
    }

    final String buyerId = buyer['id'] ?? '';

    // Crop Info (detailed)
    String cropName = crop['crop_name'] ?? _order!['crop_name'] ?? "Crop";
    String variety = crop['variety'] ?? 'Standard';
    if (variety.toLowerCase().contains('premium')) variety = 'Prem';
    String grade = crop['grade'] ?? 'Standard';
    String unit = crop['unit'] ?? 'Kg';

    // Price per unit
    double pricePerUnit =
        (double.tryParse(_order!['price_offered']?.toString() ?? "0") ??
            (crop['price'] ?? 0).toDouble());

    String dateText = "Available";
    if (crop['harvest_date'] != null) {
      try {
        dateText =
            DateFormat('dd MMM').format(DateTime.parse(crop['harvest_date']));
      } catch (_) {}
    }

    // Image Logic
    String? rawImgUrl = crop['image_url'];
    ImageProvider imgProvider;
    if (rawImgUrl != null && rawImgUrl.isNotEmpty) {
      if (rawImgUrl.startsWith('http')) {
        imgProvider = NetworkImage(rawImgUrl);
      } else {
        imgProvider = NetworkImage(
            _supabase.storage.from('crop_images').getPublicUrl(rawImgUrl));
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    // Money
    final double qty =
        (double.tryParse(_order!['quantity_kg']?.toString() ?? "0") ?? 0);
    final double totalAmount = qty * pricePerUnit;
    final double paidAmount =
        (double.tryParse(_order!['advance_amount']?.toString() ?? "0") ?? 0);

    // Tracking
    final double fLat = (farmer['latitude'] as num?)?.toDouble() ?? 0.0;
    final double fLng = (farmer['longitude'] as num?)?.toDouble() ?? 0.0;
    final double bLat = (_order!['buyer_lat'] as num?)?.toDouble() ?? 0.0;
    final double bLng = (_order!['buyer_lng'] as num?)?.toDouble() ?? 0.0;
    final bool isSharing = _order!['is_sharing_location'] ?? false;

    final status = _order!['tracking_status'] ?? _order!['status'] ?? 'Pending';
    final scheduleText = _order!['scheduled_pickup_time'] != null
        ? DateFormat('dd MMM, hh:mm a')
            .format(DateTime.parse(_order!['scheduled_pickup_time']).toLocal())
        : "Not Scheduled";

    // Dynamic padding setup based on status buttons rendering height
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double scrollPadding =
        (status == 'Pending' || status == 'Ordered') ? 200 : 140;

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        title: Text(_text('manage_order'),
            style: GoogleFonts.poppins(
                color: _textDark, fontWeight: FontWeight.bold)),
        backgroundColor: _bgGrey,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(0, 10, 0, scrollPadding + bottomSafeArea),
              child: Column(
                children: [
                  // 1. PRODUCT CARD
                  _buildProductCard(cropName, variety, grade, dateText,
                      pricePerUnit, unit, status, imgProvider),
                  const SizedBox(height: 12),

                  // 2. BREAKDOWN CARD
                  _buildBreakdownCard(qty, unit, totalAmount, paidAmount),
                  const SizedBox(height: 12),

                  // 3. SCHEDULE CARD
                  _buildScheduleCard(scheduleText),
                  const SizedBox(height: 12),

                  // 4. TRACKING/MAP CARD
                  _buildTrackingBlock(
                      status, isSharing, fLat, fLng, bLat, bLng, scheduleText),
                  const SizedBox(height: 12),

                  // ✅ 5. CONTACT CARD (Call button removed)
                  _buildContactCard("Buyer", buyerName, buyerLoc, status,
                      cropName, buyerId, Colors.blue.shade100),
                ],
              ),
            ),

            // ✅ BOTTOM ACTION BAR
            _buildBottomPanel(status, bottomSafeArea),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // ✅ Enhanced product card with price, variety, grade, harvest
  Widget _buildProductCard(
      String name,
      String variety,
      String grade,
      String date,
      double pricePerUnit,
      String unit,
      String status,
      ImageProvider img) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                height: 110,
                width: 110,
                child: Image(image: img, fit: BoxFit.cover))),
        const SizedBox(width: 20),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("$variety • $grade",
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text("Harvest: $date",
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "₹${pricePerUnit.toStringAsFixed(0)} / $unit",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(status)
            ],
          )
        ]))
      ]),
    );
  }

  Widget _buildBreakdownCard(
      double qty, String unit, double total, double paid) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        _row(_text('quantity'), "$qty $unit"),
        const SizedBox(height: 8),
        _row(_text('total'), "₹${NumberFormat('#,##0').format(total)}",
            isBold: true),
        const Divider(height: 24),
        _row("Paid", "₹${NumberFormat('#,##0').format(paid)}",
            color: Colors.green),
        const SizedBox(height: 8),
        _row("Pending", "₹${NumberFormat('#,##0').format(total - paid)}",
            color: Colors.orange),
      ]),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(color: _textGrey)),
      Flexible(
          child: Text(val,
              style: GoogleFonts.poppins(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: color ?? Colors.black),
              overflow: TextOverflow.ellipsis))
    ]);
  }

  Widget _buildScheduleCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100)),
      child: Row(children: [
        const Icon(Icons.calendar_month, color: Colors.blue),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Scheduled Pickup",
              style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          Text(text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
        ]),
      ]),
    );
  }

  Widget _buildTrackingBlock(String status, bool sharing, double fLat,
      double fLng, double bLat, double bLng, String schedule) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Shipment Status",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          if (sharing) _buildLiveBadge(),
        ]),
        const SizedBox(height: 20),
        _buildCustomTimeline(status),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      FullScreenTracking(orderId: _order!['id'].toString()))),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
                color: const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300)),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
              const Positioned(
                  left: 20,
                  bottom: 40,
                  child: _MapMarker(
                      label: "Farm", icon: Icons.store, color: Colors.brown)),
              if (bLat != 0) _buildAnimatedTruck(fLat, fLng, bLat, bLng),
              const Positioned(
                  right: 10,
                  bottom: 10,
                  child: Icon(Icons.fullscreen, size: 20, color: Colors.grey)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ✅ Clean Contact Card Setup (No Call Icon)
  Widget _buildContactCard(String role, String name, String loc, String status,
      String crop, String id, Color avatarBg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Row(children: [
        CircleAvatar(
            radius: 24,
            backgroundColor: avatarBg,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : role[0])),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("$role • $loc", style: const TextStyle(color: Colors.grey))
        ])),
        IconButton.filled(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        targetUserId: id,
                        targetName: name,
                        orderId: _order!['id'].toString(),
                        cropName: crop,
                        orderStatus: status))),
            style:
                IconButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white)),
      ]),
    );
  }

  // ✅ BOTTOM PANEL (Flush, Lowered, Full-Width workflow)
  Widget _buildBottomPanel(String status, double bottomPadding) {
    List<Widget> buttons = [];

    // Stage 1: Accept or Reject
    if (status == 'Pending' || status == 'Ordered') {
      buttons = [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
              onPressed: () => _updateStatus('Accepted'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : const Icon(Icons.thumb_up_alt_outlined,
                      color: Colors.white, size: 20),
              label: _isUpdating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_text('accept').toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
              onPressed: () => _updateStatus('Rejected'),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              child: Text(_text('reject').toUpperCase(),
                  style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16))),
        ),
      ];
    }
    // Stage 2: Mark Packed
    else if (status == 'Accepted') {
      buttons = [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
              onPressed: () => _updateStatus('Packed'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : const Icon(Icons.inventory_2_outlined,
                      color: Colors.white, size: 20),
              label: _isUpdating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text("MARK AS PACKED",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ),
      ];
    }
    // Stage 3: Start Shipping
    else if (status == 'Packed') {
      buttons = [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
              onPressed: () => _updateStatus('Shipped'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : const Icon(Icons.local_shipping_outlined,
                      color: Colors.white, size: 20),
              label: _isUpdating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text("START SHIPPING",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ),
      ];
    }
    // Stage 4: Mark Delivered (Direct completion for farmer)
    else if (status == 'Shipped' || status == 'In Transit') {
      buttons = [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
              onPressed: () => _updateStatus('Completed'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : const Icon(Icons.done_all, color: Colors.white, size: 20),
              label: _isUpdating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text("MARK DELIVERED",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
        ),
      ];
    }
    // Stage 5: Completed or Rejected
    else {
      buttons = [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: Text("STATUS: ${status.toUpperCase()}",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
      ];
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // ✅ Flush to bottom
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: buttons,
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildStatusBadge(String status) {
    Color c = (status == 'Accepted' || status == 'Completed')
        ? Colors.green
        : (status == 'Rejected'
            ? Colors.red
            : (status == 'Shipped' || status == 'In Transit'
                ? Colors.blue
                : Colors.orange));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: GoogleFonts.poppins(
                color: c, fontSize: 12, fontWeight: FontWeight.bold)));
  }

  Widget _buildLiveBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.red, borderRadius: BorderRadius.circular(4)),
      child: Text("LIVE",
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _buildCustomTimeline(String s) {
    int step = (s == 'Packed')
        ? 1
        : (['Shipped', 'In Transit'].contains(s)
            ? 2
            : (['Delivered', 'Completed'].contains(s) ? 3 : 0));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _step("Confirmed", 0, step),
      _line(0, step),
      _step("Packed", 1, step),
      _line(1, step),
      _step("Shipped", 2, step),
      _line(2, step),
      _step("Delivered", 3, step)
    ]);
  }

  Widget _step(String l, int i, int c) => Column(children: [
        Icon(Icons.check_circle,
            color: i <= c ? Colors.green : Colors.grey.shade300, size: 24),
        const SizedBox(height: 4),
        Text(l,
            style: GoogleFonts.poppins(
                fontSize: 10, color: i <= c ? Colors.black : Colors.grey))
      ]);
  Widget _line(int i, int c) => Expanded(
      child: Container(
          height: 2,
          color: i < c ? Colors.green : Colors.grey.shade300,
          margin: const EdgeInsets.only(bottom: 20)));

  Widget _buildAnimatedTruck(
      double fLat, double fLng, double bLat, double bLng) {
    double dist = Geolocator.distanceBetween(fLat, fLng, bLat, bLng);
    double prog = (1.0 - (dist / 10000)).clamp(0.0, 1.0);
    return AnimatedAlign(
        duration: const Duration(seconds: 2),
        alignment: Alignment(ui.lerpDouble(-0.8, 0.8, prog)!, 0),
        child: const Icon(Icons.local_shipping,
            color: Colors.blueAccent, size: 30));
  }
}

class _MapMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MapMarker(
      {required this.label, required this.icon, this.color = Colors.black});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold))
      ]);
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    double x = 40;
    while (x < size.width - 45) {
      canvas.drawLine(
          Offset(x, size.height / 2), Offset(x + 5, size.height / 2), paint);
      x += 12;
    }
  }

  @override
  bool shouldRepaint(old) => false;
}
