import 'package:flutter/material.dart';
import '../create_account_controller.dart';
import '../widgets/input_field.dart';

class BasicDetailsTab extends StatelessWidget {
  final CreateAccountController controller;

  const BasicDetailsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Personal Information",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 15),

        // 1. Full Vertical Layout (No Rows)
        InputField(
            label: "First Name",
            controller: controller.firstNameCtrl,
            icon: Icons.person),
        const SizedBox(height: 15),

        // Optional Middle Name (We can reuse extraFieldCtrl or ignore it if not strictly needed in DB,
        // but for UI completeness I'll add a placeholder field here that doesn't bind to logic yet)
        const TextField(
          decoration: InputDecoration(
            labelText: "Middle Name (Optional)",
            prefixIcon: Icon(Icons.person_outline, color: Color(0xFF1B5E20)),
            filled: true,
            fillColor: Color(0xFFFAFAFA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 15),

        InputField(
            label: "Last Name",
            controller: controller.lastNameCtrl,
            icon: Icons.person),
        const SizedBox(height: 15),

        InputField(
            label: "Mobile Number",
            controller: controller.phoneCtrl,
            icon: Icons.phone,
            inputType: TextInputType.phone),

        // Only show passwords if OTP hasn't been sent yet
        if (!controller.isOtpSent) ...[
          const SizedBox(height: 15),
          InputField(
              label: "Password",
              controller: controller.passCtrl,
              icon: Icons.lock,
              isPassword: true),
          const SizedBox(height: 15),
          InputField(
              label: "Confirm Password",
              controller: controller.confirmPassCtrl,
              icon: Icons.lock_clock,
              isPassword: true),
        ]
      ],
    );
  }
}
