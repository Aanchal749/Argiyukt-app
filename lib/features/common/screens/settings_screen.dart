import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agriyukt_app/features/common/screens/support_screens.dart';
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
  bool _isLoading = true;
  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _syncSettingsWithCloud();
  }

  // 🚀 Dual-Sync (Local + Cloud)
  Future<void> _syncSettingsWithCloud() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('push_notifications')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null && response['push_notifications'] != null) {
          _pushNotifications = response['push_notifications'] as bool;
        } else {
          final prefs = await SharedPreferences.getInstance();
          _pushNotifications = prefs.getBool('notif_push') ?? true;
        }
      }
    } catch (e) {
      debugPrint("DB Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚀 Save to Device AND Database
  Future<void> _toggleNotif(bool value) async {
    setState(() => _pushNotifications = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_push', value);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({'push_notifications': value}).eq('id', user.id);
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      setState(() => _pushNotifications = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to sync preference.",
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700));
      }
    }
  }

  // 🚀 Web Launcher
  Future<void> _launchWeb(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Unable to open browser.", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700));
      }
    }
  }

  // 🚀 PRODUCTION FIX: Safe Dialog Closure & Navigation
  void _showConfirm(String title, String msg, Color btnColor,
      Future<void> Function() onConfirm) {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: btnColor)),
              content: Text(msg, style: GoogleFonts.poppins(fontSize: 14)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text("Cancel",
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold))),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(
                          dialogContext); // 🚀 Close dialog FIRST to prevent black screen memory leak
                      setState(() => _isLoading = true);
                      await onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor, elevation: 0),
                    child: Text("Confirm",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ));
  }

  void _handleLogout() {
    _showConfirm("Log Out", "Are you sure you want to log out of AgriYukt?",
        widget.themeColor, () async {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    });
  }

  void _handleDelete() {
    _showConfirm(
        "Delete Account",
        "This will permanently erase your profile, crops, and data from our servers. This cannot be undone.",
        Colors.red.shade700, () async {
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase.from('profiles').delete().eq('id', user.id);
          await _supabase.auth.signOut();
          if (mounted)
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error deleting account. Contact support.",
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.red.shade700));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Settings",
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // --- 1. PREFERENCES ---
                _sectionTitle("PREFERENCES"),
                _settingsContainer([
                  SwitchListTile(
                    value: _pushNotifications,
                    onChanged: _toggleNotif,
                    activeColor: widget.themeColor,
                    title: Text("Push Notifications",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text("Receive updates on prices and orders",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ),
                ]),
                const SizedBox(height: 28),

                // --- 2. SUPPORT & LEGAL ---
                _sectionTitle("SUPPORT & LEGAL"),
                _settingsContainer([
                  _actionTile(Icons.chat_bubble_outline, "AI Assistant Chat",
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SupportChatScreen(role: widget.role)));
                  }),
                  _divider(),
                  _actionTile(Icons.headset_mic_outlined, "Contact Support",
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ContactSupportScreen(
                                themeColor: widget.themeColor)));
                  }),
                  _divider(),
                  _actionTile(
                      Icons.privacy_tip_outlined,
                      "Privacy Policy",
                      () => _launchWeb(
                          "https://agriyukt.github.io/agriyukt-legal/privacy.html")),
                  _divider(),
                  _actionTile(
                      Icons.description_outlined,
                      "Terms of Service",
                      () => _launchWeb(
                          "https://agriyukt.github.io/agriyukt-legal/terms.html")),
                ]),
                const SizedBox(height: 40),

                // --- 3. DANGER ZONE ---
                Text("DANGER ZONE",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade300,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _dangerButton(
                    "Log Out", Icons.logout, widget.themeColor, _handleLogout),
                const SizedBox(height: 12),
                _dangerButton("Delete Account", Icons.delete_forever,
                    Colors.red.shade700, _handleDelete),

                const SizedBox(height: 40),
                Center(
                    child: Text("Version 1.0.0 (Cloud Synced)",
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600))),
              ],
            ),
    );
  }

  // --- UI Helpers ---
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1)),
      );

  Widget _settingsContainer(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: children),
      );

  Widget _actionTile(IconData icon, String title, VoidCallback onTap) =>
      ListTile(
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: widget.themeColor.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: widget.themeColor, size: 20)),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        onTap: onTap,
      );

  Widget _divider() =>
      Divider(height: 1, indent: 60, color: Colors.grey.shade100);

  Widget _dangerButton(
          String label, IconData icon, Color color, VoidCallback action) =>
      InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
        ),
      );
}
