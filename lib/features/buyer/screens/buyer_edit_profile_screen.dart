import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agriyukt_app/core/services/location_service.dart';

class BuyerEditProfileScreen extends StatefulWidget {
  const BuyerEditProfileScreen({super.key});

  @override
  State<BuyerEditProfileScreen> createState() => _BuyerEditProfileScreenState();
}

class _BuyerEditProfileScreenState extends State<BuyerEditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;

  // --- 1. CONTROLLERS ---
  final _idCtrl = TextEditingController(); // Member ID
  final _fnameCtrl = TextEditingController();
  final _mnameCtrl = TextEditingController();
  final _lnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Buyer Specific
  final _gstCtrl = TextEditingController();
  final _companyCtrl = TextEditingController(); // Organization/Company Name

  // Address
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Identity
  final _aadharTextCtrl = TextEditingController();

  // --- 2. BUYER SPECIFIC ---
  String? _buyerType;
  final List<String> _buyerTypes = [
    'Wholesaler',
    'Retailer',
    'Exporter',
    'Processor',
    'FPO'
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

  // --- 4. VERIFICATION ---
  File? _selectedFrontImage;
  File? _selectedBackImage;
  String? _existingFrontUrl;
  String? _existingBackUrl;
  bool _isVerified = false;

  // Theme Colors (Buyer Blue)
  final Color _primaryBlue = const Color(0xFF1565C0);
  final Color _bgOffWhite = const Color(0xFFF8F9FC);

  @override
  void initState() {
    super.initState();
    _loadStates();
    _loadUserProfile();
  }

  void _loadStates() {
    setState(() {
      _stateList = LocationService.getStates();
    });
  }

  // ===========================================================================
  // 📥 INITIALIZATION
  // ===========================================================================
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
            // Member ID
            String memberId = data['member_id'] ?? '';
            if (memberId.isEmpty) {
              memberId = "#${user.id.substring(0, 5).toUpperCase()}";
            }
            _idCtrl.text = memberId;

            // Personal
            _fnameCtrl.text = data['first_name'] ?? "";
            _mnameCtrl.text = data['middle_name'] ?? "";
            _lnameCtrl.text = data['last_name'] ?? "";
            _phoneCtrl.text = data['phone'] ?? "";
            _emailCtrl.text = data['email'] ?? user.email ?? "";

            // Meta Data (Buyer Specific)
            final meta = data['meta_data'] ?? {};
            _buyerType = meta['buyer_type'];
            if (_buyerType != null && !_buyerTypes.contains(_buyerType))
              _buyerType = null;

            _gstCtrl.text = meta['gst_number'] ?? "";
            _companyCtrl.text = meta['company_name'] ?? "";

            // Address
            _address1Ctrl.text = meta['address_line_1'] ?? "";
            _address2Ctrl.text = meta['address_line_2'] ?? "";

            // Location
            _selectedStateId = data['state'];
            _pinCtrl.text = data['pincode'] ?? "";

            // Identity
            _aadharTextCtrl.text = data['aadhar_number'] ?? "";
            _existingFrontUrl = data['aadhar_front_url'];
            _existingBackUrl = data['aadhar_back_url'];

            _isVerified = (_existingFrontUrl != null &&
                _existingFrontUrl!.isNotEmpty &&
                _existingBackUrl != null &&
                _existingBackUrl!.isNotEmpty &&
                _aadharTextCtrl.text.isNotEmpty);

            // Chain Load Location Logic
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
      debugPrint("Error loading: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 📸 IDENTITY LOGIC
  // ===========================================================================
  Future<void> _pickIdImage(bool isFront) async {
    try {
      final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() {
          if (isFront) {
            _selectedFrontImage = File(file.path);
          } else {
            _selectedBackImage = File(file.path);
          }
        });
      }
    } catch (e) {
      debugPrint("Image Error: $e");
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
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // ===========================================================================
  // 💾 SAVE LOGIC
  // ===========================================================================
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Upload Images
        String? frontUrl =
            await _uploadFile(_selectedFrontImage, user.id, 'front');
        String? backUrl =
            await _uploadFile(_selectedBackImage, user.id, 'back');

        String finalFrontUrl = frontUrl ?? _existingFrontUrl ?? '';
        String finalBackUrl = backUrl ?? _existingBackUrl ?? '';

        String status = (finalFrontUrl.isNotEmpty &&
                finalBackUrl.isNotEmpty &&
                _aadharTextCtrl.text.isNotEmpty)
            ? 'Verified'
            : 'Pending';

        // 2. Prepare Buyer Meta Data
        final Map<String, dynamic> metaDataToSave = {
          'buyer_type': _buyerType,
          'gst_number': _gstCtrl.text.trim(),
          'company_name': _companyCtrl.text.trim(),
          'address_line_1': _address1Ctrl.text.trim(),
          'address_line_2': _address2Ctrl.text.trim(),
        };

        // 3. Update Profile
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
          'meta_data': metaDataToSave,

          // Identity
          'aadhar_number': _aadharTextCtrl.text.trim(),
          'aadhar_front_url': finalFrontUrl,
          'aadhar_back_url': finalBackUrl,
          'verification_status': status,

          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('profiles').update(updates).eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text("✅ Buyer Profile Saved!", style: GoogleFonts.poppins()),
              backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🎨 UI BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
          title: Text("Edit Buyer Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PERSONAL INFO
                    _sectionHeader("Personal Info", Icons.person_pin),
                    _buildShadowInput("Member ID", _idCtrl, Icons.badge,
                        isReadOnly: true),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _buildShadowInput(
                              "First Name", _fnameCtrl, Icons.person,
                              isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildShadowInput(
                              "Middle Name", _mnameCtrl, Icons.person_outline)),
                    ]),
                    const SizedBox(height: 12),
                    _buildShadowInput("Last Name", _lnameCtrl, Icons.person,
                        isRequired: true),
                    const SizedBox(height: 12),
                    _buildShadowInput("Mobile Number", _phoneCtrl, Icons.phone,
                        isNumber: true, isReadOnly: false),
                    const SizedBox(height: 12),
                    _buildShadowInput("Email Address", _emailCtrl, Icons.email,
                        isReadOnly: true),

                    const SizedBox(height: 28),

                    // 2. BUSINESS DETAILS (Buyer Specific)
                    _sectionHeader("Business Details", Icons.business_center),
                    _buildShadowInput(
                        "Company Name", _companyCtrl, Icons.store),
                    const SizedBox(height: 12),
                    _buildShadowDropdown("Buyer Type", _buyerType, _buyerTypes,
                        (v) => setState(() => _buyerType = v)),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        "GST Number", _gstCtrl, Icons.receipt_long),

                    const SizedBox(height: 28),

                    // 3. LOCATION & ADDRESS
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
                        LocationService.isUrban(_selectedDistrictId ?? "")
                            ? "Ward"
                            : "Taluka",
                        _selectedTalukaId,
                        _talukaList, (val) {
                      setState(() {
                        _selectedTalukaId = val;
                        _villageList = LocationService.getVillages(
                            _selectedStateId!, _selectedDistrictId!, val!);
                        _selectedVillageId = null;
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildLocationDropdown(
                        LocationService.isUrban(_selectedDistrictId ?? "")
                            ? "Locality"
                            : "Village",
                        _selectedVillageId,
                        _villageList,
                        (val) => setState(() => _selectedVillageId = val)),

                    const SizedBox(height: 12),
                    _buildShadowInput(
                        "Address Line 1", _address1Ctrl, Icons.home),
                    const SizedBox(height: 12),
                    _buildShadowInput(
                        "Address Line 2", _address2Ctrl, Icons.home_work),
                    const SizedBox(height: 12),
                    _buildShadowInput("Pincode", _pinCtrl, Icons.pin_drop,
                        isNumber: true),

                    const SizedBox(height: 28),

                    // 4. VERIFICATION
                    _sectionHeader("Verification", Icons.verified_user),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Identity Proof",
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryBlue)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _isVerified
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _isVerified
                                            ? Colors.green
                                            : Colors.orange,
                                        width: 1)),
                                child: Text(
                                    _isVerified ? "Uploaded" : "Pending",
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _isVerified
                                            ? Colors.green
                                            : Colors.orange)),
                              )
                            ],
                          ),
                          const SizedBox(height: 15),

                          // Front
                          Text("Aadhaar Front",
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          _buildDocumentUploadBox(true),

                          const SizedBox(height: 15),

                          // Back
                          Text("Aadhaar Back",
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          _buildDocumentUploadBox(false),

                          const SizedBox(height: 20),

                          // Number
                          _buildShadowInput("Aadhar Number", _aadharTextCtrl,
                              Icons.fingerprint,
                              isNumber: true, isRequired: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            shadowColor: _primaryBlue.withOpacity(0.4),
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
                  color: _primaryBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: _primaryBlue),
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
            ? "$label is required"
            : null,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon:
              Icon(icon, color: _primaryBlue.withOpacity(0.7), size: 20),
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
            prefixIcon: Icon(Icons.arrow_drop_down_circle,
                color: _primaryBlue.withOpacity(0.7), size: 20),
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
                child: Text(e.getName(false),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            labelStyle:
                GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: Icon(Icons.map_outlined,
                color: _primaryBlue.withOpacity(0.7), size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      ),
    );
  }

  Widget _buildDocumentUploadBox(bool isFront) {
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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover, width: double.infinity)
                  : Image.network(existingUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (c, e, s) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey))),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: InkWell(
                onTap: () => _pickIdImage(isFront),
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
      onTap: () => _pickIdImage(isFront),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text("Tap to Upload ${isFront ? 'Front' : 'Back'}",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13))
          ],
        ),
      ),
    );
  }
}
