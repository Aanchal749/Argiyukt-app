import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

import 'package:agriyukt_app/features/farmer/screens/add_crop_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/orders_screen.dart';
import 'package:agriyukt_app/widgets/agri_stats_dashboard.dart';
import 'package:agriyukt_app/features/farmer/screens/widgets/farmer_drawer.dart';

// 🚀 MARKET INTELLIGENCE IMPORT
import 'package:agriyukt_app/features/farmer/screens/widgets/market_intelligence_section.dart';

class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  String _name = "Farmer";
  int _cropCount = 0;
  int _pendingOrderCount = 0;
  int _activeOrderCount = 0;
  int _completedOrderCount = 0;
  bool _loading = true;

  String _temp = "--";
  String _condition = "--";
  IconData _weatherIcon = Icons.cloud;
  bool _weatherLoading = false;

  int _currentSlide = 0;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  final Color _primaryGreen = const Color(0xFF1B5E20);
  final Color _lightGreen = const Color(0xFF4CAF50);

  String _currentUserId = "";

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? "";
    _fetchRealData();
    _fetchWeather();
  }

  String _text(String key) => FarmerText.get(context, key);

  Future<void> _fetchRealData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;

        final profile = await client
            .from('profiles')
            .select('first_name')
            .eq('id', user.id)
            .maybeSingle();
        final int crops = await client
            .from('crops')
            .count(CountOption.exact)
            .eq('farmer_id', user.id)
            .neq('status', 'Archived');
        final int pending = await client
            .from('orders')
            .count(CountOption.exact)
            .eq('farmer_id', user.id)
            .eq('status', 'Pending');
        final int active = await client
            .from('orders')
            .count(CountOption.exact)
            .eq('farmer_id', user.id)
            .or('status.eq.Accepted,status.eq.Packed,status.eq.Shipped,status.eq.In Transit');
        final int completed = await client
            .from('orders')
            .count(CountOption.exact)
            .eq('farmer_id', user.id)
            .or('status.eq.Delivered,status.eq.Completed,status.eq.Rejected,status.eq.Cancelled');

        if (mounted) {
          setState(() {
            _name = profile?['first_name'] ?? "Farmer";
            _cropCount = crops;
            _pendingOrderCount = pending;
            _activeOrderCount = active;
            _completedOrderCount = completed;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
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
        await _callWeatherApi(21.1458, 79.0882);
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
    Provider.of<LanguageProvider>(context);
    const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: 20);

    if (_loading)
      return Center(child: CircularProgressIndicator(color: _primaryGreen));

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRealData();
        await _fetchWeather();
        setState(() {});
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 30),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: sectionPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_text('namaste')}, $_name 👋",
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen)),
                  Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  height: 140,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentSlide = idx),
                    children: [
                      _buildWeatherCard(),
                      _buildServicesCard(),
                      _buildPromoCard(
                          "Get 20% Off Seeds",
                          "Limited Offer!",
                          Icons.local_offer,
                          [Colors.orange.shade800, Colors.orange.shade400]),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => _buildDot(index))),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
                padding: sectionPadding,
                child: Text(_text('overview'),
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87))),
            const SizedBox(height: 12),
            Padding(
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
                      count: "$_cropCount",
                      label: _text('active_crops'),
                      icon: Icons.grass,
                      color: Colors.green),
                  _buildOverviewCard(
                      count: "$_pendingOrderCount",
                      label: _text('pending_req'),
                      icon: Icons.hourglass_top,
                      color: Colors.orange),
                  _buildOverviewCard(
                      count: "$_activeOrderCount",
                      label: _text('active_ship'),
                      icon: Icons.local_shipping_outlined,
                      color: Colors.blue),
                  _buildOverviewCard(
                      count: "$_completedOrderCount",
                      label: _text('total_history'),
                      icon: Icons.history,
                      color: Colors.purple),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
                padding: sectionPadding,
                child: Text(_text('quick_actions'),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Padding(
              padding: sectionPadding,
              child: Row(
                children: [
                  Expanded(
                      child: _buildActionButton(_text('add_crop'),
                          Icons.add_circle_outline, Colors.green, () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddCropScreen()));
                    _fetchRealData();
                  })),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildActionButton(
                          _text('orders'), Icons.list_alt, Colors.orange,
                          () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrdersScreen()));
                    _fetchRealData();
                  })),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildActionButton(_text('live_track'),
                          Icons.location_on_outlined, Colors.blue, () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const OrdersScreen(initialIndex: 1)));
                    _fetchRealData();
                  })),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (_currentUserId.isNotEmpty)
              MarketIntelligenceSection(farmerId: _currentUserId),
            const SizedBox(height: 24),
            Padding(
                padding: sectionPadding,
                child: Text(_text('market_trends'),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: const AgriStatsDashboard()),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_primaryGreen, _lightGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: _primaryGreen.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_text('weather'),
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(_temp,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              Row(children: [
                Icon(_weatherIcon, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(_condition,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 13))
              ]),
            ],
          ),
          Icon(_weatherIcon, color: Colors.yellowAccent, size: 50),
        ],
      ),
    );
  }

  Widget _buildServicesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: Row(
        children: [
          Expanded(
              child: InkWell(
                  onTap: () {},
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: Colors.grey.shade100))),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFE3F2FD),
                                child: const Icon(Icons.signal_cellular_alt,
                                    color: Color(0xFF1565C0), size: 22)),
                            const SizedBox(height: 8),
                            Text("Strong\nNetwork",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87))
                          ])))),
          Expanded(
              child: InkWell(
                  onTap: () {},
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFFFF3E0),
                                child: const Icon(Icons.account_balance,
                                    color: Color(0xFFEF6C00), size: 22)),
                            const SizedBox(height: 8),
                            Text("SBI Farmer\nLoan",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87))
                          ])))),
        ],
      ),
    );
  }

  Widget _buildPromoCard(
      String title, String subtitle, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20)),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text("OFFER",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Text(title,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11))
              ])),
          Icon(icon, size: 45, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildDot(int index) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: _currentSlide == index ? 16 : 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
          color: _currentSlide == index ? _primaryGreen : Colors.grey[300],
          borderRadius: BorderRadius.circular(3)));

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
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
          border: Border.all(color: color.withOpacity(0.1))),
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
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))
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
              ]),
          child: Column(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.black87))
          ])),
    );
  }
}
