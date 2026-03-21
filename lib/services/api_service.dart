import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  AuthService get _authService => AuthService();

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, String>? headers,
    dynamic body,
    int retryCount = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${Constants.apiUrl}$path');
    
    final Map<String, String> requestHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    int attempts = 0;
    while (attempts < retryCount) {
      try {
        http.Response response;
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: requestHeaders).timeout(timeout);
            break;
          case 'POST':
            response = await http.post(uri, headers: requestHeaders, body: jsonEncode(body)).timeout(timeout);
            break;
          case 'PATCH':
            response = await http.patch(uri, headers: requestHeaders, body: jsonEncode(body)).timeout(timeout);
            break;
          case 'PUT':
            response = await http.put(uri, headers: requestHeaders, body: jsonEncode(body)).timeout(timeout);
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: requestHeaders).timeout(timeout);
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }

        // Handle 401 Unauthorized globally
        if (response.statusCode == 401) {
          // Use a message bus or global state to trigger logout if needed
          // For now, we'll just return it and let the caller handle it.
          // In a real app, you'd trigger a logout event here.
        }

        // If success or non-retryable error, return
        if (response.statusCode < 500) {
          return response;
        }

        // Server error (5xx), retry
        attempts++;
        if (attempts < retryCount) {
          await Future.delayed(Duration(seconds: attempts * 2)); // Exponential backoff
        } else {
          return response;
        }
      } on TimeoutException {
        attempts++;
        if (attempts >= retryCount) rethrow;
        await Future.delayed(Duration(seconds: attempts * 2));
      } on SocketException {
        attempts++;
        if (attempts >= retryCount) rethrow;
        await Future.delayed(Duration(seconds: attempts * 2));
      } catch (e) {
        rethrow;
      }
    }
    throw Exception('Request failed after $retryCount attempts');
  }

  // Helper methods
  Future<http.Response> get(String path, {Map<String, String>? headers}) => 
      request('GET', path, headers: headers);
      
  Future<http.Response> post(String path, {Map<String, String>? headers, dynamic body}) => 
      request('POST', path, headers: headers, body: body);
      
  Future<http.Response> patch(String path, {Map<String, String>? headers, dynamic body}) => 
      request('PATCH', path, headers: headers, body: body);

  Future<http.Response> put(String path, {Map<String, String>? headers, dynamic body}) => 
      request('PUT', path, headers: headers, body: body);

  Future<http.Response> delete(String path, {Map<String, String>? headers}) => 
      request('DELETE', path, headers: headers);
}
