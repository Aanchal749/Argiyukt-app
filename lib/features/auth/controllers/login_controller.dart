import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController extends ChangeNotifier {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLoading = false;

  Future<void> login(BuildContext context) async {
    String input = emailCtrl.text.trim();
    // Logic: Convert 10-digit number to dummy email for Supabase compatibility
    String finalEmail = input.contains('@') ? input : "$input@agriyukt.com";

    isLoading = true;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: finalEmail,
        password: passCtrl.text.trim(),
      );

      if (response.user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .single();

        String role = profile['role'];
        if (context.mounted)
          Navigator.pushReplacementNamed(context, '/$role-dashboard');
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
