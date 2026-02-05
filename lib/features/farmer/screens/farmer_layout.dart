import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

// ✅ REAL IMPORTS
import 'package:agriyukt_app/features/farmer/screens/farmer_home_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/my_crops_tab.dart';
import 'package:agriyukt_app/features/farmer/screens/orders_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/profile_tab.dart';
import 'package:agriyukt_app/features/farmer/screens/alerts_tab.dart';
import 'package:agriyukt_app/features/farmer/screens/widgets/farmer_drawer.dart';

class FarmerLayout extends StatefulWidget {
  const FarmerLayout({super.key});

  @override
  State<FarmerLayout> createState() => _FarmerLayoutState();
}

class _FarmerLayoutState extends State<FarmerLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ FIXED: Removed 'late final' and initialized directly without 'const'
  // This solves the "Not a constant expression" error completely.
  final List<Widget> _screens = [
    const FarmerHomeScreen(),
    const MyCropsTab(), // If this line errors, remove 'const' from here
    const OrdersScreen(),
    const ProfileTab(),
  ];

  // 👇 IF THE ABOVE STILL FAILS, USE THIS LIST INSTEAD:
  /*
  final List<Widget> _screens = [
    FarmerHomeScreen(),
    MyCropsTab(),
    OrdersScreen(),
    ProfileTab(),
  ];
  */

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  // ✅ Helper for Localized Text
  String _text(String key) => FarmerText.get(context, key);

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
    Provider.of<LanguageProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: FarmerDrawer(onTabChange: _switchTab),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          "AgriYukt",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id',
                    Supabase.instance.client.auth.currentUser?.id ?? '')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final hasUnread = notifications.any((n) => n['is_read'] == false);

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 26),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AlertsTab())),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF1B5E20), width: 1.5)),
                      ),
                    )
                ],
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B5E20));
            }
            return GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _switchTab,
          backgroundColor: Colors.white,
          indicatorColor: Colors.green.shade100,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home, color: Color(0xFF1B5E20)),
                label: _text('home')),
            NavigationDestination(
                icon: const Icon(Icons.grass_outlined),
                selectedIcon: const Icon(Icons.grass, color: Color(0xFF1B5E20)),
                label: _text('my_crops').contains(' ')
                    ? _text('my_crops').split(' ').last
                    : _text('my_crops')),
            NavigationDestination(
                icon: const Icon(Icons.shopping_bag_outlined),
                selectedIcon:
                    const Icon(Icons.shopping_bag, color: Color(0xFF1B5E20)),
                label: _text('orders')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon:
                    const Icon(Icons.person, color: Color(0xFF1B5E20)),
                label: _text('profile')),
          ],
        ),
      ),
    );
  }
}