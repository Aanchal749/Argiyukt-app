import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ CORE SERVICES
import 'package:agriyukt_app/core/services/notification_service.dart';

// ✅ SCREENS
import 'inspector_home_tab.dart';
import 'inspector_add_crop_tab.dart';
import 'inspector_orders_tab.dart';
import 'inspector_profile_tab.dart';
import 'inspector_notification_screen.dart';

// ✅ WIDGETS
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

  // 🎨 Theme
  final Color _inspectorColor = const Color(0xFF512DA8);

  // 🔔 State
  bool _hasUnreadNotifications = false;

  // 📱 Screens List (Dynamic & Crash-Proof)
  // Note: We use const constructors where possible for performance,
  // but keep the list dynamic to support future changes.
  late final List<Widget> _screens = [
    const InspectorHomeTab(),
    const InspectorAddCropTab(), // Bridge screen (Safe to be const here now!)
    const InspectorOrdersTab(),
    const InspectorProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotifications();

    // 🚀 Real-time Listener (Safe)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationService().listenToOrders(context);
    });
  }

  @override
  void dispose() {
    NotificationService().stopListening();
    super.dispose();
  }

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
      debugPrint("⚠️ Notification Check Error: $e");
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return; // Prevent unnecessary rebuilds
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: InspectorDrawer(onItemSelected: _switchTab),
      appBar: AppBar(
        backgroundColor: _inspectorColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          "AgriYukt",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.notifications_active, color: Colors.white),
                tooltip: 'Notifications',
                onPressed: () {
                  setState(() => _hasUnreadNotifications = false);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InspectorNotificationScreen()));
                },
              ),
              if (_hasUnreadNotifications)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: _inspectorColor, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ✅ IndexedStack preserves state (scroll position, inputs)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: Colors.white,
        indicatorColor: Colors.deepPurple.shade100,
        labelBehavior: NavigationDestinationLabelBehavior
            .alwaysShow, // Consistent UI prevents jitter
        height: 65, // Comfortable tap height
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
