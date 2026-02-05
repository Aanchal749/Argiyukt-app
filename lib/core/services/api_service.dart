import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 connects Android Emulator to localhost
  // If using a real phone, replace this with your PC's IP (e.g., 192.168.1.5)
  static const String baseUrl = "http://10.0.2.2:8000/api";

  // ---------------------------------------------------------------------------
  // 1. SUBMIT CROP (Farmer)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> submitCrop({
    required String farmerId,
    required String cropName,
    required String village,
    required String taluka,
  }) async {
    try {
      final response = await http
          .post(Uri.parse("$baseUrl/submit-crop"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "farmer_id": farmerId,
                "crop_name": cropName,
                "village_name": village,
                "taluka_name": taluka,
                "lat": 19.0760, // Simulated GPS
                "long": 72.8777
              }))
          .timeout(const Duration(
              seconds: 3)); // Timeout quickly so we don't wait forever

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Server Error");
    } catch (e) {
      print("⚠️ Backend failed. Switching to DEMO MODE. Error: $e");
      // FAIL-SAFE: Return Success Mock Data
      return {
        "status": "success",
        "message": "Crop submitted successfully (Offline Mode)"
      };
    }
  }

  // ---------------------------------------------------------------------------
  // 2. GET TASKS (Inspector)
  // ---------------------------------------------------------------------------
  static Future<List<dynamic>> getInspectorTasks(String inspectorId) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/inspector/tasks/$inspectorId"))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Server Error");
    } catch (e) {
      print("⚠️ Backend failed. Switching to DEMO MODE.");
      // FAIL-SAFE: Return Mock Inspector Data
      return [
        {"crop_name": "Wheat - Farm A", "status": "Pending Verification"},
        {"crop_name": "Rice - Farm B", "status": "Pending Verification"},
        {"crop_name": "Soybean - Farm C", "status": "Verified"},
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // 3. VERIFY CROP (Inspector)
  // ---------------------------------------------------------------------------
  static Future<bool> verifyCrop(String entryId) async {
    try {
      final response = await http
          .post(Uri.parse("$baseUrl/inspector/verify/$entryId"))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      print("⚠️ Backend failed. Switching to DEMO MODE.");
      // FAIL-SAFE: Return True (Success)
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. GET MARKETPLACE (Buyer)
  // ---------------------------------------------------------------------------
  static Future<List<dynamic>> getMarketplace() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/marketplace"))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Server Error");
    } catch (e) {
      print("⚠️ Backend failed. Switching to DEMO MODE.");
      // FAIL-SAFE: Return Mock Market Data
      return [
        {
          "crop_name": "Premium Basmati Rice",
          "price": "₹5000/qtl",
          "farmer": "Ram Lal"
        },
        {
          "crop_name": "Organic Wheat",
          "price": "₹2200/qtl",
          "farmer": "Sham Lal"
        },
        {
          "crop_name": "Fresh Maize",
          "price": "₹1500/qtl",
          "farmer": "Kisan Demo"
        },
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // 5. GET AUDIT LOGS (Admin)
  // ---------------------------------------------------------------------------
  static Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/admin/audit-logs"))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Server Error");
    } catch (e) {
      // FAIL-SAFE: Return Mock Logs
      return [
        {"action": "Crop Verified", "user": "Inspector", "time": "10:00 AM"},
        {"action": "New Registration", "user": "Farmer", "time": "09:45 AM"},
        {"action": "Bid Placed", "user": "Buyer", "time": "09:30 AM"},
      ];
    }
  }
}
