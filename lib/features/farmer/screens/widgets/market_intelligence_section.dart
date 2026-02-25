import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';

class MarketIntelligenceSection extends StatefulWidget {
  final String farmerId;
  final Color themeColor;

  const MarketIntelligenceSection({
    super.key,
    required this.farmerId,
    this.themeColor = const Color(0xFF1B5E20),
  });

  @override
  State<MarketIntelligenceSection> createState() =>
      _MarketIntelligenceSectionState();
}

class _MarketIntelligenceSectionState extends State<MarketIntelligenceSection>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _marketData = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _fetchCloudPredictions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _text(String key, String fallback) {
    String translated = FarmerText.get(context, key);
    return translated == key ? fallback : translated;
  }

  Future<void> _fetchCloudPredictions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final farmerCrops = await _supabase
          .from('crops')
          .select('crop_name, image_url')
          .eq('farmer_id', widget.farmerId)
          .neq('status', 'Archived')
          .timeout(const Duration(seconds: 10));

      Map<String, String> cropImageMap = {};
      List<String> myCropNames = [];

      if (farmerCrops != null) {
        for (var row in farmerCrops) {
          if (row['crop_name'] != null) {
            String name = row['crop_name'].toString();
            myCropNames.add(name);
            if (row['image_url'] != null &&
                row['image_url'].toString().isNotEmpty) {
              cropImageMap[name] = row['image_url'].toString();
            }
          }
        }
      }

      // 🚀 FETCHING REAL DATA FROM SUPABASE
      List<dynamic> aiResponse = [];
      if (myCropNames.isNotEmpty) {
        aiResponse = await _supabase
            .from('market_predictions')
            .select()
            .inFilter('crop_name', myCropNames)
            .timeout(const Duration(seconds: 10));
      }

      if (aiResponse.isEmpty) {
        aiResponse = await _supabase
            .from('market_predictions')
            .select()
            .limit(3)
            .timeout(const Duration(seconds: 10));
      }

      List<Map<String, dynamic>> mergedData = [];
      for (var data in aiResponse) {
        Map<String, dynamic> item = Map<String, dynamic>.from(data);
        String cropName = item['crop_name'] ?? '';
        item['personal_image'] = cropImageMap[cropName] ?? '';
        mergedData.add(item);
      }

      if (mounted) {
        setState(() {
          _marketData = mergedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Cloud Fetch Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _formatUpdatedTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "Recently";
    try {
      DateTime dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (e) {
      return "Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context);

    if (_hasError) return _buildErrorState();
    if (_isLoading) return _buildSkeleton();
    if (_marketData.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Prevents vertical overflow
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_text('market_ai_title', "📈 AI Predictions (Tomorrow)"),
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: _fetchCloudPredictions,
                  icon: const Icon(Icons.refresh, size: 20))
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _marketData.length,
            itemBuilder: (context, i) => _buildPredictionCard(_marketData[i]),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_text('live_market_price', "📊 Live Market Price"),
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _marketData.length,
          itemBuilder: (context, index) =>
              _buildLivePriceTile(_marketData[index]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: widget.themeColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(_text('view_full_market', "View Full Market"),
                  style: GoogleFonts.poppins(
                      color: widget.themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCropAvatar(String imageUrl, String emoji, double size) {
    if (imageUrl.isNotEmpty) {
      String finalUrl = imageUrl.startsWith('http')
          ? imageUrl
          : _supabase.storage.from('crop_images').getPublicUrl(imageUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: CachedNetworkImage(
          imageUrl: finalUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(width: size, height: size, color: Colors.grey.shade200),
          errorWidget: (context, url, error) => _buildEmojiAvatar(emoji, size),
        ),
      );
    }
    return _buildEmojiAvatar(emoji, size);
  }

  Widget _buildEmojiAvatar(String emoji, double size) {
    return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(size / 4)),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.6)));
  }

  Widget _buildPredictionCard(Map<String, dynamic> data) {
    final color = data['is_upward'] == true ? Colors.green : Colors.red;
    int decimals = (data['live_price'] ?? 0) < 100 ? 1 : 0;
    String imageUrl = data['personal_image'] ?? '';
    String emoji = data['emoji'] ?? '🌱';

    return Container(
      width: 200,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _buildCropAvatar(imageUrl, emoji, 30),
            const SizedBox(width: 8),
            Expanded(
                child: Text(data['crop_name'] ?? '',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    maxLines: 1, // Fix 1: Stop multiline pixel overflow
                    overflow: TextOverflow.ellipsis))
          ]),
          const Spacer(),
          Text("₹${(data['live_price'] ?? 0).toStringAsFixed(decimals)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey)),
          FittedBox(
            // Fix 2: Auto-shrink giant price texts
            fit: BoxFit.scaleDown,
            child: Text(
                "₹${(data['predicted_price'] ?? 0).toStringAsFixed(decimals)}",
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
          Row(
            children: [
              Icon(
                  data['is_upward'] == true
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: color,
                  size: 16),
              const SizedBox(width: 4),
              Text("${(data['trend_percent'] ?? 0).toStringAsFixed(1)}%",
                  style: GoogleFonts.poppins(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Flexible(
                // Fix 3: Allows unit text to shrink instead of overflowing
                child: Text("Per ${data['unit'] ?? 'Kg'}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey[600])),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLivePriceTile(Map<String, dynamic> data) {
    int decimals = (data['live_price'] ?? 0) < 100 ? 1 : 0;
    String formattedTime = _formatUpdatedTime(data['last_updated']?.toString());
    String imageUrl = data['personal_image'] ?? '';
    String emoji = data['emoji'] ?? '🌱';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCropAvatar(imageUrl, emoji, 45),
          const SizedBox(width: 12),
          Expanded(
            flex: 2, // Fix 4: Force left side to take specific ratio
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data['crop_name'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text("APMC",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                ]),
          ),
          Flexible(
            // Fix 5: Wrap right column in Flexible to stop boundary breaks
            flex: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    // Fix 6: Scale down large monetary values safely
                    fit: BoxFit.scaleDown,
                    child: Text(
                        "₹${(data['live_price'] ?? 0).toStringAsFixed(decimals)} / ${data['unit'] ?? 'Kg'}",
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.themeColor)),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    // Fix 7: Stop long dates from breaking screen width
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text("Updated $formattedTime",
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(width: 6),
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_text('live', 'Live'),
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700))
                    ]),
                  )
                ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Fix 8: Prevent infinite height crash
        children: [
          Icon(Icons.auto_graph, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text("Market Data Processing",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
              "Waiting for the Cloud AI to process today's APMC data. Check back shortly.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _fetchCloudPredictions,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text("Refresh",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
        child: Column(
            mainAxisSize:
                MainAxisSize.min, // Fix 9: Prevent infinite height crash
            children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 40),
          Text("Cloud connection lost",
              style: GoogleFonts.poppins(color: Colors.grey)),
          TextButton(
              onPressed: _fetchCloudPredictions, child: const Text("Retry"))
        ]));
  }

  Widget _buildSkeleton() {
    return FadeTransition(
        opacity: _pulseController,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16)))));
  }
}
