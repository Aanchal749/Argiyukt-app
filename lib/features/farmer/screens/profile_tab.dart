import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

// SCREEN IMPORTS
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/edit_profile_screen.dart';
import 'package:agriyukt_app/features/common/screens/settings_screen.dart';
import 'package:agriyukt_app/features/onboarding/screens/language_screen.dart';
import 'package:agriyukt_app/features/common/screens/support_chat_screen.dart';
import 'package:agriyukt_app/features/common/screens/invite_friend_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/farmer_wallet_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _name = "Farmer";

  // Internal status tracker
  String _internalStatus = "Pending";

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF1B5E20);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _bgOffWhite = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  // ✅ Helper for Localized Text
  String _text(String key) => FarmerText.get(context, key);

  Future<void> _fetchProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select(
                'first_name, last_name, verification_status, aadhar_front_url, aadhar_back_url, aadhar_number')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (data != null) {
              String fName = data['first_name'] ?? '';
              String lName = data['last_name'] ?? '';
              _name = "$fName $lName".trim();
              if (_name.isEmpty) _name = "Farmer";

              // ✅ ROBUST STATUS CHECK
              String dbStatus =
                  (data['verification_status'] ?? 'Pending').toString();
              String? frontUrl = data['aadhar_front_url'];
              String? backUrl = data['aadhar_back_url'];
              String? num = data['aadhar_number'];

              if (dbStatus.toLowerCase() == 'verified') {
                _internalStatus = "Verified";
              } else if (frontUrl != null &&
                  frontUrl.isNotEmpty &&
                  backUrl != null &&
                  backUrl.isNotEmpty &&
                  num != null &&
                  num.isNotEmpty) {
                _internalStatus = "Under Review";
              } else {
                _internalStatus = "Pending";
              }
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _getShortId() {
    final uid = _supabase.auth.currentUser?.id ?? "";
    if (uid.length < 5) return "UNKNOWN";
    return "#${uid.substring(0, 5).toUpperCase()}";
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Consumer ensures instant translation update
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return Scaffold(
            backgroundColor: _bgOffWhite,
            body:
                Center(child: CircularProgressIndicator(color: _primaryGreen)),
          );
        }

        final memberId = _getShortId();

        return Scaffold(
          backgroundColor: _bgOffWhite,
          body: RefreshIndicator(
            onRefresh: _fetchProfileData,
            color: _primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              child: Column(
                children: [
                  // --- 1. HEADER SECTION ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryGreen, _lightGreen],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryGreen.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : "F",
                              style: GoogleFonts.poppins(
                                  color: _primaryGreen,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_text('namaste'), // "Namaste"
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 14)),
                              Text(
                                _name,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),

                              // STATUS BADGE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _internalStatus == "Verified"
                                        ? Colors.green
                                        : (_internalStatus == "Under Review"
                                            ? Colors.blue
                                            : Colors.orange),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _internalStatus == "Verified"
                                            ? Icons.verified
                                            : Icons.hourglass_top,
                                        color: Colors.white,
                                        size: 14),
                                    const SizedBox(width: 4),
                                    // ✅ Localized Status Text
                                    Text(
                                        _internalStatus == "Verified"
                                            ? _text('verified')
                                            : (_internalStatus == "Under Review"
                                                ? _text('under_review')
                                                : _text('pending')),
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ID COPY
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: memberId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("ID Copied!"),
                                        duration: Duration(milliseconds: 800)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fingerprint,
                                          size: 12, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        "ID: $memberId",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.copy,
                                          size: 10, color: Colors.white70),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- 2. QUICK ACTIONS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_text('quick_actions'), // "Quick Actions"
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            // ✅ EDIT PROFILE - Forces Refresh on Return
                            _modernGridItem(
                                icon: Icons.person_outline,
                                title: _text('personal_details'),
                                subtitle: _text('edit'),
                                color: Colors.orange,
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const EditProfileScreen()));
                                  // Refresh data immediately after return
                                  if (context.mounted) {
                                    setState(() => _isLoading = true);
                                    _fetchProfileData();
                                  }
                                }),

                            _modernGridItem(
                                icon: Icons.translate,
                                title: _text('language'),
                                subtitle: "Eng / मराठी",
                                color: Colors.purple,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        // ✅ FIXED: Using fromProfile: true
                                        builder: (_) => const LanguageScreen(
                                            fromProfile: true)))),

                            _modernGridItem(
                                icon: Icons.support_agent,
                                title: _text('agribot'),
                                subtitle: "24/7 Support",
                                color: Colors.teal,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SupportChatScreen(
                                            role: 'farmer')))),

                            _modernGridItem(
                                icon: Icons.account_balance_wallet_outlined,
                                title: _text('wallet'),
                                subtitle: "Check balance",
                                color: Colors.green,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const FarmerWalletScreen()))),
                          ],
                        ),

                        const SizedBox(height: 25),

                        // --- 3. MENU LIST ---
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              _modernListOption(
                                  icon: Icons.settings_outlined,
                                  title: _text('settings'),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SettingsScreen(
                                              themeColor: _primaryGreen,
                                              role: 'farmer')))),
                              const Divider(height: 1, indent: 60),
                              _modernListOption(
                                  icon: Icons.share_outlined,
                                  title: "Invite Friend",
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const InviteFriendScreen()))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildLogoutButton(_text),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- HELPERS ---

  Widget _modernGridItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _modernListOption(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _primaryGreen),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget _buildLogoutButton(String Function(String) text) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: Text(text('logout'),
            style: GoogleFonts.poppins(
                color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: BorderSide(color: Colors.red.shade200),
            backgroundColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}
