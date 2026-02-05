import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // For making calls

class InspectorActiveCropsScreen extends StatefulWidget {
  const InspectorActiveCropsScreen({super.key});

  @override
  State<InspectorActiveCropsScreen> createState() =>
      _InspectorActiveCropsScreenState();
}

class _InspectorActiveCropsScreenState
    extends State<InspectorActiveCropsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _crops = [];
  final Color _themeColor = const Color(0xFFE65100); // Inspector Orange

  @override
  void initState() {
    super.initState();
    _fetchActiveCrops();
  }

  Future<void> _fetchActiveCrops() async {
    try {
      // Fetch crops AND the related farmer profile in one query
      // Note: This assumes you have a Foreign Key from crops.user_id -> profiles.id
      final data = await _supabase.from('crops').select('''
            *,
            profiles:user_id (
              first_name,
              last_name,
              phone,
              address_line_1
            )
          ''').order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _crops = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching crops: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callFarmer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Active Crops (All Farmers)"),
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : _crops.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _crops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildCropCard(_crops[index]);
                  },
                ),
    );
  }

  Widget _buildCropCard(Map<String, dynamic> crop) {
    // Extract Farmer Details safely
    final profile = crop['profiles'] as Map<String, dynamic>?;
    final farmerName = profile != null
        ? "${profile['first_name']} ${profile['last_name'] ?? ''}".trim()
        : "Unknown Farmer";
    final farmerPhone = profile?['phone']?.toString() ?? "";
    final farmerLocation = profile?['address_line_1'] ?? "Unknown Location";

    final bool isVerified = (crop['status'] ?? '') == 'Verified';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // --- TOP SECTION: CROP INFO ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grass, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(crop['name'] ?? "Unknown Crop",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          "Qty: ${crop['quantity']} • Price: ₹${crop['price']}",
                          style:
                              TextStyle(color: Colors.grey[800], fontSize: 13)),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: isVerified ? Colors.green : Colors.orange,
                        width: 0.5),
                  ),
                  child: Text(
                    isVerified ? "Verified" : "Pending",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),

            // --- BOTTOM SECTION: FARMER DETAILS ---
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: _themeColor.withOpacity(0.1),
                  child: Icon(Icons.person, size: 14, color: _themeColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(farmerLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),

                // Call Button
                if (farmerPhone.isNotEmpty)
                  IconButton(
                    icon:
                        const Icon(Icons.phone, color: Colors.green, size: 20),
                    onPressed: () => _callFarmer(farmerPhone),
                    tooltip: "Call Farmer",
                    visualDensity: VisualDensity.compact,
                  ),

                // Navigate Button (Manage)
                TextButton(
                  onPressed: () {
                    // Future: Navigate to detailed verification screen
                  },
                  child: const Text("Inspect >"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grass_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No active crops found.",
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}
