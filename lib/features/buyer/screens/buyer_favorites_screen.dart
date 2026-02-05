import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'buyer_crop_details_screen.dart';

class BuyerFavoritesScreen extends StatefulWidget {
  const BuyerFavoritesScreen({super.key});

  @override
  State<BuyerFavoritesScreen> createState() => _BuyerFavoritesScreenState();
}

class _BuyerFavoritesScreenState extends State<BuyerFavoritesScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch favorites and join with crop details + farmer details
      final response = await _client
          .from('favorites')
          .select('*, crop:crops(*, profiles:farmer_id(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("My Favorites",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final favItem = _favorites[index];
                    final crop = favItem['crop'];
                    if (crop == null)
                      return const SizedBox.shrink(); // Skip if crop deleted
                    return _buildFavoriteCard(crop);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No favorites yet.",
              style:
                  GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> crop) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            crop['image_url'] != null && crop['image_url'].startsWith('http')
                ? crop['image_url']
                : _client.storage
                    .from('crop_images')
                    .getPublicUrl(crop['image_url'] ?? ''),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.grass)),
          ),
        ),
        title: Text(crop['crop_name'] ?? 'Crop',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Text("₹${crop['price'] ?? 0} / ${crop['unit'] ?? 'Kg'}",
            style: GoogleFonts.poppins(
                color: Colors.green[700], fontWeight: FontWeight.w600)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    BuyerCropDetailsScreen(crop: crop, cropData: crop)),
          );
        },
      ),
    );
  }
}
