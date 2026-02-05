import 'package:supabase_flutter/supabase_flutter.dart';

class InspectorMatchingService {
  final _client = Supabase.instance.client;

  /// Runs the AgriYuk Matching Logic (Plan A -> B -> C)
  Future<String?> findNearbyInspector(
      String villageId, String talukaId, String districtId) async {
    try {
      // 1. Plan A: Exact Village Match (Preferred)
      // Find inspector whose assigned_region_ids contains the Village ID
      final villageInspectors = await _client
          .from('inspectors')
          .select('user_id')
          .contains('assigned_region_ids', [villageId])
          .eq('status', 'Active') // Only active inspectors [cite: 25]
          .limit(1);

      if (villageInspectors.isNotEmpty) {
        return villageInspectors.first['user_id'] as String;
      }

      // 2. Plan B: Taluka Fallback
      // Find inspector assigned to the Taluka ID
      final talukaInspectors = await _client
          .from('inspectors')
          .select('user_id')
          .contains('assigned_region_ids', [talukaId])
          .eq('status', 'Active')
          .limit(1);

      if (talukaInspectors.isNotEmpty) {
        return talukaInspectors.first['user_id'] as String;
      }

      // 3. Plan C: District Fallback (Simplified) [cite: 45]
      // In a real backend, you'd calculate Distance (Haversine).
      // Here we just check if they are mapped to the District ID.
      final districtInspectors = await _client
          .from('inspectors')
          .select('user_id')
          .contains('assigned_region_ids', [districtId])
          .eq('status', 'Active')
          .limit(1);

      if (districtInspectors.isNotEmpty) {
        return districtInspectors.first['user_id'] as String;
      }

      return null; // Plan D: No inspector found (Self-Edit Mode) [cite: 47]
    } catch (e) {
      return null;
    }
  }
}
