import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ IMPORT CORE NOTIFICATION SERVICE (For Real-time Popups)
import 'package:agriyukt_app/core/services/notification_service.dart';

// ✅ RELATIVE SCREEN IMPORTS (Ensure these files exist)
import 'inspector_home_tab.dart';
import 'inspector_add_crop_tab.dart';
import 'inspector_orders_tab.dart';
import 'inspector_profile_tab.dart';

// ✅ IMPORT THE NEW INSPECTOR NOTIFICATION SCREEN
import 'inspector_notification_screen.dart';

// ✅ RELATIVE DRAWER IMPORT
import '../widgets/inspector_drawer.dart';

class InspectorLayout extends StatefulWidget {
  const InspectorLayout({super.key});

  @override
  State<InspectorLayout> createState() => _InspectorLayoutState();
}

class _InspectorLayoutState extends State<InspectorLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;

  // 🎨 Inspector Theme Color (Deep Purple)
  final Color _inspectorColor = const Color(0xFF512DA8);

  // ✅ LOGIC: Data Variables
  bool _hasUnreadNotifications = false;

  // ✅ The 4 Functional Tabs
  late final List<Widget> _screens = [
    const InspectorHomeTab(), // 0: Dashboard
    const InspectorAddCropTab(), // 1: Add Crop
    const InspectorOrdersTab(), // 2: Orders
    const InspectorProfileTab(), // 3: Profile
  ];

  @override
  void initState() {
    super.initState();

    // 1. Check for unread notifications (Red Dot Logic)
    _checkNotifications();

    // 2. ✅ CRITICAL: Start listening for Real-Time Order Notifications (Popup Logic)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("🚀 Inspector Layout: Starting Notification Listener...");
      NotificationService().listenToOrders(context);
    });
  }

  @override
  void dispose() {
    // ✅ NEW: Stop listening to save resources when Inspector leaves
    NotificationService().stopListening();
    super.dispose();
  }

  // --- CHECK NOTIFICATIONS (RED DOT) ---
  Future<void> _checkNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final count = await _supabase
            .from('notifications')
            .count(CountOption.exact)
            .eq('user_id', user.id)
            .eq('is_read', false);

        if (mounted) {
          setState(() => _hasUnreadNotifications = count > 0);
        }
      }
    } catch (e) {
      print("⚠️ Error checking notifications: $e");
    }
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // ✅ DRAWER CONNECTED CORRECTLY
      drawer: InspectorDrawer(onItemSelected: _switchTab),

      appBar: AppBar(
        backgroundColor: _inspectorColor,
        elevation: 0,
        centerTitle: true,

        // Hamburger Icon
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        // ✅ STATIC TITLE "AgriYukt"
        title: Text(
          "AgriYukt",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),

        actions: [
          // ✅ Notification Button
          Stack(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.notifications_active, color: Colors.white),
                onPressed: () {
                  // Clear the red dot immediately when clicked
                  setState(() => _hasUnreadNotifications = false);

                  // ✅ Navigates to the Inspector Notification Screen (History List)
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InspectorNotificationScreen()));
                },
              ),
              // Red Dot for Unread
              if (_hasUnreadNotifications)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),

      // ✅ State Preservation (IndexedStack keeps tabs alive)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: Colors.white,
        indicatorColor: Colors.deepPurple.shade100,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: _inspectorColor),
              label: 'Home'),
          NavigationDestination(
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle, color: _inspectorColor),
              label: 'Add Crop'),
          NavigationDestination(
              icon: const Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag, color: _inspectorColor),
              label: 'Orders'),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: _inspectorColor),
              label: 'Profile'),
        ],
      ),
    );
  }
}
