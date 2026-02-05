import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';
import 'package:agriyukt_app/features/farmer/farmer_translations.dart';
import 'package:agriyukt_app/core/services/translation_service.dart';
import 'package:agriyukt_app/features/farmer/screens/add_crop_screen.dart';
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
  int _refreshTrigger = 0;

  final Color _primaryGreen = const Color(0xFF1B5E20);
  String _text(String key) => FarmerText.get(context, key);

  // --- DELETE LOGIC ---
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
              child: Text(_text('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_text('delete'),
                  style: GoogleFonts.poppins(
                      color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await _client.from('crops').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_text('crop_deleted')), backgroundColor: Colors.red));
        _refreshList();
      }
    }
  }

  // ✅ Force Refresh
  Future<void> _refreshList() async {
    setState(() => _refreshTrigger++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final langCode =
        Provider.of<LanguageProvider>(context).appLocale.languageCode;

    if (user == null) return Center(child: Text(_text('login_required')));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddCropScreen()));
          _refreshList();
        },
        label: Text(_text('add_crop'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_text('my_crops_inventory'),
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                hintText: _text('search_crops_hint'),
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryGreen)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _tabBtn(_text('active_crops_tab'), true)),
                const SizedBox(width: 10),
                Expanded(child: _tabBtn(_text('inactive_sold_tab'), false)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_refreshTrigger),
              stream: _client
                  .from('crops')
                  .stream(primaryKey: ['id'])
                  .eq('farmer_id', user.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(
                      child: CircularProgressIndicator(color: _primaryGreen));

                final filtered = snapshot.data!.where((c) {
                  final status = c['status'] ?? 'Active';
                  // 👉 FARMER VIEW: Shows if Total Stock > 0.
                  // Even if reserved, it is "Active" in farmer's eyes until sold.
                  final double totalStock = (c['quantity_kg'] ?? 0).toDouble();
                  final isActiveGroup =
                      ['Active', 'Verified', 'Growing'].contains(status) &&
                          (totalStock > 0);

                  final matchesTab =
                      _showActive ? isActiveGroup : !isActiveGroup;
                  final name = c['crop_name'] ?? '';
                  final matchesSearch =
                      name.toString().toLowerCase().contains(_searchQuery);
                  return matchesTab && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshList,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2),
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
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
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

  Widget _tabBtn(String label, bool target) {
    bool isSel = _showActive == target;
    return GestureDetector(
      onTap: () => setState(() => _showActive = target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:
              isSel ? null : Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: isSel
              ? [
                  BoxShadow(
                      color: _primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: isSel ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLargeCard(Map<String, dynamic> crop, String langCode) {
    ImageProvider imgProvider;
    String? imgUrl = crop['image_url'];
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http'))
        imgProvider = NetworkImage(imgUrl);
      else
        imgProvider = NetworkImage(
            _client.storage.from('crop_images').getPublicUrl(imgUrl));
    } else {
      imgProvider = const AssetImage('assets/images/placeholder_crop.png');
    }

    final String name = crop['crop_name'] ?? 'Unknown Crop';
    final String variety = crop['variety'] ?? 'Generic';
    final String status = crop['status']?.toUpperCase() ?? "ACTIVE";

    // --- 👉 GOLDEN RULE LOGIC ---
    // 1. Read 'quantity_kg' (Total Stock).
    // 2. Pending Orders increase 'reserved_kg', but NOT 'quantity_kg'.
    // 3. Result: Farmer sees 100kg even if 10kg is pending.
    String qtyValue = (crop['quantity_kg'] ?? 0).toString();
    qtyValue = qtyValue.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

    String unit = crop['unit'] ?? "Unit";
    if (unit == "Unit") {
      String rawLegacy = crop['quantity']?.toString() ?? "";
      if (rawLegacy.contains(' '))
        unit = rawLegacy.split(' ').sublist(1).join(' ');
    }

    // Unit Localization
    String displayUnit = unit;
    String lowerUnit = unit.toLowerCase();
    if (lowerUnit.contains('kg'))
      displayUnit = _text('kg');
    else if (lowerUnit.contains('quintal'))
      displayUnit = _text('quintal');
    else if (lowerUnit.contains('ton'))
      displayUnit = _text('ton');
    else if (lowerUnit.contains('crate'))
      displayUnit = _text('crates');
    else
      displayUnit = _text(lowerUnit) == lowerUnit ? unit : _text(lowerUnit);

    String displayQty = "$qtyValue $displayUnit";

    // --- PRICE PARSING ---
    String priceVal =
        crop['price']?.toString() ?? crop['price_per_qty']?.toString() ?? '0';
    priceVal = priceVal.replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
    final String displayPrice = "₹$priceVal / $displayUnit";

    final String harvestDate = _formatDate(crop['harvest_date']);
    final String availDate = _formatDate(crop['available_from']);
    final String localizedStatus = _text(status.toLowerCase());

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
              Positioned(
                top: 10,
                left: 10,
                child: InkWell(
                  onTap: () => _deleteCrop(crop['id']),
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
              Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                              fontSize: 11)))),
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
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                                          AddCropScreen(cropToEdit: crop)));
                              _refreshList();
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final d = DateTime.parse(dateStr);
      return "${d.day}/${d.month}/${d.year}";
    } catch (e) {
      return "N/A";
    }
  }
}
