import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ Logic Imports
import 'package:agriyukt_app/features/common/screens/chat_screen.dart';
import 'package:agriyukt_app/features/common/services/payment_service.dart';
import 'package:agriyukt_app/features/farmer/screens/full_screen_tracking.dart';

class BuyerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? cropData;

  const BuyerOrderDetailScreen(
      {super.key, required this.orderId, this.cropData});

  @override
  State<BuyerOrderDetailScreen> createState() => _BuyerOrderDetailScreenState();
}

class _BuyerOrderDetailScreenState extends State<BuyerOrderDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = true;
  Map<String, dynamic>? _order;

  // GPS State
  StreamSubscription<Position>? _positionStream;
  bool _isSharing = false;
  double _progress = 0.0;

  // ✅ Payment Input Controller
  final TextEditingController _amountController = TextEditingController();

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _bgGrey = const Color(0xFFF4F7F6);

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  @override
  void dispose() {
    _stopSharingLocation();
    _paymentService.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 📦 DATA FETCHING
  // ---------------------------------------------------------------------------

  Future<void> _fetchOrderDetails() async {
    try {
      final data = await _supabase.from('orders').select('''
              *,
              farmer:profiles!farmer_id(first_name, last_name, phone, district, state, latitude, longitude),
              crop:crops!crop_id(image_url, crop_name, unit, variety, grade, harvest_date)
          ''').eq('id', widget.orderId).single();

      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
          _isSharing = data['is_sharing_location'] ?? false;

          String status = data['status'] ?? 'Pending';
          if (_isSharing && status != 'Completed' && status != 'Delivered') {
            _startSharingLocation();
          }
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🛰️ GPS LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _startSharingLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showSnack("Please enable GPS services.", Colors.red);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isSharing = true);

    try {
      Position initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updateDatabase(initialPos);
      _updateLocalProgress(initialPos);
    } catch (e) {
      debugPrint("GPS Error: $e");
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 10),
    ).listen((Position position) {
      _updateDatabase(position);
      _updateLocalProgress(position);
    });

    _showSnack("🔴 Live Sharing Active", Colors.green);
  }

  Future<void> _stopSharingLocation() async {
    await _positionStream?.cancel();
    _positionStream = null;
    if (mounted) setState(() => _isSharing = false);
    if (widget.orderId.isNotEmpty) {
      await _supabase
          .from('orders')
          .update({'is_sharing_location': false}).eq('id', widget.orderId);
    }
  }

  Future<void> _updateDatabase(Position pos) async {
    await _supabase.from('orders').update({
      'is_sharing_location': true,
      'buyer_lat': pos.latitude,
      'buyer_lng': pos.longitude,
    }).eq('id', widget.orderId);
  }

  void _updateLocalProgress(Position pos) {
    if (_order == null || _order!['farmer'] == null) return;
    final farmer = _order!['farmer'];
    double? farmLat = (farmer['latitude'] as num?)?.toDouble();
    double? farmLng = (farmer['longitude'] as num?)?.toDouble();

    if (farmLat == null || farmLng == null) return;

    double distMeters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, farmLat, farmLng);
    setState(() {
      _progress = (1.0 - (distMeters / 10000)).clamp(0.0, 1.0);
    });
  }

  // ---------------------------------------------------------------------------
  // 💰 PAYMENT LOGIC (35% Minimum Check)
  // ---------------------------------------------------------------------------

  void _triggerPayment(double totalAmount, double paidAmount) {
    double outstanding = totalAmount - paidAmount;
    // Calculate 35% Minimum
    double minPayment = totalAmount * 0.35;

    // If they haven't paid the advance yet, suggest min 35%. Else outstanding.
    double suggestedAmount =
        (paidAmount < minPayment) ? minPayment : outstanding;

    _amountController.text = suggestedAmount.toStringAsFixed(0);

    _showCustomPaymentDialog(totalAmount, outstanding, minPayment, paidAmount);
  }

  void _showCustomPaymentDialog(double totalOrderValue,
      double outstandingBalance, double minPayment, double currentPaid) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double inputAmount = double.tryParse(_amountController.text) ?? 0;
            double commission = inputAmount * 0.02; // 2%
            double totalPayable = inputAmount + commission;

            // ✅ VALIDATION LOGIC:
            // 1. Must be > 0
            // 2. Cannot exceed outstanding balance (+1 buffer)
            // 3. If paying advance (currentPaid == 0), must be >= 35% total
            bool isMinMet =
                (currentPaid > 0) || (inputAmount >= minPayment - 1.0);
            bool isMaxMet = inputAmount <= (outstandingBalance + 1.0);

            String? errorText;
            if (!isMinMet)
              errorText = "Min Advance: ₹${minPayment.toInt()} (35%)";
            if (!isMaxMet)
              errorText = "Max Payment: ₹${outstandingBalance.toInt()}";

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                  currentPaid == 0 ? "Pay Advance (Min 35%)" : "Pay Balance",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Order: ₹${totalOrderValue.toStringAsFixed(0)}",
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    Text("Remaining: ₹${outstandingBalance.toStringAsFixed(0)}",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 15),

                    // INPUT FIELD
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: "₹ ",
                        labelText: "Amount to Pay",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        errorText: errorText, // Shows min/max error
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),

                    const SizedBox(height: 15),
                    // BREAKDOWN CARD
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          _buildBillRow("Base Amount", inputAmount),
                          const SizedBox(height: 5),
                          _buildBillRow("Platform Fee (2%)", commission,
                              color: Colors.red),
                          const Divider(),
                          _buildBillRow("Total Charge", totalPayable,
                              isBold: true, fontSize: 16),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                  onPressed: (isMinMet && isMaxMet && inputAmount > 0)
                      ? () {
                          Navigator.pop(context);
                          _processActualPayment(inputAmount, totalPayable);
                        }
                      : null,
                  child: Text("Pay ₹${totalPayable.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBillRow(String label, double amount,
      {bool isBold = false, Color? color, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.black87)),
        Text("₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color ??
                    (isBold ? const Color(0xFF1565C0) : Colors.black))),
      ],
    );
  }

  void _processActualPayment(double principalAmount, double totalCharged) {
    // Current paid amount from DB
    double currentPaid = (_order!['advance_amount'] ?? 0).toDouble();
    double newTotalPaid = currentPaid + principalAmount;

    _paymentService.processPayment(
      context: context,
      appOrderId: widget.orderId,
      farmerId: _order!['farmer_id'],
      amount: totalCharged,
      onResult: (success) async {
        if (success) {
          // Update DB
          await _supabase.from('orders').update(
              {'advance_amount': newTotalPaid}).eq('id', widget.orderId);

          // Update local UI
          setState(() {
            if (_order != null) _order!['advance_amount'] = newTotalPaid;
          });

          _fetchOrderDetails();
          _showSnack("Payment Successful! Farmer Notified 🔔", Colors.green);
        }
      },
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)));
    if (date == null || !mounted) return;

    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null) return;

    final fullDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    await _supabase
        .from('orders')
        .update({'scheduled_pickup_time': fullDate.toIso8601String()}).eq(
            'id', widget.orderId);
    _fetchOrderDetails();
    _showSnack("Schedule Updated", Colors.green);
  }

  Future<void> _contactUser(String? phone) async {
    if (phone == null) return;
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _cancelOrder() async {
    await _supabase
        .from('orders')
        .update({'status': 'Cancelled'}).eq('id', widget.orderId);
    _showSnack("Order Cancelled", Colors.red);
    _fetchOrderDetails();
  }

  Future<void> _confirmReceipt() async {
    await _supabase
        .from('orders')
        .update({'status': 'Completed'}).eq('id', widget.orderId);
    _showSnack("Order Completed", Colors.green);
    _fetchOrderDetails();
  }

  // ---------------------------------------------------------------------------
  // 🖥️ UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
          backgroundColor: Color(0xFFF5F7FA),
          body: Center(child: CircularProgressIndicator()));
    if (_order == null)
      return const Scaffold(body: Center(child: Text("Order not found")));

    final farmer = _order!['farmer'] ?? {};
    final String farmerName =
        "${farmer['first_name'] ?? 'Farmer'} ${farmer['last_name'] ?? ''}"
            .trim();
    final String farmerLoc =
        "${farmer['district'] ?? ''}, ${farmer['state'] ?? ''}";

    final crop = _order!['crop'];
    String cropName = crop?['crop_name'] ?? _order!['crop_name'] ?? "Crop";
    // ✅ NEW DETAILS
    String variety = crop?['variety'] ?? 'Standard';
    String grade = crop?['grade'] ?? 'Standard';
    String harvestDate = "Available";
    if (crop != null && crop['harvest_date'] != null) {
      try {
        harvestDate =
            DateFormat('dd MMM').format(DateTime.parse(crop['harvest_date']));
      } catch (_) {}
    }

    String? rawImgUrl = crop?['image_url'];
    ImageProvider imgProvider;

    if (rawImgUrl != null && rawImgUrl.isNotEmpty) {
      if (rawImgUrl.startsWith('http')) {
        imgProvider = NetworkImage(rawImgUrl);
      } else {
        final publicUrl =
            _supabase.storage.from('crop_images').getPublicUrl(rawImgUrl);
        imgProvider = NetworkImage(publicUrl);
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    // Money Calculations
    final quantity = (_order!['quantity_kg'] ?? 0).toDouble();
    final price = (_order!['price_offered'] ?? 0).toDouble();
    final totalAmount = quantity * price;
    final advancePaid = (_order!['advance_amount'] ?? 0).toDouble();

    final scheduleTime = _order!['scheduled_pickup_time'];
    final scheduleText = scheduleTime != null
        ? DateFormat('dd MMM, hh:mm a')
            .format(DateTime.parse(scheduleTime).toLocal())
        : "Tap to Schedule";
    final deliveryOtp =
        (widget.orderId.hashCode.abs() % 9000 + 1000).toString();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('orders')
          .stream(primaryKey: ['id']).eq('id', widget.orderId),
      builder: (context, snapshot) {
        String status =
            _order!['tracking_status'] ?? _order!['status'] ?? 'Pending';
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          status = snapshot.data!.first['tracking_status'] ??
              snapshot.data!.first['status'] ??
              'Pending';
        }

        final isActive = status != 'Pending' &&
            status != 'Rejected' &&
            status != 'Cancelled';
        final isCompleted = status == 'Delivered' || status == 'Completed';

        // Payment Logic
        bool isFullyPaid = advancePaid >= (totalAmount - 1.0);

        if (isCompleted && _isSharing)
          Future.delayed(Duration.zero, _stopSharingLocation);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text("Order Details",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFFF5F7FA),
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context)),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(0, 10, 0, 260), // Edge to Edge
                  child: Column(
                    children: [
                      // 1. PRODUCT CARD (With Details)
                      _buildProductCard(cropName, variety, grade, harvestDate,
                          quantity, totalAmount, status, imgProvider),
                      const SizedBox(height: 12),

                      // 2. BREAKDOWN
                      _buildBreakdownCard(quantity, totalAmount, advancePaid),
                      const SizedBox(height: 12),

                      // Schedule
                      _buildScheduleCard(isActive, scheduleText),
                      const SizedBox(height: 12),

                      // Tracking & OTP
                      if (isActive) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 5)
                              ]),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Shipment Status",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  if (_isSharing && !isCompleted)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: const Text("LIVE",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold))),
                                ]),
                            const SizedBox(height: 20),
                            _buildCustomTimeline(status),
                            const SizedBox(height: 20),
                            if (!isCompleted) ...[
                              const Divider(),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.vpn_key,
                                      color: Colors.amber, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("DELIVERY OTP",
                                          style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey)),
                                      Text(deliveryOtp,
                                          style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2)),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 15),
                              _buildTrackingToggle(),
                              const SizedBox(height: 15),
                              _buildSimulationMap(),
                            ]
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Farmer Info
                      _buildFarmerCard(farmerName, farmerLoc, status),
                    ],
                  ),
                ),

                // ✅ BOTTOM FLOATING BAR (PAY ADVANCE)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -5))
                        ]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PAYMENT INFO BLOCK
                        if (isFullyPaid)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(
                                child: Text("ORDER FULLY PAID",
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green))),
                          ),

                        // ACTION BUTTON
                        if (status == 'Pending')
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _cancelOrder,
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              child: Text("Cancel Order",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 16)),
                            ),
                          )
                        else if (!isFullyPaid)
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _triggerPayment(totalAmount, advancePaid),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              icon: const Icon(Icons.payment,
                                  color: Colors.white),
                              // ✅ Dynamic Text
                              label: Text(
                                  advancePaid == 0
                                      ? "PAY ADVANCE (35%)"
                                      : "PAY BALANCE",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16)),
                            ),
                          )
                        else if (status == 'Shipped' || status == 'Delivered')
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _confirmReceipt,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              child: Text("Confirm Receipt",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16)),
                            ),
                          ),
                      ],
                    ),
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

  // ✅ IMPROVED HEADER: Includes Variety, Grade, Date
  Widget _buildProductCard(
      String name,
      String variety,
      String grade,
      String date,
      double qty,
      double amount,
      String status,
      ImageProvider img) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16), // Curved
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
          _buildStatusBadge(status)
        ]))
      ]),
    );
  }

  // ✅ RECEIPT STYLE BREAKDOWN
  Widget _buildBreakdownCard(double qty, double total, double paid) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        _row("Total Quantity", "$qty Kg"),
        const SizedBox(height: 8),
        _row("Total Price", "₹${NumberFormat('#,##0').format(total)}",
            isBold: true),
        const Divider(height: 24),
        _row("Paid Amount", "₹${NumberFormat('#,##0').format(paid)}",
            color: Colors.green),
        const SizedBox(height: 8),
        _row("Pending", "₹${NumberFormat('#,##0').format(total - paid)}",
            color: Colors.orange),
      ]),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
      Text(val,
          style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 15,
              color: color ?? Colors.black))
    ]);
  }

  Widget _buildScheduleCard(bool isActive, String text) {
    return GestureDetector(
      onTap: isActive ? _pickSchedule : null,
      child: Container(
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ]),
          const Spacer(),
          if (isActive) const Icon(Icons.edit, size: 18, color: Colors.blue)
        ]),
      ),
    );
  }

  Widget _buildTrackingToggle() {
    return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
            onPressed:
                _isSharing ? _stopSharingLocation : _startSharingLocation,
            icon: Icon(_isSharing ? Icons.stop : Icons.navigation,
                color: _isSharing ? Colors.red : Colors.blue),
            label: Text(_isSharing ? "Stop Sharing" : "Start Live GPS",
                style:
                    TextStyle(color: _isSharing ? Colors.red : Colors.blue))));
  }

  Widget _buildSimulationMap() {
    return GestureDetector(
      onTap: () {
        if (_isSharing)
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FullScreenTracking(orderId: widget.orderId)));
        else
          _showSnack("Start GPS first!", Colors.blue);
      },
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
              top: 45,
              child: _MapMarker(label: "You", icon: Icons.my_location)),
          const Positioned(
              right: 20,
              top: 45,
              child: _MapMarker(label: "Farm", icon: Icons.store)),
          AnimatedAlign(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              alignment: Alignment(ui.lerpDouble(-0.8, 0.8, _progress)!, 0),
              child: const Icon(Icons.local_shipping,
                  color: Colors.blueAccent, size: 30)),
        ]),
      ),
    );
  }

  Widget _buildFarmerCard(String name, String loc, String status) {
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Row(children: [
          CircleAvatar(
              radius: 24,
              backgroundColor: Colors.amber.shade100,
              child: Text(name.isNotEmpty ? name[0] : "F")),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Farmer • $loc",
                    style: const TextStyle(color: Colors.grey))
              ])),
          IconButton.filled(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatScreen(
                          targetUserId: _order!['farmer_id'],
                          targetName: name,
                          orderId: widget.orderId,
                          cropName: "Support",
                          orderStatus: status))),
              style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white)),
          const SizedBox(width: 10),
          IconButton.filled(
              onPressed: () => _contactUser(_order!['farmer']['phone']),
              style: IconButton.styleFrom(backgroundColor: Colors.blue),
              icon: const Icon(Icons.phone, color: Colors.white))
        ]));
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
            borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)));
  }

  Widget _buildCustomTimeline(String currentStatus) {
    int currentStep = (['Accepted', 'Confirmed'].contains(currentStatus))
        ? 0
        : (currentStatus == 'Packed')
            ? 1
            : (['Shipped', 'In Transit'].contains(currentStatus))
                ? 2
                : (['Delivered', 'Completed'].contains(currentStatus))
                    ? 3
                    : 0;
    return Row(children: [
      _step("Confirmed", 0, currentStep),
      _line(0, currentStep),
      _step("Packed", 1, currentStep),
      _line(1, currentStep),
      _step("Shipped", 2, currentStep),
      _line(2, currentStep),
      _step("Delivered", 3, currentStep)
    ]);
  }

  Widget _step(String label, int idx, int curr) {
    bool done = idx <= curr;
    return Column(children: [
      Icon(Icons.check_circle,
          color: done ? Colors.green : Colors.grey.shade300, size: 24),
      const SizedBox(height: 4),
      Text(label,
          style:
              TextStyle(fontSize: 10, color: done ? Colors.black : Colors.grey))
    ]);
  }

  Widget _line(int idx, int curr) {
    return Expanded(
        child: Container(
            height: 2,
            color: idx < curr ? Colors.green : Colors.grey.shade300,
            margin: const EdgeInsets.only(bottom: 20)));
  }
}

class _MapMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MapMarker({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.grey[700], size: 24),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
    ]);
  }
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
