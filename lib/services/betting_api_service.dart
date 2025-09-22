import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BettingApiService {
  static final BettingApiService _instance = BettingApiService._internal();
  factory BettingApiService() => _instance;
  BettingApiService._internal();


  String _baseUrl = 'https://win67game.com/lottery';
  String? _token;
  String? _currentMachineId;

  void setMachineEndpoint(String baseUrl, String? machineId) {
    _baseUrl = baseUrl;
    _currentMachineId = machineId;
  }

  // Get current machine info
  String get currentBaseUrl => _baseUrl;
  String? get currentMachineId => _currentMachineId;

  // Login and get token
  Future<bool> login(String email, String password) async {
    try {
      print('Attempting login to: $_baseUrl/login');
      print('Email: $email');
      print('Machine ID: $_currentMachineId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
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

  // Get all pending betting tickets that need to be printed
  Future<List<BettingTicket>> getPendingTickets() async {
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
        Uri.parse('$_baseUrl/tickets/pending'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data as List).map((ticket) => BettingTicket.fromJson(ticket)).toList();
      }
      throw Exception('Failed to fetch pending tickets: ${response.statusCode}');
    } catch (e) {
      print('Get pending tickets error: $e');
      return [];
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
        Uri.parse('$_baseUrl/tickets/today'),
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

  // Test machine connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Get machine status
  Future<Map<String, dynamic>?> getMachineStatus() async {
    try {
      if (_token == null) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');
      }

      if (_token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get machine status error: $e');
      return null;
    }
  }

  // Save machine configuration
  Future<void> saveMachineConfig(String name, String baseUrl, String? machineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('machine_name', name);
    await prefs.setString('machine_base_url', baseUrl);
    if (machineId != null) {
      await prefs.setString('machine_id', machineId);
    }
  }

  // Load machine configuration
  Future<Map<String, String?>> loadMachineConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('machine_name'),
      'baseUrl': prefs.getString('machine_base_url'),
      'machineId': prefs.getString('machine_id'),
    };
  }

  // Mark ticket as printed
  Future<bool> markTicketAsPrinted(String ticketId) async {
    try {
      if (_token == null) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');
      }

      if (_token == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/tickets/$ticketId/printed'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'printed_at': DateTime.now().toIso8601String(),
          'machine_id': _currentMachineId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Mark ticket as printed error: $e');
      return false;
    }
  }

  // Get specific ticket by ID
  Future<BettingTicket?> getTicketById(String ticketId) async {
    try {
      if (_token == null) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');
      }

      if (_token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/tickets/$ticketId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BettingTicket.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get ticket by ID error: $e');
      return null;
    }
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
