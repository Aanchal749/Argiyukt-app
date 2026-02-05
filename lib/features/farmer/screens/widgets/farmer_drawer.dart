import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ LOCALIZATION IMPORT
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';

// Screens
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/add_crop_screen.dart';
import 'package:agriyukt_app/features/common/screens/settings_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/orders_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/profile_tab.dart';
import 'package:agriyukt_app/features/common/screens/support_screens.dart';
import 'package:agriyukt_app/features/common/screens/wallet_screen.dart';

class FarmerDrawer extends StatefulWidget {
  final Function(int)? onTabChange;

  const FarmerDrawer({super.key, this.onTabChange});

  @override
  State<FarmerDrawer> createState() => _FarmerDrawerState();
}

class _FarmerDrawerState extends State<FarmerDrawer> {
  final _supabase = Supabase.instance.client;
  String _userName = "Farmer";
  String _shortId = "0000";
  String _email = "";

  final Color _primaryGreen = const Color(0xFF1B5E20);

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
            .select('first_name, last_name')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _email = user.email ?? "";
            _shortId = user.id.substring(0, 4).toUpperCase();
            if (data != null) {
              _userName =
                  "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}"
                      .trim();
              if (_userName.isEmpty) _userName = "Farmer";
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching drawer data: $e");
      }
    }
  }

  void _navigate(int tabIndex, Widget? screen) {
    Navigator.pop(context);
    if (widget.onTabChange != null) {
      widget.onTabChange!(tabIndex);
    } else if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // --- HEADER ---
          InkWell(
            onTap: () => _navigate(3, const ProfileTab()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(color: _primaryGreen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : "F",
                      style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ✅ LOCALIZED ("Namaste, Name")
                  Text("${_text('namaste')}, $_userName",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text("ID: AGRI-$_shortId",
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),

          // --- MENU ITEMS ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // 1. My Profile
                _drawerItem(Icons.person_outline, _text('profile'), () {
                  // ✅ LOCALIZED
                  _navigate(3, const ProfileTab());
                }),

                // 2. Dashboard
                _drawerItem(Icons.dashboard_outlined, _text('dashboard'), () {
                  // ✅ LOCALIZED
                  _navigate(0, null);
                }),

                // 3. Add New Crop (Bold & Colored)
                _drawerItem(Icons.add_circle_outline, _text('add_crop'), () {
                  // ✅ LOCALIZED
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddCropScreen()));
                }, color: _primaryGreen, isBold: true),

                // 4. Active Crops (Goes to Inventory Tab)
                _drawerItem(Icons.grass_outlined, _text('my_crops'), () {
                  // ✅ LOCALIZED
                  _navigate(1, null);
                }),

                // 5. My Orders
                _drawerItem(Icons.shopping_bag_outlined, _text('orders'), () {
                  // ✅ LOCALIZED
                  _navigate(2, const OrdersScreen());
                }),

                // 6. My Wallet
                _drawerItem(Icons.account_balance_wallet_outlined,
                    _text('wallet'), // ✅ LOCALIZED
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              WalletScreen(themeColor: _primaryGreen)));
                }),

                const Divider(),

                // 7. Settings
                _drawerItem(Icons.settings_outlined, _text('settings'), () {
                  // ✅ LOCALIZED
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                              themeColor: _primaryGreen, role: 'farmer')));
                }),

                // 8. Help & Support
                _drawerItem(Icons.help_outline, _text('help_support'), () {
                  // ✅ LOCALIZED (Mapped to AgriBot/Support)
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ContactSupportScreen(themeColor: _primaryGreen)));
                }),
              ],
            ),
          ),

          // --- 9. LOGOUT (With Safe Area) ---
          SafeArea(
            top: false, // Only add padding for bottom (navigation bar)
            child: Column(
              children: [
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(_text('logout'), // ✅ LOCALIZED
                      style: GoogleFonts.poppins(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await _supabase.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false);
                    }
                  },
                ),
                const SizedBox(height: 10), // Extra breathing room
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String text, VoidCallback onTap,
      {Color color = Colors.black87, bool isBold = false}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text,
          style: GoogleFonts.poppins(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      onTap: onTap,
    );
  }
}
