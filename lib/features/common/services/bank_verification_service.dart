import 'dart:convert';
import 'package:http/http.dart' as http;

class BankVerificationService {
  // --- RULE 1: LOCAL SYNTAX VALIDATION (Free & Instant) ---

  static String? validateSyntax(String ifsc, String accountNumber) {
    // 1. Validate IFSC Format (4 letters, 0, 6 alphanumeric)
    RegExp ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(ifsc.toUpperCase())) {
      return "Invalid IFSC Code format.";
    }

    // 2. Validate Account Number (9-18 digits, numbers only)
    RegExp accRegex = RegExp(r'^\d{9,18}$');
    if (!accRegex.hasMatch(accountNumber)) {
      return "Invalid Account Number format.";
    }

    return null; // No errors
  }

  // --- RULE 2: API VERIFICATION (The "Penny Drop") ---

  /// verifying the account exists and getting the real owner's name.
  static Future<Map<String, dynamic>> verifyBankAccount(
      {required String ifsc,
      required String accountNumber,
      required String farmerName}) async {
    // 🚨 REAL WORLD: You would call Razorpay/Cashfree API here.
    // URL: https://api.razorpay.com/v1/fund_accounts/validation

    // MOCK SIMULATION (For your current testing)
    await Future.delayed(const Duration(seconds: 2)); // Simulate API delay

    // Rule: Reject specific "Test" numbers to test failure scenarios
    if (accountNumber.endsWith("000")) {
      return {'isValid': false, 'message': 'Bank rejected the account.'};
    }

    // Rule: Simulate a Name Match Check
    // In real API, the bank sends back "RAM KUMAR". You compare with "Ram Kumar".
    // We simulate a successful match here:
    return {
      'isValid': true,
      'registered_name':
          farmerName.toUpperCase(), // Bank usually returns uppercase
      'message': 'Account Verified Successfully'
    };
  }
}
