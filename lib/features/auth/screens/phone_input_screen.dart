import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'otp_verify_screen.dart'; // We will create this next

class PhoneInputScreen extends StatefulWidget {
  final bool isPasswordReset; // True = Forgot Password, False = Sign Up

  const PhoneInputScreen({super.key, required this.isPasswordReset});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _sendOTP() {
    String phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Enter a valid 10-digit number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    _authService.sendOTP(
      phoneNumber: phone,
      onCodeSent: () {
        setState(() => _isLoading = false);
        // Navigate to OTP Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerifyScreen(
              phoneNumber: phone,
              isPasswordReset: widget.isPasswordReset,
            ),
          ),
        );
      },
      onError: (error) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $error")),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isPasswordReset ? "Reset Password" : "Create Account";
    String subtitle = widget.isPasswordReset
        ? "Enter your number to receive a reset code."
        : "Enter your number to register.";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(subtitle,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                prefixText: "+91 ",
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOTP,
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
