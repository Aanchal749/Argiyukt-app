import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // ✅ Added Provider

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key});

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  final _supabase = Supabase.instance.client;
  String _referralCode = "LOADING...";
  String _userRole = "farmer"; // Default role
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // ✅ Helper for Localized Text
  String _text(String key) => FarmerText.get(context, key);

  Future<void> _fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (data != null && data['role'] != null) {
              _userRole = data['role'].toString().toLowerCase();
            }

            // Generate Referral Code: Role Prefix + First 4 chars of UID
            String prefix = _userRole.length >= 3
                ? _userRole.substring(0, 3).toUpperCase()
                : "USR";
            String uidSnip = user.id.substring(0, 4).toUpperCase();
            _referralCode = "$prefix$uidSnip";

            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching invite data: $e");
        if (mounted) {
          setState(() {
            _referralCode = "AGRI2024"; // Fallback
            _isLoading = false;
          });
        }
      }
    }
  }

  String _getShareMessage() {
    // We can keep the share message logic simple or localize parts of it
    // For now, constructing a generic localized message
    return "Namaste! Join AgriYukt app.\n\n"
        "Referral Code: *$_referralCode*\n\n"
        "Download: https://agriyukt.com/download";
  }

  Future<void> _shareOnWhatsApp() async {
    String message = _getShareMessage();
    final url =
        Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _copyToClipboard(isError: true);
      }
    } catch (e) {
      _copyToClipboard(isError: true);
    }
  }

  void _copyToClipboard({bool isError = false}) {
    Clipboard.setData(ClipboardData(text: _getShareMessage()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isError ? _text('wa_not_installed') : _text('msg_copied'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: isError ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
    Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _text('refer_earn_title'), // ✅ Localized Title
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // --- 1. HERO SECTION ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 30, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.card_giftcard_rounded,
                            size: 80,
                            color: Colors.orange.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _text(
                              'invite_earn_title'), // ✅ "Invite Friends, Earn ₹50"
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _text('invite_earn_desc'), // ✅ Description
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- 2. REFERRAL CODE CARD ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            _text(
                                'your_referral_code'), // ✅ "YOUR REFERRAL CODE"
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _referralCode,
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  Text(
                                    _text('step_1'), // "Share your code..."
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Material(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _referralCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            _text(
                                                'code_copied'), // ✅ "Code copied!"
                                            style: GoogleFonts.poppins()),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy,
                                            size: 16, color: Color(0xFF1B5E20)),
                                        const SizedBox(width: 6),
                                        Text(
                                          _text('copy'), // ✅ "COPY"
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF1B5E20),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 3. HOW IT WORKS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "How it works?", // Simple header, can be localized or kept simple
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildStepRow(
                          "1",
                          _text('step_1'), // ✅
                          Icons.share_outlined,
                        ),
                        _buildStepRow(
                          "2",
                          _text('step_2'), // ✅
                          Icons.person_add_alt_1_outlined,
                        ),
                        _buildStepRow(
                          "3",
                          _text('step_3'), // ✅
                          Icons.account_balance_wallet_outlined,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 4. BOTTOM BUTTONS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: _shareOnWhatsApp,
                              icon: const Icon(Icons.chat_bubble_outline,
                                  color: Colors.white),
                              label: Text(_text('whatsapp'), // ✅
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: OutlinedButton.icon(
                              onPressed: () => _copyToClipboard(),
                              icon: const Icon(Icons.share,
                                  color: Colors.black87),
                              label: Text(_text('share'), // ✅
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.grey.shade300, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStepRow(String number, String text, IconData icon,
      {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade100, width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.1), blurRadius: 5)
                  ],
                ),
                child: Icon(icon, color: const Color(0xFF1B5E20), size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.green.shade50,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
