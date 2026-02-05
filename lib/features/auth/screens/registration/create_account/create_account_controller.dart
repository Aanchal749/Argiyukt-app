import 'dart:io';
import 'dart:async';
import 'dart:convert'; // ✅ Added for proper JSON encoding
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agriyukt_app/core/services/location_service.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added Typography Support

class CreateAccountController extends ChangeNotifier {
  // =====
  // 1. CONTROLLERS
  // =====
  // -- Personal Info --
  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController middleNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();

  // -- Role Specific Details (UPDATED) --

  // Farmer
  final TextEditingController acresController = TextEditingController();

  // Inspector
  final TextEditingController orgController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();

  // Buyer
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController buyerTypeController = TextEditingController();
  final TextEditingController gstController = TextEditingController();

  // -- Location --
  final TextEditingController addressLine1Ctrl = TextEditingController();
  final TextEditingController addressLine2Ctrl = TextEditingController();
  final TextEditingController pinCodeCtrl = TextEditingController();

  // =====
  // 2. STATE VARIABLES
  // =====
  String? selectedState = "Maharashtra";
  String? selectedDistrict;
  String? selectedTaluka;
  String? selectedVillage;
  String _selectedRole = "Farmer";
  String get selectedRole => _selectedRole;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- 🔴 Validation & Duplicate Check State ---
  String? phoneError;
  String? emailError;
  String? nameError;

  // DB Status Messages
  String? phoneDbStatus;
  bool isPhoneTaken = false;

  String? emailDbStatus;
  bool isEmailTaken = false;

  String? nameDbWarning;

  // Password Strength
  String passwordStrength = "";
  Color passwordStrengthColor = Colors.grey;
  double passwordStrengthValue = 0.0;

  // Debounce Timer
  Timer? _debounce;

  // Verification Data
  File? aadharFrontImage;
  File? aadharBackImage;
  String? extractedAadharNumber;
  String? verifiedAadharName;
  bool isIdVerified = false;

  // =====
  // 3. INITIALIZATION
  // =====
  CreateAccountController() {
    _initData();
  }

  Future<void> _initData() async {
    await LocationService.loadData();
    notifyListeners();
  }

  // Setters
  void selectRole(String role) {
    _selectedRole = role;
    // Clear specific controllers when role changes to avoid mixed data
    acresController.clear();
    orgController.clear();
    employeeIdController.clear();
    companyNameController.clear();
    buyerTypeController.clear();
    gstController.clear();
    notifyListeners();
  }

  void setState(String? value) {
    selectedState = value;
    selectedDistrict = null;
    selectedTaluka = null;
    selectedVillage = null;
    notifyListeners();
  }

  void setDistrict(String? value) {
    selectedDistrict = value;
    selectedTaluka = null;
    selectedVillage = null;
    notifyListeners();
  }

  void setTaluka(String? value) {
    selectedTaluka = value;
    selectedVillage = null;
    notifyListeners();
  }

  void setVillage(String? value) {
    selectedVillage = value;
    notifyListeners();
  }

  void setVerificationData(
      {required File? front,
      required File? back,
      required String? number,
      required String? name,
      required bool isValid}) {
    aadharFrontImage = front;
    aadharBackImage = back;
    extractedAadharNumber = number;
    verifiedAadharName = name;
    isIdVerified = isValid;
    notifyListeners();
  }

  // =====
  // 4. REAL-TIME VALIDATION & DB CHECKS
  // =====

  // --- 1. Phone Logic ---
  void onPhoneChanged(String value) {
    if (value.isEmpty) {
      phoneError = null;
      phoneDbStatus = null;
      isPhoneTaken = false;
    } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      phoneError = "Numbers only";
      phoneDbStatus = null;
    } else if (value.length != 10) {
      phoneError = "Must be 10 digits";
      phoneDbStatus = null;
    } else {
      phoneError = null;
      _debounceCheck(() => _checkPhoneInDb(value));
    }
    notifyListeners();
  }

  Future<void> _checkPhoneInDb(String phone) async {
    phoneDbStatus = "Checking...";
    notifyListeners();
    try {
      final count = await Supabase.instance.client
          .from('profiles')
          .count(CountOption.exact)
          .eq('phone', phone);

      if (count > 0) {
        isPhoneTaken = true;
        phoneDbStatus = "⚠️ This number is already registered.";
      } else {
        isPhoneTaken = false;
        phoneDbStatus = "✅ Number available";
      }
    } catch (e) {
      phoneDbStatus = null;
    }
    notifyListeners();
  }

  // --- 2. Email Logic ---
  void onEmailChanged(String value) {
    if (value.isEmpty) {
      emailError = null;
      emailDbStatus = null;
      isEmailTaken = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      emailError = "Invalid email format";
      emailDbStatus = null;
    } else {
      emailError = null;
      _debounceCheck(() => _checkEmailInDb(value));
    }
    notifyListeners();
  }

  Future<void> _checkEmailInDb(String email) async {
    emailDbStatus = "Checking...";
    notifyListeners();
    try {
      final count = await Supabase.instance.client
          .from('profiles')
          .count(CountOption.exact)
          .eq('email', email);

      if (count > 0) {
        isEmailTaken = true;
        emailDbStatus = "⚠️ Account with this email exists.";
      } else {
        isEmailTaken = false;
        emailDbStatus = "✅ Email available";
      }
    } catch (e) {
      emailDbStatus = null;
    }
    notifyListeners();
  }

  // --- 3. Name Logic ---
  void onNameChanged() {
    String first = firstNameCtrl.text.trim();
    String middle = middleNameCtrl.text.trim();
    String last = lastNameCtrl.text.trim();

    if (first.isNotEmpty && middle.isNotEmpty && last.isNotEmpty) {
      if (first.toLowerCase() == middle.toLowerCase() &&
          middle.toLowerCase() == last.toLowerCase()) {
        nameError = "First, Middle, and Last name cannot be same.";
      } else {
        nameError = null;
        _debounceCheck(() => _checkNameInDb(first, middle, last));
      }
    } else {
      nameError = null;
      nameDbWarning = null;
    }
    notifyListeners();
  }

  Future<void> _checkNameInDb(String f, String m, String l) async {
    try {
      final count = await Supabase.instance.client
          .from('profiles')
          .count(CountOption.exact)
          .match({'first_name': f, 'middle_name': m, 'last_name': l});

      if (count > 0) {
        nameDbWarning =
            "ℹ️ An account with this name exists. Please ensure this is not a duplicate.";
      } else {
        nameDbWarning = null;
      }
    } catch (e) {
      nameDbWarning = null;
    }
    notifyListeners();
  }

  void _debounceCheck(VoidCallback action) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), action);
  }

  void checkPasswordStrength(String value) {
    if (value.isEmpty) {
      passwordStrength = "";
      passwordStrengthValue = 0.0;
      passwordStrengthColor = Colors.grey;
    } else {
      bool hasUpper = value.contains(RegExp(r'[A-Z]'));
      bool hasLower = value.contains(RegExp(r'[a-z]'));
      bool hasDigits = value.contains(RegExp(r'[0-9]'));
      bool hasSpecial = value.contains(RegExp(r'[!@#\$&*~]'));
      bool isLong = value.length >= 8;

      if (isLong && hasUpper && hasLower && hasDigits && hasSpecial) {
        passwordStrength = "🟢 Strong";
        passwordStrengthColor = Colors.green;
        passwordStrengthValue = 1.0;
      } else if (value.length >= 6 && hasDigits) {
        passwordStrength = "🟠 Medium";
        passwordStrengthColor = Colors.orange;
        passwordStrengthValue = 0.6;
      } else {
        passwordStrength = "🔴 Weak";
        passwordStrengthColor = Colors.red;
        passwordStrengthValue = 0.3;
      }
    }
    notifyListeners();
  }

  Future<String?> validateStep1() async {
    if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty)
      return "Name required";
    if (phoneError != null) return phoneError;
    if (isPhoneTaken) return "Mobile number already registered. Please Login.";

    if (emailError != null) return emailError;
    if (isEmailTaken) return "Email already registered. Please Login.";

    if (nameError != null) return nameError;

    if (passwordStrength == "🔴 Weak") return "Password is too weak.";
    if (passCtrl.text != confirmPassCtrl.text) return "Passwords do not match";

    return null;
  }

  // =====
  // 5. REGISTER (FINAL SUBMIT)
  // =====
  Future<void> verifyAndRegister(BuildContext context) async {
    if (!isIdVerified) {
      _showError(context, "⚠️ Please complete ID Verification tab first.");
      return;
    }

    // Role Specific Validations
    if (_selectedRole == 'Farmer' && acresController.text.isEmpty) {
      _showError(context, "Please select Farm Size.");
      return;
    }
    if (_selectedRole == 'Inspector' && orgController.text.isEmpty) {
      _showError(context, "Please select Organization.");
      return;
    }
    if (_selectedRole == 'Buyer') {
      if (companyNameController.text.isEmpty) {
        _showError(context, "Please enter Company Name.");
        return;
      }
      if (buyerTypeController.text.isEmpty) {
        _showError(context, "Please select Buyer Type.");
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final AuthResponse res = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        data: {'phone': phoneCtrl.text.trim(), 'role': _selectedRole},
      );
      final user = res.user;
      if (user == null) throw "Sign up failed.";

      // Image Upload Logic
      String? frontUrl;
      String? backUrl;
      final time = DateTime.now().millisecondsSinceEpoch;
      if (aadharFrontImage != null) {
        final path = '${user.id}/front_$time.jpg';
        await supabase.storage
            .from('verification_docs')
            .upload(path, aadharFrontImage!);
        frontUrl =
            supabase.storage.from('verification_docs').getPublicUrl(path);
      }
      if (aadharBackImage != null) {
        final path = '${user.id}/back_$time.jpg';
        await supabase.storage
            .from('verification_docs')
            .upload(path, aadharBackImage!);
        backUrl = supabase.storage.from('verification_docs').getPublicUrl(path);
      }

      // --- COMPILE ROLE DATA (Updated) ---
      Map<String, dynamic> roleData = {};

      if (_selectedRole == 'Farmer') {
        roleData = {
          'farm_size_range': acresController.text, // Dropdown value
        };
      } else if (_selectedRole == 'Inspector') {
        roleData = {
          'organization': orgController.text, // Dropdown value
          'employee_id': employeeIdController.text.trim(), // Optional
        };
      } else if (_selectedRole == 'Buyer') {
        roleData = {
          'company_name': companyNameController.text.trim(),
          'buyer_type': buyerTypeController.text, // Dropdown value
          'gst_number': gstController.text.trim(), // Optional
        };
      }

      // DB Insert
      await supabase.from('profiles').insert({
        'id': user.id,
        'first_name': firstNameCtrl.text.trim(),
        'middle_name': middleNameCtrl.text.trim(),
        'last_name': lastNameCtrl.text.trim(),
        'role': _selectedRole,
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'state': selectedState,
        'district': selectedDistrict,
        'taluka': selectedTaluka,
        'village': selectedVillage,
        'pincode': pinCodeCtrl.text.trim(),
        'address_line_1': addressLine1Ctrl.text.trim(),
        'address_line_2': addressLine2Ctrl.text.trim(),

        // ✅ Saving updated role data as JSON
        'extra_field': jsonEncode(roleData),

        'aadhar_number': extractedAadharNumber,
        'aadhar_name': verifiedAadharName,
        'aadhar_front_url': frontUrl,
        'aadhar_back_url': backUrl,
        'verification_status': 'Verified',
      });

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Account Created! Login now.",
                style: GoogleFonts.poppins()), // ✅ Added Typography
            backgroundColor: Colors.green));
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showError(context, "Error: $e");
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()), // ✅ Added Typography
        backgroundColor: Colors.red));
  }

  Future<String?> validateAllFields() async {
    // Implement full validation logic if needed for stepper control
    return null;
  }
}
