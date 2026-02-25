import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class InspectorAddCropTab extends StatefulWidget {
  final Map<String, dynamic>? preSelectedFarmer;
  final Map<String, dynamic>? cropToEdit;

  const InspectorAddCropTab({
    super.key,
    this.preSelectedFarmer,
    this.cropToEdit,
  });

  @override
  State<InspectorAddCropTab> createState() => _InspectorAddCropTabState();
}

class _InspectorAddCropTabState extends State<InspectorAddCropTab> {
  // --- STATE ---
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isFarmersLoading = true;

  // --- DATA SOURCES ---
  List<Map<String, dynamic>> _myFarmers = [];
  String? _selectedFarmerId;

  // 🚀 PRODUCTION LOGIC: Strictly restricted to Vegetables & Fruits
  final List<String> _categories = ['Vegetables', 'Fruits'];

  final Map<String, List<String>> _cropSuggestions = {
    'Vegetables': [
      'Tomato',
      'Onion',
      'Potato',
      'Brinjal',
      'Chilli',
      'Okra',
      'Cabbage',
      'Spinach',
      'Carrot',
      'Cauliflower'
    ],
    'Fruits': [
      'Mango',
      'Banana',
      'Grapes',
      'Pomegranate',
      'Papaya',
      'Apple',
      'Guava',
      'Watermelon',
      'Orange'
    ],
  };

  // 🚀 SMART VARIETY ENGINE (Mandatory)
  final Map<String, List<String>> _varietySuggestions = {
    'Tomato': ['Desi/Local', 'Hybrid', 'Cherry', 'Roma'],
    'Onion': ['Red', 'White', 'Yellow', 'Spring'],
    'Potato': ['Kufri Jyoti', 'Kufri Pukhraj', 'Russet', 'Sweet Potato'],
    'Brinjal': ['Purple Long', 'Purple Round', 'Green', 'White'],
    'Chilli': ['Guntur', 'Kashmiri', 'Jalapeno', 'Bird Eye'],
    'Okra': ['Parbhani Kranti', 'Pusa Makhmali', 'Hybrid'],
    'Cabbage': ['Green', 'Red', 'Savoy'],
    'Spinach': ['Savoy', 'Semi-savoy', 'Flat-leafed'],
    'Carrot': ['Orange', 'Red', 'Black', 'Nantes'],
    'Cauliflower': ['White', 'Purple', 'Green'],
    'Mango': ['Alphonso', 'Kesar', 'Dasheri', 'Banganapalli', 'Totapuri'],
    'Banana': ['Robusta', 'Cavendish', 'Red Banana', 'Nendran', 'Poovan'],
    'Grapes': [
      'Thompson Seedless',
      'Sharad Seedless',
      'Flame Seedless',
      'Black'
    ],
    'Pomegranate': ['Bhagawa', 'Ganesh', 'Ruby', 'Arakta'],
    'Papaya': ['Red Lady', 'Taiwan', 'Coorg Honey Dew'],
    'Apple': ['Kashmiri', 'Fuji', 'Gala', 'Granny Smith'],
    'Guava': ['Allahabad Safeda', 'Lucknow 49', 'Lalit', 'Shweta'],
    'Watermelon': ['Kiran', 'Namdhari', 'Sugar Baby', 'Black Magic'],
    'Orange': ['Nagpur', 'Kinnow', 'Mandarin', 'Valencia'],
  };

  final List<String> _grades = [
    'Grade A (Premium)',
    'Grade B (Standard)',
    'Grade C (Fair)',
    'Organic Certified'
  ];
  final List<String> _units = ["Kg", "Quintal (q)", "Ton", "Crates"];

  // --- CONTROLLERS ---
  String _cropType = "Organic";
  String? _selectedCategory;
  String? _selectedCropName;
  String? _selectedVariety;
  String? _selectedGrade;
  String? _selectedUnit = "Kg";

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _harvestDate;
  DateTime? _availableDate;

  File? _imageFile;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  // 🎨 Premium Theme Colors
  final Color _inspectorColor = const Color(0xFF512DA8);
  final Color _bgWhite = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchMyFarmers();

    if (widget.cropToEdit != null) {
      _isEditMode = true;
      _loadExistingData(widget.cropToEdit!);
    } else if (widget.preSelectedFarmer != null) {
      _selectedFarmerId = widget.preSelectedFarmer!['id']?.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // --- 1. BULLETPROOF DB FETCHING & FILTERING ---
  Future<void> _fetchMyFarmers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, first_name, last_name, district, role')
          .eq('inspector_id', user.id);

      final List<dynamic> rawData = response as List<dynamic>;

      // Local case-insensitive filter prevents DB crashes from typos
      final parsedFarmers = rawData
          .map((e) => e as Map<String, dynamic>)
          .where((f) =>
              (f['role']?.toString().toLowerCase().trim() ?? '') == 'farmer')
          .toList();

      if (mounted) {
        setState(() {
          _myFarmers = parsedFarmers;
          _isFarmersLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch Farmers Error: $e");
      if (mounted) setState(() => _isFarmersLoading = false);
    }
  }

  void _loadExistingData(Map<String, dynamic> c) {
    _selectedFarmerId = c['farmer_id']?.toString();
    _cropType = c['crop_type'] ?? "Organic";
    _selectedCategory = c['category'];
    _selectedCropName = c['crop_name'] ?? c['name'];
    _selectedVariety = c['variety'];
    _selectedGrade = c['grade'];

    // Safe Legacy Quantity Parsing
    if (c['quantity_kg'] != null) {
      if (c['unit'] != null) {
        _selectedUnit = c['unit'];
        _qtyCtrl.text = c['quantity'].toString();
      } else {
        _qtyCtrl.text = c['quantity_kg'].toString();
        _selectedUnit = "Kg";
      }
    } else {
      String rawQty = (c['quantity'] ?? "0").toString();
      List<String> qtyParts = rawQty.split(' ');
      if (qtyParts.length >= 2) {
        _qtyCtrl.text = qtyParts[0];
        String unitFromDb = qtyParts.sublist(1).join(' ');
        if (_units.contains(unitFromDb)) _selectedUnit = unitFromDb;
      } else {
        _qtyCtrl.text = rawQty;
      }
    }

    _priceCtrl.text = (c['price'] ?? 0).toString();
    _notesCtrl.text = c['description'] ?? "";
    _existingImageUrl = c['image_url'];

    if (c['harvest_date'] != null)
      _harvestDate = DateTime.tryParse(c['harvest_date']);
    if (c['available_from'] != null)
      _availableDate = DateTime.tryParse(c['available_from']);
  }

  // 🚀 PRODUCTION FIX: Memory Limits on Camera App prevents OS background crashes
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080, // Caps RAM usage
        maxHeight: 1080,
      );
      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      if (mounted)
        _showError("Camera/Gallery permission denied or action cancelled.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating));
  }

  // Dynamic Injection prevents Dropdown crashes on Legacy Data
  List<String> get _currentVarieties {
    if (_selectedCropName == null) return [];

    List<String> list = _varietySuggestions[_selectedCropName] ??
        ['Standard', 'Hybrid', 'Local/Desi', 'Other'];

    if (_isEditMode &&
        _selectedVariety != null &&
        _selectedVariety!.isNotEmpty &&
        !list.contains(_selectedVariety)) {
      list = List.from(list)..insert(0, _selectedVariety!);
    }

    return list;
  }

  // --- 2. THE STRICT LOGIC LOOP GATEKEEPER ---
  void _handleStepContinue() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      if (_selectedFarmerId == null)
        return _showError("Please select a Farmer.");
      if (_selectedCategory == null)
        return _showError("Please select a Category.");
      if (_selectedCropName == null)
        return _showError("Please select a Crop Name.");
      if (_selectedVariety == null)
        return _showError("Please select a Crop Variety.");
    }

    if (_currentStep == 1) {
      final String cleanQty = _qtyCtrl.text.replaceAll(',', '').trim();
      final String cleanPrice = _priceCtrl.text.replaceAll(',', '').trim();

      if (cleanQty.isEmpty || double.tryParse(cleanQty) == null) {
        return _showError("Please enter a valid Quantity number.");
      }
      if (cleanPrice.isEmpty || double.tryParse(cleanPrice) == null) {
        return _showError("Please enter a valid Price.");
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  // --- 3. SECURE SUBMISSION ENGINE ---
  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "Authentication error. Please log in again.";

      String? imageUrl = _existingImageUrl;

      // Extension safe uploader
      if (_imageFile != null) {
        final String extension = _imageFile!.path.split('.').last.toLowerCase();
        final String safeExt =
            ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
                ? extension
                : 'jpg';
        final String fileName =
            'crops/${DateTime.now().millisecondsSinceEpoch}_${user.id}.$safeExt';

        await Supabase.instance.client.storage
            .from('crop_images')
            .upload(fileName, _imageFile!);

        imageUrl = Supabase.instance.client.storage
            .from('crop_images')
            .getPublicUrl(fileName);
      }

      // Safe Numeric Conversions
      double qtyVal =
          double.tryParse(_qtyCtrl.text.replaceAll(',', '').trim()) ?? 0;
      double finalKg = qtyVal;
      if (_selectedUnit == 'Quintal (q)') {
        finalKg = qtyVal * 100;
      } else if (_selectedUnit == 'Ton') {
        finalKg = qtyVal * 1000;
      }

      final cropData = {
        'farmer_id': _selectedFarmerId,
        'inspector_id': user.id,
        'crop_name': _selectedCropName,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'crop_type': _cropType,
        'grade': _selectedGrade,
        'description': _notesCtrl.text.trim(),
        'status': 'Active',
        'quantity': qtyVal,
        'unit': _selectedUnit,
        'quantity_kg': finalKg,
        'price':
            double.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0,
        'harvest_date': _harvestDate?.toIso8601String(),
        'available_from': _availableDate?.toIso8601String(),
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditMode) {
        await Supabase.instance.client
            .from('crops')
            .update(cropData)
            .eq('id', widget.cropToEdit!['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("✅ Crop Updated Successfully!",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.green.shade700));
          Navigator.pop(context, true);
        }
      } else {
        cropData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('crops').insert(cropData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("✅ Crop Added Successfully!",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.green.shade700));

          if (ModalRoute.of(context)?.canPop == true) {
            Navigator.pop(context, true);
          } else {
            setState(() {
              _currentStep = 0;
              _clearForm();
              _imageFile = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String err = e.toString();
        if (err.contains("message:"))
          err = err.split("message:")[1].split(",")[0];
        _showError("Failed to save: $err");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _qtyCtrl.clear();
    _priceCtrl.clear();
    _notesCtrl.clear();
    _selectedCategory = null;
    _selectedCropName = null;
    _selectedVariety = null;
    _selectedGrade = null;
    _selectedFarmerId = widget.preSelectedFarmer != null
        ? widget.preSelectedFarmer!['id']?.toString()
        : null;
  }

  // 🚀 PRODUCTION FIX: Prevents Accidental Data Loss on Back Swipe
  Future<bool> _onWillPop() async {
    if (_qtyCtrl.text.isEmpty && _selectedCropName == null)
      return true; // Form is empty, safe to pop
    if (_isLoading) return false; // Block back button during API upload

    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Discard Changes?",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            "You have unsaved crop data. Are you sure you want to go back?",
            style: GoogleFonts.poppins(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("KEEP EDITING",
                  style: GoogleFonts.poppins(
                      color: _inspectorColor, fontWeight: FontWeight.bold))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600, elevation: 0),
              child: Text("DISCARD",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isPushed = ModalRoute.of(context)?.canPop ?? false;

    return WillPopScope(
      onWillPop: isPushed ? _onWillPop : () async => true,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _bgWhite,
          appBar: isPushed || _isEditMode
              ? AppBar(
                  title: Text(_isEditMode ? "Edit Crop" : "Add Crop",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  backgroundColor: _inspectorColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                )
              : null,
          // 🚀 PRODUCTION UX: Stack overlay prevents interaction during upload, keeps UI visible
          body: Stack(
            children: [
              Theme(
                data: ThemeData(
                  colorScheme: ColorScheme.light(primary: _inspectorColor),
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: isPushed ? 0 : 8.0),
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: _currentStep,
                    elevation: 0,
                    controlsBuilder: (ctx, details) => _buildButtons(details),
                    onStepContinue: _handleStepContinue,
                    onStepCancel: () => _currentStep > 0
                        ? setState(() => _currentStep--)
                        : null,
                    steps: [
                      // STEP 1: INFO
                      Step(
                        title: Text("Info",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel("Select Farmer *"),
                            _buildSafeFarmerDropdown(),
                            _sectionLabel("Farming Type *"),
                            Row(children: [
                              _typeBtn("Organic", Colors.green.shade600),
                              const SizedBox(width: 10),
                              _typeBtn("Inorganic", Colors.orange.shade600),
                            ]),
                            const SizedBox(height: 15),
                            _dropdown(
                                "Category *", _selectedCategory, _categories,
                                (val) {
                              setState(() {
                                _selectedCategory = val;
                                _selectedCropName = null;
                                _selectedVariety = null;
                              });
                            }),
                            const SizedBox(height: 15),
                            _dropdown(
                              "Crop Name *",
                              _selectedCropName,
                              (_selectedCategory != null &&
                                      _cropSuggestions
                                          .containsKey(_selectedCategory))
                                  ? _cropSuggestions[_selectedCategory!]!
                                  : [],
                              (val) => setState(() {
                                _selectedCropName = val;
                                _selectedVariety = null;
                              }),
                            ),
                            const SizedBox(height: 15),
                            _dropdown(
                              "Variety *",
                              _selectedVariety,
                              _currentVarieties,
                              (val) => setState(() => _selectedVariety = val),
                            ),
                            const SizedBox(height: 15),
                            _dropdown("Grade", _selectedGrade, _grades,
                                (v) => setState(() => _selectedGrade = v)),
                          ],
                        ),
                      ),

                      // STEP 2: PRICE & QUANTITY
                      Step(
                        title: Text("Price",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : StepState.indexed,
                        content: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 2,
                                    child: _txt(
                                        "Quantity *",
                                        _qtyCtrl,
                                        const TextInputType.numberWithOptions(
                                            decimal: true))),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: _dropdown(
                                      "Unit",
                                      _selectedUnit,
                                      _units,
                                      (v) => setState(() => _selectedUnit = v)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _txt(
                                "Price (₹/Unit) *",
                                _priceCtrl,
                                const TextInputType.numberWithOptions(
                                    decimal: true)),
                            if (_qtyCtrl.text.isNotEmpty &&
                                _priceCtrl.text.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 15),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    border: Border.all(
                                        color: Colors.green.shade200),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.calculate,
                                      color: Colors.green),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                          "Est. Total Value: ₹${((double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0) * (double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0)).toStringAsFixed(2)}",
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis)),
                                ]),
                              )
                          ],
                        ),
                      ),

                      // STEP 3: VERIFY & FINISH
                      Step(
                        title: Text("Verify",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        isActive: _currentStep >= 2,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel("Harvest Dates (Optional)"),
                            _dateBtn("Harvest Date", _harvestDate,
                                (d) => setState(() => _harvestDate = d)),
                            const SizedBox(height: 15),
                            _dateBtn("Available From", _availableDate,
                                (d) => setState(() => _availableDate = d)),
                            const SizedBox(height: 20),
                            _sectionLabel("Additional Notes"),
                            _txt("Notes / Description", _notesCtrl,
                                TextInputType.text,
                                max: 3),
                            const SizedBox(height: 20),
                            _sectionLabel("Verification Photo (Optional)"),
                            GestureDetector(
                              onTap: _showImagePicker,
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade300)),
                                child: _imageFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(_imageFile!,
                                            fit: BoxFit.cover))
                                    : _existingImageUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                                _existingImageUrl!,
                                                fit: BoxFit.cover))
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                                Icon(Icons.add_a_photo_outlined,
                                                    size: 40,
                                                    color:
                                                        Colors.grey.shade400),
                                                const SizedBox(height: 8),
                                                Text("Tap to add crop photo",
                                                    style: GoogleFonts.poppins(
                                                        color: Colors
                                                            .grey.shade500,
                                                        fontSize: 13)),
                                              ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🚀 LOADING OVERLAY (Prevents UI jump/flicker)
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
    );
  }

  // --- TYPOGRAPHY UPGRADED WIDGET HELPERS ---

  Widget _buildSafeFarmerDropdown() {
    if (_isFarmersLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300)),
        child: const LinearProgressIndicator(),
      );
    }

    String? safeValue = _selectedFarmerId;
    if (safeValue != null &&
        !_myFarmers.any((f) => f['id'].toString() == safeValue))
      safeValue = null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        hint: Text("Choose Farmer",
            style:
                GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
        items: _myFarmers.map((f) {
          final fullName =
              "${f['first_name'] ?? ''} ${f['last_name'] ?? ''}".trim();
          final dist = f['district'] ?? 'Unknown';
          return DropdownMenuItem(
            value: f['id'].toString(),
            child: Text(
                fullName.isEmpty
                    ? "Unknown Farmer ($dist)"
                    : "$fullName ($dist)",
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
          );
        }).toList(),
        onChanged: _isEditMode || widget.preSelectedFarmer != null
            ? null
            : (v) => setState(() => _selectedFarmerId = v),
        decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _inspectorColor, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    );
  }

  Widget _buildButtons(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
                child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: _inspectorColor)),
                    child: Text("BACK",
                        style: GoogleFonts.poppins(
                            color: _inspectorColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)))),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
              flex: 2,
              child: ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _inspectorColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(
                      _currentStep == 2
                          ? (_isEditMode ? "UPDATE CROP" : "SUBMIT CROP")
                          : "CONTINUE",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)))),
        ],
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
                child: Wrap(children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Upload Photo",
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.black87),
                  title: Text('Take a Photo',
                      style: GoogleFonts.poppins(fontSize: 15)),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading:
                      const Icon(Icons.photo_library, color: Colors.black87),
                  title: Text('Choose from Gallery',
                      style: GoogleFonts.poppins(fontSize: 15)),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.pop(context);
                  }),
              const SizedBox(height: 10),
            ])));
  }

  Widget _sectionLabel(String l) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(l,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87)));

  Widget _dropdown(String l, String? v, List<String> i, Function(String?) c) {
    final List<String> safeItems = List.from(i);
    if (v != null && v.isNotEmpty && !safeItems.contains(v))
      safeItems.insert(0, v);
    return DropdownButtonFormField<String>(
        value: v,
        isExpanded: true,
        items: safeItems
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
            .toList(),
        onChanged: i.isEmpty ? null : c,
        decoration: InputDecoration(
            labelText: l,
            labelStyle:
                GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _inspectorColor, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
  }

  Widget _txt(String l, TextEditingController ctrl, TextInputType t,
      {int max = 1}) {
    return TextFormField(
        controller: ctrl,
        keyboardType: t,
        maxLines: max,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
            labelText: l,
            alignLabelWithHint: max > 1,
            labelStyle:
                GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _inspectorColor, width: 1.5)),
            filled: true,
            fillColor: Colors.white));
  }

  Widget _typeBtn(String t, Color c) {
    final bool isSelected = _cropType == t;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() => _cropType = t),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: isSelected ? c : Colors.white,
                    border: Border.all(
                        color: isSelected ? c : Colors.grey.shade300,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
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
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))))));
  }

  Widget _dateBtn(String l, DateTime? d, Function(DateTime) op) {
    return InkWell(
        onTap: () async {
          final p = await showDatePicker(
              context: context,
              initialDate: d ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                    data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: _inspectorColor,
                            onPrimary: Colors.white,
                            onSurface: Colors.black),
                        textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                                textStyle: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold)))),
                    child: child!);
              });
          if (p != null) op(p);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(d == null ? l : "${d.day}/${d.month}/${d.year}",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: d == null
                              ? Colors.grey.shade600
                              : Colors.black87)),
                  Icon(Icons.calendar_today, size: 20, color: _inspectorColor)
                ])));
  }
}
