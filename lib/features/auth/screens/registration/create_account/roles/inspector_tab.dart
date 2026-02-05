import 'package:flutter/material.dart';
import '../../widgets/input_field.dart';

class InspectorTab extends StatelessWidget {
  final TextEditingController orgController;
  final TextEditingController employeeIdController;

  const InspectorTab({
    super.key,
    required this.orgController,
    required this.employeeIdController,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> organizations = [
      'Government Agriculture Dept',
      'Private Quality Council',
      'FPO Federation',
      'Organic Certification Body',
      'Independent Surveyor',
      'Other',
    ];

    return Column(
      children: [
        // Department / Organization Dropdown
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Department / Organization',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.business),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: organizations.map((String org) {
            return DropdownMenuItem<String>(
              value: org,
              child: Text(org),
            );
          }).toList(),
          onChanged: (value) {
            orgController.text = value ?? '';
          },
          validator: (value) =>
              value == null ? 'Please select an organization' : null,
        ),
        const SizedBox(height: 16),

        // Employee ID (Optional)
        InputField(
          controller: employeeIdController,
          label: 'Employee ID (Optional)',
          icon: Icons.badge,
          validator: (value) => null, // No validation needed as it is optional
        ),
      ],
    );
  }
}
