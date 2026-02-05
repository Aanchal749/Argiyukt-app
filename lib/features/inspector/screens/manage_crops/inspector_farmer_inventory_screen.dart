import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Added Supabase
import 'inspector_crop_card.dart';

class InspectorFarmerInventoryScreen extends StatefulWidget {
  final String farmerName;
  final String farmerId; // ✅ Added ID to fetch specific farmer's data

  const InspectorFarmerInventoryScreen({
    Key? key,
    required this.farmerName,
    required this.farmerId, // ✅ Required for DB query
  }) : super(key: key);

  @override
  State<InspectorFarmerInventoryScreen> createState() =>
      _InspectorFarmerInventoryScreenState();
}

class _InspectorFarmerInventoryScreenState
    extends State<InspectorFarmerInventoryScreen> {
  bool showActive = true;
  final _client = Supabase.instance.client; // ✅ DB Client

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF387C2B), // AgriYukt Green
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage Crops",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text("${widget.farmerName}'s Inventory",
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // --- 1. Search Bar ---
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
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search your crops...",
                  prefixIcon: Icon(Icons.search, color: Colors.green),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- 2. Custom Toggle Tabs ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTabButton("Active Crops", true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTabButton("Inactive/Sold", false)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- 3. Crop List (STREAM BUILDER) ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // ✅ Fetch crops for this specific farmer
              stream: _client
                  .from('crops')
                  .stream(primaryKey: ['id'])
                  .eq('farmer_id', widget.farmerId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF387C2B)));
                }

                final crops = snapshot.data!;

                // Filter based on Active/Inactive Tab
                final filteredCrops = crops.where((crop) {
                  final status = crop['status'] ?? 'Active';
                  final double qty = (crop['quantity_kg'] ?? 0).toDouble();

                  // Active Logic: Must be 'Active'/'Verified' AND have physical stock > 0
                  final isActiveGroup =
                      ['Active', 'Verified', 'Growing'].contains(status) &&
                          (qty > 0);

                  return showActive ? isActiveGroup : !isActiveGroup;
                }).toList();

                if (filteredCrops.isEmpty) {
                  return Center(
                    child: Text(
                      showActive
                          ? "No active crops found"
                          : "No inactive crops found",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredCrops.length,
                  itemBuilder: (context, index) {
                    final crop = filteredCrops[index];

                    // ✅✅✅ STOCK LOGIC (Matching my_crops_tab.dart) ✅✅✅
                    // 1. Read 'quantity_kg' (Total Stock).
                    String qtyValue = (crop['quantity_kg'] ?? 0).toString();
                    qtyValue =
                        qtyValue.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

                    // 2. Read 'reserved_kg'
                    final double reserved =
                        (crop['reserved_kg'] ?? 0).toDouble();

                    // 3. Unit Logic
                    String unit = crop['unit'] ?? "Kg";
                    if (unit == "Unit") {
                      String rawLegacy = crop['quantity']?.toString() ?? "";
                      if (rawLegacy.contains(' ')) {
                        unit = rawLegacy.split(' ').sublist(1).join(' ');
                      }
                    }

                    // 4. Construct Display String
                    String displayQty = "$qtyValue $unit";

                    // 5. Append Reserved Status
                    if (reserved > 0) {
                      String reservedStr = reserved
                          .toString()
                          .replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
                      displayQty += " ($reservedStr Reserved)";
                    }
                    // ✅✅✅ END STOCK LOGIC ✅✅✅

                    // Helper for Image URL
                    String imageUrl = crop['image_url'] ?? '';
                    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
                      imageUrl = _client.storage
                          .from('crop_images')
                          .getPublicUrl(imageUrl);
                    } else if (imageUrl.isEmpty) {
                      imageUrl = "https://via.placeholder.com/150"; // Fallback
                    }

                    // Format Dates (Basic)
                    String hDate = crop['harvest_date'] ?? 'N/A';
                    String aDate = crop['available_from'] ?? 'N/A';
                    try {
                      if (hDate != 'N/A') {
                        final d = DateTime.parse(hDate);
                        hDate = "${d.day}/${d.month}/${d.year}";
                      }
                      if (aDate != 'N/A') {
                        final d = DateTime.parse(aDate);
                        aDate = "${d.day}/${d.month}/${d.year}";
                      }
                    } catch (_) {}

                    // Price Logic
                    String priceVal = crop['price']?.toString() ??
                        crop['price_per_qty']?.toString() ??
                        '0';
                    priceVal =
                        priceVal.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

                    return InspectorCropCard(
                      cropName: crop['crop_name'] ?? "Unknown Crop",
                      price: "₹$priceVal / $unit",
                      quantity: displayQty, // ✅ Correct String Passed
                      harvestDate: hDate,
                      availableDate: aDate,
                      imageUrl: imageUrl,
                      isActive: showActive,
                      onViewTap: () {
                        // Navigate to view details if needed
                      },
                      onEditTap: () {
                        // Navigate to edit if needed
                      },
                      onDeleteTap: () {
                        // Delete logic
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // --- 4. Floating Action Button ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Logic to add crop on behalf of farmer
        },
        backgroundColor: const Color(0xFF387C2B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Crop", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // Helper for the Toggle Buttons
  Widget _buildTabButton(String text, bool isActiveTab) {
    bool isSelected = showActive == isActiveTab;
    return GestureDetector(
      onTap: () {
        setState(() {
          showActive = isActiveTab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF387C2B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
