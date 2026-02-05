import 'package:flutter/material.dart';
import '../../widgets/input_field.dart';

class BuyerTab extends StatelessWidget {
  final TextEditingController companyNameController;
  final TextEditingController buyerTypeController;
  final TextEditingController gstController;

  const BuyerTab({
    super.key,
    required this.companyNameController,
    required this.buyerTypeController,
    required this.gstController,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> buyerTypes = [
      'Wholesaler',
      'Retailer',
      'Mill / Processor',
      'Exporter',
      'Trader',
    ];

    return Column(
      children: [
        // Company / Shop Name
        InputField(
          controller: companyNameController,
          label: 'Company / Shop Name',
          icon: Icons.store,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter company name';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Buyer Type Dropdown
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Buyer Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.category),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: buyerTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            buyerTypeController.text = value ?? '';
          },
          validator: (value) => value == null ? 'Please select buyer type' : null,
        ),
        const SizedBox(height: 16),

        // GST Number (Optional)
        InputField(
          controller: gstController,
          label: 'GST Number (Optional)',
          icon: Icons.receipt_long,
          validator: (value) => null, // Optional
        ),
      ],
    );
  }
}