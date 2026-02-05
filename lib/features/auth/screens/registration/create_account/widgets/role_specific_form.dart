import 'package:flutter/material.dart';
import 'package:agriyukt_app/features/auth/controllers/registration_controller.dart';

class RoleSpecificForm extends StatelessWidget {
  final RegistrationController ctrl;
  const RoleSpecificForm({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            ctrl.getStr('additional_info'),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
        if (ctrl.selectedRole.toLowerCase() == 'farmer') _buildFarmerForm(),
        if (ctrl.selectedRole.toLowerCase() == 'inspector')
          _buildInspectorForm(),
        if (ctrl.selectedRole.toLowerCase() == 'buyer') _buildBuyerForm(),
      ],
    );
  }

  // Farmer Form
  Widget _buildFarmerForm() {
    return Column(
      children: [
        _dd(
            ctrl.getStr('farmer_type'),
            ctrl.farmerType,
            [
              "Self farmer",
              "Family member involved in farming",
              "Tenant farmer (leased land)",
              "Contract farmer"
            ],
            (v) => ctrl.setFarmerType(v)),
        _dd(
            ctrl.getStr('land_size'),
            ctrl.landSize,
            [
              "Less than 1 acre",
              "1 – 2 acres",
              "2 – 5 acres",
              "5 – 10 acres",
              "More than 10 acres"
            ],
            (v) => ctrl.setLandSize(v)),
        const SizedBox(height: 10),
        Text(ctrl.getStr('farming_type'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: [
            "Crop farming",
            "Horticulture",
            "Dairy",
            "Poultry",
            "Fisheries",
            "Organic farming"
          ].map((type) {
            bool isSelected = ctrl.selectedFarmingTypes.contains(type);
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) => ctrl.toggleFarmingType(type),
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green,
            );
          }).toList(),
        ),
      ],
    );
  }

  // Inspector Form
  Widget _buildInspectorForm() {
    return Column(
      children: [
        _dd(
            ctrl.getStr('inspector_cat'),
            ctrl.inspectorCategory,
            [
              "Government employee",
              "Contract inspector",
              "Student intern",
              "Part-time field worker"
            ],
            (v) => ctrl.setInspectorCategory(v)),
        _dd(
            ctrl.getStr('emp_type'),
            ctrl.employmentType,
            ["Full-time", "Part-time", "Internship"],
            (v) => ctrl.setEmploymentType(v)),
        const SizedBox(height: 10),
        _txt(ctrl.orgNameCtrl, ctrl.getStr('dept_org')),
        if (ctrl.inspectorCategory != "Student intern")
          _txt(ctrl.empIdCtrl, "${ctrl.getStr('emp_id')} *"),
        if (ctrl.inspectorCategory == "Student intern")
          _txt(ctrl.empIdCtrl, "${ctrl.getStr('emp_id')} (Optional)"),
      ],
    );
  }

  // Buyer Form
  Widget _buildBuyerForm() {
    return Column(
      children: [
        _dd(
            ctrl.getStr('buyer_type'),
            ctrl.buyerType,
            [
              "Small buyer (local mandi)",
              "Trader / middleman",
              "Wholesaler",
              "Retailer",
              "Exporter"
            ],
            (v) => ctrl.setBuyerType(v)),
        _dd(
            ctrl.getStr('business_type'),
            ctrl.businessType,
            [
              "Individual",
              "Proprietorship",
              "Partnership",
              "Pvt Ltd",
              "Cooperative"
            ],
            (v) => ctrl.setBusinessType(v)),
        const SizedBox(height: 10),
        if (["Wholesaler", "Exporter", "Pvt Ltd"].contains(ctrl.buyerType) ||
            ["Pvt Ltd"].contains(ctrl.businessType))
          _txt(ctrl.gstCtrl, "${ctrl.getStr('gst_no')} *")
        else
          _txt(ctrl.gstCtrl, "${ctrl.getStr('gst_no')} (Optional)"),
      ],
    );
  }

  Widget _dd(String label, String? val, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: val,
        isExpanded: true,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      ),
    );
  }

  Widget _txt(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
          controller: c,
          decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
    );
  }
}
