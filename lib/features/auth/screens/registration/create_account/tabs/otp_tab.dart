import 'package:flutter/material.dart';
import '../create_account_controller.dart';

class OtpTab extends StatelessWidget {
  final CreateAccountController controller;
  final VoidCallback onAction;

  const OtpTab({super.key, required this.controller, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (controller.isOtpSent) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B5E20)),
            ),
            child: Column(
              children: [
                const Text("Enter Verification Code",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const SizedBox(height: 10),
                TextField(
                  controller: controller.otpCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 5,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "000000",
                    border: InputBorder.none,
                    counterText: "",
                  ),
                ),
                const Text("Demo OTP: 123456",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Action Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: controller.isLoading ? null : onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: controller.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    controller.isOtpSent ? "VERIFY & REGISTER" : "GET OTP",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
