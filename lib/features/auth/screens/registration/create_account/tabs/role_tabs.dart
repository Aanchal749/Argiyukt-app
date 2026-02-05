import 'package:flutter/material.dart';

class RoleTabs extends StatelessWidget {
  final String selectedRole;
  final Function(String) onRoleChanged;

  const RoleTabs(
      {super.key, required this.selectedRole, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildTab("Farmer", Icons.agriculture, "farmer"),
        const SizedBox(width: 10),
        _buildTab("Buyer", Icons.store, "buyer"),
        const SizedBox(width: 10),
        _buildTab("Inspector", Icons.verified_user, "inspector"),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, String roleKey) {
    bool isSelected = selectedRole == roleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => onRoleChanged(roleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : Colors.grey[100],
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF1B5E20)
                    : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? const Color(0xFF1B5E20) : Colors.grey),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? const Color(0xFF1B5E20) : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
