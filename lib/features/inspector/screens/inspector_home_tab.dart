import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Screen Imports
import 'package:agriyukt_app/features/inspector/screens/add_farmer_screen.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_add_crop_tab.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_orders_tab.dart';
import 'package:agriyukt_app/widgets/agri_stats_dashboard.dart';

class InspectorHomeTab extends StatefulWidget {
  const InspectorHomeTab({super.key});

  @override
  State<InspectorHomeTab> createState() => _InspectorHomeTabState();
}

class _InspectorHomeTabState extends State<InspectorHomeTab> {
  // Inspector Data
  String _name = "Inspector";
  int _assignedFarmers = 0;
  int _pendingOrders = 0;
  int _activeOrders = 0;
  int _totalCropsManaged = 0;
  bool _loading = true;

  // Weather Data
  String _temp = "--";
  String _condition = "Loading...";
  IconData _weatherIcon = Icons.cloud;
  bool _weatherLoading = false;

  // Slider State
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  // Theme Colors
  final Color _primaryColor = const Color(0xFF512DA8); // Deep Purple
  final Color _lightColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchInspectorStats();
    _fetchWeather();
  }

  // --- 1. FETCH STATS (CORRECTED JOINS) ---
  Future<void> _fetchInspectorStats() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null) {
        // 1. Get My Profile Name
        final profile = await client
            .from('profiles')
            .select('first_name')
            .eq('id', user.id)
            .maybeSingle();

        // 2. Get My Farmers
        // "Who has my ID in their inspector_id column?"
        final farmersData = await client
            .from('profiles')
            .select('id')
            .eq('inspector_id', user.id)
            .eq('role', 'farmer');

        // 3. Get Crops (Via Farmer Relationship)
        // ✅ FIX: Explicitly use the foreign key 'crops_farmer_id_fkey' if needed,
        // or just 'profiles!inner' if it's the only relationship.
        // We use !inner to ensure we only get crops from OUR farmers.
        final cropsData = await client
            .from('crops')
            .select('id, farmer:profiles!inner(inspector_id)')
            .eq('farmer.inspector_id', user.id);

        // 4. Get Orders (Via Farmer Relationship)
        // ✅ CRITICAL FIX: We MUST specify '!fk_orders_farmer'
        // because orders has TWO links to profiles (Buyer & Farmer).
        // Without this, it might join the Buyer and return 0 results.
        final ordersResponse = await client
            .from('orders')
            .select(
                'status, farmer:profiles!fk_orders_farmer!inner(inspector_id)')
            .eq('farmer.inspector_id', user.id);

        // 5. Calculate Order Statuses locally
        int pending = 0;
        int active = 0;
        final ordersList = ordersResponse as List<dynamic>;

        for (var o in ordersList) {
          String status = (o['status'] ?? '').toString().toLowerCase().trim();

          if (status == 'pending' || status == 'ordered') {
            pending++;
          } else if ([
            'accepted',
            'packed',
            'shipped',
            'in transit',
            'processing',
            'confirmed'
          ].contains(status)) {
            active++;
          }
        }

        if (mounted) {
          setState(() {
            _name = profile?['first_name'] ?? "Inspector";
            _assignedFarmers = (farmersData as List).length;
            _totalCropsManaged = (cropsData as List).length;
            _pendingOrders = pending;
            _activeOrders = active;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Stats Fetch Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- 2. FETCH WEATHER ---
  Future<void> _fetchWeather() async {
    if (_weatherLoading) return;
    setState(() => _weatherLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5));
        await _callWeatherApi(position.latitude, position.longitude);
      } else {
        await _callWeatherApi(21.1458, 79.0882); // Fallback Nagpur
      }
    } catch (e) {
      if (mounted) _callWeatherApi(21.1458, 79.0882);
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  Future<void> _callWeatherApi(double lat, double long) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$long&current_weather=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        if (mounted) {
          setState(() {
            _temp = "${current['temperature'].round()}°C";
            _condition = _getWeatherCondition(current['weathercode']);
            _weatherIcon = _getWeatherIcon(current['weathercode']);
          });
        }
      }
    } catch (_) {}
  }

  String _getWeatherCondition(int code) {
    if (code == 0) return "Clear Sky";
    if (code < 4) return "Cloudy";
    if (code < 50) return "Foggy";
    if (code < 80) return "Rainy";
    return "Stormy";
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code < 4) return Icons.cloud;
    if (code < 80) return Icons.water_drop;
    return Icons.thunderstorm;
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: 20);

    return RefreshIndicator(
      onRefresh: _fetchInspectorStats,
      color: _primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 1. GREETING & DATE
            Padding(
              padding: sectionPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Namaste, $_name 👋",
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor)),
                  Text(
                    DateFormat('EEEE, d MMMM').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. WEATHER & ADS (Full Width)
            Column(
              children: [
                SizedBox(
                  height: 140,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentSlide = index),
                    children: [
                      _buildWeatherCard(),
                      _buildAdCard(
                          "PM Fasal Bima",
                          "Protect crops from loss",
                          Icons.security,
                          [const Color(0xFFEF6C00), const Color(0xFFFFA726)]),
                      _buildAdCard(
                          "Soil Health Card",
                          "Check soil quality free",
                          Icons.landscape,
                          [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildDot(index)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. STATISTICS TITLE
            Padding(
              padding: sectionPadding,
              child: Text("Overview",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            const SizedBox(height: 12),

            // 4. STATISTICS GRID
            _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : Padding(
                    padding: sectionPadding,
                    child: GridView.count(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard("Farmers", "$_assignedFarmers",
                            Icons.people_outline, Colors.orange),
                        _statCard("Pending", "$_pendingOrders",
                            Icons.pending_actions, Colors.redAccent),
                        _statCard("Active Orders", "$_activeOrders",
                            Icons.local_shipping_outlined, Colors.blue),
                        _statCard("Total Crops", "$_totalCropsManaged",
                            Icons.grass, Colors.green),
                      ],
                    ),
                  ),

            const SizedBox(height: 25),

            // 5. QUICK ACTIONS
            Padding(
              padding: sectionPadding,
              child: Text("Quick Actions",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: sectionPadding,
              child: Row(
                children: [
                  _quickActionBtn(
                      "Add Farmer",
                      Icons.person_add_alt_1,
                      Colors.orange,
                      () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddFarmerScreen()))
                          .then((_) => _fetchInspectorStats())),
                  const SizedBox(width: 15),
                  _quickActionBtn(
                      "Add Crop",
                      Icons.add_circle_outline,
                      Colors.green,
                      () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const InspectorAddCropTab()))
                          .then((_) => _fetchInspectorStats())),
                  const SizedBox(width: 15),
                  _quickActionBtn(
                      "View Orders", Icons.visibility_outlined, Colors.blue,
                      () {
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const InspectorOrdersTab()))
                        .then((_) => _fetchInspectorStats());
                  }),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 6. MARKET INTELLIGENCE (Full Width)
            const AgriStatsDashboard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _lightColor]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Today's Weather",
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(_temp,
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(
                children: [
                  Icon(_weatherIcon, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(_condition,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13)),
                ],
              ),
            ],
          ),
          Icon(_weatherIcon, size: 50, color: Colors.yellowAccent),
        ],
      ),
    );
  }

  Widget _buildAdCard(
      String title, String subtitle, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text("GOVT SCHEME",
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Icon(icon, size: 45, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: _currentSlide == index ? 16 : 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: _currentSlide == index ? _primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _quickActionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}
