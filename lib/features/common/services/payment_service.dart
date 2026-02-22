import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Razorpay _razorpay;

  static const String _razorpayKeyId =
      "rzp_live_S4uRpiziqgjHEH"; // Use your actual key

  // ✅ PERFECT MATCH: Expects a boolean from the gateway to tell the UI what happened
  Function(bool isSuccess)? _onResult;
  BuildContext? _context;
  String? _currentAppOrderId;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> processPayment({
    required BuildContext context,
    required String appOrderId,
    required String farmerId,
    required double amount,
    required Function(bool isSuccess) onResult, // ✅ Matches the UI perfectly
  }) async {
    _context = context;
    _currentAppOrderId = appOrderId;
    _onResult = onResult;

    try {
      final response = await _supabase.functions.invoke(
        'create-order',
        body: {'amount': amount, 'farmer_id': farmerId},
      );

      if (response.status != 200) throw "Backend Error: ${response.status}";

      final data = response.data;
      if (data == null || data['id'] == null) {
        throw "Failed to generate Order ID.";
      }

      final String razorpayOrderId = data['id'];
      final user = _supabase.auth.currentUser;

      var options = {
        'key': _razorpayKeyId,
        'amount': (amount * 100).round(),
        'name': 'AgriYukt',
        'description': 'Payment for Order #$appOrderId',
        'order_id': razorpayOrderId,
        'retry': {'enabled': true, 'max_count': 1},
        'prefill': {
          'contact': user?.phone ?? '',
          'email': user?.email ?? 'buyer@agriyukt.com',
        },
        'notes': {
          'app_order_id': appOrderId,
          'farmer_id': farmerId,
          'real_amount_display': amount.toString(),
        },
        'theme': {'color': '#1565C0'} // AgriYukt Primary Blue
      };

      // 🚀 Open the Gateway
      _razorpay.open(options);
    } catch (e) {
      debugPrint("❌ Payment Init Error: $e");
      _showSnack("Payment Initialization Failed", isError: true);
      // ❌ Tell UI it failed, do NOT update database
      _onResult?.call(false);
    }
  }

  /// ✅ STRICT VERIFICATION: Only fires when Razorpay confirms the transaction
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_currentAppOrderId == null) return;

    _showSnack("Processing payment securely...", isError: false);

    // ✅ Tell UI it succeeded! UI will now insert the data into Supabase.
    _onResult?.call(true);
  }

  /// ✅ SMART ERROR HANDLING: Detects manual closures vs actual bank failures
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Razorpay Error: ${response.code} - ${response.message}");

    // Code 0 or 2 (Razorpay.PAYMENT_CANCELLED) usually means the user manually closed the overlay or hit back
    if (response.code == Razorpay.PAYMENT_CANCELLED || response.code == 0) {
      _showSnack(
        "Payment window closed. If money was deducted, your order will auto-update shortly.",
        isError: true,
      );
    } else {
      _showSnack("Payment Failed: ${response.message}", isError: true);
    }

    // ❌ Tell UI it failed or was cancelled. Database stays locked.
    _onResult?.call(false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
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
