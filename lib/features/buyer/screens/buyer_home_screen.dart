import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Navigation Imports
import 'package:agriyukt_app/features/buyer/screens/buyer_marketplace_screen.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_favorites_screen.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_orders_screen.dart';

// ✅ DATA VISUALIZATION IMPORT
import 'package:agriyukt_app/widgets/agri_stats_dashboard.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  // --- Data Variables ---
  String _name = "Buyer";
  int _activeOrders = 0;
  int _pendingOrders = 0;
  int _favoritesCount = 0;
  int _freshArrivalsCount = 0; // ✅ New Variable for Fresh Arrivals
  bool _loading = true;

  // --- Weather Variables ---
  String _temp = "--";
  String _condition = "Loading...";
  IconData _weatherIcon = Icons.cloud;
  bool _weatherLoading = false;

  // --- Controllers ---
  int _currentSlide = 0;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  // --- Theme Color (Buyer Blue) ---
  final Color _primaryBlue = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _fetchRealData();
    _fetchWeather();
  }

  // ✅ LOGIC: Real Database Counts
  Future<void> _fetchRealData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;

        // 1. Fetch Profile Name
        final profile = await client
            .from('profiles')
            .select('first_name')
            .eq('id', user.id)
            .maybeSingle();

        // 2. Count "Favorites"
        final int favs = await client
            .from('favorites')
            .count(CountOption.exact)
            .eq('user_id', user.id);

        // 3. Count "Fresh Arrivals" (Active Crops added in last 7 days)
        final DateTime sevenDaysAgo =
            DateTime.now().subtract(const Duration(days: 7));
        final int fresh = await client
            .from('crops')
            .count(CountOption.exact)
            .gte('created_at', sevenDaysAgo.toIso8601String())
            .eq('status', 'Active');

        // 4. Fetch Orders for Status Counts
        final response = await client
            .from('orders')
            .select('status, tracking_status')
            .eq('buyer_id', user.id);

        // 5. Calculate Order Logic
        int pending = 0;
        int active = 0;

        final List<dynamic> orders = response as List<dynamic>;

        for (var o in orders) {
          final String status =
              (o['status'] ?? '').toString().toLowerCase().trim();
          final String tracking =
              (o['tracking_status'] ?? '').toString().toLowerCase().trim();

          // Pending Logic
          if (status == 'pending') {
            pending++;
          }
          // Active Logic (Accepted AND NOT Delivered/Completed)
          else if (status == 'accepted' &&
              !['delivered', 'completed'].contains(tracking)) {
            active++;
          }
        }

        if (mounted) {
          setState(() {
            _name = profile?['first_name'] ?? "Buyer";
            _favoritesCount = favs;
            _freshArrivalsCount = fresh; // ✅ Update Fresh Count
            _pendingOrders = pending;
            _activeOrders = active;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

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
        Position position = await Geolocator.getCurrentPosition();
        await _callWeatherApi(position.latitude, position.longitude);
      } else {
        await _callWeatherApi(19.0760, 72.8777);
      }
    } catch (_) {
      if (mounted) _callWeatherApi(19.0760, 72.8777);
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
            _condition = _getWeatherCode(current['weathercode']);
            _weatherIcon = _getWeatherIcon(current['weathercode']);
          });
        }
      }
    } catch (_) {}
  }

  String _getWeatherCode(int code) =>
      code <= 3 ? "Clear" : (code >= 51 ? "Rainy" : "Sunny");
  IconData _getWeatherIcon(int code) => code <= 3
      ? Icons.cloud
      : (code >= 51 ? Icons.water_drop : Icons.wb_sunny);

  @override
  Widget build(BuildContext context) {
    const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: 20);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchRealData();
          await _fetchWeather();
        },
        color: _primaryBlue,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 30),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 1. HEADER
              Padding(
                padding: sectionPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Namaste, $_name 👋",
                        style: GoogleFonts.poppins(
                            color: _primaryBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: GoogleFonts.poppins(
                            color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. HERO CAROUSEL
              SizedBox(
                height: 140,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentSlide = idx),
                  children: [
                    _buildWeatherCard(),
                    _buildPromoCard("Bulk Discount",
                        "Get 5% off on orders > 100kg", Colors.orange.shade800),
                    _buildPromoCard(
                        "Fresh Arrivals",
                        "New organic Wheat stock available!",
                        Colors.green.shade700),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: _currentSlide == index ? 16 : 6,
                    decoration: BoxDecoration(
                      color: _currentSlide == index
                          ? _primaryBlue
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // 3. OVERVIEW TITLE
              Padding(
                padding: sectionPadding,
                child: Text("Overview",
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              const SizedBox(height: 12),

              // 4. OVERVIEW GRID
              _loading
                  ? Center(
                      child: CircularProgressIndicator(color: _primaryBlue))
                  : Padding(
                      padding: sectionPadding,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 1.4,
                        padding: EdgeInsets.zero,
                        children: [
                          _buildOverviewCard(
                            count: "$_activeOrders",
                            label: "Active Orders",
                            icon: Icons.local_shipping_outlined,
                            color: _primaryBlue,
                          ),
                          _buildOverviewCard(
                            count: "$_pendingOrders",
                            label: "Pending Req.",
                            icon: Icons.hourglass_top,
                            color: Colors.orange,
                          ),
                          // ✅ REPLACED "In Bucket" with "Fresh Arrivals"
                          _buildOverviewCard(
                            count: "$_freshArrivalsCount",
                            label: "Fresh Arrivals",
                            icon: Icons.new_releases_outlined,
                            color: Colors.green,
                          ),
                          _buildOverviewCard(
                            count: "$_favoritesCount",
                            label: "Favorites",
                            icon: Icons.favorite_border,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 20),

              // 5. QUICK ACTIONS
              Padding(
                padding: sectionPadding,
                child: Text("Quick Actions",
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: sectionPadding,
                child: Row(
                  children: [
                    // ✅ 1. Marketplace
                    Expanded(
                      child: _buildActionButton("Marketplace",
                          Icons.storefront_outlined, Colors.green, () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const BuyerMarketplaceScreen()));
                      }),
                    ),
                    const SizedBox(width: 15),

                    // ✅ 2. Track Orders (Links to Active Tab - Index 1)
                    Expanded(
                      child: _buildActionButton("Track Orders",
                          Icons.location_on_outlined, _primaryBlue, () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const BuyerOrdersScreen(initialIndex: 1)));
                      }),
                    ),
                    const SizedBox(width: 15),

                    // ✅ 3. Favorites
                    Expanded(
                      child: _buildActionButton(
                          "Favorites", Icons.favorite, Colors.red, () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BuyerFavoritesScreen()));
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 6. MARKET INTELLIGENCE
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: const AgriStatsDashboard(),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🎨 VISUAL HELPERS ---

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
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
          Icon(_weatherIcon, color: Colors.yellowAccent, size: 50),
        ],
      ),
    );
  }

  Widget _buildPromoCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text("OFFER",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(title,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
      {required String count,
      required String label,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(count,
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

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
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
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
