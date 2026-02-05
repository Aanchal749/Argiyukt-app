import 'package:supabase_flutter/supabase_flutter.dart';

class FarmService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get userId => _supabase.auth.currentUser?.id;

  // Fetch Farms
  Future<List<Map<String, dynamic>>> getMyFarms() async {
    try {
      if (userId == null) return [];

      final data = await _supabase
          .from('farms')
          .select()
          .eq('farmer_id', userId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error fetching farms: $e");
      return [];
    }
  }

  // Add Farm
  Future<bool> addFarm(String name, String address, String cropType) async {
    try {
      if (userId == null) return false;

      await _supabase.from('farms').insert({
        'farmer_id': userId,
        'name': name,
        'location': address,
        'primary_crop': cropType,
        'size_acres': 0, // You can add a text field for this later
      });
      return true;
    } catch (e) {
      print("Error adding farm: $e");
      return false;
    }
  }
}
