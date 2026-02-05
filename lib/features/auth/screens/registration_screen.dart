import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agriyukt_app/features/auth/controllers/registration_controller.dart';
import 'package:agriyukt_app/core/services/location_service.dart';

class RegistrationScreen extends StatelessWidget {
  final RegistrationController controller;
  const RegistrationScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        bool isMr = controller.currentLang == 'mr';
        bool isUrban =
            LocationService.isUrban(controller.selectedDistrict ?? "");

        return Scaffold(
          appBar: AppBar(title: Text(controller.getStr('register'))),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Personal Details
                _sectionHeader("Personal Details"),
                _input(
                    controller.firstNameCtrl, controller.getStr('first_name')),
                _input(controller.middleNameCtrl,
                    controller.getStr('middle_name')),
                _input(controller.lastNameCtrl, controller.getStr('last_name')),

                // Role
                DropdownButtonFormField<String>(
                  value: controller.selectedRole,
                  items: ['Farmer', 'Inspector']
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(controller.getStr(r.toLowerCase()))))
                      .toList(),
                  onChanged: (val) => controller.setRole(val!),
                  decoration: _decor(controller.getStr('role')),
                ),
                const SizedBox(height: 12),

                // 2. Location Details
                _sectionHeader("Location Details"),

                // State
                _dropdown(
                    controller.getStr('state'),
                    controller.selectedState,
                    LocationService.getStates(),
                    isMr,
                    (val) => controller.setState(val)),

                // District
                _dropdown(
                    controller.getStr('district'),
                    controller.selectedDistrict,
                    controller.selectedState != null
                        ? LocationService.getDistricts(
                            controller.selectedState!)
                        : [],
                    isMr,
                    (val) => controller.setDistrict(val)),

                // Taluka / Ward (Dynamic Label)
                _dropdown(
                    isUrban
                        ? controller.getStr('ward')
                        : controller.getStr('taluka'),
                    controller.selectedTaluka,
                    controller.selectedDistrict != null
                        ? LocationService.getTalukas(controller.selectedState!,
                            controller.selectedDistrict!)
                        : [],
                    isMr,
                    (val) => controller.setTaluka(val)),

                // Village / Locality (Dynamic Label)
                _dropdown(
                    isUrban
                        ? controller.getStr('locality')
                        : controller.getStr('village'),
                    controller.selectedVillage,
                    controller.selectedTaluka != null
                        ? LocationService.getVillages(
                            controller.selectedState!,
                            controller.selectedDistrict!,
                            controller.selectedTaluka!)
                        : [],
                    isMr,
                    (val) => controller.setVillage(val)),

                // Sub Village (Rural Only)
                if (!isUrban && controller.selectedVillage != null)
                  _input(controller.subVillageCtrl,
                      controller.getStr('sub_village')),

                // PIN Code
                TextFormField(
                  controller: controller.pinCodeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decor(controller.getStr('pin_code'))
                      .copyWith(counterText: ""),
                ),
                const SizedBox(height: 30),

                // Submit
                controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => controller.registerUser(context),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(controller.getStr('submit'),
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white)),
                      )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }

  Widget _input(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(controller: ctrl, decoration: _decor(label)),
    );
  }

  Widget _dropdown(String label, String? val, List<LocalizedItem> items,
      bool isMr, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: val,
        isExpanded: true,
        items: items
            .map((e) => DropdownMenuItem(
                value: e.id, // Value is English ID
                child: Text(isMr ? e.nameLc : e.nameEn,
                    overflow: TextOverflow.ellipsis) // Display is Localized
                ))
            .toList(),
        onChanged: onChanged,
        decoration: _decor(label),
      ),
    );
  }

  InputDecoration _decor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}
