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

  Future<void> _openPrinterConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterConfigScreen()),
    );
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

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : Colors.grey,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? color : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Betting Terminal'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.casino),
              onPressed: _openMachineConfig,
              tooltip: 'Machine Configuration',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _openPrinterConfig,
              tooltip: 'Printer Configuration',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: _loadTodaysTickets,
              tooltip: 'Refresh Tickets',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, left: 4),
            child: IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: _logout,
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.print_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                              'Machine Status',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              _currentMachineName ?? 'Not configured',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Status Indicators
                      Row(
                        children: [
                          // Bluetooth Status
                          Expanded(
                            child: _buildStatusChip(
                              icon: _isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                              label: _isBluetoothEnabled ? 'Bluetooth' : 'BT Disabled',
                              color: _isBluetoothEnabled ? Colors.blue : Colors.grey,
                              isActive: _isBluetoothEnabled,
                            ),
                          ),
                          
                          if (_selectedDevice != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatusChip(
                                icon: _isConnected ? Icons.print : Icons.print_disabled,
                                label: _isConnected ? 'Connected' : 'Disconnected',
                                color: _isConnected ? Colors.green : Colors.red,
                                isActive: _isConnected,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
              const SizedBox(height: 20),
              
              // Bluetooth Controls Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bluetooth_outlined,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Printer Connection',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Connect to thermal printer',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isBluetoothEnabled ? null : _enableBluetooth,
                              icon: const Icon(Icons.bluetooth, size: 18),
                              label: const Text('Enable BT'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isBluetoothEnabled ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isBluetoothEnabled && !_isScanning ? _startScanning : null,
                              icon: _isScanning 
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.search, size: 18),
                              label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
              const SizedBox(height: 20),
              
              // Device List Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.devices_outlined,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Devices',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Select thermal printer',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: _devices.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isScanning ? Icons.search : Icons.bluetooth_disabled,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _isScanning 
                                            ? 'Scanning for devices...'
                                            : 'No devices found',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (!_isScanning) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap "Scan Devices" to search',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
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
                    ],
                  ),
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
              const SizedBox(height: 20),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.purple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Betting Tickets',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_todaysTickets.length} tickets available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _todaysTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _todaysTickets[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.casino,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Ticket ${ticket.id}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('${ticket.event} - \$${ticket.netAmount.toStringAsFixed(2)}'),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.print, color: Colors.white),
                                    onPressed: () => _printSingleTicket(ticket),
                                    tooltip: 'Print this betting ticket',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
