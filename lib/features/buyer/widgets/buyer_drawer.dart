import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ Screen Imports
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/common/screens/settings_screen.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_favorites_screen.dart';
// ✅ Import the new Support Screen file
import 'package:agriyukt_app/features/common/screens/support_screens.dart';

class BuyerDrawer extends StatefulWidget {
  final Function(int) onTabChange;
  const BuyerDrawer({super.key, required this.onTabChange});

  @override
  State<BuyerDrawer> createState() => _BuyerDrawerState();
}

class _BuyerDrawerState extends State<BuyerDrawer> {
  final _supabase = Supabase.instance.client;
  String _userName = "Buyer";
  String _shortId = "0000";
  String _email = "";

  // ✅ Buyer Theme Color
  final Color _buyerBlue = const Color(0xFF1565C0);

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
            _shortId = user.id.length > 4
                ? user.id.substring(0, 4).toUpperCase()
                : "0778";

            if (data != null) {
              _userName =
                  "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}"
                      .trim();
              if (_userName.isEmpty) _userName = "Buyer";
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching drawer data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // --- 1. HEADER (Blue) ---
          InkWell(
            onTap: () {
              Navigator.pop(context);
              widget.onTabChange(3); // Go to Profile Tab
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                color: _buyerBlue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : "B",
                      style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _buyerBlue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Namaste, $_userName",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "ID: BUY-$_shortId",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. MENU ITEMS ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _drawerItem(
                  icon: Icons.person_outline,
                  text: "My Profile",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTabChange(3); // Profile Tab
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(thickness: 0.5),
                ),
                _drawerItem(
                  icon: Icons.home_outlined,
                  text: "Home",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTabChange(0); // Home Tab
                  },
                ),
                _drawerItem(
                  icon: Icons.storefront_outlined,
                  text: "Market",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTabChange(1); // Market Tab
                  },
                ),

                _drawerItem(
                  icon: Icons.favorite_border,
                  text: "My Favorites",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BuyerFavoritesScreen()),
                    );
                  },
                ),

                _drawerItem(
                  icon: Icons.receipt_long_outlined,
                  text: "My Orders",
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTabChange(2); // Orders Tab
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Divider(thickness: 0.5),
                ),

                // 1. Settings
                _drawerItem(
                  icon: Icons.settings_outlined,
                  text: "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          themeColor: _buyerBlue,
                          role: 'buyer',
                        ),
                      ),
                    );
                  },
                ),

                // ✅ 2. Help & Support (Now links to ContactSupportScreen)
                _drawerItem(
                  icon: Icons.support_agent,
                  text: "Help & Support",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactSupportScreen(
                            themeColor: _buyerBlue), // ✅ FIXED
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- 3. LOGOUT ---
          SafeArea(
            bottom: true,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 24),
                title: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  await _supabase.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widget for Items ---
  Widget _drawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: Colors.black87, size: 24),
      title: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
