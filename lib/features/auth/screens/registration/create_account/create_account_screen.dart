import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agriyukt_app/core/services/location_service.dart';
import 'package:agriyukt_app/features/onboarding/onboarding_controller.dart';
import 'create_account_controller.dart';
import 'tabs/verification_tab.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added Typography Support

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateAccountController(),
      child: const _CreateAccountContent(),
    );
  }
}

class _CreateAccountContent extends StatefulWidget {
  const _CreateAccountContent();

  @override
  State<_CreateAccountContent> createState() => _CreateAccountContentState();
}

class _CreateAccountContentState extends State<_CreateAccountContent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // UI States
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _otpSent = false;
  bool _phoneVerified = false;

  List<LocalizedItem> _stateList = [];
  List<LocalizedItem> _districtList = [];
  List<LocalizedItem> _talukaList = [];
  List<LocalizedItem> _villageList = [];

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  void _loadStates() {
    setState(() {
      _stateList = LocationService.getStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<CreateAccountController>(context);
    final langCode =
        Provider.of<OnboardingController>(context).selectedLanguage;
    final isMarathi = langCode == 'mr';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Compact Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_currentPage > 0) {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child:
                        const Icon(Icons.arrow_back_ios, color: Colors.green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentPage == 0
                          ? (isMarathi ? 'खाते तयार करा' : 'Create Account')
                          : (isMarathi ? 'पडताळणी' : 'Verification'),
                      style: GoogleFonts.poppins(
                          // ✅ Added Typography
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Progress Indicator
                  Text(
                    "${_currentPage + 1}/2",
                    style: GoogleFonts.poppins(
                        // ✅ Added Typography
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  )
                ],
              ),
            ),

            // Thin Progress Bar
            LinearProgressIndicator(
              value: _currentPage == 0 ? 0.5 : 1.0,
              backgroundColor: Colors.grey[100],
              color: Colors.green,
              minHeight: 4,
            ),

            // --- 2. Form Content ---
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildStep1_AllInfo(ctrl, isMarathi),
                  VerificationTab(controller: ctrl),
                ],
              ),
            ),

            // --- 3. Bottom Action Button ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: ctrl.isLoading
                      ? null
                      : () async {
                          if (_currentPage == 0) {
                            // Validation
                            String? error = await ctrl.validateStep1();
                            if (error != null) {
                              _showSnack(error, Colors.red);
                              return;
                            }

                            // Note: Phone verify check can be enabled here
                            /* if (!_phoneVerified) {
                        _showSnack("Please verify mobile number", Colors.orange);
                        return;
                      } */

                            if (ctrl.selectedDistrict == null) {
                              _showSnack("Please select District", Colors.red);
                              return;
                            }
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            // Submit
                            await ctrl.verifyAndRegister(context);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                  ),
                  child: ctrl.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentPage == 0
                              ? (isMarathi ? 'पुढे' : 'Next')
                              : (isMarathi
                                  ? 'खाते तयार करा'
                                  : 'Create Account'),
                          style: GoogleFonts.poppins(
                              // ✅ Added Typography
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====
  // STEP 1: FORM
  // =====
  Widget _buildStep1_AllInfo(CreateAccountController ctrl, bool isMarathi) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Role Selection
          _sectionLabel("Select Role"),
          Row(
            children: [
              Expanded(child: _roleCard(ctrl, 'Farmer', Icons.agriculture)),
              const SizedBox(width: 8),
              Expanded(child: _roleCard(ctrl, 'Buyer', Icons.shopping_cart)),
              const SizedBox(width: 8),
              Expanded(
                  child: _roleCard(ctrl, 'Inspector', Icons.verified_user)),
            ],
          ),
          const SizedBox(height: 25),

          // 2. Personal Info (Row for First & Middle)
          _sectionLabel("Personal Details"),
          Row(
            children: [
              Expanded(
                child: _customTextField(
                    ctrl.firstNameCtrl, "First Name", Icons.person),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _customTextField(
                    ctrl.middleNameCtrl, "Middle Name", Icons.person_outline),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Last Name (Full Width)
          _customTextField(
              ctrl.lastNameCtrl, "Last Name", Icons.person_outline),

          const SizedBox(height: 15),

          // 3. Phone Verification
          _phoneVerificationField(ctrl),
          if (_otpSent && !_phoneVerified) _otpField(ctrl),

          const SizedBox(height: 15),
          _customTextField(
              ctrl.emailCtrl, "Email Address", Icons.email_outlined,
              type: TextInputType.emailAddress),
          const SizedBox(height: 15),

          _customTextField(ctrl.passCtrl, "Password", Icons.lock_outline,
              isPass: true,
              obscure: _obscurePass,
              onToggle: () => setState(() => _obscurePass = !_obscurePass)),
          const SizedBox(height: 15),

          _customTextField(
              ctrl.confirmPassCtrl, "Confirm Password", Icons.lock_outline,
              isPass: true,
              obscure: _obscureConfirmPass,
              onToggle: () =>
                  setState(() => _obscureConfirmPass = !_obscureConfirmPass)),

          const SizedBox(height: 25),

          // 4. Role Specifics
          if (ctrl.selectedRole != null) ...[
            _sectionLabel("${ctrl.selectedRole} Info"),
            if (ctrl.selectedRole == 'Farmer')
              _customDropdown(
                  "Farm Size",
                  ctrl.acresController.text.isEmpty
                      ? null
                      : ctrl.acresController.text,
                  ['< 2 acres', '2-5 acres', '5-10 acres', '10+ acres'],
                  (v) => ctrl.acresController.text = v!,
                  Icons.landscape),
            if (ctrl.selectedRole == 'Buyer') ...[
              _customTextField(
                  ctrl.companyNameController, "Company Name", Icons.store),
              const SizedBox(height: 15),
              _customDropdown(
                  "Buyer Type",
                  ctrl.buyerTypeController.text.isEmpty
                      ? null
                      : ctrl.buyerTypeController.text,
                  ['Wholesaler', 'Retailer', 'Exporter', 'Trader'],
                  (v) => ctrl.buyerTypeController.text = v!,
                  Icons.category),
            ],
            if (ctrl.selectedRole == 'Inspector')
              _customDropdown(
                  "Organization",
                  ctrl.orgController.text.isEmpty
                      ? null
                      : ctrl.orgController.text,
                  ['Govt Dept', 'Private Quality', 'FPO', 'Other'],
                  (v) => ctrl.orgController.text = v!,
                  Icons.business),
          ],

          const SizedBox(height: 25),

          // 5. Location
          _sectionLabel("Location"),
          _customLocDropdown(isMarathi ? 'राज्य' : 'State', ctrl.selectedState,
              _stateList, isMarathi, (val) {
            ctrl.setState(val);
            setState(() {
              _districtList = LocationService.getDistricts(val!);
              _talukaList = [];
              _villageList = [];
            });
          }),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _customLocDropdown(isMarathi ? 'जिल्हा' : 'District',
                    ctrl.selectedDistrict, _districtList, isMarathi, (val) {
                  ctrl.setDistrict(val);
                  setState(() {
                    _talukaList =
                        LocationService.getTalukas(ctrl.selectedState!, val!);
                    _villageList = [];
                  });
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _customLocDropdown(isMarathi ? 'तालुका' : 'Taluka',
                    ctrl.selectedTaluka, _talukaList, isMarathi, (val) {
                  ctrl.setTaluka(val);
                  setState(() {
                    _villageList = LocationService.getVillages(
                        ctrl.selectedState!, ctrl.selectedDistrict!, val!);
                  });
                }),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _customLocDropdown(
              isMarathi ? 'गाव' : 'Village',
              ctrl.selectedVillage,
              _villageList,
              isMarathi,
              (val) => ctrl.setVillage(val)),

          const SizedBox(height: 25),

          // 6. Address & Pincode (At the very end as requested)
          _sectionLabel("Address Details"),
          _customTextField(
              ctrl.addressLine1Ctrl, "Address / Landmark", Icons.home),
          const SizedBox(height: 15),
          _customTextField(ctrl.pinCodeCtrl, "Enter Pincode", Icons.pin_drop,
              type: TextInputType.number),

          const SizedBox(height: 20),

          // Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "Already have an account? ",
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14), // ✅ Added Typography
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false),
                child: Text(
                  "Login",
                  style: GoogleFonts.poppins(
                    // ✅ Added Typography
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // =====
  // WIDGETS
  // =====

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: GoogleFonts.poppins(
              // ✅ Added Typography
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green)),
    );
  }

  Widget _customTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPass = false,
      bool obscure = false,
      VoidCallback? onToggle,
      TextInputType type = TextInputType.text,
      bool enabled = true}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      enabled: enabled,
      style: GoogleFonts.poppins(fontSize: 14), // ✅ Added Typography
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 14, color: Colors.grey[600]), // ✅ Added Typography
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        isDense: true,
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggle)
            : null,
      ),
    );
  }

  // Added isExpanded: true to prevent 71px overflow on small screens
  Widget _customDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged,
      [IconData? icon]) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e,
                  style:
                      GoogleFonts.poppins(fontSize: 14)))) // ✅ Added Typography
          .toList(),
      onChanged: onChanged,
      isExpanded: true, // ✅ Prevents overflow
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 14, color: Colors.grey[600]), // ✅ Added Typography
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        isDense: true,
      ),
    );
  }

  Widget _customLocDropdown(String label, String? value,
      List<LocalizedItem> items, bool isMr, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.getName(isMr),
                  style:
                      GoogleFonts.poppins(fontSize: 14), // ✅ Added Typography
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      isExpanded: true, // ✅ Prevents overflow
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 14, color: Colors.grey[600]), // ✅ Added Typography
        prefixIcon: const Icon(Icons.map, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        isDense: true,
      ),
    );
  }

  Widget _roleCard(CreateAccountController ctrl, String role, IconData icon) {
    bool isSelected = ctrl.selectedRole == role;
    return GestureDetector(
      onTap: () => ctrl.selectRole(role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? Colors.green : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24, color: isSelected ? Colors.green : Colors.grey),
            const SizedBox(height: 5),
            Text(role,
                style: GoogleFonts.poppins(
                    // ✅ Added Typography
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.green : Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _phoneVerificationField(CreateAccountController ctrl) {
    return TextField(
      controller: ctrl.phoneCtrl,
      keyboardType: TextInputType.phone,
      enabled: !_phoneVerified,
      style: GoogleFonts.poppins(fontSize: 14), // ✅ Added Typography
      decoration: InputDecoration(
        labelText: "Mobile Number",
        labelStyle: GoogleFonts.poppins(
            fontSize: 14, color: Colors.grey[600]), // ✅ Added Typography
        prefixIcon: const Icon(Icons.phone, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        isDense: true,
        suffixIcon: _phoneVerified
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () {
                  if (ctrl.phoneCtrl.text.length == 10) {
                    setState(() => _otpSent = true);
                    _showSnack(
                        "OTP Sent to ${ctrl.phoneCtrl.text}", Colors.blue);
                  } else {
                    _showSnack("Enter valid 10-digit number", Colors.red);
                  }
                },
                child: Text("Verify",
                    style: GoogleFonts.poppins(
                        // ✅ Added Typography
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ),
      ),
    );
  }

  Widget _otpField(CreateAccountController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl.otpCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 14), // ✅ Added Typography
              decoration: InputDecoration(
                labelText: "Enter OTP",
                labelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600]), // ✅ Added Typography
                hintText: "123456",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              if (ctrl.otpCtrl.text == "123456") {
                setState(() {
                  _phoneVerified = true;
                  _otpSent = false;
                });
                _showSnack("Mobile Verified Successfully!", Colors.green);
              } else {
                _showSnack("Invalid OTP (Try 123456)", Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                minimumSize: const Size(80, 50)),
            child: Text("Submit",
                style: GoogleFonts.poppins(
                    color: Colors.white)), // ✅ Added Typography
          )
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()), // ✅ Added Typography
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
