import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ❌ Removed external import to make this file self-contained
// import 'package:agriyukt_app/core/services/location_service.dart';

class AddFarmerScreen extends StatefulWidget {
  const AddFarmerScreen({super.key});

  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- 1. PERSONAL CONTROLLERS ---
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // --- 2. ADDRESS CONTROLLERS ---
  final _addr1Ctrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // --- 3. BANK CONTROLLERS ---
  final _bankAccCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  // --- 4. FARM DETAILS ---
  String? _farmSize;
  final List<String> _farmSizeOptions = [
    '< 2 acres',
    '2-5 acres',
    '5-10 acres',
    '10+ acres'
  ];

  // --- 5. ID VERIFICATION STATE ---
  File? _frontImage;
  File? _backImage;
  String _frontMsg = "Tap to Scan Front";
  String _backMsg = "Tap to Scan Back";
  bool _isFrontValid = false;
  bool _isBackValid = false;
  String? _extractedAadharNumber;

  // --- 6. LOCATION STATE ---
  String? _selectedStateId;
  String? _selectedDistrictId;
  String? _selectedTalukaId;
  String? _selectedVillageId;

  List<LocalizedItem> _stateList = [];
  List<LocalizedItem> _districtList = [];
  List<LocalizedItem> _talukaList = [];
  List<LocalizedItem> _villageList = [];

  // Theme Color (Inspector Purple)
  final Color _inspectorColor = const Color(0xFF512DA8);

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
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addr1Ctrl.dispose();
    _pinCtrl.dispose();
    _bankAccCtrl.dispose();
    _bankIfscCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  // --- IMAGE PICKER & OCR LOGIC ---
  Future<void> _pickImage(bool isFront) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: _inspectorColor),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: _inspectorColor),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: source);
      if (img == null) return;

      // Crop the image
      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: img.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isFront ? 'Crop Front Side' : 'Crop Back Side',
            toolbarColor: _inspectorColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
          ),
        ],
      );

      if (cropped != null) {
        setState(() {
          if (isFront) {
            _frontImage = File(cropped.path);
            _frontMsg = "Processing...";
          } else {
            _backImage = File(cropped.path);
            _backMsg = "Processing...";
          }
        });
        await _processImage(File(cropped.path), isFront);
      }
    } catch (e) {
      debugPrint("Image Error: $e");
    }
  }

  Future<void> _processImage(File image, bool isFront) async {
    final input = InputImage.fromFile(image);
    final recognizer = TextRecognizer();
    try {
      final text = await recognizer.processImage(input);
      String fullText = text.text.toLowerCase().replaceAll("\n", " ");

      if (isFront) {
        bool hasKeywords = fullText.contains("government") ||
            fullText.contains("india") ||
            fullText.contains("dob");
        RegExp digitRegex = RegExp(r'[2-9]{1}[0-9]{3}\s[0-9]{4}\s[0-9]{4}');
        var match = digitRegex.firstMatch(text.text);

        if (mounted) {
          setState(() {
            _isFrontValid = (match != null || hasKeywords);
            _frontMsg =
                _isFrontValid ? "✅ Valid ID Detected" : "❌ ID Unclear - Retake";
            if (match != null) _extractedAadharNumber = match.group(0);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isBackValid = (fullText.contains("address") ||
                fullText.contains("pincode") ||
                fullText.contains("pin"));
            _backMsg =
                _isBackValid ? "✅ Address Detected" : "⚠️ Address Unclear";
          });
        }
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      recognizer.close();
    }
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _registerFarmer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStateId == null || _selectedDistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select State and District"),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final inspector = _supabase.auth.currentUser;
      if (inspector == null) throw "Inspector not logged in";

      // 1. Check Duplicates
      final existingFarmer = await _supabase
          .from('profiles')
          .select('id')
          .eq('phone', _phoneCtrl.text.trim())
          .maybeSingle();

      if (existingFarmer != null) {
        throw "Farmer with this phone number already exists!";
      }

      // 2. Upload Images
      String frontUrl = "";
      String backUrl = "";
      String time = DateTime.now().millisecondsSinceEpoch.toString();

      if (_frontImage != null) {
        String path = 'farmers_docs/${_phoneCtrl.text}_front_$time.jpg';
        try {
          await _supabase.storage
              .from('verification_docs')
              .upload(path, _frontImage!);
          frontUrl =
              _supabase.storage.from('verification_docs').getPublicUrl(path);
        } catch (_) {}
      }
      if (_backImage != null) {
        String path = 'farmers_docs/${_phoneCtrl.text}_back_$time.jpg';
        try {
          await _supabase.storage
              .from('verification_docs')
              .upload(path, _backImage!);
          backUrl =
              _supabase.storage.from('verification_docs').getPublicUrl(path);
        } catch (_) {}
      }

      // 3. Insert Data
      final newFarmerId = const Uuid().v4();

      final Map<String, dynamic> farmerData = {
        'id': newFarmerId,
        'role': 'farmer',
        'first_name': _firstNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'land_size': _farmSize,

        // Address
        'address_line_1': _addr1Ctrl.text.trim(),
        'pincode': _pinCtrl.text.trim(),
        'state': _selectedStateId,
        'district': _selectedDistrictId,
        'taluka': _selectedTalukaId,
        'village': _selectedVillageId,

        // Bank Details
        'bank_account_no': _bankAccCtrl.text.trim(),
        'ifsc_code': _bankIfscCtrl.text.trim().toUpperCase(),
        'bank_name': _bankNameCtrl.text.trim(),

        // ID Details
        'aadhar_number': _extractedAadharNumber ?? "MANUAL-VERIFIED",
        'aadhar_front_url': frontUrl,
        'aadhar_back_url': backUrl,

        // System Fields
        'verification_status': 'Verified',
        'wallet_balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'inspector_id': inspector.id,
      };

      await _supabase.from('profiles').insert(farmerData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Farmer Account Created Successfully!"),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: ${e.toString().split(']').last}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: const Text("Register New Farmer"),
        backgroundColor: _inspectorColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. PERSONAL INFO ---
              _sectionHeader("Personal Details"),
              _buildTextField("First Name *", _firstNameCtrl, Icons.person),
              const SizedBox(height: 15),
              _buildTextField(
                  "Middle Name", _middleNameCtrl, Icons.person_outline,
                  required: false),
              const SizedBox(height: 15),
              _buildTextField(
                  "Last Name *", _lastNameCtrl, Icons.person_outline),
              const SizedBox(height: 15),
              _buildTextField("Mobile Number *", _phoneCtrl, Icons.phone,
                  isNumber: true, maxLength: 10),

              const SizedBox(height: 25),

              // --- 2. ID VERIFICATION ---
              _sectionHeader("Identity Verification (Aadhar)"),
              Row(
                children: [
                  Expanded(
                      child: _buildIdCard("Front Side", _frontImage, _frontMsg,
                          _isFrontValid, true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildIdCard("Back Side", _backImage, _backMsg,
                          _isBackValid, false)),
                ],
              ),
              if (_extractedAadharNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Detected ID: $_extractedAadharNumber",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ),

              const SizedBox(height: 25),

              // --- 3. FARM INFO ---
              _sectionHeader("Farming Details"),
              DropdownButtonFormField<String>(
                value: _farmSize,
                decoration: _inputDecoration("Farm Size *", Icons.landscape),
                items: _farmSizeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _farmSize = v),
                validator: (v) => v == null ? "Required" : null,
              ),

              const SizedBox(height: 25),

              // --- 4. LOCATION ---
              _sectionHeader("Location"),
              _locationDropdown("State *", _selectedStateId, _stateList, (val) {
                setState(() {
                  _selectedStateId = val;
                  _districtList = LocationService.getDistricts(val!);
                  _selectedDistrictId = null;
                  _talukaList = [];
                  _villageList = [];
                });
              }),
              const SizedBox(height: 15),
              _locationDropdown(
                  "District *", _selectedDistrictId, _districtList, (val) {
                setState(() {
                  _selectedDistrictId = val;
                  _talukaList =
                      LocationService.getTalukas(_selectedStateId!, val!);
                  _selectedTalukaId = null;
                  _villageList = [];
                });
              }),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _locationDropdown(
                        "Taluka", _selectedTalukaId, _talukaList, (val) {
                      setState(() {
                        _selectedTalukaId = val;
                        _villageList = LocationService.getVillages(
                            _selectedStateId!, _selectedDistrictId!, val!);
                        _selectedVillageId = null;
                      });
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _locationDropdown(
                        "Village", _selectedVillageId, _villageList, (val) {
                      setState(() => _selectedVillageId = val);
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // --- 5. ADDRESS ---
              _sectionHeader("Address"),
              _buildTextField("Address / Landmark *", _addr1Ctrl, Icons.home),
              const SizedBox(height: 15),
              _buildTextField("Pincode *", _pinCtrl, Icons.pin_drop,
                  isNumber: true, maxLength: 6),

              const SizedBox(height: 25),

              // --- 6. BANK DETAILS ---
              _sectionHeader("Bank Details"),
              _buildTextField("Bank Name", _bankNameCtrl, Icons.account_balance,
                  required: false),
              const SizedBox(height: 15),
              _buildTextField("Account Number", _bankAccCtrl, Icons.numbers,
                  isNumber: true, required: false),
              const SizedBox(height: 15),
              _buildTextField("IFSC Code", _bankIfscCtrl, Icons.qr_code,
                  required: false),

              const SizedBox(height: 40),

              // --- SUBMIT ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerFarmer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inspectorColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Create Farmer Account",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: _inspectorColor),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, int? maxLength, bool required = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? "$label is required"
          : null,
      decoration: _inputDecoration(label, icon).copyWith(counterText: ""),
    );
  }

  Widget _locationDropdown(String label, String? value,
      List<LocalizedItem> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.nameEn, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => label.contains("*") && v == null ? "Required" : null,
      decoration: _inputDecoration(label, Icons.map),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _inspectorColor.withOpacity(0.6)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _inspectorColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildIdCard(
      String title, File? img, String msg, bool isValid, bool isFront) {
    Color borderColor = isValid
        ? Colors.green
        : (msg.contains("❌") ? Colors.red : Colors.grey.shade300);
    return GestureDetector(
      onTap: () => _pickImage(isFront),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              child: img == null
                  ? Icon(Icons.add_a_photo,
                      color: _inspectorColor.withOpacity(0.3), size: 35)
                  : ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.file(img,
                          width: double.infinity, fit: BoxFit.cover)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green
                    : (img != null ? Colors.orange : Colors.grey.shade100),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Text(
                isValid ? "Verified" : title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (isValid || img != null)
                        ? Colors.white
                        : Colors.black54),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 📍 LOCATION SERVICE & MODEL
// (Included here to ensure the file compiles without external dependencies)
// -----------------------------------------------------------------------------

class LocalizedItem {
  final String id;
  final String nameEn;
  LocalizedItem(this.id, this.nameEn);
}

class LocationService {
  static List<LocalizedItem> getStates() {
    return [
      LocalizedItem("MH", "Maharashtra"),
      LocalizedItem("GJ", "Gujarat"),
      LocalizedItem("KA", "Karnataka"),
      LocalizedItem("MP", "Madhya Pradesh"),
    ];
  }

  static List<LocalizedItem> getDistricts(String stateId) {
    if (stateId == "MH") {
      return [
        LocalizedItem("PUN", "Pune"),
        LocalizedItem("NAG", "Nagpur"),
        LocalizedItem("NAS", "Nashik"),
        LocalizedItem("AUR", "Aurangabad"),
      ];
    }
    return [LocalizedItem("OTHER", "Other District")];
  }

  static List<LocalizedItem> getTalukas(String stateId, String distId) {
    return [
      LocalizedItem("T1", "Taluka 1"),
      LocalizedItem("T2", "Taluka 2"),
    ];
  }

  static List<LocalizedItem> getVillages(
      String stateId, String distId, String talukaId) {
    return [
      LocalizedItem("V1", "Village A"),
      LocalizedItem("V2", "Village B"),
    ];
  }
}
