import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agriyukt_app/features/common/screens/verification_screen.dart';

class VerificationGuard {
  /// Checks if the current user is verified.
  /// If Verified -> Executes the [onVerified] function.
  /// If Not -> Shows a dialog blocking the action.
  static Future<void> check(
      BuildContext context, VoidCallback onVerified) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Check Database Status
    final data = await Supabase.instance.client
        .from('profiles')
        .select('verification_status')
        .eq('id', user.id)
        .maybeSingle();

    final status = data?['verification_status'] ?? 'Not Uploaded';

    if (status == 'Verified') {
      // ✅ SUCCESS: Run the action
      onVerified();
    } else {
      // ❌ BLOCKED: Show Alert
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Verification Required 🔒"),
            content: Text(status == 'Pending'
                ? "Your document is Pending verification. Please wait for approval before performing this action."
                : "You must verify your identity with Aadhar Card to use this feature."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Redirect to Verification Screen
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VerificationScreen()));
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                child: const Text("Verify Now",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }
}
