import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// Your existing project imports
import 'package:agriyukt_app/features/inspector/screens/inspector_add_crop_tab.dart';
import 'package:agriyukt_app/features/farmer/screens/view_crop_screen.dart';
import 'package:agriyukt_app/features/inspector/screens/manage_crops/inspector_crop_card.dart';

class InspectorFarmerCropsScreen extends StatefulWidget {
  final String farmerId;
  final String farmerName;

  const InspectorFarmerCropsScreen({
    super.key,
    required this.farmerId,
    required this.farmerName,
  });

  @override
  State<InspectorFarmerCropsScreen> createState() =>
      _InspectorFarmerCropsScreenState();
}

class _InspectorFarmerCropsScreenState
    extends State<InspectorFarmerCropsScreen> {
  final _client = Supabase.instance.client;
  bool _showActive = true;

  // 🎨 Inspector Theme Color
  final Color _inspectorColor = const Color(0xFF512DA8);

  void _navigateToEditScreen(Map<String, dynamic>? crop) async {
    final dummyFarmerMap = {
      'id': widget.farmerId,
      'first_name': widget.farmerName.split(' ')[0],
      'last_name': '',
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectorAddCropTab(
          preSelectedFarmer: dummyFarmerMap,
          cropToEdit: crop,
        ),
      ),
    );
    // No need to manually refresh, StreamBuilder handles it.
  }

  Future<void> _deleteCrop(String cropId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Crop?",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This cannot be undone.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("CANCEL",
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("DELETE",
                  style: GoogleFonts.poppins(
                      color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('crops').delete().eq('id', cropId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Crop Deleted", style: GoogleFonts.poppins()),
              backgroundColor: Colors.black),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Delete Failed: $e", style: GoogleFonts.poppins()),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Manage Crops",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text("${widget.farmerName}'s Inventory",
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70)),
          ],
        ),
        backgroundColor: _inspectorColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: "Search your crops...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: _inspectorColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTabButton("Active Crops", true)),
                const SizedBox(width: 12),
                Expanded(child: _buildTabButton("Inactive/Sold", false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ✅ LIST (STREAM BUILDER)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _client
                  .from('crops')
                  .stream(primaryKey: ['id'])
                  .eq('farmer_id', widget.farmerId) // Filter by Farmer
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: _inspectorColor));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text("No crops found.",
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                // Filter Active/Inactive
                final allCrops = snapshot.data!;
                final displayList = allCrops.where((c) {
                  final status =
                      c['status']?.toString().toLowerCase() ?? 'active';
                  // Active = 'active', 'verified', 'growing' AND Stock > 0
                  // However, for Inspector View, we stick to status primarily
                  final isActiveStatus =
                      ['active', 'verified', 'growing'].contains(status);
                  return _showActive ? isActiveStatus : !isActiveStatus;
                }).toList();

                if (displayList.isEmpty) {
                  return Center(
                    child: Text(
                        _showActive ? "No active crops" : "No inactive crops",
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) =>
                      _buildCropCard(displayList[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditScreen(null),
        backgroundColor: _inspectorColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text("Add Crop",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActiveTab) {
    bool isSelected = _showActive == isActiveTab;
    return GestureDetector(
      onTap: () => setState(() => _showActive = isActiveTab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _inspectorColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: _inspectorColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropCard(Map<String, dynamic> crop) {
    final name = crop['crop_name'] ?? crop['name'] ?? 'Unnamed';
    final price = crop['price'] ?? 0;

    // ✅ STOCK LOGIC (Total & Reserved)
    final double total = (crop['quantity_kg'] ?? 0).toDouble();
    final double reserved = (crop['reserved_kg'] ?? 0).toDouble();

    // 1. Format Total
    String qtyValue =
        total.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
    String unit = crop['unit'] ?? "Kg";
    if (unit == "Unit") {
      String rawLegacy = crop['quantity']?.toString() ?? "";
      if (rawLegacy.contains(' '))
        unit = rawLegacy.split(' ').sublist(1).join(' ');
    }

    // 2. Base String
    String qtyDisplay = "$qtyValue $unit";

    // 3. Append Reserved
    if (reserved > 0) {
      String resStr =
          reserved.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
      qtyDisplay += " ($resStr Reserved)";
    }

    // Image Logic
    final imgUrl = crop['image_url'];
    final harvestDate = crop['harvest_date'] ?? '--';
    final availableDate = crop['available_from'] ?? '--';
    final isCropActive =
        (crop['status']?.toString().toLowerCase() ?? 'active') == 'active';

    // Helper for URL vs Path
    ImageProvider? provider;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http')) {
        provider = NetworkImage(imgUrl);
      } else {
        provider = NetworkImage(
            _client.storage.from('crop_images').getPublicUrl(imgUrl));
      }
    }

    return InspectorCropCard(
      cropName: name,
      price: "₹$price",
      quantity: qtyDisplay, // ✅ Correct String Passed
      harvestDate: _formatDate(harvestDate),
      availableDate: _formatDate(availableDate),
      imageUrl: "", // We use provider below
      imageProvider: provider, // ✅ Pass provider
      isActive: isCropActive,
      onViewTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewCropScreen(crop: crop)),
        );
      },
      onEditTap: () => _navigateToEditScreen(crop),
      onDeleteTap: () => _deleteCrop(crop['id']),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == '--') return '--';
    try {
      final d = DateTime.parse(dateStr);
      return "${d.day}/${d.month}/${d.year}";
    } catch (e) {
      return dateStr ?? '--';
    }
  }
}
