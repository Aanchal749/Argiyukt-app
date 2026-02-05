import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/buyer_drawer.dart';
import 'buyer_home_screen.dart';
import 'buyer_marketplace_screen.dart';
import 'buyer_profile_screen.dart';
import 'buyer_orders_screen.dart';
import 'buyer_favorites_screen.dart';
// ✅ CHANGED: Import the specific Buyer Notification Screen
import 'package:agriyukt_app/features/buyer/screens/buyer_notification_screen.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;

  // AgriYukt Primary Green
  final Color _primaryGreen = const Color(0xFF1565C0);

  final List<Widget> _screens = [
    const BuyerHomeScreen(),
    const BuyerMarketplaceScreen(),
    const BuyerOrdersScreen(),
    const BuyerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: BuyerDrawer(onTabChange: _onTabChange),
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          "AgriYukt",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          // ✅ Favorites Icon
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyerFavoritesScreen()),
              );
            },
          ),

          // ✅ REAL-TIME NOTIFICATION STREAM
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id', _supabase.auth.currentUser?.id ?? '')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              // Check if there are any unread notifications
              final notifications = snapshot.data ?? [];
              final bool hasUnread =
                  notifications.any((n) => n['is_read'] == false);

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      // ✅ UPDATED: Navigates to BuyerNotificationScreen
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BuyerNotificationScreen()));
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: _primaryGreen, width: 1.5)),
                        constraints: const BoxConstraints(
                          minWidth: 10,
                          minHeight: 10,
                        ),
                      ),
                    )
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabChange,
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: Colors.green.shade100,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF2E7D32)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF2E7D32)),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF2E7D32)),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF2E7D32)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
