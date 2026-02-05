import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class InspectorAddCropTab extends StatefulWidget {
  final Map<String, dynamic>? preSelectedFarmer;
  final Map<String, dynamic>? cropToEdit;

  const InspectorAddCropTab(
      {super.key, this.preSelectedFarmer, this.cropToEdit});

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

  // --- DROPDOWN OPTIONS ---
  final List<String> _categories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Pulses',
    'Flowers',
    'Spices',
    'Commercial'
  ];
  final Map<String, List<String>> _cropSuggestions = {
    'Vegetables': [
      'Tomato',
      'Onion',
      'Potato',
      'Brinjal',
      'Chilli',
      'Okra',
      'Cabbage'
    ],
    'Fruits': ['Mango', 'Banana', 'Grapes', 'Pomegranate', 'Papaya', 'Apple'],
    'Grains': ['Wheat', 'Rice', 'Maize', 'Bajra', 'Jowar'],
    'Spices': ['Turmeric', 'Cumin', 'Pepper', 'Chilli Powder'],
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
  String? _selectedGrade;
  String? _selectedUnit = "Kg";

  final _varietyCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _harvestDate;
  DateTime? _availableDate;

  File? _imageFile;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  final Color _inspectorColor = const Color(0xFF512DA8);

  @override
  void initState() {
    super.initState();
    _fetchMyFarmers();

    if (widget.cropToEdit != null) {
      _isEditMode = true;
      _loadExistingData(widget.cropToEdit!);
    } else if (widget.preSelectedFarmer != null) {
      _selectedFarmerId = widget.preSelectedFarmer!['id'];
    }
  }

  Future<void> _fetchMyFarmers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, first_name, last_name, district')
          .eq('inspector_id', user.id)
          .eq('role', 'farmer');

      if (mounted) {
        setState(() {
          _myFarmers = List<Map<String, dynamic>>.from(response);
          _isFarmersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFarmersLoading = false);
    }
  }

  void _loadExistingData(Map<String, dynamic> c) {
    _selectedFarmerId = c['farmer_id'];
    _cropType = c['crop_type'] ?? "Organic";
    _selectedCategory = c['category'];
    _selectedCropName = c['crop_name'] ?? c['name'];
    _varietyCtrl.text = c['variety'] ?? "";
    _selectedGrade = c['grade'];

    // Handle quantity logic for loading
    if (c['quantity_kg'] != null) {
      // Logic: Try to deduce the original unit input from the KG value if 'unit' column is missing or null
      // For now, simpler to default to Kg if not specified
      if (c['unit'] != null) {
        _selectedUnit = c['unit'];
        _qtyCtrl.text = c['quantity'].toString();
      } else {
        _qtyCtrl.text = c['quantity_kg'].toString();
        _selectedUnit = "Kg";
      }
    } else {
      // Legacy data support (if stored as string "10 Kg")
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

    if (c['harvest_date'] != null) {
      _harvestDate = DateTime.tryParse(c['harvest_date']);
    }
    if (c['available_from'] != null) {
      _availableDate = DateTime.tryParse(c['available_from']);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 60);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  // --- SUBMIT LOGIC ---
  Future<void> _submit() async {
    if (_selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a Farmer"),
          backgroundColor: Colors.red));
      return;
    }
    if (_selectedCropName == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Fill Crop Name, Qty & Price"),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? imageUrl = _existingImageUrl;

      if (_imageFile != null) {
        final String fileName =
            'crops/${DateTime.now().millisecondsSinceEpoch}_${user!.id}.jpg';
        await Supabase.instance.client.storage
            .from('crop_images')
            .upload(fileName, _imageFile!);
        imageUrl = Supabase.instance.client.storage
            .from('crop_images')
            .getPublicUrl(fileName);
      }

      // Prepare Numeric Data
      double qtyVal = double.tryParse(_qtyCtrl.text.trim()) ?? 0;

      // Calculate Normalized Quantity in KG (for sorting/filtering)
      double finalKg = qtyVal;
      if (_selectedUnit == 'Quintal (q)') {
        finalKg = qtyVal * 100;
      } else if (_selectedUnit == 'Ton') {
        finalKg = qtyVal * 1000;
      }

      final cropData = {
        'farmer_id': _selectedFarmerId,
        'inspector_id': user!.id,
        'crop_name': _selectedCropName,
        'category': _selectedCategory,
        'variety': _varietyCtrl.text.trim(),
        'crop_type': _cropType,
        'grade': _selectedGrade,
        'description': _notesCtrl.text.trim(),
        'status': 'Active',

        // ✅ CRITICAL FIX: Storing structured quantity data
        'quantity': qtyVal, // The number entered by user (e.g., 10)
        'unit': _selectedUnit, // The unit selected (e.g., Quintal)
        'quantity_kg': finalKg, // The standardized weight (e.g., 1000)

        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Crop Updated!"), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        cropData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('crops').insert(cropData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Crop Added Successfully!"),
              backgroundColor: Colors.green));
          setState(() {
            _currentStep = 0;
            _clearForm();
            _imageFile = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String err = e.toString();
        // Friendly Error Message Parsing
        if (err.contains("message:")) {
          err = err.split("message:")[1].split(",")[0];
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("DB Error: $err"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _varietyCtrl.clear();
    _qtyCtrl.clear();
    _priceCtrl.clear();
    _notesCtrl.clear();
    _selectedCategory = null;
    _selectedCropName = null;
    _selectedGrade = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: widget.preSelectedFarmer != null || _isEditMode
          ? AppBar(
              title: Text(_isEditMode ? "Edit Crop" : "Add Crop"),
              backgroundColor: _inspectorColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _inspectorColor))
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              elevation: 0,
              controlsBuilder: (ctx, details) => _buildButtons(details),
              onStepContinue: () =>
                  _currentStep < 2 ? setState(() => _currentStep++) : _submit(),
              onStepCancel: () =>
                  _currentStep > 0 ? setState(() => _currentStep--) : null,
              steps: [
                // STEP 1: INFO
                Step(
                  title: const Text("Info"),
                  isActive: _currentStep >= 0,
                  state:
                      _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Select Farmer"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _isFarmersLoading
                            ? const LinearProgressIndicator()
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFarmerId,
                                  isExpanded: true,
                                  hint: const Text("Choose Farmer"),
                                  items: _myFarmers
                                      .map((f) => DropdownMenuItem(
                                            value: f['id'] as String,
                                            child: Text(
                                                "${f['first_name']} ${f['last_name']} (${f['district']})"),
                                          ))
                                      .toList(),
                                  onChanged: _isEditMode
                                      ? null
                                      : (v) =>
                                          setState(() => _selectedFarmerId = v),
                                ),
                              ),
                      ),
                      _sectionLabel("Farming Type"),
                      Row(children: [
                        _typeBtn("Organic", Colors.green),
                        const SizedBox(width: 10),
                        _typeBtn("Inorganic", Colors.orange),
                      ]),
                      const SizedBox(height: 15),
                      _dropdown("Category", _selectedCategory, _categories,
                          (val) {
                        setState(() {
                          _selectedCategory = val;
                          _selectedCropName = null;
                        });
                      }),
                      const SizedBox(height: 15),
                      _dropdown(
                        "Crop Name",
                        _selectedCropName,
                        (_selectedCategory != null &&
                                _cropSuggestions.containsKey(_selectedCategory))
                            ? _cropSuggestions[_selectedCategory!]!
                            : [],
                        (val) => setState(() => _selectedCropName = val),
                      ),
                      const SizedBox(height: 15),
                      _txt("Variety", _varietyCtrl, TextInputType.text),
                      const SizedBox(height: 15),
                      _dropdown("Grade", _selectedGrade, _grades,
                          (v) => setState(() => _selectedGrade = v)),
                    ],
                  ),
                ),

                // STEP 2: PRICE & QUANTITY
                Step(
                  title: const Text("Price"),
                  isActive: _currentStep >= 1,
                  state:
                      _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: _txt(
                                  "Quantity", _qtyCtrl, TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: _dropdown("Unit", _selectedUnit, _units,
                                (v) => setState(() => _selectedUnit = v)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _txt("Price (₹/Unit)", _priceCtrl, TextInputType.number),
                      if (_qtyCtrl.text.isNotEmpty &&
                          _priceCtrl.text.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.calculate, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    "Est. Value: ₹${(double.tryParse(_qtyCtrl.text) ?? 0) * (double.tryParse(_priceCtrl.text) ?? 0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                        )
                    ],
                  ),
                ),

                // STEP 3: VERIFY
                Step(
                  title: const Text("Verify"),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      _dateBtn("Harvest Date", _harvestDate,
                          (d) => setState(() => _harvestDate = d)),
                      const SizedBox(height: 15),
                      _dateBtn("Available From", _availableDate,
                          (d) => setState(() => _availableDate = d)),
                      const SizedBox(height: 15),
                      _txt(
                          "Notes / Description", _notesCtrl, TextInputType.text,
                          max: 3),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _showImagePicker,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400)),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_imageFile!,
                                      fit: BoxFit.cover))
                              : _existingImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(_existingImageUrl!,
                                          fit: BoxFit.cover))
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                          Icon(Icons.camera_alt,
                                              size: 40,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          const Text(
                                              "Tap to add verification photo",
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- HELPERS ---
  Widget _buildButtons(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
                child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: _inspectorColor)),
                    child: Text("BACK",
                        style: TextStyle(color: _inspectorColor)))),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _inspectorColor,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: Text(
                      _currentStep == 2
                          ? (_isEditMode
                              ? "UPDATE & VERIFY"
                              : "SUBMIT & VERIFY")
                          : "NEXT",
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.pop(context);
                  }),
            ])));
  }

  Widget _sectionLabel(String l) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(l,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)));

  Widget _dropdown(String l, String? v, List<String> i, Function(String?) c) {
    if (v != null && !i.contains(v)) v = null;
    return DropdownButtonFormField(
        value: v,
        isExpanded: true,
        items:
            i.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: c,
        decoration: InputDecoration(
            labelText: l,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14)));
  }

  Widget _txt(String l, TextEditingController ctrl, TextInputType t,
      {int max = 1}) {
    return TextFormField(
        controller: ctrl,
        keyboardType: t,
        maxLines: max,
        decoration: InputDecoration(
            labelText: l,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white));
  }

  Widget _typeBtn(String t, Color c) {
    final bool isSelected = _cropType == t;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() => _cropType = t),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: isSelected ? c : Colors.white,
                    border: Border.all(color: c),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                    child: Text(t,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold))))));
  }

  Widget _dateBtn(String l, DateTime? d, Function(DateTime) op) {
    return InkWell(
        onTap: () async {
          final p = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030));
          if (p != null) op(p);
        },
        child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(d == null ? l : "${d.day}/${d.month}/${d.year}"),
                  const Icon(Icons.calendar_today, size: 18)
                ])));
  }
}
