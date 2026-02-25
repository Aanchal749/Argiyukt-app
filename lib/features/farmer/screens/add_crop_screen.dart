import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class AddCropScreen extends StatefulWidget {
  final Map<String, dynamic>? cropToEdit;

  const AddCropScreen({super.key, this.cropToEdit});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF1B5E20);

  // --- DATA LISTS ---
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
    },
    'Grains': {
      'Wheat': ['Lokwan', 'Sharbati', 'Sihore', 'Durum'],
      'Rice': ['Basmati', 'Indrayani', 'Kolam', 'Sona Masoori'],
      'Maize': ['Sweet Corn', 'Field Corn', 'Baby Corn'],
    }
  };

  final List<String> _gradeOptions = [
    "Grade A (Premium)",
    "Grade B (Standard)",
    "Grade C (Fair)"
  ];

  final List<String> _statusOptions = ["Active", "Sold", "Inactive"];

  // --- CONTROLLERS ---
  String _cropType = "Organic";
  String _status = "Active";
  String? _selectedCategory;
  String? _selectedCrop;
  String? _selectedVariety;
  String? _selectedGrade;
  String? _selectedUnit = "Quintal (q)";

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _harvestDate;
  DateTime? _availableDate;

  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.cropToEdit != null) {
      _isEditMode = true;
      _prefillData(widget.cropToEdit!);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _text(String key) => FarmerText.get(context, key);

  void _prefillData(Map<String, dynamic> c) {
    String dbStatus = c['status'] ?? 'Active';
    if (dbStatus.isNotEmpty) {
      dbStatus =
          dbStatus[0].toUpperCase() + dbStatus.substring(1).toLowerCase();
    }
    _status = _statusOptions.contains(dbStatus) ? dbStatus : 'Active';

    _cropType = c['crop_type'] ?? "Organic";

    String? dbCategory = c['category'];
    _selectedCategory =
        (dbCategory != null && _cropData.containsKey(dbCategory))
            ? dbCategory
            : null;

    String? dbCrop = c['crop_name'];
    List<String> validCrops = _selectedCategory != null
        ? _cropData[_selectedCategory]!.keys.toList()
        : [];
    _selectedCrop =
        (dbCrop != null && validCrops.contains(dbCrop)) ? dbCrop : null;

    String? dbVariety = c['variety'];
    List<String> validVarieties =
        (_selectedCategory != null && _selectedCrop != null)
            ? _cropData[_selectedCategory]![_selectedCrop]!
            : [];
    _selectedVariety = (dbVariety != null && validVarieties.contains(dbVariety))
        ? dbVariety
        : null;

    String? dbGrade = c['grade'];
    _selectedGrade =
        (dbGrade != null && _gradeOptions.contains(dbGrade)) ? dbGrade : null;

    // Prefill Quantity logic (Safely handles both strings and numbers)
    String rawQty = c['quantity']?.toString() ?? "0";
    List<String> qtyParts = rawQty.split(' ');

    if (qtyParts.length >= 2) {
      _qtyCtrl.text = qtyParts[0];
      String unit = qtyParts.sublist(1).join(' ');
      if (["Kg", "Quintal (q)", "Ton", "Crates"].contains(unit)) {
        _selectedUnit = unit;
      }
    } else {
      _qtyCtrl.text = rawQty.replaceAll(RegExp(r'[^0-9.]'), '');
      if (c['unit'] != null) {
        _selectedUnit = c['unit'];
      }
    }

    _priceCtrl.text = (c['price'] ?? 0).toString();
    _notesCtrl.text = c['description'] ?? "";
    _existingImageUrl = c['image_url'];

    if (c['harvest_date'] != null)
      _harvestDate = DateTime.parse(c['harvest_date']);
    if (c['available_from'] != null)
      _availableDate = DateTime.parse(c['available_from']);
  }

  // --- IMAGE PICKER ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Image Error: $e");
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_text('upload_crop_photo'),
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

  // --- SUBMIT LOGIC ---
  Future<void> _submit() async {
    if (_isLoading) return;

    if (_selectedCrop == null ||
        _qtyCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_text('fill_required'), style: GoogleFonts.poppins()),
          backgroundColor: Colors.red));
      return;
    }

    if (!_isEditMode && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_text('upload_crop_photo'), style: GoogleFonts.poppins()),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not logged in";

      // Verify Profile
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('verification_status')
          .eq('id', user.id)
          .maybeSingle();

      final String status =
          profileData?['verification_status'] ?? 'Not Uploaded';

      if (status != 'Verified') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Verification Required",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text(
                  "You must verify your identity before adding crops.",
                  style: GoogleFonts.poppins()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK"))
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last.toLowerCase();
        final safeExt =
            ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

        await Supabase.instance.client.storage.from('crop_images').uploadBinary(
            fileName, await _selectedImage!.readAsBytes(),
            fileOptions: const FileOptions(upsert: true));
        imageUrl = fileName;
      }

      // Safe Data Parsing
      final double parsedQty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
      final double parsedPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

      // 🚨 DATABASE FIX: We now send pure numbers to numeric columns, and text to text columns.
      final Map<String, dynamic> cropData = {
        'farmer_id': user.id,
        'crop_name': _selectedCrop,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'grade': _selectedGrade,
        'quantity': parsedQty, // ✅ Fixed: Sending pure number to match your DB
        'unit':
            _selectedUnit, // ✅ Make sure this column is created in Supabase!
        'price': parsedPrice,
        'crop_type': _cropType,
        'status': _status,
        'harvest_date': _harvestDate?.toIso8601String(),
        'available_from': _availableDate?.toIso8601String(),
        'description': _notesCtrl.text.trim(),
        'image_url': imageUrl,
        if (!_isEditMode) 'created_at': DateTime.now().toIso8601String(),
      };

      if (_isEditMode) {
        await Supabase.instance.client
            .from('crops')
            .update(cropData)
            .eq('id', widget.cropToEdit!['id']);
      } else {
        await Supabase.instance.client.from('crops').insert(cropData);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditMode ? "Crop Updated!" : "Crop Listed!",
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("DB Error: $e", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context);

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_isEditMode ? _text('edit_crop') : _text('add_crop'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_isEditMode && !_isLoading)
              TextButton(
                  onPressed: _submit,
                  child: Text(_text('save'),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)))
          ],
        ),
        body: _isLoading
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
                  controlsBuilder: (context, details) => _buildButtons(details),
                  onStepContinue: () => _currentStep < 2
                      ? setState(() => _currentStep++)
                      : _submit(),
                  onStepCancel: () =>
                      _currentStep > 0 ? setState(() => _currentStep--) : null,
                  steps: _getSteps(),
                ),
              ),
      ),
    );
  }

  Widget _buildButtons(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 20),
      child: Row(children: [
        Expanded(
            child: ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(
                    _currentStep == 2
                        ? (_isEditMode ? _text('update_save') : _text('submit'))
                        : _text('next'),
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)))),
        if (_currentStep > 0) ...[
          const SizedBox(width: 16),
          Expanded(
              child: OutlinedButton(
                  onPressed: details.onStepCancel,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.grey)),
                  child: Text(_text('back'),
                      style: GoogleFonts.poppins(
                          color: Colors.black54, fontWeight: FontWeight.bold))))
        ],
      ]),
    );
  }

  List<Step> _getSteps() {
    return [
      // STEP 1: INFO
      Step(
          title: Text(_text('info'), style: GoogleFonts.poppins(fontSize: 12)),
          isActive: _currentStep >= 0,
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            if (_isEditMode) ...[
              _sectionLabel(_text('status')),
              Container(
                margin: const EdgeInsets.only(bottom: 20, top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _status,
                    items: _statusOptions
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold))))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ),
            ],
            _sectionLabel(_text('farming_type')),
            const SizedBox(height: 10),
            Row(children: [
              _typeBtn(_text('organic'), Colors.green),
              const SizedBox(width: 12),
              _typeBtn(_text('inorganic'), Colors.orange)
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
                (_selectedCategory != null &&
                        _cropData.containsKey(_selectedCategory))
                    ? _cropData[_selectedCategory]!.keys.toList()
                    : [], (val) {
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
                (v) => setState(() => _selectedGrade = v)),
          ])),

      // STEP 2: PRICE
      Step(
          title: Text(_text('price'), style: GoogleFonts.poppins(fontSize: 12)),
          isActive: _currentStep >= 1,
          content: Column(children: [
            const SizedBox(height: 10),
            _inputField("${_text('quantity_avail')} *", _qtyCtrl,
                type: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),
            _dropdown(
                _text('unit'),
                _selectedUnit,
                ["Quintal (q)", "Kg", "Ton", "Crates"],
                (v) => setState(() => _selectedUnit = v)),
            const SizedBox(height: 16),
            _inputField("${_text('price_per_unit')} (₹) *", _priceCtrl,
                type: const TextInputType.numberWithOptions(decimal: true),
                prefix: "₹"),
            const SizedBox(height: 20),
            if (_priceCtrl.text.isNotEmpty && _qtyCtrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.calculate, color: Colors.green),
                  const SizedBox(width: 10),
                  Flexible(
                      child: Text(
                          "${_text('total')}: ₹${((double.tryParse(_qtyCtrl.text) ?? 0) * (double.tryParse(_priceCtrl.text) ?? 0)).toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                              fontSize: 16),
                          overflow: TextOverflow.ellipsis)),
                ]),
              )
          ])),

      // STEP 3: PHOTO
      Step(
          title: Text(_text('pic'), style: GoogleFonts.poppins(fontSize: 12)),
          isActive: _currentStep >= 2,
          content: Column(children: [
            const SizedBox(height: 10),
            _dateBtn(_text('harvest_date'), _harvestDate,
                (d) => setState(() => _harvestDate = d),
                isHarvest: true),
            const SizedBox(height: 16),
            _dateBtn(_text('avail_from'), _availableDate,
                (d) => setState(() => _availableDate = d),
                isHarvest: false),
            const SizedBox(height: 16),

            _inputField(_text('notes'), _notesCtrl,
                type: TextInputType.text, maxLines: 2),

            const SizedBox(height: 20),

            // Image Picker Box
            InkWell(
              onTap: () => _showImagePickerOptions(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_selectedImage != null)
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity))
                      else if (_existingImageUrl != null)
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                                _existingImageUrl!.startsWith('http')
                                    ? _existingImageUrl!
                                    : Supabase.instance.client.storage
                                        .from('crop_images')
                                        .getPublicUrl(_existingImageUrl!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity))
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
                            ]),
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
                              Icon(Icons.edit, size: 20, color: _primaryGreen),
                        ),
                      )
                    ],
                  )),
            ),
          ])),
    ];
  }

  // --- HELPERS ---
  Widget _sectionLabel(String l) => Text(l,
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16));

  Widget _dropdown(String l, String? v, List<String> i, Function(String?) c,
      {bool allowCustom = false}) {
    if (v != null && !i.contains(v)) v = null;
    return DropdownButtonFormField(
        isExpanded: true,
        value: v,
        items: i
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins())))
            .toList(),
        onChanged: c,
        decoration: InputDecoration(
            labelText: l,
            labelStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
  }

  Widget _inputField(String l, TextEditingController ctrl,
          {TextInputType type = TextInputType.text,
          int maxLines = 1,
          String? prefix}) =>
      TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
              labelText: l,
              labelStyle: GoogleFonts.poppins(),
              prefixText: prefix,
              prefixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB)));

  Widget _dateBtn(String l, DateTime? d, Function(DateTime) op,
          {bool isHarvest = false}) =>
      InkWell(
          onTap: () async {
            final p = await showDatePicker(
                context: context,
                initialDate: d ?? DateTime.now(),
                firstDate: isHarvest ? DateTime(2020) : DateTime.now(),
                lastDate: DateTime(2030));
            if (p != null) op(p);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF9FAFB)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d == null ? l : "${d.day}/${d.month}/${d.year}",
                        style: GoogleFonts.poppins(
                            color: d == null ? Colors.grey[700] : Colors.black,
                            fontSize: 16)),
                    const Icon(Icons.calendar_today,
                        size: 20, color: Colors.green)
                  ])));

  Widget _typeBtn(String t, Color c) => Expanded(
      child: GestureDetector(
          onTap: () => setState(() => _cropType = t),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: _cropType == t ? c : Colors.white,
                  border: Border.all(
                      color: _cropType == t ? c : Colors.grey.shade300,
                      width: _cropType == t ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _cropType == t
                      ? [
                          BoxShadow(
                              color: c.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : []),
              child: Center(
                  child: Text(t,
                      style: GoogleFonts.poppins(
                          color: _cropType == t ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold))))));
}
