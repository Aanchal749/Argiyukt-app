import 'package:flutter/material.dart';
import '../../widgets/input_field.dart'; // Adjust path if needed

class FarmerTab extends StatelessWidget {
  final TextEditingController acresController;

  const FarmerTab({
    super.key,
    required this.acresController,
  });

  @override
  Widget build(BuildContext context) {
    // List of Acre Ranges
    final List<String> acreRanges = [
      'Less than 2 acres',
      '2 - 5 acres',
      '5 - 10 acres',
      '10 - 20 acres',
      'More than 20 acres',
    ];

    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Farm Size (Acres)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.landscape),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: acreRanges.map((String range) {
            return DropdownMenuItem<String>(
              value: range,
              child: Text(range),
            );
          }).toList(),
          onChanged: (value) {
            acresController.text = value ?? '';
          },
          validator: (value) =>
              value == null ? 'Please select farm size' : null,
        ),
      ],
    );
  }
}
