import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final String baseUrl = "http://127.0.0.1:8000/auth";
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> saveToken(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['access_token']);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', data['user']?['name'] ?? 'Traveler');
    await prefs.setString('userEmail', data['user']?['email'] ?? '');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('isLoggedIn');
    // await _googleSignIn.signOut();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    String? phone,
    String? email,
    String? password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "phone": phone,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final isEmail = identifier.contains('@');
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": isEmail ? null : identifier,
        "email": isEmail ? identifier : null,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
    }
  }

  Future<void> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to send OTP');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otpCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": phone,
        "otp_code": otpCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'needs_registration') {
        return data;
      }
      await saveToken(data);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to verify OTP');
    }
  }

  Future<Map<String, dynamic>> googleLogin() async {
    throw Exception("Google Sign-In requires a Client ID and Web configuration. Please test Email and Phone OTP flows instead.");
  }
}
