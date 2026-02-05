import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // --- STATE ---
  File? _frontImage;
  File? _backImage;
  String? _existingFrontUrl;
  String? _existingBackUrl;

  bool _isUploading = false;
  String _status = "Loading...";
  bool _isEditing = false;

  // STRICT VALIDATION FLAGS
  bool _isFrontValid = false;
  bool _isBackValid = false;

  // MESSAGES
  String _frontScanMsg = "Waiting for upload...";
  String _backScanMsg = "Waiting for upload...";

  // DATA TO STORE
  String? _extractedAadharNumber;
  String? _extractedNameFromCard;
  String _expectedName = "";

  @override
  void initState() {
    super.initState();
    _fetchProfileAndStatus();
  }

  // --- 1. FETCH PROFILE ---
  Future<void> _fetchProfileAndStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select(
              'first_name, last_name, verification_status, aadhar_number, aadhar_name, aadhar_front_url, aadhar_back_url')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          // Normalize name for matching
          String fname = (data['first_name'] ?? "").toLowerCase();
          String lname = (data['last_name'] ?? "").toLowerCase();
          _expectedName = "$fname $lname".trim();

          _status = data['verification_status'] ?? "Not Uploaded";
          _extractedAadharNumber = data['aadhar_number'];
          _extractedNameFromCard = data['aadhar_name'];
          _existingFrontUrl = data['aadhar_front_url'];
          _existingBackUrl = data['aadhar_back_url'];

          _isEditing = _status != 'Verified';

          if (_status == 'Verified') {
            _isFrontValid = true;
            _isBackValid = true;
            _frontScanMsg = "✅ Identity Verified";
            _backScanMsg = "✅ Address Verified";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  // --- 2. ANALYZE IMAGE (ML KIT - STRICT LOGIC) ---
  Future<void> _analyzeImage(File image, bool isFront) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      String fullText = recognizedText.text.toLowerCase().replaceAll("\n", " ");

      // Quality Check (Low char count = blurry)
      if (fullText.length < 20) {
        setState(() {
          if (isFront) {
            _frontScanMsg = "❌ Image Blurry. Retake.";
            _isFrontValid = false;
            _extractedAadharNumber = null;
            _extractedNameFromCard = null;
          } else {
            _backScanMsg = "❌ Text Unreadable. Retake.";
            _isBackValid = false;
          }
        });
        return;
      }

      if (isFront) {
        // Front Logic: Govt + Number + Name
        bool hasGovt = fullText.contains("government") ||
            fullText.contains("india") ||
            fullText.contains("govt");

        RegExp digitRegex = RegExp(r'\d{4}\s\d{4}\s\d{4}');
        RegExpMatch? match = digitRegex.firstMatch(recognizedText.text);
        bool hasNumber = match != null;

        // Strict Name Matching
        bool nameMatches = false;
        String foundName = "";

        if (_expectedName.isNotEmpty) {
          String firstNameOnly = _expectedName.split(" ")[0];

          for (TextBlock block in recognizedText.blocks) {
            for (TextLine line in block.lines) {
              // Check if line contains user's first name
              if (line.text.toLowerCase().contains(firstNameOnly)) {
                foundName = line.text;
                nameMatches = true;
                break;
              }
            }
            if (nameMatches) break;
          }
        }

        if (!hasGovt) {
          _updateFrontStatus(false, "❌ Not an Aadhar Card.");
        } else if (!hasNumber) {
          _updateFrontStatus(false, "❌ Aadhar Number Not Visible.");
        } else if (!nameMatches) {
          _updateFrontStatus(
              false, "❌ Name Mismatch (Expected: $_expectedName).");
        } else {
          // ✅ SUCCESS
          _extractedAadharNumber = match!.group(0);
          _extractedNameFromCard = foundName;
          _updateFrontStatus(true, "✅ Verified: Name & ID Match!");
        }
      } else {
        // Back Logic: Address
        bool hasAddress = fullText.contains("address") ||
            fullText.contains("pin") ||
            fullText.contains("father");
        if (hasAddress) {
          setState(() {
            _isBackValid = true;
            _backScanMsg = "✅ Address Detected";
          });
        } else {
          setState(() {
            _isBackValid = false;
            _backScanMsg = "⚠️ Address unclear. Try again.";
          });
        }
      }
    } catch (e) {
      setState(() {
        if (isFront) _frontScanMsg = "❌ Scan Error.";
      });
    } finally {
      textRecognizer.close();
    }
  }

  void _updateFrontStatus(bool isValid, String msg) {
    setState(() {
      _isFrontValid = isValid;
      _frontScanMsg = msg;
      if (!isValid) {
        _extractedAadharNumber = null;
        _extractedNameFromCard = null;
      }
    });
  }

  // --- 3. PICKER & CROPPER (FIXED: STATUS BAR OVERLAP) ---
  Future<void> _pickAndCropImage(bool isFront, {File? sourceFile}) async {
    String? sourcePath;
    if (sourceFile != null) {
      sourcePath = sourceFile.path;
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) sourcePath = pickedFile.path;
    }

    if (sourcePath != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Align Card',
            toolbarColor: Colors.blue[900], // Toolbar color
            toolbarWidgetColor: Colors.white, // Icon/Text color

            // ✅ CRITICAL FIX: Forces status bar to be solid Black
            // preventing the overlap issue.
            statusBarColor: Colors.black,

            activeControlsWidgetColor: Colors.blue[900],
            backgroundColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit Card',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        File finalImage = File(croppedFile.path);

        setState(() {
          if (isFront) {
            _frontImage = finalImage;
            _frontScanMsg = "🔍 Scanning...";
          } else {
            _backImage = finalImage;
            _backScanMsg = "🔍 Scanning...";
          }
        });

        await _analyzeImage(finalImage, isFront);
      }
    }
  }

  void _deleteImage(bool isFront) {
    setState(() {
      if (isFront) {
        _frontImage = null;
        _isFrontValid = false;
        _frontScanMsg = "Waiting for upload...";
        _extractedAadharNumber = null;
        _extractedNameFromCard = null;
      } else {
        _backImage = null;
        _isBackValid = false;
        _backScanMsg = "Waiting for upload...";
      }
    });
  }

  // --- 4. SUBMIT & STORE ---
  Future<void> _submitVerification() async {
    if (!_isFrontValid || _extractedAadharNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Front ID Invalid. Cannot Submit."),
          backgroundColor: Colors.red));
      return;
    }
    if (!_isBackValid && _backImage == null && _existingBackUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please upload Back side."),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isUploading = true);
    final user = Supabase.instance.client.auth.currentUser!;
    final time = DateTime.now().millisecondsSinceEpoch;

    try {
      String? frontUrl = _existingFrontUrl;
      String? backUrl = _existingBackUrl;

      if (_frontImage != null) {
        final frontPath = '${user.id}/front_$time.jpg';
        await Supabase.instance.client.storage
            .from('verification_docs')
            .upload(frontPath, _frontImage!);
        frontUrl = Supabase.instance.client.storage
            .from('verification_docs')
            .getPublicUrl(frontPath);
      }

      if (_backImage != null) {
        final backPath = '${user.id}/back_$time.jpg';
        await Supabase.instance.client.storage
            .from('verification_docs')
            .upload(backPath, _backImage!);
        backUrl = Supabase.instance.client.storage
            .from('verification_docs')
            .getPublicUrl(backPath);
      }

      String finalStatus = _isFrontValid ? 'Verified' : 'Pending';

      // ✅ Store URL, Number AND Name
      await Supabase.instance.client.from('profiles').update({
        'aadhar_front_url': frontUrl,
        'aadhar_back_url': backUrl,
        'aadhar_number': _extractedAadharNumber,
        'aadhar_name': _extractedNameFromCard,
        'verification_status': finalStatus,
      }).eq('id', user.id);

      setState(() {
        _status = finalStatus;
        _isEditing = false;
        _existingFrontUrl = frontUrl;
        _existingBackUrl = backUrl;
        _frontImage = null;
        _backImage = null;
      });

      if (mounted) {
        if (finalStatus == 'Verified') {
          _showSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Uploaded!"), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.verified_user,
                  size: 50, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text("Identity Confirmed",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
                "Name: ${_extractedNameFromCard ?? 'Matched'}\nID: ${_extractedAadharNumber ?? 'N/A'}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text("Continue"),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_isEditing ? "Smart Verification" : "My Digital ID",
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isEditing && _status == 'Verified')
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
              label: const Text("Re-Verify",
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      // ✅ SAFE AREA: Prevents content from going under status bar or bottom nav
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatusCard()),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    "Card name must match '$_expectedName'",
                                    style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: 13))),
                          ],
                        ),
                      ),
                    _buildDocumentCard(
                      label: "Front Side (Name & Photo)",
                      isFront: true,
                      newImage: _frontImage,
                      existingUrl: _existingFrontUrl,
                      isValid: _isFrontValid,
                      message: _frontScanMsg,
                    ),
                    const SizedBox(height: 20),
                    _buildDocumentCard(
                      label: "Back Side (Address)",
                      isFront: false,
                      newImage: _backImage,
                      existingUrl: _existingBackUrl,
                      isValid: _isBackValid,
                      message: _backScanMsg,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (_isEditing)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isUploading || !_isFrontValid)
                          ? null
                          : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("VERIFY & SAVE",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Your identity is verified and secured.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color bg = _status == 'Verified'
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFDBEAFE);
    Color text = _status == 'Verified'
        ? const Color(0xFF166534)
        : const Color(0xFF1E40AF);
    IconData icon = _status == 'Verified' ? Icons.verified : Icons.shield;
    String title =
        _status == 'Verified' ? "Verified Account" : "Verification Required";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: bg.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        children: [
          Icon(icon, color: text, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: text, fontWeight: FontWeight.bold, fontSize: 16)),
              if (_extractedAadharNumber != null)
                Text("ID: $_extractedAadharNumber",
                    style:
                        TextStyle(color: text.withOpacity(0.8), fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String label,
    required bool isFront,
    required File? newImage,
    required String? existingUrl,
    required bool isValid,
    required String message,
  }) {
    bool hasImage =
        newImage != null || (existingUrl != null && existingUrl.isNotEmpty);
    Color statusColor =
        isValid ? Colors.green : (hasImage ? Colors.red : Colors.grey);
    IconData statusIcon =
        isValid ? Icons.check_circle : (hasImage ? Icons.error : Icons.info);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14))),
        GestureDetector(
          onTap: (_isEditing && newImage == null)
              ? () => _pickAndCropImage(isFront)
              : null,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
            ),
            child: Stack(
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox.expand(
                      child: newImage != null
                          ? Image.file(newImage, fit: BoxFit.cover)
                          : Image.network(
                              existingUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, loading) {
                                if (loading == null) return child;
                                return const Center(
                                    child: CircularProgressIndicator());
                              },
                              errorBuilder: (ctx, err, stack) => const Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    Icon(Icons.broken_image,
                                        color: Colors.grey),
                                    Text("Failed to load",
                                        style: TextStyle(fontSize: 10))
                                  ])),
                            ),
                    ),
                  )
                else
                  Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.add_a_photo,
                            size: 30, color: Colors.blue[200]),
                        const SizedBox(height: 10),
                        const Text("Tap to Scan",
                            style: TextStyle(color: Colors.grey)),
                      ])),

                // ✅ ACTION ICONS: Pen & Delete (Always visible on top of image)
                if (_isEditing && hasImage)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _pickAndCropImage(isFront,
                                sourceFile: newImage),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: "Replace",
                          ),
                          Container(
                              width: 1,
                              height: 20,
                              color: Colors.grey.shade300),
                          IconButton(
                            onPressed: () => _deleteImage(isFront),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: "Remove",
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(message,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
            ]))
      ],
    );
  }
}
