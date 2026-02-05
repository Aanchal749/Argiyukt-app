// lib/features/auth/screens/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _subVillageController = TextEditingController();

  // Toggle for the optional tab
  bool _showSubVillage = false;
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final subVillage = _subVillageController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Backend Fix: Use correct signUp with redirect and metadata
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo:
            'io.supabase.flutterquickstart://login-callback', // Important for deep linking
        data: {
          'sub_village': _showSubVillage
              ? subVillage
              : null, // Adds sub-village if enabled
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registration Successful! Check your email.'),
              backgroundColor: Colors.green),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Mobile Layout Fix: Center + ConstrainedBox
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // This 'maxWidth' ensures the UI looks like a mobile app even on web/desktop
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.agriculture,
                        size: 60, color: Colors.green),
                    const SizedBox(height: 10),
                    const Text(
                      "AgriYukt Register",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 3. Optional Sub-Village Tab
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _showSubVillage = !_showSubVillage),
                          icon: Icon(_showSubVillage
                              ? Icons.remove_circle
                              : Icons.add_circle),
                          label: Text(_showSubVillage
                              ? "Remove Sub-Village"
                              : "Add Sub-Village (Optional)"),
                        ),
                      ],
                    ),

                    if (_showSubVillage) ...[
                      const SizedBox(height: 5),
                      TextField(
                        controller: _subVillageController,
                        decoration: InputDecoration(
                          labelText: 'Sub-Village Name',
                          filled: true,
                          fillColor: Colors.green[50],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.home_work),
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Create Account",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
