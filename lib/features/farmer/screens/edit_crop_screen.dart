import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';

class EditCropScreen extends StatefulWidget {
  final Map<String, dynamic> cropData;

  const EditCropScreen({super.key, required this.cropData});

  @override
  State<EditCropScreen> createState() => _EditCropScreenState();
}

class _EditCropScreenState extends State<EditCropScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF1B5E20);

  // --- DATA SOURCE ---
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
  final List<String> _statusOptions = ['Active', 'Sold', 'Inactive'];
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

  // ✅ Helper for Localized Text
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

    String dbVariety = _safeString(c['variety']);
    List<String> validVarieties =
        (_selectedCategory != null && _selectedCrop != null)
            ? _cropData[_selectedCategory]![_selectedCrop]!
            : [];
    _selectedVariety = validVarieties.contains(dbVariety) ? dbVariety : null;

    String dbGrade = _safeString(c['grade']);
    _selectedGrade = _gradeOptions.contains(dbGrade) ? dbGrade : null;

    _cropType = _safeString(c['crop_type'], "Organic");
    if (!["Organic", "Inorganic"].contains(_cropType)) _cropType = "Organic";

    // ✅ SMART PARSER: Checks for old vs new column names
    String rawQty =
        _safeString(c['quantity_kg'], _safeString(c['quantity'], "0"));
    String qtyVal = "0";
    String parsedUnit = _safeString(c['unit'], "Quintal (q)");

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
    if (qtyVal.isEmpty) qtyVal = "0";

    _selectedUnit = parsedUnit;
    _qtyCtrl.text = qtyVal;

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
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 70);
      if (file != null) {
        setState(() => _selectedImage = File(file.path));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Image Error: $e");
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
            Icon(icon, size: 32, color: _primaryGreen),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 12))
          ],
        ),
      ),
    );
  }

  // 🛡️ CRITICAL FIX: The Intelligent Update Engine
  Future<void> _updateCrop(String fillReqMsg, String updatedMsg) async {
    if (_selectedCrop == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(fillReqMsg, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null && user != null) {
        final ext = _selectedImage!.path.split('.').last;
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await Supabase.instance.client.storage.from('crop_images').uploadBinary(
            fileName, await _selectedImage!.readAsBytes(),
            fileOptions: const FileOptions(upsert: true));
        imageUrl = fileName;
      }

      String englishNotes = await TranslationService.toEnglish(_notesCtrl.text);

      final double parsedQty =
          double.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
      final double parsedPrice =
          double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;

      // Base Data that ALWAYS exists
      final Map<String, dynamic> data = {
        'crop_name': _selectedCrop,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'grade': _selectedGrade,
        'unit': _selectedUnit,
        'crop_type': _cropType,
        'description': englishNotes,
        'status': _status,
      };

      // 🧠 DYNAMIC COLUMN TARGETING
      // If the database gave us these columns, we must update them to ensure the UI changes.
      if (widget.cropData.containsKey('quantity_kg'))
        data['quantity_kg'] = parsedQty;
      if (widget.cropData.containsKey('quantity'))
        data['quantity'] = parsedQty; // Legacy fallback

      if (widget.cropData.containsKey('price_per_qty'))
        data['price_per_qty'] = parsedPrice;
      if (widget.cropData.containsKey('price'))
        data['price'] = parsedPrice; // Legacy fallback

      if (imageUrl != null) data['image_url'] = imageUrl;
      if (_harvestDate != null)
        data['harvest_date'] = _harvestDate!.toIso8601String();
      if (_availableDate != null)
        data['available_from'] = _availableDate!.toIso8601String();

      // EXECUTE UPDATE
      await Supabase.instance.client
          .from('crops')
          .update(data)
          .eq('id', widget.cropData['id']);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(updatedMsg, style: GoogleFonts.poppins()),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titleCropName =
        _selectedCrop ?? _safeString(widget.cropData['crop_name'], 'Crop');

    final String msgFillRequired = _text('fill_required');
    final String msgCropUpdated = _text('crop_updated');
    final String msgUploadPhoto = _text('upload_crop_photo');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${_text('edit_crop')} ($titleCropName)",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryGreen))
            : Theme(
                data: ThemeData(
                  colorScheme: ColorScheme.light(primary: _primaryGreen),
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
                          Expanded(
                            child: ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                _currentStep == 2
                                    ? _text('update_save')
                                    : _text('next'),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ),
                          if (_currentStep > 0) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: details.onStepCancel,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(_text('back'),
                                    style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ]
                        ],
                      ),
                    );
                  },
                  onStepContinue: () {
                    if (_currentStep < 2) {
                      setState(() => _currentStep += 1);
                    } else {
                      _updateCrop(msgFillRequired, msgCropUpdated);
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) setState(() => _currentStep -= 1);
                  },
                  steps: _getSteps(msgUploadPhoto),
                ),
              ),
      ),
    );
  }

  List<Step> _getSteps(String msgUploadPhoto) {
    return [
      Step(
        title: Text(_text('info'), style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 0,
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
                  Text(_text('current_status'),
                      style: GoogleFonts.poppins(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 5),
                  _dropdown(_text('status'), _status, _statusOptions,
                      (val) => setState(() => _status = val!)),
                ],
              ),
            ),
            Row(children: [
              _typeButton("Organic", Colors.green),
              const SizedBox(width: 10),
              _typeButton("Inorganic", Colors.orange),
            ]),
            const SizedBox(height: 20),
            _dropdown("${_text('category')} *", _selectedCategory,
                ['Vegetables', 'Fruits', 'Grains'], (val) {
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
            _dropdown(
                _text('variety'),
                _selectedVariety,
                (_selectedCategory != null && _selectedCrop != null)
                    ? _cropData[_selectedCategory]![_selectedCrop]!
                    : [],
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
        content: Column(
          children: [
            const SizedBox(height: 10),
            _inputField("${_text('quantity_avail')} *", _qtyCtrl,
                type: TextInputType.number),
            const SizedBox(height: 16),
            _dropdown(_text('unit'), _selectedUnit, _unitOptions,
                (val) => setState(() => _selectedUnit = val)),
            const SizedBox(height: 16),
            _inputField("${_text('price_per_unit')} (₹) *", _priceCtrl,
                type: TextInputType.number, prefix: "₹"),
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
                          "${_text('total')}: ₹${((double.tryParse(_qtyCtrl.text) ?? 0.0) * (double.tryParse(_priceCtrl.text) ?? 0.0)).toStringAsFixed(0)}",
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
                          child: _existingImageUrl!.startsWith('http')
                              ? Image.network(_existingImageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover)
                              : Image.network(
                                  Supabase.instance.client.storage
                                      .from('crop_images')
                                      .getPublicUrl(_existingImageUrl!),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover))
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
                        child: Icon(Icons.edit, size: 20, color: _primaryGreen),
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
            _inputField(_text('notes'), _notesCtrl, maxLines: 3),
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
    if (value != null && !items.contains(value)) value = null;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(
              value: e, child: Text(e, style: GoogleFonts.poppins())))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
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
      style: GoogleFonts.poppins(),
      onChanged: (val) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixText: prefix,
        prefixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
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
            lastDate: DateTime(2030));
        if (d != null) onConfirm(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                date == null ? label : "${date.day}/${date.month}/${date.year}",
                style: GoogleFonts.poppins(
                    color: date == null ? Colors.grey[700] : Colors.black,
                    fontSize: 16)),
            const Icon(Icons.calendar_today, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
