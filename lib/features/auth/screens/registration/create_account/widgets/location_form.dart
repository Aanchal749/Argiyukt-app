import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agriyukt_app/features/auth/controllers/registration_controller.dart';
import 'package:agriyukt_app/core/services/location_service.dart';

class LocationForm extends StatelessWidget {
  final RegistrationController ctrl;
  const LocationForm({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // 1. Get Districts (Dependent on State Selection)
    // Returns empty list if no state is selected
    var districts = ctrl.selectedState != null
        ? LocationService.getDistricts(ctrl.selectedState!)
        : <LocalizedItem>[];

    // 2. Check if selected district is Urban (e.g., Mumbai)
    // This switches the UI from Taluka/Village -> Ward/Locality
    bool isUrban = LocationService.isUrban(ctrl.selectedDistrict ?? "");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ctrl.getStr(
              'loc_details'), // Ensure key matches your translation file
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 15),

        // --- STATE DROPDOWN ---
        _dd(
          label: ctrl.getStr('state'),
          val: ctrl.selectedState,
          items: LocationService.getStates(),
          onChanged: (v) => ctrl.setState(v),
        ),

        // --- DISTRICT DROPDOWN ---
        _dd(
          label: ctrl.getStr('district'),
          val: ctrl.selectedDistrict,
          items: districts,
          onChanged: (v) => ctrl.setDistrict(v),
        ),

        // --- DYNAMIC FIELDS (Urban vs Rural) ---
        if (isUrban) ...[
          // URBAN UI: Ward & Locality
          _dd(
            label: ctrl.getStr('ward') ?? "Ward",
            val: ctrl.selectedTaluka, // Reusing taluka variable for Ward
            items: ctrl.selectedDistrict != null
                ? LocationService.getTalukas(
                    ctrl.selectedState!, ctrl.selectedDistrict!)
                : [],
            onChanged: (v) => ctrl.setTaluka(v),
          ),
          _dd(
            label: ctrl.getStr('locality') ?? "Locality",
            val: ctrl.selectedVillage, // Reusing village variable for Locality
            items:
                (ctrl.selectedDistrict != null && ctrl.selectedTaluka != null)
                    ? LocationService.getVillages(ctrl.selectedState!,
                        ctrl.selectedDistrict!, ctrl.selectedTaluka!)
                    : [],
            onChanged: (v) => ctrl.setVillage(v),
          ),
        ] else ...[
          // RURAL UI: Taluka & Village
          _dd(
            label: ctrl.getStr('taluka'),
            val: ctrl.selectedTaluka,
            items: ctrl.selectedDistrict != null
                ? LocationService.getTalukas(
                    ctrl.selectedState!, ctrl.selectedDistrict!)
                : [],
            onChanged: (v) => ctrl.setTaluka(v),
          ),
          _dd(
            label: ctrl.getStr('village'),
            val: ctrl.selectedVillage,
            items:
                (ctrl.selectedDistrict != null && ctrl.selectedTaluka != null)
                    ? LocationService.getVillages(ctrl.selectedState!,
                        ctrl.selectedDistrict!, ctrl.selectedTaluka!)
                    : [],
            onChanged: (v) => ctrl.setVillage(v),
          ),

          // Optional Sub-Village (Only needed for Rural)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: ctrl.subVillageCtrl,
              decoration: _dec(ctrl.getStr('sub_village')),
            ),
          ),
        ],

        // --- PIN CODE ---
        TextFormField(
          controller: ctrl.pinCodeCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _dec(ctrl.getStr('pin')),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _dd({
    required String label,
    required String? val,
    required List<LocalizedItem> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: val,
        isExpanded: true,
        hint: const Text("Select..."),
        items: items.map((e) {
          return DropdownMenuItem(
            value: e.id,
            // Uses the localized name based on controller state
            child: Text(e.getName(ctrl.isMarathi)),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: _dec(label),
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
