import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:agriyukt_app/core/services/location_service.dart';

class InspectorEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const InspectorEditProfileScreen({super.key, required this.profile});

  @override
  State<InspectorEditProfileScreen> createState() =>
      _InspectorEditProfileScreenState();
}

class _InspectorEditProfileScreenState
    extends State<InspectorEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // --- Services ---
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isLoading = false;
  bool _isScanning = false;

  // --- 1. TEXT CONTROLLERS ---
  late TextEditingController _idCtrl;
  late TextEditingController _fnameCtrl;
  late TextEditingController _mnameCtrl;
  late TextEditingController _lnameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _aadharTextCtrl;

  // --- 2. DROPDOWNS ---
  String? _selectedOrg;
  final List<String> _orgOptions = [
    'Govt Dept',
    'Private Quality',
    'FPO',
    'Other'
  ];

  // --- 3. LOCATION STATE (Cascading) ---
  String? _selectedStateId;
  String? _selectedDistrictId;
  String? _selectedTalukaId;
  String? _selectedVillageId;

  List<LocalizedItem> _stateList = [];
  List<LocalizedItem> _districtList = [];
  List<LocalizedItem> _talukaList = [];
  List<LocalizedItem> _villageList = [];

  // --- 4. IDENTITY IMAGES ---
  File? _frontImageFile;
  File? _backImageFile;
  String? _existingFrontUrl;
  String? _existingBackUrl;
  bool _isVerified = false;

  // --- THEME ---
  final Color _inspectorColor = const Color(0xFF512DA8);
  final Color _bgOffWhite = const Color(0xFFF8F9FC); // Premium Light Background

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ===========================================================================
  // 📥 INITIALIZATION
  // ===========================================================================
  void _initializeData() {
    final p = widget.profile;
    final user = _supabase.auth.currentUser;

    String memberId = p['member_id'] ?? '';
    if (memberId.isEmpty && user != null) {
      memberId = "#${user.id.substring(0, 5).toUpperCase()}";
    }
    _idCtrl = TextEditingController(text: memberId);
    _fnameCtrl = TextEditingController(text: p['first_name'] ?? '');
    _mnameCtrl = TextEditingController(text: p['middle_name'] ?? '');
    _lnameCtrl = TextEditingController(text: p['last_name'] ?? '');
    _phoneCtrl = TextEditingController(text: p['phone'] ?? '');
    _emailCtrl = TextEditingController(text: p['email'] ?? user?.email ?? '');

    if (p['organization'] != null && _orgOptions.contains(p['organization'])) {
      _selectedOrg = p['organization'];
    }

    _addrCtrl = TextEditingController(text: p['address_line_1'] ?? '');
    _pinCtrl = TextEditingController(text: p['pincode'] ?? '');

    _aadharTextCtrl = TextEditingController(text: p['aadhar_number'] ?? '');
    _existingFrontUrl = p['aadhar_front_url'];
    _existingBackUrl = p['aadhar_back_url'];

    _isVerified = (_existingFrontUrl != null &&
        _existingFrontUrl!.isNotEmpty &&
        _existingBackUrl != null &&
        _existingBackUrl!.isNotEmpty &&
        _aadharTextCtrl.text.isNotEmpty);

    _loadLocationHierarchy();
  }

  void _loadLocationHierarchy() {
    _stateList = LocationService.getStates();
    final p = widget.profile;

    _selectedStateId = p['state'];
    if (_selectedStateId != null) {
      _districtList = LocationService.getDistricts(_selectedStateId!);
      if (_districtList.any((e) => e.id == p['district'])) {
        _selectedDistrictId = p['district'];
      }
    }
    if (_selectedStateId != null && _selectedDistrictId != null) {
      _talukaList =
          LocationService.getTalukas(_selectedStateId!, _selectedDistrictId!);
      if (_talukaList.any((e) => e.id == p['taluka'])) {
        _selectedTalukaId = p['taluka'];
      }
    }
    if (_selectedStateId != null &&
        _selectedDistrictId != null &&
        _selectedTalukaId != null) {
      _villageList = LocationService.getVillages(
          _selectedStateId!, _selectedDistrictId!, _selectedTalukaId!);
      if (_villageList.any((e) => e.id == p['village'])) {
        _selectedVillageId = p['village'];
      }
    }
    if (mounted) setState(() {});
  }

  // ===========================================================================
  // 📸 IDENTITY LOGIC
  // ===========================================================================

  Future<void> _pickImage(bool isFront) async {
    try {
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 90);
      if (photo != null) {
        await _cropImage(File(photo.path), isFront);
      }
    } catch (e) {
      debugPrint("Pick Error: $e");
    }
  }

  Future<void> _cropImage(File imageFile, bool isFront) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isFront ? 'Crop Front ID' : 'Crop Back ID',
          toolbarColor: _inspectorColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio3x2,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Adjust ID Card', aspectRatioLockEnabled: false),
      ],
    );

    if (croppedFile != null) {
      File processedFile = File(croppedFile.path);
      if (isFront) {
        await _validateFrontSide(processedFile);
      } else {
        await _validateBackSide(processedFile);
      }
    }
  }

  Future<void> _validateFrontSide(File imageFile) async {
    setState(() => _isScanning = true);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      RegExp aadharRegex = RegExp(r'(?<!\d)\d{4}\s?\d{4}\s?\d{4}(?!\d)');
      RegExpMatch? match = aadharRegex.firstMatch(recognizedText.text);

      setState(() => _frontImageFile = imageFile);

      if (match != null) {
        String idNumber = match.group(0)!.replaceAll(' ', '');
        setState(() => _aadharTextCtrl.text = idNumber);
        _showSuccess("Number Detected: $idNumber");
      } else {
        _showWarning("Number not clear. Please type manually.");
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _validateBackSide(File imageFile) async {
    setState(() => _backImageFile = imageFile);
    _showSuccess("Back Side Selected");
  }

  Future<String?> _uploadFile(File? file, String userId, String side) async {
    if (file == null) return null;
    try {
      final time = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/${side}_$time.jpg';
      await _supabase.storage.from('verification_docs').upload(path, file);
      return _supabase.storage.from('verification_docs').getPublicUrl(path);
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_aadharTextCtrl.text.isEmpty) {
      _showWarning("Missing Aadhar Number. Please verify identity.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        String? frontUrl = await _uploadFile(_frontImageFile, user.id, 'front');
        String? backUrl = await _uploadFile(_backImageFile, user.id, 'back');

        String finalFrontUrl = frontUrl ?? _existingFrontUrl ?? '';
        String finalBackUrl = backUrl ?? _existingBackUrl ?? '';
        String status = (finalFrontUrl.isNotEmpty &&
                finalBackUrl.isNotEmpty &&
                _aadharTextCtrl.text.isNotEmpty)
            ? 'Verified'
            : 'Pending';

        final updates = {
          'id': user.id,
          'first_name': _fnameCtrl.text.trim(),
          'middle_name': _mnameCtrl.text.trim(),
          'last_name': _lnameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'organization': _selectedOrg,
          'state': _selectedStateId,
          'district': _selectedDistrictId,
          'taluka': _selectedTalukaId,
          'village': _selectedVillageId,
          'address_line_1': _addrCtrl.text.trim(),
          'pincode': _pinCtrl.text.trim(),
          'aadhar_number': _aadharTextCtrl.text.trim(),
          'aadhar_front_url': finalFrontUrl,
          'aadhar_back_url': finalBackUrl,
          'verification_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('profiles').upsert(updates);

        if (mounted) {
          _showSuccess("✅ Profile Updated Successfully!");
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange));

  // ===========================================================================
  // 🎨 UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: Text("Edit Profile",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: _inspectorColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _inspectorColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PERSONAL INFO
                    _sectionHeader("Personal Details", Icons.person_pin),
                    _buildShadowInput("Member ID", _idCtrl, Icons.badge,
                        isReadOnly: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildShadowInput(
                                "First Name", _fnameCtrl, Icons.person,
                                isRequired: true)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildShadowInput("Middle Name", _mnameCtrl,
                                Icons.person_outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildShadowInput("Last Name", _lnameCtrl, Icons.person,
                        isRequired: true),
                    const SizedBox(height: 12),
                    _buildShadowInput("Mobile Number", _phoneCtrl, Icons.phone,
                        isNumber: true, isRequired: true),
                    const SizedBox(height: 12),
                    _buildShadowInput("Email Address", _emailCtrl, Icons.email,
                        isReadOnly: true),

                    const SizedBox(height: 28),

                    // 2. PROFESSIONAL
                    _sectionHeader("Professional Info", Icons.work),
                    _buildShadowDropdown("Organization", _selectedOrg,
                        _orgOptions, (v) => setState(() => _selectedOrg = v)),

                    const SizedBox(height: 28),

                    // 3. LOCATION
                    _sectionHeader("Location & Address", Icons.map),
                    _buildLocationDropdown(
                        "State", _selectedStateId, _stateList, (val) {
                      setState(() {
                        _selectedStateId = val;
                        _districtList = LocationService.getDistricts(val!);
                        _selectedDistrictId = null;
                        _talukaList = [];
                        _villageList = [];
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildLocationDropdown(
                        "District", _selectedDistrictId, _districtList, (val) {
                      setState(() {
                        _selectedDistrictId = val;
                        _talukaList =
                            LocationService.getTalukas(_selectedStateId!, val!);
                        _selectedTalukaId = null;
                        _villageList = [];
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildLocationDropdown(
                        "Taluka", _selectedTalukaId, _talukaList, (val) {
                      setState(() {
                        _selectedTalukaId = val;
                        _villageList = LocationService.getVillages(
                            _selectedStateId!, _selectedDistrictId!, val!);
                        _selectedVillageId = null;
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildLocationDropdown(
                        "Village",
                        _selectedVillageId,
                        _villageList,
                        (val) => setState(() => _selectedVillageId = val)),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        "Address / Landmark", _addrCtrl, Icons.home),
                    const SizedBox(height: 12),
                    _buildShadowInput("Pincode", _pinCtrl, Icons.pin_drop,
                        isNumber: true),

                    const SizedBox(height: 28),

                    // 4. IDENTITY
                    _buildIdentitySection(),

                    const SizedBox(height: 40),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _inspectorColor,
                            shadowColor: _inspectorColor.withOpacity(0.4),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        child: Text("SAVE CHANGES",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // ===========================================================================
  // 🧱 PREMIUM WIDGETS
  // ===========================================================================

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
              height: 24,
              width: 4,
              decoration: BoxDecoration(
                  color: _inspectorColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: _inspectorColor),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Identity Proof",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _inspectorColor)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _isVerified
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _isVerified ? Colors.green : Colors.orange,
                        width: 1)),
                child: Text(_isVerified ? "Verified" : "Pending",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isVerified ? Colors.green : Colors.orange)),
              )
            ],
          ),
          const SizedBox(height: 15),
          Text("Aadhaar Card (Front)",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          _buildModernUploadBox(true),
          const SizedBox(height: 15),
          Text("Aadhaar Card (Back)",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          _buildModernUploadBox(false),
          const SizedBox(height: 15),
          _buildShadowInput("Aadhar Number", _aadharTextCtrl, Icons.fingerprint,
              isNumber: true, isRequired: true),
        ],
      ),
    );
  }

  Widget _buildShadowInput(
      String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false,
      bool isReadOnly = false,
      bool isRequired = false}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: isReadOnly,
        validator: (v) {
          if (isReadOnly) return null;
          if (isRequired && (v == null || v.trim().isEmpty))
            return "$label is required";
          return null;
        },
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon:
              Icon(icon, color: _inspectorColor.withOpacity(0.7), size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade50 : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildShadowDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: GoogleFonts.poppins(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            labelStyle:
                GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: Icon(Icons.business,
                color: _inspectorColor.withOpacity(0.7), size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      ),
    );
  }

  Widget _buildLocationDropdown(String label, String? value,
      List<LocalizedItem> items, Function(String?) onChanged) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        items: items
            .map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.nameEn,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            labelStyle:
                GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: Icon(Icons.map_outlined,
                color: _inspectorColor.withOpacity(0.7), size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      ),
    );
  }

  Widget _buildModernUploadBox(bool isFront) {
    File? file = isFront ? _frontImageFile : _backImageFile;
    String? existingUrl = isFront ? _existingFrontUrl : _existingBackUrl;
    bool hasImage =
        file != null || (existingUrl != null && existingUrl.isNotEmpty);

    if (hasImage) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          image: file != null
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : DecorationImage(
                  image: NetworkImage(existingUrl!), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            if (_isScanning && isFront)
              Container(
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.white))),
            Positioned(
              right: 10,
              bottom: 10,
              child: InkWell(
                onTap: () => _pickImage(isFront),
                child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: Icon(Icons.edit, size: 18, color: Colors.black87)),
              ),
            )
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickImage(isFront),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning && isFront) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text("Scanning...",
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: _inspectorColor))
            ] else ...[
              Icon(Icons.add_a_photo_rounded,
                  size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text("Tap to Upload",
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13))
            ]
          ],
        ),
      ),
    );
  }
}
