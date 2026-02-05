import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Razorpay _razorpay;

  // ⚠️ DEMO TIP: Use a Test Key if possible.
  static const String _razorpayKeyId = "rzp_live_S4uRpiziqgjHEH";

  Function(bool)? _onResult;
  BuildContext? _context;
  String? _currentAppOrderId;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// 🚀 CORE PROCESS:
  Future<void> processPayment({
    required BuildContext context,
    required String appOrderId,
    required String farmerId,
    required double amount, // Real Amount (e.g., 1,60,000)
    required Function(bool) onResult,
  }) async {
    _context = context;
    _currentAppOrderId = appOrderId;
    _onResult = onResult;

    // ✅ DEMO HACK: Force the actual payment to be ₹1.00
    // This allows testing the flow without paying the full crop price.
    double gatewayAmount = 1.0;

    try {
      // 1. CALL SUPABASE EDGE FUNCTION (Create Order for ₹1)
      final response = await _supabase.functions.invoke(
        'create-order',
        body: {
          'amount': gatewayAmount, // Send ₹1 to Gateway
          'farmer_id': farmerId,
        },
      );

      // 2. CHECK FOR BACKEND ERRORS
      if (response.status != 200) {
        throw "Backend Error: ${response.status}";
      }

      final data = response.data;
      if (data == null || data['id'] == null) {
        throw "Failed to generate Order ID from backend.";
      }

      // 3. EXTRACT RAZORPAY ORDER ID
      final String razorpayOrderId = data['id'];

      // 4. LAUNCH RAZORPAY CHECKOUT
      final user = _supabase.auth.currentUser;

      var options = {
        'key': _razorpayKeyId,
        'amount': (gatewayAmount * 100).round(), // Razorpay sees 100 paise (₹1)
        'name': 'AgriYukt',
        'description': 'Order #$appOrderId',
        'order_id': razorpayOrderId,
        'retry': {'enabled': true, 'max_count': 1},
        'prefill': {
          'contact': user?.phone ?? '9876543210',
          'email': user?.email ?? 'buyer@agriyukt.com',
        },
        'notes': {
          'app_order_id': appOrderId,
          'farmer_id': farmerId,
          'real_amount_display': amount,
          'type': 'agriyukt_demo'
        },
        'theme': {'color': '#2E7D32'}
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint("❌ Payment Init Error: $e");
      _showSnack("Payment Init Failed: ${e.toString()}", isError: true);
      _onResult?.call(false);
    }
  }

  /// ✅ NEW LOGIC: Calls Database Function to Deduct Stock
  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_currentAppOrderId == null) return;

    try {
      debugPrint("✅ Razorpay Success. Updating Database...");

      // 🚀 CALL THE NEW SQL FUNCTION
      // This function:
      // 1. Checks if stock is available
      // 2. Deducts stock
      // 3. Updates order status to 'Paid'
      final rpcResponse = await _supabase.rpc('confirm_crop_purchase', params: {
        'p_order_id': _currentAppOrderId,
        'p_payment_id': response.paymentId
      });

      // Check result from SQL
      if (rpcResponse['success'] == true) {
        _showSnack("✅ Order Placed! Stock Updated.", isError: false);
        _onResult?.call(true);
      } else {
        // If SQL returns error (e.g. stock ran out during payment)
        _showSnack(
            "⚠️ Payment success, but stock update failed: ${rpcResponse['error']}",
            isError: true);

        // We still treat it as success for the UI flow, but log it.
        // In a real app, you might trigger an automatic refund here.
        _onResult?.call(true);
      }
    } catch (e) {
      debugPrint("❌ DB Update Error: $e");
      _showSnack("Order Placed, but server verification failed.",
          isError: true);
      _onResult?.call(true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Razorpay Error: ${response.code} - ${response.message}");
    _showSnack("Payment Failed: ${response.message}", isError: true);
    _onResult?.call(false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet Selected: ${response.walletName}");
    _showSnack("Redirecting to ${response.walletName}...", isError: false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
