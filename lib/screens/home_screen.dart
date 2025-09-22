import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/thermal_printer_service.dart';
import '../widgets/device_list_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final ThermalPrinterService _printerService = ThermalPrinterService();
  
  List<blue_plus.BluetoothDevice> _devices = [];
  blue_plus.BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isBluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
    _loadBondedDevices();
  }

  Future<void> _checkBluetoothStatus() async {
    final isEnabled = await _bluetoothService.isBluetoothAvailable();
    setState(() {
      _isBluetoothEnabled = isEnabled;
    });
  }

  Future<void> _loadBondedDevices() async {
    final devices = await _bluetoothService.getBondedDevices();
    setState(() {
      _devices = devices;
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
  }

  Future<void> _enableBluetooth() async {
    await _requestPermissions();
    final enabled = await _bluetoothService.enableBluetooth();
    if (enabled) {
      setState(() {
        _isBluetoothEnabled = true;
      });
      _loadBondedDevices();
    }
  }

  Future<void> _startScanning() async {
    if (!_isBluetoothEnabled) {
      await _enableBluetooth();
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _bluetoothService.startDiscovery().listen((results) {
      setState(() {
        _devices = results;
      });
    });

    // Stop scanning after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      _bluetoothService.stopDiscovery();
      setState(() {
        _isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(blue_plus.BluetoothDevice device) async {
    setState(() {
      _selectedDevice = device;
    });

    final connected = await _bluetoothService.connectToDevice(device);
    setState(() {
      _isConnected = connected;
    });

    if (connected) {
      _showSnackBar('Connected to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString()}');
    } else {
      _showSnackBar('Failed to connect to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString()}');
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    setState(() {
      _isConnected = false;
      _selectedDevice = null;
    });
    _showSnackBar('Disconnected');
  }

  Future<void> _printTestPage() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final success = await _printerService.printTestPage();
    if (success) {
      _showSnackBar('Test page sent to printer');
    } else {
      _showSnackBar('Failed to send test page');
    }
  }

  Future<void> _printSampleReceipt() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final success = await _printerService.printTextReceipt(
      title: 'SAMPLE RECEIPT',
      items: [
        'Item 1 - \$10.00',
        'Item 2 - \$15.50',
        'Item 3 - \$8.75',
      ],
      total: 34.25,
      footer: 'Thank you for your business!',
    );

    if (success) {
      _showSnackBar('Receipt sent to printer');
    } else {
      _showSnackBar('Failed to send receipt');
    }
  }

  Future<void> _printCustomText() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Custom Text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter text to print...',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Print'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _printerService.printCustomReceipt(result);
      if (success) {
        _showSnackBar('Custom text sent to printer');
      } else {
        _showSnackBar('Failed to send custom text');
      }
    }
  }

  Future<void> _printSimpleText() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final success = await _printerService.printSimpleText('Hello from Flutter!\nThis is a simple test.');
    if (success) {
      _showSnackBar('Simple text sent to printer');
    } else {
      _showSnackBar('Failed to send simple text');
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
        title: const Text('Thermal Printer App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                          color: _isBluetoothEnabled ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isBluetoothEnabled ? 'Bluetooth Enabled' : 'Bluetooth Disabled',
                          style: TextStyle(
                            color: _isBluetoothEnabled ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedDevice != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isConnected ? Icons.check_circle : Icons.cancel,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                        Text(
                          _isConnected 
                              ? 'Connected to ${_selectedDevice!.platformName.isNotEmpty ? _selectedDevice!.platformName : _selectedDevice!.remoteId.toString()}'
                              : 'Disconnected',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bluetooth Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBluetoothEnabled ? null : _enableBluetooth,
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Enable Bluetooth'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBluetoothEnabled && !_isScanning ? _startScanning : null,
                    icon: _isScanning 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Device List
            Text(
              'Available Devices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Text(
                        _isScanning 
                            ? 'Scanning for devices...'
                            : 'No devices found. Tap "Scan Devices" to search.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = _selectedDevice?.remoteId == device.remoteId;
                        final isConnected = isSelected && _isConnected;
                        
                        return DeviceListTile(
                          device: device,
                          isSelected: isSelected,
                          isConnected: isConnected,
                          onTap: () => _connectToDevice(device),
                          onDisconnect: _disconnect,
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Print Controls
            if (_isConnected) ...[
              Text(
                'Print Options',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printTestPage,
                      icon: const Icon(Icons.print),
                      label: const Text('Test Page'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printSampleReceipt,
                      icon: const Icon(Icons.receipt),
                      label: const Text('Sample Receipt'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printSimpleText,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Simple Text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printCustomText,
                      icon: const Icon(Icons.edit),
                      label: const Text('Custom Text'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
