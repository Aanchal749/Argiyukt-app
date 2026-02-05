import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added typography
import 'package:agriyukt_app/features/common/screens/change_password_screen.dart';
import 'package:agriyukt_app/features/common/screens/support_screens.dart';
import 'package:agriyukt_app/features/common/screens/legal_screens.dart';
import 'package:agriyukt_app/features/common/screens/support_chat_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Color themeColor;
  final String role;

  const SettingsScreen({
    super.key,
    required this.themeColor,
    this.role = 'farmer',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  // Notification Toggles
  bool _notifyCrops = true;
  bool _notifyOrders = true;
  bool _notifyInspector = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Simulate loading settings from DB/Local Storage
  Future<void> _loadSettings() async {
    // In a real app, fetch from SharedPreferences or Supabase 'user_settings' table
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        // Mock data
        _notifyCrops = true;
        _notifyOrders = true;
        _notifyInspector = false;
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    setState(() {
      if (key == 'crops') _notifyCrops = value;
      if (key == 'orders') _notifyOrders = value;
      if (key == 'inspector') _notifyInspector = value;
    });

    // Simulate API call to save preference
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // await _supabase.from('settings').upsert(...);
      }
      debugPrint("Updated $key to $value");
    } catch (e) {
      debugPrint("Error saving setting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // Matches App Theme
      appBar: AppBar(
        title: Text("Settings",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- 1. PREFERENCES ---
                _sectionHeader("Notifications & Preferences"),
                _buildContainer([
                  ListTile(
                    leading: _buildIcon(Icons.language),
                    title: Text("Language",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("English",
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            color: Colors.grey, size: 20),
                      ],
                    ),
                    onTap: () {
                      // Future: Show Language Dialog
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),

                  // NOTIFICATION TOGGLES
                  _buildSwitchTile(
                      "Crop Alerts",
                      "Get price updates & weather info",
                      _notifyCrops,
                      (v) => _toggleSetting('crops', v)),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildSwitchTile(
                      "Order Updates",
                      "Receive alerts for new orders & status",
                      _notifyOrders,
                      (v) => _toggleSetting('orders', v)),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildSwitchTile(
                      "Inspector Visits",
                      "Notify when an inspector is assigned",
                      _notifyInspector,
                      (v) => _toggleSetting('inspector', v)),
                ]),

                const SizedBox(height: 24),

                // --- 2. SECURITY & PRIVACY ---
                _sectionHeader("Security & Privacy"),
                _buildContainer([
                  _buildListTile(Icons.lock_outline, "Change Password", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangePasswordScreen(themeColor: widget.themeColor),
                      ),
                    );
                  }),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildListTile(Icons.privacy_tip_outlined, "Privacy Policy",
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaticContentScreen(
                          title: "Privacy Policy",
                          content: kPrivacyPolicy,
                          themeColor: widget.themeColor,
                        ),
                      ),
                    );
                  }),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildListTile(
                      Icons.description_outlined, "Terms & Conditions", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaticContentScreen(
                          title: "Terms & Conditions",
                          content: kTermsConditions,
                          themeColor: widget.themeColor,
                        ),
                      ),
                    );
                  }),
                ]),

                const SizedBox(height: 24),

                // --- 3. SUPPORT ---
                _sectionHeader("Support"),
                _buildContainer([
                  ListTile(
                    leading: _buildIcon(Icons.chat_bubble_outline),
                    title: Text("Chatbot (AI Assistant)",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text("Get instant help & FAQs",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupportChatScreen(role: widget.role),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildListTile(Icons.headset_mic_outlined, "Contact Support",
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ContactSupportScreen(themeColor: widget.themeColor),
                      ),
                    );
                  }),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  _buildListTile(Icons.bug_report_outlined, "Report an Issue",
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReportIssueScreen(themeColor: widget.themeColor),
                      ),
                    );
                  }),
                ]),

                const SizedBox(height: 24),

                // --- 4. ABOUT ---
                _sectionHeader("About"),
                _buildContainer([
                  _buildListTile(Icons.info_outline, "About App", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaticContentScreen(
                          title: "About AgriYukt",
                          content: kAboutApp,
                          themeColor: widget.themeColor,
                        ),
                      ),
                    );
                  }),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  ListTile(
                    leading: _buildIcon(Icons.android),
                    title: Text("App Version",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    trailing: Text("1.0.0",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  ),
                ]),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            color: widget.themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 16),
      ),
    );
  }

  Widget _buildContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: widget.themeColor.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: widget.themeColor, size: 20),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: _buildIcon(icon),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: widget.themeColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
    );
  }
}
