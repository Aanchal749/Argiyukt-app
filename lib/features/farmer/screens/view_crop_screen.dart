import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// ✅ LOCALIZATION & TRANSLATION IMPORTS
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/features/farmer/screens/add_crop_tab.dart';

// 🛡️ PRODUCTION CACHE
final Map<String, String> _globalTranslationCache = {};

class ViewCropScreen extends StatelessWidget {
  final Map<String, dynamic> crop;

  // 🛡️ PROPS FOR INSPECTOR INTEGRATION
  final bool hideEditButton;
  final VoidCallback? onCustomEditTap;

  const ViewCropScreen({
    super.key,
    required this.crop,
    this.hideEditButton = false,
    this.onCustomEditTap,
  });

  Future<String> _getCachedTranslation(String text, String langCode) async {
    if (text.trim().isEmpty) return text;
    final cacheKey = '${text}_$langCode';
    if (_globalTranslationCache.containsKey(cacheKey)) {
      return _globalTranslationCache[cacheKey]!;
    }
    try {
      final translated = await TranslationService.toLocal(text, langCode);
      _globalTranslationCache[cacheKey] = translated;
      return translated;
    } catch (e) {
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    // 🛡️ Safe fallback translation helper
    String text(String key, {String fallback = ""}) {
      String trans = FarmerText.get(context, key);
      return trans == key && fallback.isNotEmpty ? fallback : trans;
    }

    // --- 1. SMART DATA PARSING ---
    final String name = crop['crop_name'] ??
        crop['name'] ??
        text('unknown_crop', fallback: 'Unknown Crop');
    final String variety = crop['variety'] ?? 'Generic';
    final String status = crop['status'] ?? 'Active';
    final String category = crop['category'] ?? 'General';
    final String grade =
        crop['grade'] ?? text('standard', fallback: 'Standard');

    // Safe Numeric Formatting for Price & Total Value
    String rawPrice =
        (crop['price']?.toString() ?? crop['price_per_qty']?.toString() ?? "0")
            .replaceAll(RegExp(r'[^0-9.]'), '');
    double priceNumeric = double.tryParse(rawPrice) ?? 0.0;
    String priceVal = NumberFormat.decimalPattern('en_IN').format(priceNumeric);

    // Safe Numeric Formatting for Quantity
    String rawQty =
        (crop['quantity_kg']?.toString() ?? crop['quantity']?.toString() ?? "0")
            .replaceAll(RegExp(r'[^0-9.]'), '');
    double qtyVal = double.tryParse(rawQty) ?? 0.0;
    String cleanQty = qtyVal == qtyVal.truncateToDouble()
        ? qtyVal.toInt().toString()
        : qtyVal.toStringAsFixed(2);

    String unit = crop['unit'] ?? "Kg";
    if (crop['quantity'] != null && crop['quantity'].toString().contains(' ')) {
      unit = crop['quantity'].toString().split(' ').sublist(1).join(' ');
    }
    final String quantityStr =
        "$cleanQty ${text(unit.toLowerCase(), fallback: unit)}";

    // Total Value Calculation for Bottom Bar
    double totalValueNumeric = qtyVal * priceNumeric;
    String totalValueStr =
        NumberFormat.decimalPattern('en_IN').format(totalValueNumeric);

    // Description Parsing
    String description = crop['description'] ?? crop['health_notes'] ?? "";
    if (description.trim().isEmpty) {
      description = text('no_notes',
          fallback: "No specific notes provided for this crop.");
    }

    final String imgUrl = crop['image_url']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(
          text('crop_details', fallback: "Crop Details"),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // 🎨 SMART BOTTOM ACTION BAR
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom
                : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text('total_est_value', fallback: "Est. Total Value"),
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  Text("₹$totalValueStr",
                      maxLines: 1, // ✅ Prevents massive number overflow
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
            ),
            if (!hideEditButton)
              ElevatedButton.icon(
                onPressed: () async {
                  if (onCustomEditTap != null) {
                    onCustomEditTap!();
                    return;
                  }
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddCropTab(cropToEdit: crop)),
                  );
                  if (result == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 18),
                label: Text(text('edit', fallback: "EDIT"),
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- IMAGE SECTION ---
            Hero(
              // ✅ Fallback to UniqueKey prevents crash if ID is entirely missing
              tag: crop['id']?.toString() ?? UniqueKey().toString(),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[100],
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: imgUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imgUrl.startsWith('http')
                              ? imgUrl
                              : Supabase.instance.client.storage
                                  .from('crop_images')
                                  .getPublicUrl(imgUrl),
                          fit: BoxFit.cover,
                          memCacheHeight:
                              750, // ✅ OOM Memory Protection (250px * 3x pixel density)
                          placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.green)),
                          errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey)),
                        )
                      : const Center(
                          child:
                              Icon(Icons.image, size: 80, color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- TITLE & STATUS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder<String>(
                    future: _getCachedTranslation(name, langCode),
                    initialData: name,
                    builder: (context, snapshot) {
                      return Text(
                        "${snapshot.data ?? name} ($variety)",
                        maxLines: 2, // ✅ Protects against RenderFlex overflow
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.5))),
                  child: FutureBuilder<String>(
                    future: _getCachedTranslation(status, langCode),
                    initialData: status,
                    builder: (context, snapshot) => Text(
                      (snapshot.data ?? status).toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 5),

            FutureBuilder<List<String>>(
              future: Future.wait([
                _getCachedTranslation(category, langCode),
                _getCachedTranslation(grade, langCode)
              ]),
              initialData: [category, grade],
              builder: (context, snapshot) {
                final cat = snapshot.data?[0] ?? category;
                final grd = snapshot.data?[1] ?? grade;
                return Text("$cat • $grd",
                    maxLines: 1, // ✅ Overflow protection
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 15,
                        fontWeight: FontWeight.w500));
              },
            ),

            const Divider(height: 40, thickness: 1),

            // --- DETAILS GRID ---
            _detailRow(Icons.currency_rupee, text('price', fallback: "Price"),
                "₹$priceVal"),
            _detailRow(Icons.scale, text('quantity', fallback: "Quantity"),
                quantityStr),

            _detailRow(
                Icons.eco,
                text('farming_type', fallback: "Farming Mode"),
                crop['crop_type'] ?? 'Organic',
                langCode: langCode,
                shouldTranslateValue: true),

            _detailRow(
                Icons.event_available,
                text('harvest_date', fallback: "Harvest Date"),
                _formatDate(context, crop['harvest_date'])),
            _detailRow(
                Icons.local_shipping,
                text('avail_from', fallback: "Available From"),
                _formatDate(context, crop['available_from'])),

            const SizedBox(height: 30),

            // --- DESCRIPTION ---
            Text(text('notes', fallback: "Farmer's Notes / Description"),
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.green.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100)),
              child: FutureBuilder<String>(
                future: _getCachedTranslation(description, langCode),
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
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {String? langCode, bool shouldTranslateValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Text("$label:",
              style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(
              width:
                  8), // ✅ Changed from Spacer to ensure long values truncate safely
          Expanded(
            child: shouldTranslateValue && langCode != null
                ? FutureBuilder<String>(
                    future: _getCachedTranslation(value, langCode),
                    initialData: value,
                    builder: (context, snapshot) {
                      return Text(snapshot.data ?? value,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87));
                    },
                  )
                : Text(value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, String? dateStr) {
    String text(String key, {String fallback = ""}) {
      String trans = FarmerText.get(context, key);
      return trans == key && fallback.isNotEmpty ? fallback : trans;
    }

    if (dateStr == null || dateStr.isEmpty || dateStr == '--') {
      return text('not_specified', fallback: "Not Specified");
    }
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy').format(d);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF2E7D32); // Deep Green
      case 'sold':
        return Colors.red.shade700;
      case 'inactive':
        return Colors.grey.shade600;
      case 'verified':
        return Colors.orange.shade700;
      default:
        return Colors.blue.shade700;
    }
  }
}
