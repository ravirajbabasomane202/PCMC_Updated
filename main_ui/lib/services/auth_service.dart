import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'package:main_ui/utils/constants.dart';
import '../exceptions/auth_exception.dart';

/// Pure JWT-based auth service — no Firebase / Google SDK dependency.
/// Login methods: email+password, OTP (phone). Google OAuth is handled
/// via a server-side redirect (no client-side Firebase needed).
class AuthService {
  static final String _baseUrl = Constants.baseUrl;

  static String? _token;

  static final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  /// Stream to notify auth changes
  static Stream<String?> get authStateChanges =>
      _authStateController.stream;

  static Future<SharedPreferences> get _storage async =>
      SharedPreferences.getInstance();

  /* -------------------- INIT -------------------- */

  static Future<void> initialize() async {
    final prefs = await _storage;
    _token = prefs.getString('access_token');
    _authStateController.add(_token);
  }

  /* -------------------- TOKEN MANAGEMENT -------------------- */

  static Future<void> storeToken(String token) async {
    if (token.isEmpty) throw Exception('Cannot store empty token');
    final prefs = await _storage;
    await prefs.setString('access_token', token);
    _token = token;
    _authStateController.add(token);
  }

  static Future<void> clearToken() async {
    final prefs = await _storage;
    await prefs.remove('access_token');
    _token = null;
    _authStateController.add(null);
  }

  static Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;
    final prefs = await _storage;
    _token = prefs.getString('access_token');
    return _token;
  }

  static Future<String> _setTokenFromResponse(
      Map<String, dynamic> response) async {
    final token = response['access_token'];
    if (token == null || (token as String).isEmpty) {
      throw Exception('Invalid token received from backend');
    }
    await storeToken(token);
    return token;
  }

  /* -------------------- REGISTER -------------------- */

  static Future<void> register(
    String name,
    String email,
    String password, {
    String? address,
    String? phoneNumber,
    String? voterId,
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        if (address != null) 'address': address,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (voterId != null) 'voter_id': voterId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await passwordLogin(email, password);
      } else {
        throw AuthException(
          data['msg'] ?? 'Registration failed',
          field: data['error'],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /* -------------------- EMAIL LOGIN -------------------- */

  static Future<void> passwordLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await _setTokenFromResponse(data);
      } else {
        throw AuthException(data['msg'] ?? 'Invalid email or password');
      }
    } catch (e) {
      rethrow;
    }
  }

  /* -------------------- OTP LOGIN -------------------- */

  static Future<void> requestOtp(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone_number': phoneNumber}),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        json.decode(response.body)['msg'] ?? 'OTP request failed',
      );
    }
  }

  static Future<void> verifyOtp(String phoneNumber, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone_number': phoneNumber, 'otp': otp}),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      await _setTokenFromResponse(data);
    } else {
      throw AuthException(data['msg'] ?? 'OTP verification failed');
    }
  }

  /* -------------------- CURRENT USER -------------------- */

  static Future<User?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }

      await logout();
      return null;
    } catch (_) {
      return null;
    }
  }

  /* -------------------- LOGOUT -------------------- */

  static Future<void> logout() async {
    await clearToken();
  }

  static void dispose() {
    _authStateController.close();
  }
}
