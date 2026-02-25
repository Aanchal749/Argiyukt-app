import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class AddCropTab extends StatefulWidget {
  final Map<String, dynamic>? cropToEdit;
  // 🛡️ PRODUCTION FIX: Allow Inspectors to pass a specific farmer's ID
  final String? farmerId;

  const AddCropTab({
    super.key,
    this.cropToEdit,
    this.farmerId, // ✅ Added to constructor
  });

  @override
  State<AddCropTab> createState() => _AddCropTabState();
}

class _AddCropTabState extends State<AddCropTab> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isEditMode = false;

  // 🎨 Premium Theme Colors
  final Color _primaryGreen = const Color(0xFF1B5E20);
  final Color _surfaceColor = const Color(0xFFF4F6F8);
  final Color _inputFillColor = const Color(0xFFFFFFFF);

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
  final List<String> _statusOptions = ['Active', 'Sold', 'Inactive'];

  // --- CONTROLLERS ---
  String _status = 'Active';
  String _cropType = "Organic";
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

  // --- IMAGE LOGIC ---
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

    // 🛡️ PRODUCTION FIX: Real-time Total Calculator
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  // 🛡️ PRODUCTION FIX: Prevent Memory Leaks
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
    if (dbCategory != null && _cropData.containsKey(dbCategory)) {
      _selectedCategory = dbCategory;
    }

    String? dbCrop = c['crop_name'];
    if (_selectedCategory != null) {
      List<String> validCrops = _cropData[_selectedCategory]!.keys.toList();
      if (validCrops.contains(dbCrop)) _selectedCrop = dbCrop;
    }

    String? dbVariety = c['variety'];
    if (_selectedCategory != null && _selectedCrop != null) {
      List<String> validVarieties =
          _cropData[_selectedCategory]![_selectedCrop]!;
      if (validVarieties.contains(dbVariety)) _selectedVariety = dbVariety;
    }

    String? dbGrade = c['grade'];
    if (_gradeOptions.contains(dbGrade)) _selectedGrade = dbGrade;

    // ✅ DATABASE ALIGNMENT: Read pure numbers safely from numeric columns
    String rawQty = (c['quantity'] ?? c['quantity_kg'] ?? 0).toString();
    _qtyCtrl.text = rawQty.replaceAll(
        RegExp(r"([.]*0)(?!.*\d)"), ""); // removes trailing .0

    String? dbUnit = c['unit'];
    if (dbUnit != null &&
        ["Kg", "Quintal (q)", "Ton", "Crates"].contains(dbUnit)) {
      _selectedUnit = dbUnit;
    }

    _priceCtrl.text =
        (c['price'] ?? 0).toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
    _notesCtrl.text = c['description'] ?? "";
    _existingImageUrl = c['image_url'];

    if (c['harvest_date'] != null) {
      _harvestDate = DateTime.parse(c['harvest_date']);
    }
    if (c['available_from'] != null) {
      _availableDate = DateTime.parse(c['available_from']);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // 🛡️ PRODUCTION FIX: OOM Protection
      final XFile? pickedFile = await _picker.pickImage(
          source: source, imageQuality: 70, maxWidth: 1080, maxHeight: 1080);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showImagePickerOptions() {
    FocusScope.of(context).unfocus(); // Close keyboard
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Upload Crop Photo",
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, ImageSource src) {
    return InkWell(
      onTap: () => _pickImage(src),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade100)),
        child: Column(
          children: [
            Icon(icon, size: 36, color: _primaryGreen),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _primaryGreen))
          ],
        ),
      ),
    );
  }

  // --- SUBMIT ---
  Future<void> _submit() async {
    if (_isLoading) return; // Prevent double taps

    if (_selectedCrop == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please fill all required fields (*)",
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade700));
      return;
    }

    if (!_isEditMode && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Please upload a crop image.", style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade700));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not logged in";

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

      // 🛡️ DATABASE ALIGNMENT: ROBUST NUMBER PARSING
      // Replaces commas with dots, and removes any non-numeric characters before parsing
      String cleanQtyText =
          _qtyCtrl.text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
      String cleanPriceText = _priceCtrl.text
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.]'), '');

      final double parsedQty = double.tryParse(cleanQtyText) ?? 0.0;
      final double parsedPrice = double.tryParse(cleanPriceText) ?? 0.0;

      // 🛡️ PRODUCTION FIX: Determine if an Inspector is making this entry
      final String finalFarmerId = widget.farmerId ?? user.id;
      final String? finalInspectorId = widget.farmerId != null ? user.id : null;

      final Map<String, dynamic> cropData = {
        'farmer_id': finalFarmerId,
        'inspector_id': finalInspectorId,
        'crop_name': _selectedCrop,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'grade': _selectedGrade,

        // ✅ CRITICAL FIX: Numeric fields ONLY receive pure numbers, Unit field receives text
        'quantity': parsedQty,
        'quantity_kg': parsedQty,
        'unit': _selectedUnit,

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
            content: Text(
                _isEditMode
                    ? "Crop Updated Successfully!"
                    : "Crop Listed Successfully!",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            backgroundColor: Colors.green.shade700));
      }
    } catch (e) {
      debugPrint("SUBMIT ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700));
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
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _surfaceColor,
          appBar: AppBar(
            title: Text(_isEditMode ? "Edit Crop" : "Add New Crop",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 18)),
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryGreen))
              : Theme(
                  data: ThemeData(
                    colorScheme: ColorScheme.light(primary: _primaryGreen),
                    canvasColor: _surfaceColor,
                  ),
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: _currentStep,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    controlsBuilder: (context, details) =>
                        _buildButtons(details),
                    onStepContinue: () {
                      FocusScope.of(context)
                          .unfocus(); // Close keyboard on step change
                      if (_currentStep < 2) {
                        setState(() => _currentStep++);
                      } else {
                        _submit();
                      }
                    },
                    onStepCancel: () {
                      FocusScope.of(context).unfocus();
                      if (_currentStep > 0) setState(() => _currentStep--);
                    },
                    steps: _getSteps(),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildButtons(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      child: Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: details.onStepContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentStep == 2
                  ? (_isEditMode ? "UPDATE CROP" : "SUBMIT LISTING")
                  : "CONTINUE",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.5),
            ),
          ),
        ),
        if (_currentStep > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: details.onStepCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("BACK",
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
          ),
        ],
      ]),
    );
  }

  List<Step> _getSteps() {
    return [
      // ---------------------------------------------------------
      // STEP 1: INFO
      // ---------------------------------------------------------
      Step(
        title: Text("Info",
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditMode) ...[
              _sectionLabel("Listing Status", Icons.toggle_on),
              Container(
                margin: const EdgeInsets.only(bottom: 20, top: 10),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200)),
                child: _dropdown(null, _status, _statusOptions,
                    (v) => setState(() => _status = v!),
                    icon: Icons.storefront),
              ),
            ],
            _sectionLabel("Farming Method", Icons.eco),
            const SizedBox(height: 10),
            Row(children: [
              _typeButton("Organic", Colors.green.shade600, Icons.grass),
              const SizedBox(width: 12),
              _typeButton("Inorganic", Colors.blueGrey.shade500, Icons.science),
            ]),
            const SizedBox(height: 24),
            _sectionLabel("Crop Details", Icons.category),
            const SizedBox(height: 10),
            _dropdown("Category *", _selectedCategory,
                ['Vegetables', 'Fruits', 'Grains'], (val) {
              setState(() {
                _selectedCategory = val;
                _selectedCrop = null;
                _selectedVariety = null;
              });
            }, icon: Icons.grid_view),
            const SizedBox(height: 16),
            _dropdown(
                "Crop Name *",
                _selectedCrop,
                (_selectedCategory != null &&
                        _cropData.containsKey(_selectedCategory))
                    ? _cropData[_selectedCategory]!.keys.toList()
                    : [], (val) {
              setState(() {
                _selectedCrop = val;
                _selectedVariety = null;
              });
            }, icon: Icons.local_florist),
            const SizedBox(height: 16),
            _dropdown(
                "Variety (Optional)",
                _selectedVariety,
                (_selectedCategory != null && _selectedCrop != null)
                    ? _cropData[_selectedCategory]![_selectedCrop]!
                    : [],
                (val) => setState(() => _selectedVariety = val),
                icon: Icons.style),
            const SizedBox(height: 16),
            _dropdown("Quality Grade", _selectedGrade, _gradeOptions,
                (v) => setState(() => _selectedGrade = v),
                icon: Icons.workspace_premium),
          ],
        ),
      ),

      // ---------------------------------------------------------
      // STEP 2: PRICE & QUANTITY
      // ---------------------------------------------------------
      Step(
        title: Text("Rate",
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("Inventory Stock", Icons.inventory_2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _inputField("Quantity *", _qtyCtrl,
                      type:
                          const TextInputType.numberWithOptions(decimal: true),
                      icon: Icons.scale),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _dropdown(
                      "Unit",
                      _selectedUnit,
                      ["Kg", "Quintal (q)", "Ton", "Crates"],
                      (v) => setState(() => _selectedUnit = v)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _sectionLabel("Pricing", Icons.payments),
            const SizedBox(height: 10),
            _inputField("Price per Unit (₹) *", _priceCtrl,
                type: const TextInputType.numberWithOptions(decimal: true),
                prefix: "₹ ",
                icon: Icons.sell),
            const SizedBox(height: 20),

            // 🛡️ PRODUCTION FIX: Safe Math + Premium Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4)
                        ]),
                    child: Icon(Icons.account_balance_wallet,
                        color: Colors.green.shade700, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Estimated Total Value",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600)),
                        Text(
                          "₹${((double.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * (double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0)).toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                              fontSize: 22),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),

      // ---------------------------------------------------------
      // STEP 3: PHOTO & DATES
      // ---------------------------------------------------------
      Step(
        title: Text("Pic",
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 2,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("Timelines", Icons.calendar_month),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _datePicker("Harvested", _harvestDate,
                        (d) => setState(() => _harvestDate = d),
                        isHarvest: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _datePicker("Available", _availableDate,
                        (d) => setState(() => _availableDate = d),
                        isHarvest: false)),
              ],
            ),
            const SizedBox(height: 24),

            _sectionLabel("Description", Icons.description),
            const SizedBox(height: 10),
            _inputField("Add extra details (Optional)", _notesCtrl,
                type: TextInputType.multiline, maxLines: 3),
            const SizedBox(height: 24),

            _sectionLabel("Crop Photo *", Icons.image),
            const SizedBox(height: 10),

            // 🎨 Premium Interactive Dropzone
            InkWell(
              onTap: _showImagePickerOptions,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: _inputFillColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            _selectedImage != null || _existingImageUrl != null
                                ? _primaryGreen
                                : Colors.grey.shade400,
                        width: 2,
                        style: BorderStyle.solid)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImage != null)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover))
                    else if (_existingImageUrl != null)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle),
                            child: Icon(Icons.cloud_upload_outlined,
                                size: 36, color: _primaryGreen),
                          ),
                          const SizedBox(height: 12),
                          Text("Tap to upload photo",
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600)),
                          Text("JPG or PNG (Max 5MB)",
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    if (_selectedImage != null || _existingImageUrl != null)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              const Icon(Icons.edit,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text("Change",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // --- UI WIDGET HELPERS ---

  Widget _sectionLabel(String l, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(l,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.grey.shade800)),
        ],
      );

  Widget _dropdown(String? label, String? value, List<String> items,
      Function(String?) onChanged,
      {IconData? icon}) {
    if (value != null && !items.contains(value)) value = null;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: Colors.grey),
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.grey.shade500, size: 20)
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryGreen, width: 2)),
        filled: true,
        fillColor: _inputFillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      String? prefix,
      IconData? icon}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        prefixText: prefix,
        prefixStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.grey.shade500, size: 20)
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryGreen, width: 2)),
        filled: true,
        fillColor: _inputFillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, Function(DateTime) onConfirm,
      {bool isHarvest = false}) {
    return InkWell(
      onTap: () async {
        FocusScope.of(context).unfocus();
        final d = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: isHarvest ? DateTime(2020) : DateTime.now(),
            lastDate: DateTime(2030),
            builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: _primaryGreen)),
                  child: child!,
                ));
        if (d != null) onConfirm(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: _inputFillColor,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    date == null
                        ? "Select"
                        : "${date.day}/${date.month}/${date.year}",
                    style: GoogleFonts.poppins(
                        color: date == null
                            ? Colors.grey.shade400
                            : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Icon(Icons.calendar_month, color: _primaryGreen, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String type, Color activeColor, IconData icon) {
    bool isSelected = _cropType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _cropType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : _inputFillColor,
            border: Border.all(
                color: isSelected ? activeColor : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? activeColor : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(type,
                  style: GoogleFonts.poppins(
                      color: isSelected ? activeColor : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
