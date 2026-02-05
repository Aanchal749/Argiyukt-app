import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../create_account_controller.dart'; 

class VerificationTab extends StatefulWidget {
  final CreateAccountController controller;

  const VerificationTab({super.key, required this.controller});

  @override
  State<VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends State<VerificationTab> {
  File? _frontImage;
  File? _backImage;
  String _frontMsg = "Upload Front Side";
  String _backMsg = "Upload Back Side";
  bool _isFrontValid = false;
  bool _isBackValid = false;

  // ML Kit Logic
  Future<void> _processImage(File image, bool isFront) async {
    final input = InputImage.fromFile(image);
    final recognizer = TextRecognizer();
    
    try {
      final text = await recognizer.processImage(input);
      String fullText = text.text.toLowerCase().replaceAll("\n", " ");

      if (isFront) {
        // Strict Front Logic
        bool hasGovt = fullText.contains("government") || fullText.contains("india");
        RegExp digitRegex = RegExp(r'\d{4}\s\d{4}\s\d{4}');
        var match = digitRegex.firstMatch(text.text);
        
        // ✅ FIXED: Use 'firstNameCtrl' instead of 'firstNameController'
        String enteredName = widget.controller.firstNameCtrl.text.toLowerCase();
        
        // Simple name check
        bool nameMatch = enteredName.isNotEmpty && fullText.contains(enteredName);

        if (hasGovt && match != null && nameMatch) {
          setState(() {
            _isFrontValid = true;
            _frontMsg = "✅ Valid: Name & ID Match";
          });
          
          // Update Controller
          widget.controller.setVerificationData(
            front: _frontImage,
            back: _backImage,
            number: match.group(0),
            name: enteredName, 
            isValid: _isFrontValid && _isBackValid,
          );
        } else {
          setState(() { 
            _isFrontValid = false; 
            _frontMsg = "❌ Name mismatch or unclear ID"; 
          });
        }
      } else {
        // Back Logic
        if (fullText.contains("address")) {
          setState(() { _isBackValid = true; _backMsg = "✅ Address Detected"; });
          
          // ✅ FIXED: Use 'verifiedAadharName' instead of 'verifiedName'
          widget.controller.setVerificationData(
            front: _frontImage,
            back: _backImage,
            number: widget.controller.extractedAadharNumber,
            name: widget.controller.verifiedAadharName, 
            isValid: _isFrontValid && _isBackValid,
          );
        } else {
           setState(() { _isBackValid = false; _backMsg = "⚠️ Address unclear"; });
        }
      }
    } finally {
      recognizer.close();
    }
  }

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: img.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Align Card',
          toolbarColor: Colors.blue[900],
          toolbarWidgetColor: Colors.white,
          statusBarColor: Colors.black, // Fix Overlap
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
        ),
      ],
    );

    if (cropped != null) {
      setState(() {
        if (isFront) _frontImage = File(cropped.path);
        else _backImage = File(cropped.path);
      });
      await _processImage(File(cropped.path), isFront);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Verify Identity", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("We need to verify your Aadhar card to create your account.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 25),

          _buildCard("Front Side (Name/Photo)", _frontImage, _frontMsg, _isFrontValid, true),
          const SizedBox(height: 20),
          _buildCard("Back Side (Address)", _backImage, _backMsg, _isBackValid, false),
        ],
      ),
    );
  }

  Widget _buildCard(String title, File? img, String msg, bool isValid, bool isFront) {
    return GestureDetector(
      onTap: () => _pickImage(isFront),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isValid ? Colors.green : Colors.grey.shade300, width: 2),
        ),
        child: img == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.blue[200]),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(img, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      color: isValid ? Colors.green : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
