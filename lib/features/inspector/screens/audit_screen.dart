/*import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // 🔗 CONFIGURATION
  // Use 'http://10.0.2.2:8000' if using Android Emulator
  // Use your PC IP (e.g. 'http://192.168.1.5:8000') if using a physical phone
  static const String _baseUrl = "http://10.0.2.2:8000";

  // Session State
  static String? _currentLoggedInRole;

  // ------------------------------------------------------------------------
  // 1️⃣ REGISTER USER (Calls FastAPI /register)
  // ------------------------------------------------------------------------
  static Future<bool> registerUser({
    required String phone,
    required String password,
    required String role,
    required String name,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/register");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "password": password,
          "role": role,
          "full_name": name,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Registration Success: ${response.body}");
        _currentLoggedInRole = role; // Auto-login
        return true;
      } else {
        print("❌ Registration Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("⚠️ Network Error: $e");
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // 2️⃣ LOGIN USER (Calls FastAPI /login)
  // ------------------------------------------------------------------------
  static Future<Map<String, String>?> loginUser(
      String phone, String password) async {
    try {
      final url = Uri.parse("$_baseUrl/login");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentLoggedInRole = data['role'];
        return {
          "role": data['role'],
          "name": data['full_name'] ?? "User",
        };
      } else {
        print("❌ Login Failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Network Error: $e");
      return null;
    }
  }

  // ------------------------------------------------------------------------
  // 3️⃣ CHECK SESSION & LOGOUT
  // ------------------------------------------------------------------------
  static Future<String?> checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _currentLoggedInRole;
  }

  static Future<void> logout() async {
    _currentLoggedInRole = null;
  }
}
*/
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // 🔗 CONNECTION CONFIG
  // --------------------------------------------------------
  // IF USING EMULATOR: Use 'http://10.0.2.2:8000'
  // IF USING REAL PHONE: Use 'http://YOUR_PC_IP:8000' (e.g. 192.168.1.5)
  static const String _baseUrl = "http://10.0.2.2:8000";
  // --------------------------------------------------------

  static String? _currentLoggedInRole;

  // 🚀 FAST LOGIN FUNCTION
  static Future<Map<String, String>?> loginUser(
      String phone, String password) async {
    try {
      print("🔵 Connecting to: $_baseUrl/login");

      final response = await http
          .post(
            Uri.parse("$_baseUrl/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"phone": phone, "password": password}),
          )
          .timeout(
              const Duration(seconds: 5)); // 👈 Fails fast if no connection

      print("🔵 Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentLoggedInRole = data['role'];
        return {
          "role": data['role'],
          "name": data['full_name'] ?? "User",
        };
      } else {
        print("🔴 Login Failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("🔴 CONNECTION ERROR: $e");
      return null;
    }
  }

  // 🚀 FAST REGISTRATION FUNCTION
  static Future<bool> registerUser({
    required String phone,
    required String password,
    required String role,
    required String name,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/register"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "phone": phone,
              "password": password,
              "role": role,
              "full_name": name,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _currentLoggedInRole = role;
        return true;
      }
      return false;
    } catch (e) {
      print("🔴 CONNECTION ERROR: $e");
      return false;
    }
  }

  static Future<String?> checkLoginStatus() async {
    return _currentLoggedInRole;
  }

  static Future<void> logout() async {
    _currentLoggedInRole = null;
  }
}
