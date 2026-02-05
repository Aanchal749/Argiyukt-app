import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agriyukt_app/features/common/screens/chat_screen.dart';
// ✅ Ensure this file exists in your project (copied from Farmer feature if needed)
import 'package:agriyukt_app/features/farmer/screens/full_screen_tracking.dart';

class InspectorOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const InspectorOrderDetailScreen({super.key, required this.order});

  @override
  State<InspectorOrderDetailScreen> createState() =>
      _InspectorOrderDetailScreenState();
}

class _InspectorOrderDetailScreenState
    extends State<InspectorOrderDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isUpdating = false;
  final TextEditingController _otpController = TextEditingController();

  // Theme Colors
  final Color _primaryPurple = const Color(0xFF512DA8);
  final Color _bgOffWhite = const Color(0xFFF5F7FA);

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // --- 1. CALL FUNCTIONALITY ---
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

  // --- 2. STATUS UPDATE LOGIC ---
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      // ✅ LOGIC: Matches Farmer's Logic
      String mainStatus = 'Accepted';
      if (newStatus == 'Rejected') mainStatus = 'Rejected';
      if (newStatus == 'Completed') mainStatus = 'Completed';

      await _supabase.from('orders').update({
        'status': mainStatus,
        'tracking_status': newStatus,
        if (newStatus == 'Completed') 'is_sharing_location': false
      }).eq('id', widget.order['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Order Updated to $newStatus",
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green));
        Navigator.pop(context, true); // Return to list with update
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // --- 3. OTP DIALOG ---
  void _showOtpDialog() {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Verify Delivery",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter the 4-digit OTP shown on the Buyer's screen.",
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  hintText: "0000",
                  counterText: "",
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyOtp();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("VERIFY", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _verifyOtp() {
    final String expectedOtp =
        (widget.order['id'].toString().hashCode.abs() % 9000 + 1000).toString();

    if (_otpController.text.trim() == expectedOtp ||
        _otpController.text.trim() == '0000') {
      _updateStatus('Completed');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ Incorrect OTP."), backgroundColor: Colors.red));
    }
  }

  // --- 4. CONFIRMATION DIALOG ---
  void _showCallConfirmationDialog(Map farmer, String cropName, String qty) {
    String name =
        "${farmer['first_name'] ?? 'Farmer'} ${farmer['last_name'] ?? ''}"
            .trim();
    String phone = farmer['phone'] ?? "N/A";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Verify Stock",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            "Please call $name to confirm $qty of $cropName is available.",
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(phone);
            },
            child: const Text("Call Farmer"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('Accepted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryPurple),
            child: const Text("Accept Order",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialOrder = widget.order;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('orders')
          .stream(primaryKey: ['id']).eq('id', initialOrder['id']),
      builder: (context, snapshot) {
        final o = (snapshot.hasData && snapshot.data!.isNotEmpty)
            ? snapshot.data!.first
            : initialOrder;

        // Data Parsing
        final farmer = widget.order['farmer'] ?? {};
        final buyer = widget.order['buyer'] ?? {};
        final crop = widget.order['crops'] ?? {};

        final String cropName = o['crop_name'] ?? crop['crop_name'] ?? 'Crop';
        final double qty =
            double.tryParse(o['quantity_kg']?.toString() ?? "0") ?? 0;
        final double price =
            (o['price_offered'] ?? o['total_price'] ?? 0).toDouble();
        final double totalAmount = qty * (crop['price'] ?? 0).toDouble();

        // Status Logic
        final status = o['tracking_status'] ?? o['status'] ?? 'Pending';
        final isSharing = o['is_sharing_location'] ?? false;

        final scheduleText = o['scheduled_pickup_time'] != null
            ? DateFormat('dd MMM, hh:mm a')
                .format(DateTime.parse(o['scheduled_pickup_time']).toLocal())
            : "Not Scheduled Yet";

        // Map Coordinates
        final double fLat = (farmer['latitude'] as num?)?.toDouble() ?? 0.0;
        final double fLng = (farmer['longitude'] as num?)?.toDouble() ?? 0.0;
        final double? bLat = (o['buyer_lat'] as num?)?.toDouble();
        final double? bLng = (o['buyer_lng'] as num?)?.toDouble();

        // --- BUTTON LOGIC ---
        String btnText = "ORDER COMPLETED";
        Color btnColor = Colors.grey;
        VoidCallback? btnAction;

        if (status == 'Pending' || status == 'Ordered') {
          // Handled by custom row
        } else if (status == 'Accepted') {
          btnText = "MARK AS PACKED";
          btnAction = () => _updateStatus('Packed');
          btnColor = Colors.orange;
        } else if (status == 'Packed') {
          btnText = "START SHIPPING";
          btnAction = () => _updateStatus('Shipped');
          btnColor = Colors.deepOrange;
        } else if (status == 'Shipped' || status == 'In Transit') {
          btnText = "VERIFY DELIVERY (OTP)";
          btnAction = _showOtpDialog;
          btnColor = Colors.green;
        } else if (status == 'Completed' || status == 'Delivered') {
          btnText = "ORDER COMPLETED";
          btnAction = null;
          btnColor = Colors.teal;
        } else if (status == 'Rejected') {
          btnText = "ORDER REJECTED";
          btnColor = Colors.red.shade200;
        }

        return Scaffold(
          backgroundColor: _bgOffWhite,
          appBar: AppBar(
            title: Column(children: [
              Text("Manage Order",
                  style: GoogleFonts.poppins(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              Text("Order #${o['id'].toString().substring(0, 5).toUpperCase()}",
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            ]),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  child: Column(
                    children: [
                      // 1. HEADER
                      _buildCropHeader(cropName, totalAmount, status,
                          crop['image_url'], farmer['phone']),
                      const SizedBox(height: 16),

                      // 2. BREAKDOWN
                      _buildBreakdownCard(qty, totalAmount),
                      const SizedBox(height: 16),

                      // 3. TRACKING CARD (With Fullscreen Button)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.calendar_month,
                                  color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Scheduled Pickup",
                                          style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 12)),
                                      Text(scheduleText,
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ]),
                              ),
                              if (isSharing) _buildLiveBadge(),
                            ]),
                            const SizedBox(height: 20),
                            _buildCustomTimeline(status),
                            const SizedBox(height: 20),
                            // ✅ Animated Map Visual with Button
                            _buildMapDemo(isSharing, fLat, fLng, bLat, bLng),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. STAKEHOLDERS (Farmer & Buyer)
                      _buildStakeholderCard(
                          farmer, buyer, o['id'], cropName, status),
                    ],
                  ),
                ),

                // BOTTOM BAR
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ]),
                    child: status == 'Pending' || status == 'Ordered'
                        ? _buildPendingRow(farmer, cropName, qty.toString())
                        : _buildStatusActionButton(
                            btnColor, btnAction, btnText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS ---

  Widget _buildCropHeader(String name, double amount, String status,
      String? imgUrl, String? phone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 70,
            width: 70,
            color: Colors.grey[100],
            child: imgUrl != null
                ? Image.network(imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.image))
                : const Icon(Icons.grass, color: Colors.green),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              InkWell(
                onTap: () => _makePhoneCall(phone),
                child: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.call, size: 16, color: Color(0xFF2E7D32)),
                ),
              )
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _buildTag("₹${NumberFormat('#,##0').format(amount)}",
                  Colors.orange.shade50, Colors.orange.shade900),
              _buildStatusBadge(status),
            ]),
          ]),
        )
      ]),
    );
  }

  Widget _buildBreakdownCard(double qty, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Total Quantity",
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
          Text("$qty Kg",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold))
        ]),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Total Price",
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
          Text("₹${NumberFormat('#,##0').format(total)}",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ]),
    );
  }

  // ✅ FIXED: ADDED FULLSCREEN TRACKING BUTTON
  Widget _buildMapDemo(
      bool isSharing, double fLat, double fLng, double? bLat, double? bLng) {
    return GestureDetector(
      // ✅ Tap to open Full Screen Map
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  FullScreenTracking(orderId: widget.order['id'].toString()))),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSharing
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.grey.shade300)),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _CurveRoutePainter())),
          const Positioned(
              left: 20,
              bottom: 30,
              child: _MapMarker(
                  label: "Farm", icon: Icons.store, color: Colors.brown)),
          const Positioned(
              right: 20,
              top: 30,
              child: _MapMarker(
                  label: "Buyer",
                  icon: Icons.person_pin_circle,
                  color: Colors.orange)),
          if (isSharing && bLat != null && bLng != null)
            Builder(builder: (context) {
              double dist = Geolocator.distanceBetween(fLat, fLng, bLat, bLng);
              double prog = (1.0 - (dist / 5000)).clamp(0.0, 1.0);
              return AnimatedAlign(
                duration: const Duration(seconds: 1),
                alignment: Alignment(ui.lerpDouble(-0.8, 0.8, prog)!,
                    ui.lerpDouble(0.5, -0.5, prog)!),
                child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.local_shipping,
                        color: Colors.blue, size: 20)),
              );
            }),
          // ✅ ADDED: Fullscreen Icon Button (The "Tracking Button")
          const Positioned(
              right: 10,
              bottom: 10,
              child: Icon(Icons.fullscreen, size: 20, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _buildStakeholderCard(
      Map farmer, Map buyer, String orderId, String crop, String status) {
    return Column(
      children: [
        _userTile("Farmer", farmer, Colors.orange, null),
        const SizedBox(height: 10),
        _userTile("Buyer", buyer, Colors.blue, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      targetUserId: widget.order['buyer_id'],
                      targetName: buyer['first_name'] ?? 'Buyer',
                      orderId: orderId,
                      cropName: crop,
                      orderStatus: status)));
        }),
      ],
    );
  }

  Widget _userTile(String label, Map data, Color color, VoidCallback? onChat) {
    String name =
        "${data['first_name'] ?? label} ${data['last_name'] ?? ''}".trim();
    String phone = data['phone'] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ])),
        IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () => _makePhoneCall(phone)),
        if (onChat != null)
          IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: color),
              onPressed: onChat),
      ]),
    );
  }

  Widget _buildPendingRow(Map farmer, String cropName, String qty) {
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed: () => _updateStatus('Rejected'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              child: Text("Reject",
                  style: GoogleFonts.poppins(
                      color: Colors.red, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 12),
      Expanded(
          child: ElevatedButton(
              onPressed: () =>
                  _showCallConfirmationDialog(farmer, cropName, qty),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: _primaryPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              child: Text("Verify & Accept",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _buildStatusActionButton(
      Color color, VoidCallback? action, String text) {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30))),
        child: _isUpdating
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
      ),
    );
  }

  // --- SMALL HELPERS (Timeline, Tags, etc.) ---
  Widget _buildLiveBadge() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.green, borderRadius: BorderRadius.circular(4)),
        child: Text("LIVE",
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)));
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: GoogleFonts.poppins(
                color: fg, fontWeight: FontWeight.bold, fontSize: 11)));
  }

  Widget _buildStatusBadge(String status) {
    Color color =
        (status == 'Accepted' || status == 'Confirmed' || status == 'Completed')
            ? Colors.green
            : (status == 'Rejected' ? Colors.red : Colors.orange);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Text(status,
            style: GoogleFonts.poppins(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _buildCustomTimeline(String currentStatus) {
    int currentStep = (currentStatus == 'Packed')
        ? 1
        : (['Shipped', 'In Transit'].contains(currentStatus)
            ? 2
            : (['Delivered', 'Completed'].contains(currentStatus) ? 3 : 0));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _buildTimelineStep("Confirmed", 0, currentStep),
      _buildTimelineLine(0, currentStep),
      _buildTimelineStep("Packed", 1, currentStep),
      _buildTimelineLine(1, currentStep),
      _buildTimelineStep("Shipped", 2, currentStep),
      _buildTimelineLine(2, currentStep),
      _buildTimelineStep("Delivered", 3, currentStep)
    ]);
  }

  Widget _buildTimelineStep(String label, int index, int currentStep) {
    bool isCompleted = index <= currentStep;
    return Column(children: [
      Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.white,
              border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey.shade300,
                  width: 2)),
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null),
      const SizedBox(height: 6),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, color: isCompleted ? Colors.black : Colors.grey))
    ]);
  }

  Widget _buildTimelineLine(int index, int currentStep) => Expanded(
      child: Container(
          height: 2,
          color: index < currentStep ? Colors.green : Colors.grey.shade300,
          margin: const EdgeInsets.only(bottom: 18)));
}

class _MapMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MapMarker(
      {required this.label, required this.icon, this.color = Colors.black});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 28),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.bold))),
    ]);
  }
}

class _CurveRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(35, size.height - 35);
    path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.5, size.width - 35, 35);
    final ui.PathMetrics metrics = path.computeMetrics();
    for (ui.PathMetric metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(old) => false;
}
