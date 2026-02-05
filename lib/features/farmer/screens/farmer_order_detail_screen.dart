import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // ✅ Added for Localization
import 'package:agriyukt_app/features/common/screens/chat_screen.dart';
import 'full_screen_tracking.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class FarmerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const FarmerOrderDetailScreen({super.key, required this.orderId});

  @override
  State<FarmerOrderDetailScreen> createState() =>
      _FarmerOrderDetailScreenState();
}

class _FarmerOrderDetailScreenState extends State<FarmerOrderDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _order;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // ✅ Helper for Localized Text
  String _text(String key) => FarmerText.get(context, key);

  Future<void> _fetchOrderDetails() async {
    try {
      final data = await _supabase.from('orders').select('''
              *,
              buyer:profiles!buyer_id(id, first_name, last_name, phone, district, state),
              farmer:profiles!farmer_id(latitude, longitude),
              crop:crops!crop_id(image_url, crop_name)
          ''').eq('id', widget.orderId).single();

      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching: $e");
      if (mounted) {
        try {
          final simpleData = await _supabase
              .from('orders')
              .select()
              .eq('id', widget.orderId)
              .single();
          setState(() {
            _order = simpleData;
            _isLoading = false;
          });
        } catch (e2) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    // 1. Calculate the new main status
    String mainStatus = (newStatus == 'Rejected')
        ? 'Rejected'
        : (newStatus == 'Completed' ? 'Completed' : 'Accepted');

    // 2. OPTIMISTIC UPDATE: Update UI Immediately!
    setState(() {
      _isUpdating = true;
      if (_order != null) {
        _order!['status'] = mainStatus;
        _order!['tracking_status'] = newStatus;
        if (newStatus == 'Completed') {
          _order!['is_sharing_location'] = false;
        }
      }
    });

    try {
      // 3. Perform DB Update in Background
      // 👉 STOCK UPDATION LOGIC HAPPENS HERE VIA DB TRIGGER
      // If stock is insufficient, this line will throw an error
      await _supabase.from('orders').update({
        'status': mainStatus,
        'tracking_status': newStatus,
        if (newStatus == 'Completed') 'is_sharing_location': false
      }).eq('id', widget.orderId);

      if (mounted) {
        // 4. Show Success
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${_text('status_updated')}: $newStatus",
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green));

        // 5. Fetch fresh data just to be safe
        await _fetchOrderDetails();
      }
    } catch (e) {
      debugPrint("Update Error: $e");

      // 👉 STOCK ERROR HANDLING: If DB refuses due to low stock, revert UI & Alert User
      if (mounted) {
        String errorMsg = "Update failed. Please check connection.";
        if (e.toString().contains("Insufficient Stock") ||
            e.toString().contains("insufficient stock")) {
          errorMsg = "Cannot Accept: Insufficient Stock in Inventory!";
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Action Failed",
                style: TextStyle(color: Colors.red)),
            content: Text(errorMsg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      }

      // Revert changes by re-fetching
      _fetchOrderDetails();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_text('verify_delivery_title'), // ✅ LOCALIZED
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_text('otp_instruction'), // ✅ LOCALIZED
                style: GoogleFonts.poppins()),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(_text('cancel'))), // ✅ LOCALIZED
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyOtp();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(_text('verify'), // ✅ LOCALIZED
                style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _verifyOtp() {
    final String expectedOtp =
        (widget.orderId.hashCode.abs() % 9000 + 1000).toString();
    if (_otpController.text.trim() == expectedOtp) {
      _updateStatus('Completed');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ ${_text('incorrect_otp')}"), // ✅ LOCALIZED
          backgroundColor: Colors.red));
    }
    _otpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null)
      return Scaffold(
          body: Center(child: Text(_text('order_not_found')))); // ✅ LOCALIZED

    final buyer = _order!['buyer'] ?? {};
    final farmer = _order!['farmer'] ?? {};
    final buyerName =
        "${buyer['first_name'] ?? 'Buyer'} ${buyer['last_name'] ?? ''}".trim();
    final buyerLoc = "${buyer['district'] ?? ''}, ${buyer['state'] ?? ''}";
    final crop = _order!['crop'];
    String cropName =
        crop?['crop_name'] ?? _order!['crop_name'] ?? "Unknown Crop";
    String? imgUrl = crop?['image_url'];

    // ✅ ROBUST IMAGE LOGIC (Copied from OrdersScreen)
    ImageProvider imgProvider;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http')) {
        imgProvider = NetworkImage(imgUrl);
      } else {
        try {
          final fullUrl =
              _supabase.storage.from('crop_images').getPublicUrl(imgUrl);
          imgProvider = NetworkImage(fullUrl);
        } catch (e) {
          imgProvider = const AssetImage('assets/images/placeholder_crop.png');
        }
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    final status = _order!['tracking_status'] ?? _order!['status'] ?? 'Pending';
    final quantity = (_order!['quantity_kg'] ?? 0).toDouble();
    final price = (_order!['price_offered'] ?? 0).toDouble();
    final totalAmount = quantity * price;

    final scheduleText = _order!['scheduled_pickup_time'] != null
        ? DateFormat('dd MMM, hh:mm a')
            .format(DateTime.parse(_order!['scheduled_pickup_time']).toLocal())
        : _text('not_scheduled'); // ✅ LOCALIZED

    // Action Button Logic
    String btnText = _text('order_completed_btn'); // ✅ LOCALIZED
    Color btnColor = Colors.grey;
    VoidCallback? btnAction;
    if (status == 'Pending' || status == 'Ordered') {
      btnText = _text('accept'); // ✅ LOCALIZED
      btnAction = () => _updateStatus('Accepted');
      btnColor = Colors.blue;
    } else if (status == 'Accepted') {
      btnText = _text('mark_packed'); // ✅ LOCALIZED
      btnAction = () => _updateStatus('Packed');
      btnColor = Colors.orange;
    } else if (status == 'Packed') {
      btnText = _text('start_shipping'); // ✅ LOCALIZED
      btnAction = () => _updateStatus('Shipped');
      btnColor = Colors.deepOrange;
    } else if (status == 'Shipped' || status == 'In Transit') {
      btnText = _text('verify_delivery_btn'); // ✅ LOCALIZED
      btnAction = _showOtpDialog;
      btnColor = Colors.green;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(children: [
          Text(_text('manage_order'), // ✅ LOCALIZED
              style: GoogleFonts.poppins(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          Text(
              "${_text('order')} #${widget.orderId.substring(0, 5).toUpperCase()}", // ✅ LOCALIZED
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
        ]),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  16, 10, 16, 120), // Increased bottom padding for floating bar
              child: Column(
                children: [
                  _buildCropHeader(
                      imgProvider, cropName, totalAmount, status, langCode),
                  const SizedBox(height: 16),
                  _buildBreakdownCard(quantity, totalAmount),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('orders')
                        .stream(primaryKey: ['id']).eq('id', widget.orderId),
                    builder: (context, snapshot) {
                      final orderData =
                          (snapshot.hasData && snapshot.data!.isNotEmpty)
                              ? snapshot.data!.first
                              : _order!;
                      final isSharing =
                          orderData['is_sharing_location'] ?? false;
                      final double fLat =
                          (farmer['latitude'] as num?)?.toDouble() ?? 0.0;
                      final double fLng =
                          (farmer['longitude'] as num?)?.toDouble() ?? 0.0;
                      final double? bLat =
                          (orderData['buyer_lat'] as num?)?.toDouble();
                      final double? bLng =
                          (orderData['buyer_lng'] as num?)?.toDouble();

                      return Container(
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
                              // ✅ FIXED: Wrapped in Expanded to prevent horizontal overflow
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        _text(
                                            'scheduled_pickup'), // ✅ LOCALIZED
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey, fontSize: 12)),
                                    Text(scheduleText,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _buildCustomTimeline(status),
                            const SizedBox(height: 20),

                            // Map Preview
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => FullScreenTracking(
                                          orderId: widget.orderId))),
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9)
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade300)),
                                child: Stack(children: [
                                  Positioned.fill(
                                      child: CustomPaint(
                                          painter: _CurveRoutePainter())),
                                  Positioned(
                                      left: 20,
                                      bottom: 30,
                                      child: _MapMarker(
                                          label: _text('farm'), // ✅ LOCALIZED
                                          icon: Icons.store,
                                          color: Colors.brown)),
                                  Positioned(
                                      right: 20,
                                      top: 30,
                                      child: _MapMarker(
                                          label: _text('buyer'), // ✅ LOCALIZED
                                          icon: Icons.person_pin_circle,
                                          color: Colors.orange)),
                                  if (isSharing && bLat != null && bLng != null)
                                    Builder(builder: (context) {
                                      double dist = Geolocator.distanceBetween(
                                          fLat, fLng, bLat, bLng);
                                      double prog =
                                          (1.0 - (dist / 5000)).clamp(0.0, 1.0);
                                      return AnimatedAlign(
                                        duration: const Duration(seconds: 1),
                                        alignment: Alignment(
                                            ui.lerpDouble(-0.8, 0.8, prog)!,
                                            ui.lerpDouble(0.5, -0.5, prog)!),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.local_shipping,
                                              color: Colors.blue,
                                              size: 20),
                                        ),
                                      );
                                    }),
                                  const Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: Icon(Icons.fullscreen,
                                          size: 18, color: Colors.grey)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildBuyerInfoCard(buyerName, buyerLoc, status, cropName,
                      _order!['buyer_id']),
                ],
              ),
            ),

            // Bottom Action Bar
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
                child: status == 'Pending'
                    ? _buildAcceptRejectRow()
                    : _buildStatusActionButton(btnColor, btnAction, btnText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildCropHeader(ImageProvider img, String name, double amount,
      String status, String langCode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                height: 70,
                width: 70,
                child: Image(image: img, fit: BoxFit.cover))),
        const SizedBox(width: 12),
        // ✅ Keep Expanded
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ✅ DYNAMIC TRANSLATION for Crop Name
            FutureBuilder<String>(
              future: TranslationService.toLocal(name, langCode),
              initialData: name,
              builder: (context, snapshot) => Text(
                snapshot.data ?? name,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag("₹${NumberFormat('#,##0').format(amount)}",
                    Colors.orange.shade50, Colors.orange.shade800),
                // ✅ DYNAMIC TRANSLATION for Status
                FutureBuilder<String>(
                  future: TranslationService.toLocal(status, langCode),
                  initialData: status,
                  builder: (context, snapshot) =>
                      _buildStatusBadge(snapshot.data ?? status),
                ),
              ],
            )
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
          Text(_text('quantity'), // ✅ LOCALIZED "Total Quantity"
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
          Text("$qty ${_text('kg')}", // ✅ LOCALIZED "Kg"
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold))
        ]),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_text('total'), // ✅ LOCALIZED "Total Price"
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
          Text("₹${NumberFormat('#,##0').format(total)}",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ]),
    );
  }

  Widget _buildBuyerInfoCard(
      String name, String loc, String status, String crop, String buyerId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade50,
            child: Text(name.isNotEmpty ? name[0] : "B",
                style: GoogleFonts.poppins(
                    color: Colors.blue.shade800, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis),
          Text("${_text('buyer')} • $loc", // ✅ LOCALIZED "Buyer"
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ])),
        IconButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      targetUserId: buyerId,
                      targetName: name,
                      orderId: widget.orderId,
                      cropName: crop,
                      orderStatus: status))),
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
        )
      ]),
    );
  }

  Widget _buildAcceptRejectRow() {
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed: () => _updateStatus('Rejected'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              child: Text(_text('reject'), // ✅ LOCALIZED "Reject"
                  style: GoogleFonts.poppins(
                      color: Colors.red, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 12),
      Expanded(
          child: ElevatedButton(
              onPressed: () => _updateStatus('Accepted'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
              child: Text(_text('accept'), // ✅ LOCALIZED "Accept"
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _buildStatusActionButton(
      Color color, VoidCallback? action, String text) {
    return SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
            onPressed: action,
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(text,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold))));
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
      _buildTimelineStep(_text('confirmed'), 0, currentStep), // ✅ "Confirmed"
      _buildTimelineLine(0, currentStep),
      _buildTimelineStep(_text('packed'), 1, currentStep), // ✅ "Packed"
      _buildTimelineLine(1, currentStep),
      _buildTimelineStep(_text('shipped'), 2, currentStep), // ✅ "Shipped"
      _buildTimelineLine(2, currentStep),
      _buildTimelineStep(_text('delivered'), 3, currentStep) // ✅ "Delivered"
    ]);
  }

  Widget _buildTimelineStep(String label, int index, int currentStep) {
    bool isCompleted = index <= currentStep;
    return Column(children: [
      Container(
          height: 20,
          width: 20,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.white,
              border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey.shade300,
                  width: 2)),
          child: isCompleted
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null),
      const SizedBox(height: 4),
      // ✅ Use SizedBox to control label width
      SizedBox(
          width: 50,
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isCompleted ? Colors.black : Colors.grey))),
    ]);
  }

  Widget _buildTimelineLine(int index, int currentStep) {
    return Expanded(
        child: Container(
            height: 2,
            color: index < currentStep ? Colors.green : Colors.grey.shade300,
            margin: const EdgeInsets.only(bottom: 14)));
  }
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
      Icon(icon, color: color, size: 24),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 8, fontWeight: FontWeight.bold))),
    ]);
  }
}

class _CurveRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
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
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(old) => false;
}
