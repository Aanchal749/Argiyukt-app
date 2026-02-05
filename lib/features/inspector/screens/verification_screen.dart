import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const VerificationScreen(
      {super.key, required this.farmId, required this.farmName});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();

  File? _evidenceImage;
  String? _selectedGrade;
  bool _isSubmitting = false;

  // 1. Image Picker Logic
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _evidenceImage = File(pickedFile.path);
      });
    }
  }

  // 2. Upload & Submit Logic
  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_evidenceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an evidence photo')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // A. Upload Image to Supabase Storage
      final fileName =
          '${widget.farmId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('inspection-images')
          .upload(fileName, _evidenceImage!);

      // B. Get Public URL
      final imageUrl = Supabase.instance.client.storage
          .from('inspection-images')
          .getPublicUrl(fileName);

      // C. Insert Record into Database
      await Supabase.instance.client.from('inspections').insert({
        'inspector_id': userId,
        'farm_id': widget.farmId,
        'report_summary': _reportController.text,
        'quality_grade': _selectedGrade,
        'status': 'verified',
        'inspection_images': [imageUrl], // Storing as array
        'completed_date': DateTime.now().toIso8601String(),
      });

      // D. Update Farm Status to "Verified"
      await Supabase.instance.client.from('farms').update({
        'is_verified': true,
      }).match({'id': widget.farmId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification Submitted Successfully!')),
        );
        Navigator.pop(context); // Go back to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Farm")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Inspecting: ${widget.farmName}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Photo Section
              GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _evidenceImage != null
                      ? Image.file(_evidenceImage!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt,
                                size: 50, color: Colors.grey),
                            Text("Tap to take Evidence Photo"),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Grade Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Quality Grade', border: OutlineInputBorder()),
                value: _selectedGrade,
                items: ['A', 'B', 'C'].map((grade) {
                  return DropdownMenuItem(
                      value: grade, child: Text("Grade $grade"));
                }).toList(),
                onChanged: (val) => setState(() => _selectedGrade = val),
                validator: (val) =>
                    val == null ? 'Please assign a grade' : null,
              ),
              const SizedBox(height: 20),

              // Report Text Area
              TextFormField(
                controller: _reportController,
                decoration: const InputDecoration(
                  labelText: 'Inspection Report',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (val) =>
                    val!.isEmpty ? 'Report cannot be empty' : null,
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInspection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT VERIFICATION",
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
