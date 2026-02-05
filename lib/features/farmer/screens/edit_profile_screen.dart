import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ IMPORTS
import 'package:agriyukt_app/core/services/location_service.dart';
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isLoading = true;
  bool _isScanning = false;

  final _idCtrl = TextEditingController();
  final _fnameCtrl = TextEditingController();
  final _mnameCtrl = TextEditingController();
  final _lnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _aadharTextCtrl = TextEditingController();

  // --- 2. FARMER SPECIFIC ---
  String? _landSize; // Stores the KEY (e.g., '10_plus_acres')

  // ✅ Defined keys must match exactly with farmer_translations.dart
  final List<String> _landSizeKeys = [
    'less_2_acres',
    '2_5_acres',
    '5_10_acres',
    '10_plus_acres'
  ];

  // --- 3. LOCATION STATE ---
  String? _selectedStateId;
  String? _selectedDistrictId;
  String? _selectedTalukaId;
  String? _selectedVillageId;

  List<LocalizedItem> _stateList = [];
  List<LocalizedItem> _districtList = [];
  List<LocalizedItem> _talukaList = [];
  List<LocalizedItem> _villageList = [];

  File? _selectedFrontImage;
  File? _selectedBackImage;
  String? _existingFrontUrl;
  String? _existingBackUrl;

  final Color _primaryGreen = const Color(0xFF1B5E20);
  final Color _bgOffWhite = const Color(0xFFF8F9FC);

  @override
  void initState() {
    super.initState();
    _loadStates();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  String _text(String key) => FarmerText.get(context, key);

  void _loadStates() {
    setState(() {
      _stateList = LocationService.getStates();
    });
  }

  // ✅ CRITICAL FIX: MAP LEGACY DATA TO NEW KEYS
  String? _normalizeLandSize(String? dbValue) {
    if (dbValue == null) return null;

    // If DB has old English text, return the corresponding KEY
    if (dbValue == '< 2 acres') return 'less_2_acres';
    if (dbValue == '2-5 acres') return '2_5_acres';
    if (dbValue == '5-10 acres') return '5_10_acres';
    if (dbValue == '10+ acres') return '10_plus_acres';

    // If it's already a key (or unknown), return as is
    if (_landSizeKeys.contains(dbValue)) return dbValue;

    // If it doesn't match anything, return null to avoid crash
    return null;
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _idCtrl.text = data['member_id'] ??
                "#${user.id.substring(0, 5).toUpperCase()}";
            _fnameCtrl.text = data['first_name'] ?? "";
            _mnameCtrl.text = data['middle_name'] ?? "";
            _lnameCtrl.text = data['last_name'] ?? "";
            _phoneCtrl.text = data['phone'] ?? "";
            _emailCtrl.text = data['email'] ?? user.email ?? "";
            _aadharTextCtrl.text = data['aadhar_number'] ?? "";

            final meta = data['meta_data'] ?? {};

            // ✅ USE NORMALIZATION FUNCTION
            _landSize = _normalizeLandSize(meta['land_size']);

            _address1Ctrl.text = meta['address_line_1'] ?? "";
            _address2Ctrl.text = meta['address_line_2'] ?? "";

            _selectedStateId = data['state'];
            _pinCtrl.text = data['pincode'] ?? "";

            _existingFrontUrl = data['aadhar_front_url'];
            _existingBackUrl = data['aadhar_back_url'];

            if (_selectedStateId != null) {
              _districtList = LocationService.getDistricts(_selectedStateId!);
              if (_districtList.any((e) => e.id == data['district'])) {
                _selectedDistrictId = data['district'];
                _talukaList = LocationService.getTalukas(
                    _selectedStateId!, _selectedDistrictId!);
                if (_talukaList.any((e) => e.id == data['taluka'])) {
                  _selectedTalukaId = data['taluka'];
                  _villageList = LocationService.getVillages(_selectedStateId!,
                      _selectedDistrictId!, _selectedTalukaId!);
                  if (_villageList.any((e) => e.id == data['village'])) {
                    _selectedVillageId = data['village'];
                  }
                }
              }
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep Image Picker/Scanner Logic same as before) ...
  Future<void> _pickAndProcessImage(bool isFront) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 90);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isFront ? _text('crop_front') : _text('crop_back'),
            toolbarColor: _primaryGreen,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio3x2,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Adjust ID Card'),
        ],
      );

      if (croppedFile == null) return;
      await _validateImageContent(File(croppedFile.path), isFront);
    } catch (e) {
      debugPrint("Pipeline Error: $e");
    }
  }

  Future<void> _validateImageContent(File imageFile, bool isFront) async {
    setState(() => _isScanning = true);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      String text = recognizedText.text;

      bool isValid = false;
      String message = "";

      if (isFront) {
        RegExp aadharRegex = RegExp(r'(?<!\d)\d{4}\s\d{4}\s\d{4}(?!\d)');
        RegExpMatch? match = aadharRegex.firstMatch(text);
        if (match != null) {
          isValid = true;
          String num = match.group(0)!.replaceAll(' ', '');
          _aadharTextCtrl.text = num;
          message = _text('valid_front');
        } else {
          message = _text('invalid_front');
        }
      } else {
        if (text.toLowerCase().contains("address") ||
            text.toLowerCase().contains("pin") ||
            text.contains(RegExp(r'\d{6}'))) {
          isValid = true;
          message = _text('valid_back');
        } else {
          message = _text('invalid_back');
        }
      }

      if (isValid) {
        setState(() {
          if (isFront)
            _selectedFrontImage = imageFile;
          else
            _selectedBackImage = imageFile;
        });
        _showSnack(message, isError: false);
      } else {
        _showSnack(message, isError: true);
      }
    } catch (e) {
      _showSnack("${_text('scan_failed')}: $e", isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_aadharTextCtrl.text.isEmpty) {
      _showSnack(_text('verify_first'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        String? frontUrl =
            await _uploadFile(_selectedFrontImage, user.id, 'front');
        String? backUrl =
            await _uploadFile(_selectedBackImage, user.id, 'back');

        String finalFrontUrl = frontUrl ?? _existingFrontUrl ?? '';
        String finalBackUrl = backUrl ?? _existingBackUrl ?? '';

        bool isComplete = finalFrontUrl.isNotEmpty &&
            finalBackUrl.isNotEmpty &&
            _aadharTextCtrl.text.isNotEmpty;

        // If complete, set to Verified immediately (matching Buyer logic)
        String status = isComplete ? 'Verified' : 'Pending';

        final Map<String, dynamic> updates = {
          'first_name': _fnameCtrl.text.trim(),
          'middle_name': _mnameCtrl.text.trim(),
          'last_name': _lnameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'state': _selectedStateId,
          'district': _selectedDistrictId,
          'taluka': _selectedTalukaId,
          'village': _selectedVillageId,
          'pincode': _pinCtrl.text.trim(),
          'meta_data': {
            'land_size': _landSize, // Saves the KEY to DB
            'address_line_1': _address1Ctrl.text.trim(),
            'address_line_2': _address2Ctrl.text.trim(),
          },
          'aadhar_number': _aadharTextCtrl.text.trim(),
          'aadhar_front_url': finalFrontUrl,
          'aadhar_back_url': finalBackUrl,
          'verification_status': status, // ✅ Status Update
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('profiles').update(updates).eq('id', user.id);

        if (mounted) {
          _showSnack(_text('profile_saved'), isError: false);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showSnack("${_text('save_error')}: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadFile(File? file, String userId, String side) async {
    if (file == null) return null;
    try {
      final time = DateTime.now().millisecondsSinceEpoch;
      final path = 'id_proofs/${userId}/${side}_$time.jpg';
      await _supabase.storage.from('verification_docs').uploadBinary(
          path, await file.readAsBytes(),
          fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('verification_docs').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
          title: Text(_text('edit_profile_title'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(_text('personal_info'), Icons.person_pin),
                    _buildShadowInput(_text('member_id'), _idCtrl, Icons.badge,
                        isReadOnly: true),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _buildShadowInput(
                              _text('first_name'), _fnameCtrl, Icons.person,
                              isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildShadowInput(_text('middle_name'),
                              _mnameCtrl, Icons.person_outline)),
                    ]),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        _text('last_name'), _lnameCtrl, Icons.person,
                        isRequired: true),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        _text('mobile_number'), _phoneCtrl, Icons.phone,
                        isNumber: true, isRequired: true),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        _text('email_address'), _emailCtrl, Icons.email,
                        isReadOnly: true),

                    const SizedBox(height: 28),
                    _sectionHeader(_text('farm_details'), Icons.agriculture),

                    // ✅ DROPDOWN FIX
                    _buildShadowDropdown(_text('farm_size'), _landSize,
                        _landSizeKeys, (v) => setState(() => _landSize = v)),

                    const SizedBox(height: 28),
                    _sectionHeader(_text('location_address'), Icons.map),
                    _buildLocationDropdown(
                        _text('state'), _selectedStateId, _stateList, (val) {
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
                        _text('district'), _selectedDistrictId, _districtList,
                        (val) {
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
                        _text('taluka'), _selectedTalukaId, _talukaList, (val) {
                      setState(() {
                        _selectedTalukaId = val;
                        _villageList = LocationService.getVillages(
                            _selectedStateId!, _selectedDistrictId!, val!);
                        _selectedVillageId = null;
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildLocationDropdown(
                        _text('village'),
                        _selectedVillageId,
                        _villageList,
                        (val) => setState(() => _selectedVillageId = val)),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        _text('address_line_1'), _address1Ctrl, Icons.home),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        _text('pincode'), _pinCtrl, Icons.pin_drop,
                        isNumber: true),

                    const SizedBox(height: 28),
                    _sectionHeader(
                        _text('verification_strict'), Icons.verified_user),
                    Container(
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
                          Text(_text('aadhar_front_label'),
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          _buildSmartUploadBox(true),
                          const SizedBox(height: 15),
                          Text(_text('aadhar_back_label'),
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          _buildSmartUploadBox(false),
                          const SizedBox(height: 20),
                          _buildShadowInput(_text('aadhar_number_label'),
                              _aadharTextCtrl, Icons.fingerprint,
                              isNumber: true,
                              isRequired: true,
                              isReadOnly: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 8),
                        child: Text(_text('save_verify'),
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

  // --- HELPERS ---
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(children: [
          Container(
              height: 24,
              width: 4,
              decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: _primaryGreen),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ]));
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
        validator: (v) => isRequired && (v == null || v.trim().isEmpty)
            ? "$label ${_text('is_required')}"
            : null,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: _primaryGreen.withOpacity(0.7), size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
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
        // ✅ MAP KEYS TO TRANSLATED VALUES
        items: items
            .map((key) => DropdownMenuItem(
                value:
                    key, // The internal value is the KEY (e.g. '10_plus_acres')
                child: Text(
                    _text(
                        key), // The display is TRANSLATED (e.g. '10+ acres' or '१०+ एकर')
                    style: GoogleFonts.poppins(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.arrow_drop_down_circle,
                color: _primaryGreen.withOpacity(0.7), size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)),
      ),
    );
  }

  Widget _buildLocationDropdown(String label, String? value,
      List<LocalizedItem> items, Function(String?) onChanged) {
    final isMarathi =
        Provider.of<LanguageProvider>(context).appLocale.languageCode == 'mr';

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
                child: Text(e.getName(isMarathi),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.map_outlined,
                color: _primaryGreen.withOpacity(0.7), size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)),
      ),
    );
  }

  Widget _buildSmartUploadBox(bool isFront) {
    File? file = isFront ? _selectedFrontImage : _selectedBackImage;
    String? existingUrl = isFront ? _existingFrontUrl : _existingBackUrl;
    bool hasImage =
        file != null || (existingUrl != null && existingUrl.isNotEmpty);

    if (hasImage) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: file != null
                    ? Image.file(file,
                        fit: BoxFit.cover, width: double.infinity)
                    : Image.network(existingUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (c, e, s) =>
                            const Center(child: Icon(Icons.broken_image)))),
            Positioned(
                right: 10,
                bottom: 10,
                child: InkWell(
                    onTap: () => _pickAndProcessImage(isFront),
                    child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.edit,
                            size: 18, color: Colors.black87)))),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickAndProcessImage(isFront),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_isScanning) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_text('scanning'),
                style: GoogleFonts.poppins(color: _primaryGreen))
          ] else ...[
            Icon(Icons.camera_alt_outlined,
                size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(_text('scan_upload') + " ${isFront ? 'Front' : 'Back'}",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600))
          ]
        ]),
      ),
    );
  }
}
