import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/betting_ticket_printer.dart';
import '../services/betting_api_service.dart';
import '../widgets/device_list_tile.dart';
import 'betting_login_screen.dart';
import 'machine_config_screen.dart';
import 'printer_config_screen.dart';

class BettingHomeScreen extends StatefulWidget {
  const BettingHomeScreen({super.key});

  @override
  State<BettingHomeScreen> createState() => _BettingHomeScreenState();
}

class _BettingHomeScreenState extends State<BettingHomeScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final BettingTicketPrinter _ticketPrinter = BettingTicketPrinter();
  final BettingApiService _apiService = BettingApiService();
  
  List<blue_plus.BluetoothDevice> _devices = [];
  blue_plus.BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isBluetoothEnabled = false;
  
  // Betting ticket state
  List<BettingTicket> _todaysTickets = [];
  List<BettingTicket> _pendingTickets = [];
  bool _isLoadingTickets = false;
  bool _isLoadingPendingTickets = false;
  
  // Machine status
  Map<String, dynamic>? _machineStatus;
  bool _isLoadingMachineStatus = false;
  String? _currentMachineName;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
    _loadBondedDevices();
    _loadMachineConfig();
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

  Future<void> _loadMachineConfig() async {
    final config = await _apiService.loadMachineConfig();
    setState(() {
      _currentMachineName = config['name'];
    });
    
    // Set the endpoint if config exists
    if (config['baseUrl'] != null) {
      _apiService.setMachineEndpoint(
        config['baseUrl']!,
        config['machineId'],
      );
    }
  }

  Future<void> _openMachineConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MachineConfigScreen()),
    );
    
    if (result == true) {
      // Config was saved, reload it
      await _loadMachineConfig();
      _showSnackBar('Machine configuration updated');
    }
  }

  Future<void> _openPrinterConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterConfigScreen()),
    );
  }

  Future<void> _checkMachineStatus() async {
    setState(() {
      _isLoadingMachineStatus = true;
    });

    try {
      final status = await _apiService.getMachineStatus();
      setState(() {
        _machineStatus = status;
      });
      
      if (status != null) {
        _showSnackBar('Machine status updated');
      } else {
        _showSnackBar('Failed to get machine status');
      }
    } catch (e) {
      _showSnackBar('Error checking machine status: $e');
    } finally {
      setState(() {
        _isLoadingMachineStatus = false;
      });
    }
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

  Future<void> _printTestTicket() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final success = await _ticketPrinter.printTestBettingTicket();
    if (success) {
      _showSnackBar('Test betting ticket sent to printer');
    } else {
      _showSnackBar('Failed to send test ticket');
    }
  }

  Future<void> _loadTodaysTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });

    try {
      final tickets = await _apiService.getTodaysTickets();
      setState(() {
        _todaysTickets = tickets;
      });
    } catch (e) {
      _showSnackBar('Failed to load tickets: $e');
    } finally {
      setState(() {
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _loadPendingTickets() async {
    setState(() {
      _isLoadingPendingTickets = true;
    });

    try {
      final tickets = await _apiService.getPendingTickets();
      setState(() {
        _pendingTickets = tickets;
      });
      
      if (tickets.isNotEmpty) {
        _showSnackBar('Found ${tickets.length} pending tickets');
      } else {
        _showSnackBar('No pending tickets found');
      }
    } catch (e) {
      _showSnackBar('Failed to load pending tickets: $e');
    } finally {
      setState(() {
        _isLoadingPendingTickets = false;
      });
    }
  }

  Future<void> _printAllPendingTickets() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    if (_pendingTickets.isEmpty) {
      await _loadPendingTickets();
      if (_pendingTickets.isEmpty) {
        _showSnackBar('No pending tickets to print');
        return;
      }
    }

    _showSnackBar('Printing ${_pendingTickets.length} pending tickets...');
    
    int successCount = 0;
    for (BettingTicket ticket in _pendingTickets) {
      final success = await _ticketPrinter.printBettingTicket(ticket);
      if (success) {
        successCount++;
      }
      
      // Small delay between tickets
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    _showSnackBar('Successfully printed $successCount of ${_pendingTickets.length} tickets');
    
    // Reload pending tickets to see updated list
    await _loadPendingTickets();
  }

  Future<void> _printAllTickets() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    if (_todaysTickets.isEmpty) {
      _showSnackBar('No tickets to print');
      return;
    }

    final success = await _ticketPrinter.printBettingTickets(_todaysTickets);
    if (success) {
      _showSnackBar('All betting tickets sent to printer');
    } else {
      _showSnackBar('Failed to print some tickets');
    }
  }

  Future<void> _printSingleTicket(BettingTicket ticket) async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a printer first');
      return;
    }

    final success = await _ticketPrinter.printBettingTicket(ticket);
    if (success) {
      _showSnackBar('Betting ticket sent to printer');
    } else {
      _showSnackBar('Failed to send ticket');
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BettingLoginScreen()),
      );
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
        title: const Text('Betting Ticket Printer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openMachineConfig,
            tooltip: 'Machine Configuration',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _openPrinterConfig,
            tooltip: 'Printer Configuration',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodaysTickets,
            tooltip: 'Refresh Tickets',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Machine Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Machine Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: _openMachineConfig,
                          tooltip: 'Configure Machine',
                        ),
                        IconButton(
                          icon: _isLoadingMachineStatus 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          onPressed: _isLoadingMachineStatus ? null : _checkMachineStatus,
                          tooltip: 'Check Machine Status',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_currentMachineName != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.casino,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentMachineName!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
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
                    if (_machineStatus != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Machine Online',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
            
            // Betting Ticket Controls
            if (_isConnected) ...[
              Text(
                'Betting Ticket Printing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              
              // Load tickets buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingTickets ? null : _loadTodaysTickets,
                      icon: _isLoadingTickets 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isLoadingTickets ? 'Loading...' : 'Load Today\'s Tickets'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingPendingTickets ? null : _loadPendingTickets,
                      icon: _isLoadingPendingTickets 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.pending_actions),
                      label: Text(_isLoadingPendingTickets ? 'Loading...' : 'Load Pending'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Print all tickets buttons
              if (_todaysTickets.isNotEmpty || _pendingTickets.isNotEmpty) ...[
                Row(
                  children: [
                    if (_todaysTickets.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printAllTickets,
                          icon: const Icon(Icons.print),
                          label: Text('Print Today\'s (${_todaysTickets.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_pendingTickets.isNotEmpty) const SizedBox(width: 8),
                    ],
                    if (_pendingTickets.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printAllPendingTickets,
                          icon: const Icon(Icons.print_outlined),
                          label: Text('Print Pending (${_pendingTickets.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Test print button
              ElevatedButton.icon(
                onPressed: _printTestTicket,
                icon: const Icon(Icons.bug_report),
                label: const Text('Test Betting Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            
            // Tickets List
            if (_todaysTickets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Today\'s Betting Tickets (${_todaysTickets.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _todaysTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _todaysTickets[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.casino),
                        title: Text('Ticket ${ticket.id}'),
                        subtitle: Text('${ticket.event} - \$${ticket.netAmount.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.print),
                          onPressed: () => _printSingleTicket(ticket),
                          tooltip: 'Print this betting ticket',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
