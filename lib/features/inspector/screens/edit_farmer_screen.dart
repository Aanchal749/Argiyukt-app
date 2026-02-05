import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agriyukt_app/core/services/location_service.dart';

class EditFarmerScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;
  const EditFarmerScreen({super.key, required this.farmer});

  @override
  State<EditFarmerScreen> createState() => _EditFarmerScreenState();
}

class _EditFarmerScreenState extends State<EditFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- CONTROLLERS ---
  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addr1Ctrl;
  late TextEditingController _pinCtrl;

  // --- BANK CONTROLLERS (NEW) ---
  late TextEditingController _bankAccCtrl;
  late TextEditingController _bankIfscCtrl;
  late TextEditingController _bankNameCtrl;

  // --- FARM DETAILS ---
  String? _farmSize;
  final List<String> _farmSizeOptions = [
    '< 2 acres',
    '2-5 acres',
    '5-10 acres',
    '10+ acres'
  ];

  // --- LOCATION STATE ---
  String? _selectedStateId;
  String? _selectedDistrictId;
  String? _selectedTalukaId;
  String? _selectedVillageId;

  List<LocalizedItem> _stateList = [];
  List<LocalizedItem> _districtList = [];
  List<LocalizedItem> _talukaList = [];
  List<LocalizedItem> _villageList = [];

  final Color _inspectorColor = const Color(0xFF512DA8);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final f = widget.farmer;

    // 1. Text Controllers
    _firstNameCtrl = TextEditingController(text: f['first_name']);
    _middleNameCtrl = TextEditingController(text: f['middle_name']);
    _lastNameCtrl = TextEditingController(text: f['last_name']);
    _phoneCtrl = TextEditingController(text: f['phone']);
    _addr1Ctrl = TextEditingController(text: f['address_line_1']);
    _pinCtrl = TextEditingController(text: f['pincode']);

    // 2. Bank Controllers (Load existing data)
    _bankNameCtrl = TextEditingController(text: f['bank_name']);
    _bankAccCtrl = TextEditingController(text: f['bank_account_no']);
    _bankIfscCtrl = TextEditingController(text: f['ifsc_code']);

    // 3. Safe Dropdown Initialization
    String? dbFarmSize = f['land_size'];
    if (dbFarmSize != null && _farmSizeOptions.contains(dbFarmSize)) {
      _farmSize = dbFarmSize;
    } else {
      _farmSize = null;
    }

    // 4. Pre-load Location Hierarchy
    _stateList = LocationService.getStates();
    _selectedStateId = f['state'];

    if (_selectedStateId != null) {
      _districtList = LocationService.getDistricts(_selectedStateId!);
      if (_districtList.any((e) => e.id == f['district'])) {
        _selectedDistrictId = f['district'];
      }
    }

    if (_selectedStateId != null && _selectedDistrictId != null) {
      _talukaList =
          LocationService.getTalukas(_selectedStateId!, _selectedDistrictId!);
      if (_talukaList.any((e) => e.id == f['taluka'])) {
        _selectedTalukaId = f['taluka'];
      }
    }

    if (_selectedStateId != null &&
        _selectedDistrictId != null &&
        _selectedTalukaId != null) {
      _villageList = LocationService.getVillages(
          _selectedStateId!, _selectedDistrictId!, _selectedTalukaId!);
      if (_villageList.any((e) => e.id == f['village'])) {
        _selectedVillageId = f['village'];
      }
    }
  }

  Future<void> _updateFarmer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'first_name': _firstNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'land_size': _farmSize,
        'address_line_1': _addr1Ctrl.text.trim(),
        'pincode': _pinCtrl.text.trim(),

        // Location Updates
        'state': _selectedStateId,
        'district': _selectedDistrictId,
        'taluka': _selectedTalukaId,
        'village': _selectedVillageId,

        // Bank Updates
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_account_no': _bankAccCtrl.text.trim(),
        'ifsc_code': _bankIfscCtrl.text.trim().toUpperCase(),
      };

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', widget.farmer['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Farmer Updated Successfully!"),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: const Text("Edit Farmer Details"),
        backgroundColor: _inspectorColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("Personal Details"),
              _buildTextField("First Name *", _firstNameCtrl, Icons.person),
              const SizedBox(height: 15),
              _buildTextField(
                  "Middle Name", _middleNameCtrl, Icons.person_outline,
                  required: false),
              const SizedBox(height: 15),
              _buildTextField(
                  "Last Name *", _lastNameCtrl, Icons.person_outline),
              const SizedBox(height: 15),
              _buildTextField("Mobile Number *", _phoneCtrl, Icons.phone,
                  isNumber: true, maxLength: 10),

              const SizedBox(height: 25),

              _sectionHeader("Farming Details"),
              DropdownButtonFormField<String>(
                value: _farmSize,
                decoration: _inputDecoration("Farm Size *", Icons.landscape),
                items: _farmSizeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _farmSize = v),
                validator: (v) => v == null ? "Required" : null,
              ),

              const SizedBox(height: 25),

              _sectionHeader("Location"),
              _locationDropdown("State *", _selectedStateId, _stateList, (val) {
                setState(() {
                  _selectedStateId = val;
                  _districtList = LocationService.getDistricts(val!);
                  _selectedDistrictId = null;
                  _talukaList = [];
                  _villageList = [];
                });
              }),
              const SizedBox(height: 15),
              _locationDropdown(
                  "District *", _selectedDistrictId, _districtList, (val) {
                setState(() {
                  _selectedDistrictId = val;
                  _talukaList =
                      LocationService.getTalukas(_selectedStateId!, val!);
                  _selectedTalukaId = null;
                  _villageList = [];
                });
              }),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _locationDropdown(
                        "Taluka", _selectedTalukaId, _talukaList, (val) {
                      setState(() {
                        _selectedTalukaId = val;
                        _villageList = LocationService.getVillages(
                            _selectedStateId!, _selectedDistrictId!, val!);
                        _selectedVillageId = null;
                      });
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _locationDropdown(
                        "Village", _selectedVillageId, _villageList, (val) {
                      setState(() => _selectedVillageId = val);
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              _sectionHeader("Address"),
              _buildTextField("Address / Landmark *", _addr1Ctrl, Icons.home),
              const SizedBox(height: 15),
              _buildTextField("Pincode *", _pinCtrl, Icons.pin_drop,
                  isNumber: true, maxLength: 6),

              const SizedBox(height: 25),

              // --- BANK DETAILS SECTION ---
              _sectionHeader("Bank Details"),
              _buildTextField("Bank Name", _bankNameCtrl, Icons.account_balance,
                  required: false),
              const SizedBox(height: 15),
              _buildTextField("Account Number", _bankAccCtrl, Icons.numbers,
                  isNumber: true, required: false),
              const SizedBox(height: 15),
              _buildTextField("IFSC Code", _bankIfscCtrl, Icons.qr_code,
                  required: false),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateFarmer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inspectorColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: _inspectorColor),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, int? maxLength, bool required = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      validator: (value) {
        if (!required) return null;
        return value == null || value.trim().isEmpty
            ? "$label is required"
            : null;
      },
      decoration: _inputDecoration(label, icon).copyWith(counterText: ""),
    );
  }

  Widget _locationDropdown(String label, String? value,
      List<LocalizedItem> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.nameEn, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => label.contains("*") && v == null ? "Required" : null,
      decoration: _inputDecoration(label, Icons.map),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _inspectorColor.withOpacity(0.6)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
