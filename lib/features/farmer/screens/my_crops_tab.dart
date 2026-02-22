import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// ✅ CORE & FEATURE IMPORTS
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';
import 'package:agriyukt_app/features/farmer/screens/add_crop_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/edit_crop_screen.dart';
import 'package:agriyukt_app/features/farmer/screens/view_crop_screen.dart';

class MyCropsTab extends StatefulWidget {
  const MyCropsTab({super.key});

  @override
  State<MyCropsTab> createState() => _MyCropsTabState();
}

class _MyCropsTabState extends State<MyCropsTab> {
  final _client = Supabase.instance.client;

  bool _showActive = true;
  String _searchQuery = "";
  final _searchCtrl = TextEditingController();

  // 🛡️ CRITICAL FIX: Forces the stream to drop cache and re-query DB
  int _refreshTrigger = 0;

  final Color _primaryGreen = const Color(0xFF1B5E20);

  // Translation Helper
  String _text(String key) => FarmerText.get(context, key);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 🔄 MANUAL REFRESH LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _refreshList() async {
    setState(() => _refreshTrigger++);
    // Slight delay to allow the pull-to-refresh animation to look smooth
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // ---------------------------------------------------------------------------
  // 🗑️ DELETE LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _deleteCrop(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_text('delete_listing'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content:
            Text(_text('delete_confirm_msg'), style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_text('cancel'), style: GoogleFonts.poppins())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_text('delete'),
                  style: GoogleFonts.poppins(
                      color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('crops').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(_text('crop_deleted'), style: GoogleFonts.poppins()),
              backgroundColor: Colors.red));
          _refreshList(); // 🔄 Force UI to update immediately
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error deleting: $e", style: GoogleFonts.poppins()),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🛡️ DATA SAFETY HELPERS
  // ---------------------------------------------------------------------------
  String _safeStr(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    return val.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // 🖥️ UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    if (user == null) {
      return Center(
          child: Text(_text('login_required'), style: GoogleFonts.poppins()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddCropScreen()));
          if (!mounted) return;
          _refreshList(); // 🔄 Force fetch new crop from DB
        },
        label: Text(_text('add_crop'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 🎨 CUSTOM GREEN HEADER (Search + Tabs only)
          Container(
            padding: EdgeInsets.only(
              // 🔥 EXTREME UPLIFT: Removed the +8 entirely. It now sits flush with the status bar.
              top: MediaQuery.of(context).padding.top,
              // 🔥 EXTREME UPLIFT: Tighter bottom padding.
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: _primaryGreen,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                // --- SEARCH BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase().trim()),
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: _text('search_crops_hint'),
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search, color: _primaryGreen),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = "");
                              })
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      // 🔥 EXTREME UPLIFT: Slimmer Search Bar height.
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white)),
                    ),
                  ),
                ),
                // 🔥 EXTREME UPLIFT: Shrunk the gap between search and tabs to just 6 pixels.
                const SizedBox(height: 6),
                // --- TABS ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: _tabBtn(_text('active_crops_tab'), true)),
                        Expanded(
                            child: _tabBtn(_text('inactive_sold_tab'), false)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- STREAM LIST ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_refreshTrigger), // 🛡️ CRITICAL: Busts the Cache
              stream: _client
                  .from('crops')
                  .stream(primaryKey: ['id'])
                  .eq('farmer_id', user.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: _primaryGreen));
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error loading crops.",
                          style: GoogleFonts.poppins(color: Colors.red)));
                }

                final rawData = snapshot.data;
                if (rawData == null || rawData.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshList,
                    color: _primaryGreen,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                            child: Text(_text('no_crops_found'),
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[500]))),
                      ],
                    ),
                  );
                }

                // 🧠 FILTER LOGIC
                final filtered = rawData.where((c) {
                  final status = _safeStr(c['status'], 'Active');

                  // Extract raw strings safely
                  final String qtyKgStr = _safeStr(c['quantity_kg'], '0');
                  final String fallbackQtyStr = _safeStr(c['quantity'], '0');

                  // Strip letters, parse to double safely
                  final double qtyKg = double.tryParse(
                          qtyKgStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0.0;
                  final double fallbackQty = double.tryParse(
                          fallbackQtyStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0.0;

                  // Always assume they have stock if Legacy Quantity exists, else use exact Kg logic
                  final double totalStock = qtyKg > 0 ? qtyKg : fallbackQty;

                  // Active logic: Status is good AND they physically have stock left
                  final isActiveGroup =
                      ['Active', 'Verified', 'Growing'].contains(status) &&
                          (totalStock > 0);

                  final matchesTab =
                      _showActive ? isActiveGroup : !isActiveGroup;

                  final name = _safeStr(c['crop_name']).toLowerCase();
                  final variety = _safeStr(c['variety']).toLowerCase();
                  final matchesSearch = name.contains(_searchQuery) ||
                      variety.contains(_searchQuery);

                  return matchesTab && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshList,
                    color: _primaryGreen,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                            child: Text(_text('no_crops_found'),
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[500]))),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshList,
                  color: _primaryGreen,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 🔥 EXTREME UPLIFT: Reduced list top padding so cards pull up instantly.
                    padding: const EdgeInsets.only(
                        top: 8, left: 16, right: 16, bottom: 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) =>
                        _buildLargeCard(filtered[i], langCode),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧩 WIDGET COMPONENTS
  // ---------------------------------------------------------------------------
  Widget _tabBtn(String label, bool target) {
    bool isSel = _showActive == target;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showActive = target);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSel
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: isSel ? _primaryGreen : Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
      ),
    );
  }

  Widget _buildLargeCard(Map<String, dynamic> crop, String langCode) {
    // --- IMAGE LOGIC ---
    ImageProvider imgProvider;
    String imgUrl = _safeStr(crop['image_url']);
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http')) {
        imgProvider = NetworkImage(imgUrl);
      } else {
        imgProvider = NetworkImage(
            _client.storage.from('crop_images').getPublicUrl(imgUrl));
      }
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    // --- DATA EXTRACTION ---
    final String name = _safeStr(crop['crop_name'], 'Unknown Crop');
    final String variety = _safeStr(crop['variety'], 'Generic');
    final String status = _safeStr(crop['status'], 'ACTIVE').toUpperCase();

    // Quantity Logic
    String rawQty =
        _safeStr(crop['quantity_kg'], _safeStr(crop['quantity'], '0'));
    String qtyValue = rawQty.replaceAll(
        RegExp(r"([.]*0)(?!.*\d)"), ""); // Remove trailing zeroes

    String unit = _safeStr(crop['unit'], 'Unit');
    if (unit == 'Unit' && rawQty.contains(' ')) {
      unit = rawQty.split(' ').sublist(1).join(' ');
    }

    // Translate Units
    String displayUnit = unit;
    String lowerUnit = unit.toLowerCase();
    if (lowerUnit.contains('kg'))
      displayUnit = 'kg';
    else if (lowerUnit.contains('quintal') || lowerUnit == 'q')
      displayUnit = 'q';
    else if (lowerUnit.contains('ton') || lowerUnit == 't')
      displayUnit = 't';
    else if (lowerUnit.contains('crate'))
      displayUnit = 'crates';
    else
      displayUnit = _text(lowerUnit) == lowerUnit ? unit : _text(lowerUnit);

    String displayQty = "$qtyValue $displayUnit";

    // Price Logic
    String priceVal =
        _safeStr(crop['price'], _safeStr(crop['price_per_qty'], '0'));
    priceVal = priceVal.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
    final String displayPrice = "₹$priceVal / $displayUnit";

    final String harvestDate = _formatDate(_safeStr(crop['harvest_date']));
    final String availDate = _formatDate(_safeStr(crop['available_from']));
    final String localizedStatus = _text(status.toLowerCase());

    // Status Colors
    Color statusColor = Colors.green;
    if (status == 'SOLD')
      statusColor = Colors.red;
    else if (status == 'INACTIVE')
      statusColor = Colors.grey;
    else if (status == 'VERIFIED') statusColor = Colors.orange;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      image: DecorationImage(
                          image: imgProvider, fit: BoxFit.cover)),
                ),
              ),
              // 🟢 STATUS ON TOP LEFT
              Positioned(
                top: 15,
                left: 15,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ]),
                  child: Text(localizedStatus.toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ),
              // 🔴 DELETE ON TOP RIGHT
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: () => _deleteCrop(_safeStr(crop['id'])),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ]),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: TranslationService.toLocal(name, langCode),
                          initialData: name,
                          builder: (context, snapshot) => Text(
                            snapshot.data ?? name,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(variety,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    )),
                    Text(displayPrice,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _primaryGreen)),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _infoItem(Icons.scale, _text('quantity'),
                            displayQty, Colors.blue)),
                    Expanded(
                        child: _infoItem(Icons.agriculture,
                            _text('harvest_date'), harvestDate, Colors.orange)),
                  ],
                ),
                const SizedBox(height: 6),
                _infoItem(Icons.event_available, _text('avail_from'), availDate,
                    Colors.purple),
                const SizedBox(height: 12),

                // --- ACTION BUTTONS ---
                Row(
                  children: [
                    Expanded(
                        child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ViewCropScreen(crop: crop))),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.visibility,
                                color: Colors.white, size: 16),
                            label: Text(_text('view'),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          EditCropScreen(cropData: crop)));
                              if (mounted)
                                _refreshList(); // 🔄 Fetch fresh edit data!
                            },
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.edit,
                                color: Colors.orange, size: 16),
                            label: Text(_text('edit'),
                                style: GoogleFonts.poppins(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)))),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)
        ])),
      ],
    );
  }

  // ✅ NUMERICAL DATE FORMATTER (DD/MM/YYYY)
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "N/A";
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return "N/A";
    }
  }
}
