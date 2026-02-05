import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_crop_details_screen.dart';

class BuyerMarketplaceScreen extends StatefulWidget {
  const BuyerMarketplaceScreen({super.key});

  @override
  State<BuyerMarketplaceScreen> createState() => _BuyerMarketplaceScreenState();
}

class _BuyerMarketplaceScreenState extends State<BuyerMarketplaceScreen> {
  final _client = Supabase.instance.client;

  String _searchQuery = "";
  String _selectedCategory = "All";
  bool _isLoading = true;

  List<Map<String, dynamic>> _allCrops = [];
  List<Map<String, dynamic>> _filteredCrops = [];
  Set<String> _likedCropIds = {};

  final List<String> _categories = [
    "All",
    "Vegetables",
    "Fruits",
    "Grains",
    "Pulses",
    "Flowers",
    "Oils"
  ];

  @override
  void initState() {
    super.initState();
    _fetchMarketData();
  }

  Future<void> _fetchMarketData() async {
    try {
      final userId = _client.auth.currentUser?.id;

      // ✅ 1. Fetch All Active Crops
      final response = await _client
          .from('crops')
          .select('''
            *,
            profiles:farmer_id (first_name, last_name, district, taluka, village) 
          ''')
          .eq('status', 'Active') // Must be Active
          .order('created_at', ascending: false);

      // 2. Fetch User's Favorites
      if (userId != null) {
        try {
          final favResponse = await _client
              .from('favorites')
              .select('crop_id')
              .eq('user_id', userId);
          final favData = favResponse as List<dynamic>;
          _likedCropIds = favData.map((e) => e['crop_id'].toString()).toSet();
        } catch (e) {
          debugPrint("Error fetching favorites: $e");
        }
      }

      if (mounted) {
        setState(() {
          // ✅ STOCK FILTERING LOGIC
          // Only show items where Available Stock (Total - Reserved) is greater than 0
          _allCrops = List<Map<String, dynamic>>.from(response).where((crop) {
            final double total = (crop['quantity_kg'] ?? 0).toDouble();
            final double reserved = (crop['reserved_kg'] ?? 0).toDouble();
            return (total - reserved) > 0; // Hide if fully reserved
          }).toList();

          _runFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Market Data Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String cropId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      if (_likedCropIds.contains(cropId)) {
        _likedCropIds.remove(cropId);
      } else {
        _likedCropIds.add(cropId);
      }
    });

    try {
      if (_likedCropIds.contains(cropId)) {
        await _client
            .from('favorites')
            .upsert({'user_id': userId, 'crop_id': cropId});
      } else {
        await _client
            .from('favorites')
            .delete()
            .match({'user_id': userId, 'crop_id': cropId});
      }
    } catch (e) {
      debugPrint("Error toggling like: $e");
    }
  }

  void _runFilter() {
    setState(() {
      _filteredCrops = _allCrops.where((crop) {
        final name =
            (crop['crop_name'] ?? crop['name'] ?? '').toString().toLowerCase();
        final category = (crop['category'] ?? '').toString();
        final matchesSearch = name.contains(_searchQuery);
        final matchesCategory =
            _selectedCategory == "All" || category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    _searchQuery = val.toLowerCase();
                    _runFilter();
                  },
                  decoration: InputDecoration(
                    hintText: "Search wheat, tomato...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _categories.map((cat) {
                      bool isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (val) {
                            setState(() => _selectedCategory = cat);
                            _runFilter();
                          },
                          selectedColor: Colors.blue,
                          labelStyle: GoogleFonts.poppins(
                              color: isSel ? Colors.white : Colors.black,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.normal),
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide.none),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),

          // GRID
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue))
                : _filteredCrops.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchMarketData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCrops.length,
                          itemBuilder: (ctx, i) =>
                              _buildMarketCard(_filteredCrops[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No active crops found.",
              style:
                  GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMarketCard(Map<String, dynamic> crop) {
    final String cropId = crop['id'].toString();
    final String name = crop['crop_name'] ?? "Unknown Crop";
    final String price = "₹${crop['price'] ?? 0}";

    // ✅ 👉 CORRECT STOCK LOGIC (Total - Reserved)
    final double total = (crop['quantity_kg'] ?? 0).toDouble();
    final double reserved = (crop['reserved_kg'] ?? 0).toDouble();
    double available = total - reserved;

    if (available < 0) available = 0; // Prevent negative display

    String qtyValue =
        available.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
    final String displayQty = "$qtyValue ${crop['unit'] ?? 'Kg'}";

    final bool isLiked = _likedCropIds.contains(cropId);
    final farmerData = crop['profiles'];
    String farmerName = farmerData != null
        ? "${farmerData['first_name']} ${farmerData['last_name']}"
        : "AgriYukt Farmer";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // ✅ CRITICAL FIX: Await return + Refresh Data
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BuyerCropDetailsScreen(crop: crop, cropData: crop),
            ),
          );
          // 🔁 Refresh when user returns (in case they bought something)
          _fetchMarketData();
        },
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildCropImage(crop['image_url']),
                ),
                if (crop['crop_type'] == 'Organic')
                  Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text("Organic",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)))),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[600],
                          size: 20),
                      onPressed: () => _toggleLike(cropId),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18))),
                        Text(price,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 18)),
                      ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(farmerName,
                            style: GoogleFonts.poppins(
                                color: Colors.grey[700], fontSize: 13))),
                    const SizedBox(width: 12),
                    const Icon(Icons.scale_outlined,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(displayQty,
                        style: GoogleFonts.poppins(
                            color: Colors.grey[700], fontSize: 13)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () async {
                        // ✅ CRITICAL FIX: Also applied to the button
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BuyerCropDetailsScreen(
                                    crop: crop, cropData: crop)));
                        _fetchMarketData();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: Text("VIEW DETAILS",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCropImage(String? imgUrl) {
    if (imgUrl == null || imgUrl.isEmpty)
      return Container(
          height: 170,
          color: Colors.grey[200],
          child: const Icon(Icons.grass, size: 50, color: Colors.grey));
    return Image.network(
      imgUrl.startsWith('http')
          ? imgUrl
          : _client.storage.from('crop_images').getPublicUrl(imgUrl),
      height: 170,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
          height: 170,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image)),
    );
  }
}
