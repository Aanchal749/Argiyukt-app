import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ Screen Imports
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/common/screens/settings_screen.dart';
import 'package:agriyukt_app/features/common/screens/wallet_screen.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_farmers_tab.dart';

// ✅ Import Support Screen (For Help & Support Button)
import 'package:agriyukt_app/features/common/screens/support_screens.dart';

class InspectorDrawer extends StatefulWidget {
  final Function(int) onItemSelected;
  const InspectorDrawer({super.key, required this.onItemSelected});

  @override
  State<InspectorDrawer> createState() => _InspectorDrawerState();
}

class _InspectorDrawerState extends State<InspectorDrawer> {
  final _supabase = Supabase.instance.client;
  String _userName = "Officer";
  String _shortId = "0000";
  String _email = "";

  // 🎨 Inspector Theme Colors (Deep Purple)
  final Color _primaryPurple = const Color(0xFF512DA8);
  final Color _lightPurple = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _email = user.email ?? "";
            _shortId = user.id.length > 5
                ? user.id.substring(0, 5).toUpperCase()
                : "OFFICER";

            if (data != null) {
              String fName = data['first_name'] ?? '';
              String lName = data['last_name'] ?? '';
              _userName = "$fName $lName".trim();
              if (_userName.isEmpty) _userName = "Aanchal chauhan";
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching inspector data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // --- 1. HEADER SECTION ---
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryPurple, _lightPurple],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : "I",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _primaryPurple,
                ),
              ),
            ),
            accountName: Text(
              _userName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              "ID: #$_shortId • $_email",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            onDetailsPressed: () {
              Navigator.pop(context);
              widget.onItemSelected(3); // Switch to Profile Tab
            },
          ),

          // --- 2. MENU ITEMS ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ✅ 1. Profile (Moved to Top)
                _drawerTile(
                  icon: Icons.person_outline,
                  title: "My Profile",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onItemSelected(3); // Index 3 = InspectorProfileTab
                  },
                ),

                // ✅ 2. Dashboard
                _drawerTile(
                  icon: Icons.dashboard_outlined,
                  title: "Dashboard",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onItemSelected(0);
                  },
                ),

                // ✅ 3. Add Crop
                _drawerTile(
                  icon: Icons.add_circle_outline,
                  title: "Add Crop",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onItemSelected(1);
                  },
                ),

                // ✅ 4. Mapped Farmers
                _drawerTile(
                  icon: Icons.people_outline,
                  title: "Mapped Farmers",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InspectorFarmersTab()),
                    );
                  },
                ),

                // ✅ 5. Monitor Orders
                _drawerTile(
                  icon: Icons.shopping_bag_outlined,
                  title: "Monitor Orders",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onItemSelected(2);
                  },
                ),

                const Divider(indent: 20, endIndent: 20),

                // ✅ 6. My Wallet
                _drawerTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: "My Wallet",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WalletScreen(themeColor: _primaryPurple),
                      ),
                    );
                  },
                ),

                // ❌ REMOVED: Order History (As requested)

                // ✅ 7. Settings
                _drawerTile(
                  icon: Icons.settings_outlined,
                  title: "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          themeColor: _primaryPurple,
                          role: 'inspector',
                        ),
                      ),
                    );
                  },
                ),

                const Divider(indent: 20, endIndent: 20),

                // ✅ 8. Help & Support (Now opens ContactSupportScreen)
                _drawerTile(
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactSupportScreen(
                          themeColor: _primaryPurple,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- 3. LOGOUT FOOTER ---
          SafeArea(
            top: false, // Only apply to bottom
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: _buildLogoutButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _primaryPurple, size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await _supabase.auth.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: Text(
          "Log Out",
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.red.shade200),
          backgroundColor: Colors.red.shade50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
