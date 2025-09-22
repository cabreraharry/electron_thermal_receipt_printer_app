import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'bluetooth_service.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  final BluetoothService _bluetoothService = BluetoothService();

  // Print a simple text receipt
  Future<bool> printTextReceipt({
    required String title,
    required List<String> items,
    required double total,
    String? footer,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Initialize printer with minimal commands
      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      
      // Title
      bytes += generator.text(title);
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Add items
      for (String item in items) {
        bytes += generator.text(item);
        bytes += generator.feed(1);
      }

      bytes += generator.hr();
      bytes += generator.feed(1);
      
      // Add total
      bytes += generator.text('Total: \$${total.toStringAsFixed(2)}');
      bytes += generator.feed(1);

      // Add footer if provided
      if (footer != null) {
        bytes += generator.feed(1);
        bytes += generator.text(footer);
      }

      // Cut paper
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send to printer in chunks
      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Print error: $e');
      return false;
    }
  }

  // Print a test page
  Future<bool> printTestPage() async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      
      // Simple test content
      bytes += generator.text('THERMAL PRINTER TEST');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Hello World!');
      bytes += generator.feed(1);
      bytes += generator.text('Test successful!');
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Test print error: $e');
      return false;
    }
  }

  // Print a simple receipt with custom content
  Future<bool> printCustomReceipt(String content) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      bytes += generator.text(content);
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Custom print error: $e');
      return false;
    }
  }

  // Print simple text without ESC/POS commands (most compatible)
  Future<bool> printSimpleText(String text) async {
    try {
      // Convert text to bytes and send directly
      List<int> bytes = text.codeUnits;
      bytes.add(10); // Add newline
      bytes.add(13); // Add carriage return
      
      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Simple print error: $e');
      return false;
    }
  }
}
