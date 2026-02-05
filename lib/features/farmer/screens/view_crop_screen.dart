import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ✅ LOCALIZATION & TRANSLATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class ViewCropScreen extends StatelessWidget {
  final Map<String, dynamic> crop;

  const ViewCropScreen({super.key, required this.crop});

  @override
  Widget build(BuildContext context) {
    // Get current language code
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    // ✅ Helper for Localized Text
    String text(String key) => FarmerText.get(context, key);

    // --- 1. SMART DATA PARSING ---
    final String name = crop['crop_name'] ?? crop['name'] ?? 'Unknown Crop';
    final String variety = crop['variety'] ?? 'Generic';
    final String status = crop['status'] ?? 'Active';
    final String category = crop['category'] ?? 'General';
    final String grade = crop['grade'] ?? 'Standard';

    // Price
    String priceVal =
        crop['price']?.toString() ?? crop['price_per_qty']?.toString() ?? '0';
    priceVal = priceVal.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

    // Quantity
    String quantity = crop['quantity']?.toString() ??
        "${crop['quantity_available'] ?? 0} ${crop['quantity_unit'] ?? ''}";
    quantity = quantity.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

    // Description
    final String description = crop['description'] ??
        crop['health_notes'] ??
        "No specific notes provided for this crop.";

    // Image Logic
    ImageProvider? imageProvider;
    if (crop['image_url'] != null) {
      final String url = crop['image_url'];
      if (url.startsWith('http')) {
        imageProvider = NetworkImage(url);
      } else {
        imageProvider = NetworkImage(Supabase.instance.client.storage
            .from('crop_images')
            .getPublicUrl(url));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: CustomScrollView(
        slivers: [
          // --- HEADER IMAGE ---
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1B5E20),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageProvider != null
                  ? Image(image: imageProvider, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                          child:
                              Icon(Icons.image, size: 80, color: Colors.grey))),
            ),
          ),

          // --- CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & STATUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ DYNAMIC TRANSLATION: Crop Name
                            FutureBuilder<String>(
                              future:
                                  TranslationService.toLocal(name, langCode),
                              initialData: name,
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? name,
                                  style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                            Text("$variety • $category",
                                style: GoogleFonts.poppins(
                                    fontSize: 14, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(status))),
                        child: FutureBuilder<String>(
                          // ✅ DYNAMIC TRANSLATION: Status
                          future: TranslationService.toLocal(status, langCode),
                          initialData: status,
                          builder: (context, snapshot) => Text(
                            (snapshot.data ?? status).toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 24),

                  // PRICE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                text(
                                    'price'), // ✅ LOCALIZED "Price" (mapped to 'Asking Price' contextually)
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                            Text("₹$priceVal",
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1B5E20))),
                          ],
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text('grade'), // ✅ LOCALIZED "Grade"
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                            Text(grade,
                                style: GoogleFonts.poppins(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DETAILS GRID
                  Text(text('info'), // ✅ LOCALIZED "Info" (Specifications)
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100)),
                    child: Column(
                      children: [
                        _detailRow(Icons.scale, text('quantity'),
                            quantity), // ✅ LOCALIZED
                        const Divider(height: 24),
                        _detailRow(
                            Icons.eco,
                            text('farming_type'), // ✅ LOCALIZED
                            crop['crop_type'] ?? 'Organic'),
                        const Divider(height: 24),
                        _detailRow(
                            Icons.event_available,
                            text('harvest_date'), // ✅ LOCALIZED
                            _formatDate(crop['harvest_date'])),
                        const Divider(height: 24),
                        _detailRow(
                            Icons.local_shipping,
                            text('avail_from'), // ✅ LOCALIZED
                            _formatDate(crop['available_from'])),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DESCRIPTION
                  Text(text('notes'), // ✅ LOCALIZED "Notes" (Farmer's Notes)
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100)),
                    child: FutureBuilder<String>(
                      // ✅ DYNAMIC TRANSLATION: Description
                      future: TranslationService.toLocal(description, langCode),
                      initialData: description,
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? description,
                          style: GoogleFonts.poppins(
                              fontSize: 14, height: 1.6, color: Colors.black87),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14)),
        const Spacer(),
        Text(value,
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Not Specified";
    try {
      final d = DateTime.parse(dateStr);
      return "${d.day}/${d.month}/${d.year}";
    } catch (e) {
      return "N/A";
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'sold':
        return Colors.red;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
