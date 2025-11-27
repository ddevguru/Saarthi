

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;

  Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefToken, token);
    }
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.prefToken);
    return _token;
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {bool requireAuth = false}) async {
    try {
      if (requireAuth) {
        final token = await getToken();
        if (token == null || token.isEmpty) {
          throw Exception('Authentication required. Please login first.');
        }
      }

      final url = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      
      http.Response response;
      try {
        response = await http.post(
          url,
          headers: _getHeaders(includeAuth: requireAuth),
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 30));
      } catch (e) {
        if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
          throw Exception('Request timeout. Please check your internet connection.');
        } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          throw Exception('Cannot connect to server. Please check your internet connection.');
        }
        throw Exception('Network error: $e');
      }

      // Handle empty response
      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid response from server: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
      }
      
      // Handle token expiration (401)
      if (response.statusCode == 401) {
        // Clear token and throw specific error
        await setToken(null);
        final errorMsg = responseData['message'] ?? 'Invalid or expired token. Please login again.';
        throw Exception(errorMsg);
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        // Extract actual error message from response
        final errorMsg = responseData['message'] ?? 
                        responseData['error'] ?? 
                        'Request failed with status ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Re-throw with original message if it's already an Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams, bool requireAuth = true}) async {
    try {
      if (requireAuth) {
        final token = await getToken();
        if (token == null || token.isEmpty) {
          throw Exception('Authentication required. Please login first.');
        }
      }

      var url = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      if (queryParams != null) {
        url = url.replace(queryParameters: queryParams);
      }

      http.Response response;
      try {
        response = await http.get(
          url,
          headers: _getHeaders(includeAuth: requireAuth),
        ).timeout(const Duration(seconds: 30));
      } catch (e) {
        if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
          throw Exception('Request timeout. Please check your internet connection.');
        } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          throw Exception('Cannot connect to server. Please check your internet connection.');
        }
        throw Exception('Network error: $e');
      }

      // Handle empty response
      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid response from server');
      }
      
      // Handle token expiration (401)
      if (response.statusCode == 401) {
        // Clear token and throw specific error
        await setToken(null);
        final errorMsg = responseData['message'] ?? 'Invalid or expired token. Please login again.';
        throw Exception(errorMsg);
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        final errorMsg = responseData['message'] ?? 
                        responseData['error'] ?? 
                        'Request failed with status ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }
}

