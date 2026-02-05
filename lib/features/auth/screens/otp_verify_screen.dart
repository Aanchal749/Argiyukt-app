import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
// import 'register_details_screen.dart'; // Next Step (Signup)
// import 'reset_password_screen.dart'; // Next Step (Reset)

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isPasswordReset;

  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.isPasswordReset,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _verify() async {
    setState(() => _isLoading = true);

    bool isValid = await _authService.verifyOTP(_otpController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Verified Successfully!")));

      // LOGIC FOR NEXT STEP
      if (widget.isPasswordReset) {
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResetPasswordScreen()));
        print("Go to Reset Password Screen");
      } else {
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RegisterDetailsScreen()));
        print("Go to Register Form");
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ Invalid OTP")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text("OTP sent to +91 ${widget.phoneNumber}"),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 5),
              decoration: const InputDecoration(
                hintText: "______",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify & Proceed"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
