import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class BuyerCropDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> crop;
  final Map<String, dynamic>? cropData;

  const BuyerCropDetailsScreen({super.key, required this.crop, this.cropData});

  @override
  State<BuyerCropDetailsScreen> createState() => _BuyerCropDetailsScreenState();
}

class _BuyerCropDetailsScreenState extends State<BuyerCropDetailsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isOrdering = false;

  // --- 1. ORDER DIALOG LOGIC ---
  void _showOrderDialog(String priceStr, double maxQty) {
    final double pricePerKg = double.tryParse(priceStr) ?? 0.0;
    final TextEditingController qtyController = TextEditingController();
    double totalCost = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Place Order",
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: "Quantity (Kg)",
                      hintText: "Max available: $maxQty",
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixText: "Kg",
                      suffixStyle: GoogleFonts.poppins(),
                    ),
                    onChanged: (val) {
                      final q = double.tryParse(val) ?? 0.0;
                      setSheetState(() {
                        totalCost = q * pricePerKg;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Cost:",
                          style: GoogleFonts.poppins(fontSize: 16)),
                      Text("₹${totalCost.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isOrdering
                          ? null
                          : () async {
                              final qty =
                                  double.tryParse(qtyController.text) ?? 0.0;
                              if (qty <= 0 || qty > maxQty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Invalid Quantity",
                                            style: GoogleFonts.poppins())));
                                return;
                              }
                              // Close sheet first, then process
                              Navigator.pop(context);
                              await _placeOrder(qty, totalCost);
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _isOrdering
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("CONFIRM ORDER",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. ORDER SUBMISSION (UPDATED WITH CORRECT RPC) ---
  Future<void> _placeOrder(double quantity, double totalCost) async {
    setState(() => _isOrdering = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final crop = widget.cropData ?? widget.crop;
      final cropId = crop['id'];
      final farmerId = crop['farmer_id'];
      final cropName = crop['crop_name'] ?? 'Unknown Crop';

      // Fetch Buyer Name safely
      String buyerName = "Buyer";
      try {
        final profile = await _supabase
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', user.id)
            .single();
        buyerName = "${profile['first_name']} ${profile['last_name']}";
      } catch (_) {}

      // ✅ CALL 'place_order_request' (Safe Logic)
      // This reserves stock but does not deduct from total until acceptance
      final response = await _supabase.rpc('place_order_request', params: {
        'p_buyer_id': user.id,
        'p_farmer_id': farmerId,
        'p_crop_id': cropId,
        'p_qty_ordered': quantity,
        'p_total_price': totalCost,
        'p_crop_name': cropName,
        'p_buyer_name': buyerName,
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("✅ Order Requested! Waiting for Farmer approval.",
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.blue));

          // Go back to list to force refresh
          Navigator.pop(context, true);
        }
      } else {
        throw response['message'];
      }
    } on PostgrestException catch (e) {
      String errorMsg = "Order Failed";
      if (e.code == 'P0001') {
        errorMsg = e.message; // Custom DB error (e.g., Insufficient Stock)
      } else {
        errorMsg = e.message;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ $errorMsg", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Priority check for fixed data map
    final crop = widget.cropData ?? widget.crop;

    // --- DATA PARSING ---
    final String name = crop['crop_name'] ?? crop['name'] ?? 'Unknown Crop';
    final String variety = crop['variety'] ?? 'Generic';
    final String status = crop['status'] ?? 'Active';
    final String category = crop['category'] ?? 'General';
    final String grade = crop['grade'] ?? 'Standard';
    final String price = crop['price']?.toString() ?? '0';

    // ✅ STOCK LOGIC: Calculate Available Stock
    double totalQty =
        double.tryParse(crop['quantity_kg']?.toString() ?? "0") ?? 0.0;

    // Fallback logic
    if (totalQty <= 0) {
      totalQty =
          double.tryParse(crop['quantity']?.toString().split(' ')[0] ?? "0") ??
              0.0;
    }

    double reservedQty =
        double.tryParse(crop['reserved_kg']?.toString() ?? "0") ?? 0.0;

    // 👉 IMPORTANT: Available = Total - Reserved
    double recoveredMaxQty = totalQty - reservedQty;
    if (recoveredMaxQty < 0) recoveredMaxQty = 0.0;

    final bool isBuyable = recoveredMaxQty > 0 && status == 'Active';

    final String description =
        crop['description'] ?? "No specific notes provided for this crop.";
    final farmerProfile = crop['profiles'] ?? {};
    final String farmerName =
        "${farmerProfile['first_name'] ?? 'Farmer'} ${farmerProfile['last_name'] ?? ''}"
            .trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text("Crop Details",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Price",
                        style: GoogleFonts.poppins(
                            color: Colors.grey, fontSize: 12)),
                    Text("₹$price / Kg",
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 170,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isBuyable
                        ? () => _showOrderDialog(price, recoveredMaxQty)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isBuyable ? const Color(0xFF2E7D32) : Colors.grey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isBuyable ? "BUY NOW" : "OUT OF STOCK",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. IMAGE HERO ---
            _buildHeroImage(crop['image_url']),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 2. HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.poppins(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            Text("$variety • $category",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 3. SPECS GRID (PREVENTS OVERFLOW) ---
                  _buildSpecGrid([
                    _specTile(Icons.scale_outlined, "Available",
                        "$recoveredMaxQty Kg"),
                    _specTile(Icons.verified_outlined, "Grade", grade),
                    _specTile(Icons.eco_outlined, "Farming",
                        crop['farming_type'] ?? 'Standard'),
                    _specTile(Icons.calendar_today_outlined, "Harvest",
                        _formatDate(crop['harvest_date'])),
                  ]),
                  const Divider(height: 40),

                  // --- 4. FARMER INFO ---
                  Text("Farmer Details",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildFarmerCard(farmerName, farmerProfile),
                  const SizedBox(height: 30),

                  // --- 5. DESCRIPTION ---
                  Text("Description",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100)),
                    child: Text(description,
                        style: GoogleFonts.poppins(
                            fontSize: 14, height: 1.6, color: Colors.black87)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeroImage(String? url) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[100]),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url.startsWith('http')
                  ? url
                  : _supabase.storage.from('crop_images').getPublicUrl(url),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.broken_image, size: 50),
            )
          : const Icon(Icons.agriculture, size: 80, color: Colors.grey),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status.toLowerCase() == 'active' ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(),
          style: GoogleFonts.poppins(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSpecGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: children,
    );
  }

  Widget _specTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey[600])),
              Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFarmerCard(String name, Map profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(name.isNotEmpty ? name[0] : "F",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Verified Producer",
                      style: GoogleFonts.poppins(
                          color: Colors.green, fontSize: 12)),
                ],
              )
            ],
          ),
          const Divider(height: 25),
          _farmerLocRow(
              Icons.location_city, "District", profile['district'] ?? 'Nashik'),
          _farmerLocRow(Icons.map, "Taluka", profile['taluka'] ?? 'Baglan'),
        ],
      ),
    );
  }

  Widget _farmerLocRow(IconData icon, String l, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$l:",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          Text(v,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return "Recent";
    try {
      final d = DateTime.parse(date);
      return "${d.day}/${d.month}/${d.year}";
    } catch (_) {
      return "N/A";
    }
  }
}
