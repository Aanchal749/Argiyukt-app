import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Login
  Future<AuthResponse> login(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Get User Role
  Future<String?> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return response?['role'] as String?;
    } catch (e) {
      print("Error fetching role: $e");
      return null;
    }
  }

  // Register
  static Future<bool> registerUser({
    required String phone,
    required String password,
    required String role,
    required String fullName,
    required String email,
    required String state,
    required String district,
    required String taluka,
    required String village,
    required String extraField, // This is land_size / buyer_type / employee_id
    required String pinCode,
  }) async {
    try {
      // 1. Create Auth User
      print("Attempting to create user: $email");
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        phone: phone,
      );

      if (response.user == null) {
        print("Auth failed: User is null");
        return false;
      }
      final String userId = response.user!.id;

      // 2. Prepare Profile Data
      // ✅ FIX: Split Full Name into First/Last
      List<String> nameParts = fullName.trim().split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts.first : '';
      String lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // ✅ FIX: Base Profile Data
      final Map<String, dynamic> profileData = {
        'id': userId,
        'role': role,
        'first_name': firstName, // Database expects first_name
        'last_name': lastName, // Database expects last_name
        'phone': phone,
        'email': email,
        'state': state,
        'district': district,
        'taluka': taluka.isEmpty ? 'Unknown' : taluka,
        'village': village.isEmpty ? 'Unknown' : village,
        'pincode': pinCode, // Database column is 'pincode', not 'pin_code'
        'created_at': DateTime.now().toIso8601String(),
        'verification_status': 'Not Uploaded', // Default status
      };

      // ✅ FIX: Map 'extraField' based on Role
      if (role == 'Farmer') {
        profileData['land_size'] = extraField;
      } else if (role == 'Buyer') {
        profileData['buyer_type'] = extraField;
      } else if (role == 'Inspector') {
        profileData['employee_id'] = extraField;
      }

      // 3. Insert Profile Entry
      print("Inserting profile for ID: $userId with Data: $profileData");
      await _supabase.from('profiles').insert(profileData);

      print("Registration Successful!");
      return true;
    } catch (e) {
      print("Registration Error (Detailed): $e");
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
