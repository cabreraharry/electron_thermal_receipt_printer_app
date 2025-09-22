import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BettingApiService {
  static final BettingApiService _instance = BettingApiService._internal();
  factory BettingApiService() => _instance;
  BettingApiService._internal();

  // Update this with your actual API URL
  static const String baseUrl = 'https://api.win67game.com/api';
  String? _token;

  // Login and get token
  Future<bool> login(String email, String password) async {
    try {
      print('Attempting login to: $baseUrl/login');
      print('Email: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        
        // Save token to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        
        return true;
      } else {
        print('Login failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Get today's betting tickets
  Future<List<BettingTicket>> getTodaysTickets() async {
    try {
      if (_token == null) {
        // Try to load token from storage
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');
      }

      if (_token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/tickets/today'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data as List).map((ticket) => BettingTicket.fromJson(ticket)).toList();
      }
      throw Exception('Failed to fetch tickets: ${response.statusCode}');
    } catch (e) {
      print('Get tickets error: $e');
      return [];
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    if (_token != null) return true;
    
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token != null;
  }
}

class BettingTicket {
  final String id;
  final String event;
  final String eventType;
  final String scheduleNumber;
  final String drawTime;
  final String betType;
  final double betAmount;
  final String selections;
  final double grossAmount;
  final double tax;
  final double netAmount;

  BettingTicket({
    required this.id,
    required this.event,
    required this.eventType,
    required this.scheduleNumber,
    required this.drawTime,
    required this.betType,
    required this.betAmount,
    required this.selections,
    required this.grossAmount,
    required this.tax,
    required this.netAmount,
  });

  factory BettingTicket.fromJson(Map<String, dynamic> json) {
    return BettingTicket(
      id: json['id'] ?? '',
      event: json['event'] ?? '',
      eventType: json['eventType'] ?? '',
      scheduleNumber: json['scheduleNumber'] ?? '',
      drawTime: json['drawTime'] ?? '',
      betType: json['betType'] ?? '',
      betAmount: (json['betAmount'] ?? 0.0).toDouble(),
      selections: json['selections'] ?? '',
      grossAmount: (json['grossAmount'] ?? 0.0).toDouble(),
      tax: (json['tax'] ?? 0.0).toDouble(),
      netAmount: (json['netAmount'] ?? 0.0).toDouble(),
    );
  }
}
