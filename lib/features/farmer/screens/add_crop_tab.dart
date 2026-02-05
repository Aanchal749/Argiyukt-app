import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added typography

class AddCropTab extends StatefulWidget {
  final Map<String, dynamic>? cropToEdit;

  const AddCropTab({super.key, this.cropToEdit});

  @override
  State<AddCropTab> createState() => _AddCropTabState();
}

class _AddCropTabState extends State<AddCropTab> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF1B5E20);

  // --- 1. DATA SOURCE ---
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

  // --- 2. CONTROLLERS ---
  String _status = 'Active'; // Status Controller
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
  }

  void _prefillData(Map<String, dynamic> c) {
    // 1. Status Parsing
    String dbStatus = c['status'] ?? 'Active';
    if (dbStatus.isNotEmpty) {
      dbStatus =
          dbStatus[0].toUpperCase() + dbStatus.substring(1).toLowerCase();
    }
    _status = _statusOptions.contains(dbStatus) ? dbStatus : 'Active';

    // 2. Dropdowns (Safe Loading)
    _cropType = c['crop_type'] ?? "Organic";

    // Category
    String? dbCategory = c['category'];
    if (dbCategory != null && _cropData.containsKey(dbCategory)) {
      _selectedCategory = dbCategory;
    }

    // Crop
    String? dbCrop = c['crop_name'];
    if (_selectedCategory != null) {
      List<String> validCrops = _cropData[_selectedCategory]!.keys.toList();
      if (validCrops.contains(dbCrop)) _selectedCrop = dbCrop;
    }

    // Variety
    String? dbVariety = c['variety'];
    if (_selectedCategory != null && _selectedCrop != null) {
      List<String> validVarieties =
          _cropData[_selectedCategory]![_selectedCrop]!;
      if (validVarieties.contains(dbVariety)) _selectedVariety = dbVariety;
    }

    // Grade
    String? dbGrade = c['grade'];
    if (_gradeOptions.contains(dbGrade)) _selectedGrade = dbGrade;

    // 3. Quantity Parsing
    String rawQty = c['quantity'] ?? "0 Kg";
    List<String> qtyParts = rawQty.split(' ');
    if (qtyParts.length >= 2) {
      _qtyCtrl.text = qtyParts[0];
      String unit = qtyParts.sublist(1).join(' ');
      if (["Kg", "Quintal (q)", "Ton", "Crates"].contains(unit))
        _selectedUnit = unit;
    } else {
      _qtyCtrl.text = rawQty;
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
      final XFile? pickedFile =
          await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
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

  // --- SUBMIT ---
  Future<void> _submit() async {
    if (_selectedCrop == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please fill all required fields (*)",
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red));
      return;
    }

    if (!_isEditMode && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Please upload a crop image.", style: GoogleFonts.poppins()),
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
          .single();
      final String status =
          profileData['verification_status'] ?? 'Not Uploaded';

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
        return;
      }

      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last;
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage.from('crop_images').uploadBinary(
            fileName, await _selectedImage!.readAsBytes(),
            fileOptions: const FileOptions(upsert: true));
        imageUrl = fileName;
      }

      final Map<String, dynamic> cropData = {
        'farmer_id': user.id,
        'crop_name': _selectedCrop,
        'category': _selectedCategory,
        'variety': _selectedVariety,
        'grade': _selectedGrade,
        'quantity': "${_qtyCtrl.text} $_selectedUnit",
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'crop_type': _cropType,
        'status': _status, // ✅ Uses correct status
        'harvest_date': _harvestDate?.toIso8601String(),
        'available_from': _availableDate?.toIso8601String(),
        'description': _notesCtrl.text,
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(_isEditMode ? "Edit Crop" : "Add New Crop",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : Theme(
              // Override Stepper Theme to match
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _currentStep == 2
                                  ? (_isEditMode ? "UPDATE" : "SUBMIT")
                                  : "NEXT",
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
                              child: Text("BACK",
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
                  if (_currentStep < 2)
                    setState(() => _currentStep += 1);
                  else
                    _submit();
                },
                onStepCancel: () {
                  if (_currentStep > 0) setState(() => _currentStep -= 1);
                },
                steps: _getSteps(),
              ),
            ),
    );
  }

  List<Step> _getSteps() {
    return [
      Step(
        title: Text("Info", style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 0,
        content: Column(
          children: [
            const SizedBox(height: 10),

            // ✅ STATUS DROPDOWN (Only visible in Edit Mode)
            if (_isEditMode)
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
                    Text("Current Status",
                        style: GoogleFonts.poppins(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 5),
                    _dropdown("Status", _status, _statusOptions,
                        (v) => setState(() => _status = v!)),
                  ],
                ),
              ),

            Row(children: [
              _typeButton("Organic", Colors.green),
              const SizedBox(width: 8),
              _typeButton("Inorganic", Colors.orange)
            ]),
            const SizedBox(height: 15),
            _dropdown("Category *", _selectedCategory, ['Vegetables', 'Fruits'],
                (val) {
              setState(() {
                _selectedCategory = val;
                _selectedCrop = null;
                _selectedVariety = null;
              });
            }),
            const SizedBox(height: 15),
            _dropdown(
                "Crop *",
                _selectedCrop,
                _selectedCategory == null
                    ? []
                    : _cropData[_selectedCategory]!.keys.toList(), (val) {
              setState(() {
                _selectedCrop = val;
                _selectedVariety = null;
              });
            }),
            const SizedBox(height: 15),
            _dropdown(
                "Variety",
                _selectedVariety,
                (_selectedCategory != null && _selectedCrop != null)
                    ? _cropData[_selectedCategory]![_selectedCrop]!
                    : [],
                (val) => setState(() => _selectedVariety = val)),
            const SizedBox(height: 15),
            _dropdown("Grade", _selectedGrade, _gradeOptions,
                (v) => setState(() => _selectedGrade = v)),
          ],
        ),
      ),
      Step(
        title: Text("Rate", style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 1,
        content: Column(
          children: [
            const SizedBox(height: 10),
            _inputField("Quantity Available *", _qtyCtrl,
                type: TextInputType.number),
            const SizedBox(height: 15),
            _dropdown(
                "Unit",
                _selectedUnit,
                ["Kg", "Quintal (q)", "Ton", "Crates"],
                (v) => setState(() => _selectedUnit = v)),
            const SizedBox(height: 15),
            _inputField("Price per Unit (₹) *", _priceCtrl,
                type: TextInputType.number, prefix: "₹"),
            const SizedBox(height: 10),
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
                          "Est. Total Value: ₹${(double.tryParse(_qtyCtrl.text) ?? 0 * (double.tryParse(_priceCtrl.text) ?? 0)).toStringAsFixed(0)}",
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
        title: Text("Pic", style: GoogleFonts.poppins(fontSize: 12)),
        isActive: _currentStep >= 2,
        content: Column(
          children: [
            const SizedBox(height: 10),

            // Image Box
            InkWell(
              onTap: _showImagePickerOptions,
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
                          Text("Tap to change photo",
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

            _datePicker("Harvest Date", _harvestDate,
                (d) => setState(() => _harvestDate = d)),
            const SizedBox(height: 12),
            _datePicker("Available From", _availableDate,
                (d) => setState(() => _availableDate = d)),

            const SizedBox(height: 20),
            _inputField("Description / Notes", _notesCtrl, maxLines: 3),
          ],
        ),
      ),
    ];
  }

  // --- WIDGET HELPERS ---

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
    if (value != null && !items.contains(value)) {
      value = null;
    }

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
            initialDate: DateTime.now(),
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
