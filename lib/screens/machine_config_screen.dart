import 'package:flutter/material.dart';
import '../services/betting_api_service.dart';

class MachineConfigScreen extends StatefulWidget {
  const MachineConfigScreen({super.key});

  @override
  State<MachineConfigScreen> createState() => _MachineConfigScreenState();
}

class _MachineConfigScreenState extends State<MachineConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _machineIdController = TextEditingController();
  
  final BettingApiService _apiService = BettingApiService();
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _machineIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await _apiService.loadMachineConfig();
    setState(() {
      _nameController.text = config['name'] ?? '';
      _baseUrlController.text = config['baseUrl'] ?? 'https://api.win67game.com/api';
      _machineIdController.text = config['machineId'] ?? '';
    });
  }

  Future<void> _testConnection() async {
    if (_baseUrlController.text.isEmpty) {
      _showSnackBar('Please enter a base URL');
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      // Temporarily set the endpoint for testing
      _apiService.setMachineEndpoint(_baseUrlController.text.trim(), _machineIdController.text.trim().isEmpty ? null : _machineIdController.text.trim());
      
      final isConnected = await _apiService.testConnection();
      setState(() {
        _connectionStatus = isConnected ? 'Connected successfully!' : 'Connection failed';
      });
      
      _showSnackBar(_connectionStatus!);
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection test failed: $e';
      });
      _showSnackBar(_connectionStatus!);
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.saveMachineConfig(
        _nameController.text.trim(),
        _baseUrlController.text.trim(),
        _machineIdController.text.trim().isEmpty ? null : _machineIdController.text.trim(),
      );

      // Update the current endpoint
      _apiService.setMachineEndpoint(
        _baseUrlController.text.trim(),
        _machineIdController.text.trim().isEmpty ? null : _machineIdController.text.trim(),
      );

      _showSnackBar('Machine configuration saved successfully!');
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate config was saved
      }
    } catch (e) {
      _showSnackBar('Failed to save configuration: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Betting Machine Setup',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configure your betting machine connection settings',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Machine Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Machine Name',
                  hintText: 'e.g., Main Betting Terminal',
                  prefixIcon: Icon(Icons.casino),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a machine name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Base URL
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.win67game.com/api',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the API base URL';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Machine ID (Optional)
              TextFormField(
                controller: _machineIdController,
                decoration: const InputDecoration(
                  labelText: 'Machine ID (Optional)',
                  hintText: 'Unique identifier for this machine',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Connection Test
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (_connectionStatus != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _connectionStatus!.contains('successfully')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _connectionStatus!.contains('successfully')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _connectionStatus!.contains('successfully')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _connectionStatus!.contains('successfully')
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            color: _connectionStatus!.contains('successfully')
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveConfiguration,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Configuration'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info Card
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Configuration Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Test the connection before saving\n'
                        '• Machine ID is optional but recommended for multi-machine setups\n'
                        '• Make sure the API URL is accessible from your network\n'
                        '• Contact your betting system administrator for the correct endpoints',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
