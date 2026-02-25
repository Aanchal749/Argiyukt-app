import 'dart:io';
import 'dart:async'; // 🚀 PRODUCTION FIX: Required for network timeouts
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';

class InspectorEditCropScreen extends StatefulWidget {
  final Map<String, dynamic> cropData;
  final String farmerId;

  const InspectorEditCropScreen({
    super.key,
    required this.cropData,
    required this.farmerId,
  });

  @override
  State<InspectorEditCropScreen> createState() =>
      _InspectorEditCropScreenState();
}

class _InspectorEditCropScreenState extends State<InspectorEditCropScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _canPop = false; // 🚀 Prevents accidental back-swipe data loss

  // 🎨 STRICT THEME COLOR: Inspector Purple
  final Color _inspectorColor = const Color(0xFF512DA8);

  // --- DATA SOURCE (Strictly Vegetables & Fruits) ---
  final Map<String, Map<String, List<String>>> _cropData = {
    'Vegetables': {
      'Tomato': [
        'Hybrid Tomato',
        'Roma Tomato',
        'Local Desi',
        'Cherry Tomato',
        'Beefsteak'
      ],
      'Onion': [
        'Red Onion',
        'White Onion',
        'Yellow Onion',
        'Bhima Super',
        'N-53'
      ],
      'Potato': ['Kufri Jyoti', 'Kufri Lauvkar', 'Chipsona', 'Rosetta'],
      'Brinjal': ['Manjari Gota', 'Pusa Purple', 'Vengurla', 'Bharit'],
      'Chilli': ['Pusa Jwala', 'G-4', 'Sankeshwari', 'Byadgi', 'Sitara'],
      'Ladyfinger (Okra)': ['Arka Anamika', 'Parbhani Kranti', 'Hybrid Okra'],
      'Cabbage': ['Golden Acre', 'Green Express', 'Red Cabbage'],
    },
    'Fruits': {
      'Mango': ['Alphonso (Hapus)', 'Kesar', 'Dasheri', 'Langra', 'Totapuri'],
      'Banana': ['Grand Naine (G-9)', 'Robusta', 'Yellaki', 'Nendran'],
      'Grapes': ['Thompson Seedless', 'Sonaka', 'Manik Chaman', 'Red Globe'],
      'Orange': ['Nagpur Orange', 'Mosambi', 'Kinnow'],
      'Pomegranate': ['Bhagwa', 'Ganesh', 'Arakta'],
      'Papaya': ['Red Lady', 'Taiwan 786', 'Washington'],
    }
  };

  final List<String> _gradeOptions = [
    "Grade A (Premium)",
    "Grade B (Standard)",
    "Grade C (Fair)"
  ];

  final List<String> _statusOptions = [
    'Active',
    'Sold',
    'Inactive',
  ];

  final List<String> _unitOptions = ["Kg", "Quintal (q)", "Ton", "Crates"];

  // --- CONTROLLERS ---
  String _status = 'Active';
  String _cropType = "Organic";
  String? _selectedCategory;
  String? _selectedCrop;
  String? _selectedVariety;
  String? _selectedGrade;
  String? _selectedUnit = "Quintal (q)";

  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;

  DateTime? _harvestDate;
  DateTime? _availableDate;

  // --- IMAGE ---
  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  String _text(String key) => FarmerText.get(context, key);

  String _safeString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: "0");
    _priceCtrl = TextEditingController(text: "0");
    _notesCtrl = TextEditingController(text: "");

    _prefillData();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefillData() {
    final c = widget.cropData;

    String dbStatus = _safeString(c['status'], 'Active');
    if (dbStatus.isNotEmpty) {
      dbStatus =
          dbStatus[0].toUpperCase() + dbStatus.substring(1).toLowerCase();
    }
    _status = _statusOptions.contains(dbStatus) ? dbStatus : 'Active';

    String dbCategory = _safeString(c['category']);
    _selectedCategory = _cropData.containsKey(dbCategory) ? dbCategory : null;

    String dbCrop = _safeString(c['crop_name'], _safeString(c['name']));
    List<String> validCrops = _selectedCategory != null
        ? _cropData[_selectedCategory]!.keys.toList()
        : [];
    _selectedCrop = validCrops.contains(dbCrop) ? dbCrop : null;

    _selectedVariety = _safeString(c['variety']);
    if (_selectedVariety!.isEmpty) _selectedVariety = null;

    String dbGrade = _safeString(c['grade']);
    _selectedGrade = _gradeOptions.contains(dbGrade) ? dbGrade : null;

    _cropType = _safeString(c['crop_type'], "Organic");
    if (!["Organic", "Inorganic"].contains(_cropType)) _cropType = "Organic";

    String rawQty =
        _safeString(c['quantity'], _safeString(c['quantity_kg'], "0"));
    String qtyVal = "0";
    String parsedUnit = _safeString(c['unit'], "Kg");

    if (rawQty.contains(' ') && c['unit'] == null) {
      List<String> parts = rawQty.split(' ');
      qtyVal = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');
      String unitPart = parts.sublist(1).join(' ').trim();
      for (var u in _unitOptions) {
        if (u.toLowerCase() == unitPart.toLowerCase()) {
          parsedUnit = u;
          break;
        }
      }
    } else {
      qtyVal = rawQty.replaceAll(RegExp(r'[^0-9.]'), '');
    }

    _qtyCtrl.text = qtyVal.isEmpty ? "0" : qtyVal;
    _selectedUnit = parsedUnit;

    _priceCtrl.text =
        _safeString(c['price_per_qty'], _safeString(c['price'], '0'));
    _notesCtrl.text = _safeString(c['description']);

    String img = _safeString(c['image_url']);
    _existingImageUrl = img.isNotEmpty ? img : null;

    try {
      String hDate = _safeString(c['harvest_date']);
      if (hDate.isNotEmpty) _harvestDate = DateTime.tryParse(hDate);

      String aDate = _safeString(c['available_from']);
      if (aDate.isNotEmpty) _availableDate = DateTime.tryParse(aDate);
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (file != null) {
        setState(() => _selectedImage = File(file.path));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Image Error: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating));
  }

  void _handleStepContinue() {
    // 🚀 PRODUCTION FIX: Concurrency Lock prevents Double-Taps
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      if (_selectedCategory == null || _selectedCrop == null) {
        return _showError("Please select a Category and Crop Name.");
      }
      if (_selectedVariety == null) {
        return _showError("Please select a Crop Variety.");
      }
    }

    if (_currentStep == 1) {
      if (_qtyCtrl.text.trim().isEmpty ||
          double.tryParse(_qtyCtrl.text.replaceAll(',', '')) == null) {
        return _showError("Please enter a valid Quantity.");
      }
      if (_priceCtrl.text.trim().isEmpty ||
          double.tryParse(_priceCtrl.text.replaceAll(',', '')) == null) {
        return _showError("Please enter a valid Price.");
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      _updateCrop();
    }
  }

  void _showImagePickerOptions(String uploadPhotoText) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(uploadPhotoText,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOption(Icons.camera_alt, "Camera", ImageSource.camera),
                _pickerOption(
                    Icons.photo_library, "Gallery", ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, ImageSource src) {
    return InkWell(
      onTap: () => _pickImage(src),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!)),
        child: Column(
          children: [
            Icon(icon, size: 32, color: _inspectorColor),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 12))
          ],
        ),
      ),
    );
  }

  Future<void> _updateCrop() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null && user != null) {
        final ext = _selectedImage!.path.split('.').last.toLowerCase();
        final safeExt =
            ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
        final fileName =
            'crops/${DateTime.now().millisecondsSinceEpoch}_${user.id}.$safeExt';

        // 🚀 PRODUCTION FIX: Strict 30-Second Timeout for 2G Networks
        await Supabase.instance.client.storage
            .from('crop_images')
            .uploadBinary(fileName, await _selectedImage!.readAsBytes(),
                fileOptions: const FileOptions(upsert: true))
            .timeout(const Duration(seconds: 30),
                onTimeout: () =>
                    throw "Image upload timed out. Check your internet.");

        imageUrl = Supabase.instance.client.storage
            .from('crop_images')
            .getPublicUrl(fileName);
      }

      String englishNotes = _notesCtrl.text.trim();
      try {
        if (englishNotes.isNotEmpty) {
          englishNotes = await TranslationService.toEnglish(englishNotes);
        }
      } catch (_) {
        // Fallback: Save local notes if translation API fails
      }

      final double parsedQty =
          double.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
      final double parsedPrice =
          double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;

      double finalKg = parsedQty;
      if (_selectedUnit == 'Quintal (q)') {
        finalKg = parsedQty * 100;
      } else if (_selectedUnit == 'Ton') {
        finalKg = parsedQty * 1000;
      }

      final Map<String, dynamic> data = {
        'farmer_id': widget.farmerId,
        'inspector_id': user?.id,
        'crop_name': _selectedCrop,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'grade': _selectedGrade,
        'unit': _selectedUnit,
        'crop_type': _cropType,
        'description': englishNotes,
        'status': _status,
        'updated_at': DateTime.now().toIso8601String(),
        'quantity': parsedQty,
        'quantity_kg': finalKg,
        'price': parsedPrice,
      };

      if (widget.cropData.containsKey('price_per_qty')) {
        data['price_per_qty'] = parsedPrice;
      }

      if (imageUrl != null) data['image_url'] = imageUrl;
      if (_harvestDate != null)
        data['harvest_date'] = _harvestDate!.toIso8601String();
      if (_availableDate != null)
        data['available_from'] = _availableDate!.toIso8601String();

      // 🚀 PRODUCTION FIX: Strict 15-Second Timeout for DB Saves
      await Supabase.instance.client
          .from('crops')
          .update(data)
          .eq('id', widget.cropData['id'])
          .timeout(const Duration(seconds: 15),
              onTimeout: () => throw "Database update timed out.");

      if (mounted) {
        setState(() => _canPop = true);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Crop Updated Successfully!",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.green.shade700));
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll(RegExp(r'Exception:\s*'), "");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMsg, style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titleCropName =
        _selectedCrop ?? _safeString(widget.cropData['crop_name'], 'Crop');
    final String msgUploadPhoto = _text('upload_crop_photo');

    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_isLoading) return;

        final bool? discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Discard Changes?",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
                "Are you sure you want to go back? Unsaved changes will be lost.",
                style: GoogleFonts.poppins(fontSize: 14)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("KEEP EDITING",
                      style: GoogleFonts.poppins(
                          color: _inspectorColor,
                          fontWeight: FontWeight.bold))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700, elevation: 0),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text("DISCARD",
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        );

        if (discard == true && mounted) {
          setState(() => _canPop = true);
          Navigator.pop(context);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text("Edit: $titleCropName",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: _inspectorColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Theme(
                  data: ThemeData(
                    colorScheme: ColorScheme.light(primary: _inspectorColor),
                    canvasColor: Colors.white,
                  ),
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: _currentStep,
                    elevation: 0,
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 30, bottom: 20),
                        child: Row(
                          children: [
                            if (_currentStep > 0) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: details.onStepCancel,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(color: _inspectorColor),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(_text('back'),
                                      style: GoogleFonts.poppins(
                                          color: _inspectorColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: details.onStepContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _inspectorColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                ),
                                child: Text(
                                  _currentStep == 2
                                      ? "SAVE CROP"
                                      : _text('next'),
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onStepContinue: _handleStepContinue,
                    onStepCancel: () {
                      if (_currentStep > 0) setState(() => _currentStep -= 1);
                    },
                    steps: _getSteps(msgUploadPhoto),
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10)
                            ]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _inspectorColor),
                            const SizedBox(height: 16),
                            Text("Saving Crop...",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: _inspectorColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Step> _getSteps(String msgUploadPhoto) {
    List<String> validVarieties =
        (_selectedCategory != null && _selectedCrop != null)
            ? _cropData[_selectedCategory]![_selectedCrop]!
            : [];

    return [
      Step(
        title: Text(_text('info'), style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Crop Status",
                      style: GoogleFonts.poppins(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 5),
                  _dropdown("Status", _status, _statusOptions,
                      (val) => setState(() => _status = val!)),
                ],
              ),
            ),
            Row(children: [
              _typeButton("Organic", Colors.green.shade600),
              const SizedBox(width: 10),
              _typeButton("Inorganic", Colors.orange.shade600),
            ]),
            const SizedBox(height: 20),
            _dropdown("${_text('category')} *", _selectedCategory,
                ['Vegetables', 'Fruits'], (val) {
              setState(() {
                _selectedCategory = val;
                _selectedCrop = null;
                _selectedVariety = null;
              });
            }),
            const SizedBox(height: 16),
            _dropdown(
                "${_text('crop_name')} *",
                _selectedCrop,
                _selectedCategory == null
                    ? []
                    : _cropData[_selectedCategory]!.keys.toList(), (val) {
              setState(() {
                _selectedCrop = val;
                _selectedVariety = null;
              });
            }),
            const SizedBox(height: 16),
            _dropdown(_text('variety'), _selectedVariety, validVarieties,
                (val) => setState(() => _selectedVariety = val)),
            const SizedBox(height: 16),
            _dropdown(_text('grade'), _selectedGrade, _gradeOptions,
                (val) => setState(() => _selectedGrade = val)),
          ],
        ),
      ),
      Step(
        title: Text(_text('price'), style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            const SizedBox(height: 10),
            _inputField("Quantity *", _qtyCtrl,
                type: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),
            _dropdown(_text('unit'), _selectedUnit, _unitOptions,
                (val) => setState(() => _selectedUnit = val)),
            const SizedBox(height: 16),
            _inputField("Price/Unit (₹) *", _priceCtrl,
                type: const TextInputType.numberWithOptions(decimal: true),
                prefix: "₹"),
            const SizedBox(height: 20),
            if (_priceCtrl.text.isNotEmpty && _qtyCtrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!)),
                child: Row(
                  children: [
                    const Icon(Icons.calculate, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          "${_text('total')}: ₹${((double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0.0) * (double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0.0)).toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                              fontSize: 16)),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
      Step(
        title: Text(_text('pic'), style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 2,
        content: Column(
          children: [
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showImagePickerOptions(msgUploadPhoto),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImage != null)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover))
                    else if (_existingImageUrl != null)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _existingImageUrl!.startsWith('http')
                                ? _existingImageUrl!
                                : Supabase.instance.client.storage
                                    .from('crop_images')
                                    .getPublicUrl(_existingImageUrl!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    size: 40, color: Colors.grey.shade400),
                                Text("Image Unavailable",
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey)),
                              ],
                            ),
                          ))
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo,
                              size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(_text('tap_to_add_photo'),
                              style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(blurRadius: 5, color: Colors.black26)
                            ]),
                        child:
                            Icon(Icons.edit, size: 20, color: _inspectorColor),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _datePicker(_text('harvest_date'), _harvestDate,
                (d) => setState(() => _harvestDate = d)),
            const SizedBox(height: 12),
            _datePicker(_text('avail_from'), _availableDate,
                (d) => setState(() => _availableDate = d)),
            const SizedBox(height: 20),
            _inputField("Inspector Remarks / Issues", _notesCtrl, maxLines: 3),
          ],
        ),
      ),
    ];
  }

  Widget _typeButton(String type, Color color) {
    bool isSelected = _cropType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cropType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: Text(type,
                style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    final List<String> safeItems = List.from(items);
    if (value != null && value.isNotEmpty && !safeItems.contains(value)) {
      safeItems.insert(0, value);
    }

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: safeItems
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
          .toList(),
      onChanged: safeItems.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _inspectorColor, width: 2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      String? prefix}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      onChanged: (val) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        prefixText: prefix,
        prefixStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, color: Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _inspectorColor, width: 2)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _datePicker(
      String label, DateTime? date, Function(DateTime) onConfirm) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                      primary: _inspectorColor,
                      onPrimary: Colors.white,
                      onSurface: Colors.black),
                ),
                child: child!,
              );
            });
        if (d != null) onConfirm(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                date == null ? label : "${date.day}/${date.month}/${date.year}",
                style: GoogleFonts.poppins(
                    color: date == null ? Colors.grey[600] : Colors.black87,
                    fontSize: 14)),
            Icon(Icons.calendar_today, color: _inspectorColor, size: 20),
          ],
        ),
      ),
    );
  }
}
