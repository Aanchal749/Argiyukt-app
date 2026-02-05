import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Package imports
import 'package:agriyukt_app/features/inspector/screens/inspector_add_crop_tab.dart';
import 'package:agriyukt_app/features/inspector/screens/add_farmer_screen.dart';
import 'package:agriyukt_app/features/inspector/screens/edit_farmer_screen.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_farmer_crops_screen.dart';

class InspectorFarmersTab extends StatefulWidget {
  const InspectorFarmersTab({super.key});

  @override
  State<InspectorFarmersTab> createState() => _InspectorFarmersTabState();
}

class _InspectorFarmersTabState extends State<InspectorFarmersTab> {
  final _client = Supabase.instance.client;
  String _searchQuery = "";
  final _searchCtrl = TextEditingController();

  // State for fetching
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchFarmers();
  }

  Future<void> _fetchFarmers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = _client.auth.currentUser;
      if (user == null) throw "User not logged in";

      // Fetching farmers managed by this inspector
      final response = await _client
          .from('profiles')
          .select()
          .eq('role',
              'farmer') // ✅ FIXED: Changed 'Farmer' to 'farmer' (lowercase)
          .eq('inspector_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _farmers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _deleteFarmer(String farmerId, String farmerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Farmer?"),
        content: Text("Delete $farmerName? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('profiles').delete().eq('id', farmerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Deleted successfully"),
            backgroundColor: Colors.red));
        _fetchFarmers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please Login")));

    final filteredFarmers = _farmers.where((f) {
      final name =
          "${f['first_name'] ?? ''} ${f['last_name'] ?? ''}".toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddFarmerScreen()));
          _fetchFarmers(); // Refresh list after adding
        },
        backgroundColor: const Color(0xFF512DA8), // ✅ Inspector Purple
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Add Farmer", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Managed Farmers",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF512DA8))), // ✅ Inspector Purple
                IconButton(
                    onPressed: _fetchFarmers,
                    icon: const Icon(Icons.refresh, color: Colors.indigo))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search Name...",
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.indigo))
                : _errorMsg != null
                    ? Center(
                        child: Text("Error: $_errorMsg",
                            style: const TextStyle(color: Colors.red)))
                    : filteredFarmers.isEmpty
                        ? const Center(
                            child: Text("No farmers found.",
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                            itemCount: filteredFarmers.length,
                            itemBuilder: (ctx, i) =>
                                _buildFarmerCard(filteredFarmers[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> farmer) {
    final name =
        "${farmer['first_name'] ?? 'Unknown'} ${farmer['last_name'] ?? ''}"
            .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100, // ✅ Inspector Theme
          child: const Icon(Icons.verified_user, color: Colors.indigo),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Phone: ${farmer['phone'] ?? 'N/A'}"),
            Text("Location: ${farmer['district'] ?? 'N/A'}", // ✅ Show District
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'add') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          InspectorAddCropTab(preSelectedFarmer: farmer)));
            } else if (value == 'view') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => InspectorFarmerCropsScreen(
                          farmerId: farmer['id'], farmerName: name)));
            } else if (value == 'edit') {
              bool? updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditFarmerScreen(farmer: farmer)));
              if (updated == true) _fetchFarmers();
            } else if (value == 'delete') {
              _deleteFarmer(farmer['id'], name);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'add',
                child: Row(children: [
                  Icon(Icons.add_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Add Crop')
                ])),
            const PopupMenuItem(
                value: 'view',
                child: Row(children: [
                  Icon(Icons.visibility, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('View Crops')
                ])),
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Edit Details')
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete')
                ])),
          ],
        ),
      ),
    );
  }
}
