import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'bluetooth_service.dart';
import 'betting_api_service.dart';

class BettingTicketPrinter {
  static final BettingTicketPrinter _instance = BettingTicketPrinter._internal();
  factory BettingTicketPrinter() => _instance;
  BettingTicketPrinter._internal();

  final BluetoothService _bluetoothService = BluetoothService();
  final BettingApiService _apiService = BettingApiService();

  // Send data with retry logic
  Future<bool> _sendDataWithRetry(Uint8List data, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final success = await _bluetoothService.sendData(data);
        if (success) {
          return true;
        }
        
        if (attempt < maxRetries) {
          print('Print attempt $attempt failed, retrying...');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      } catch (e) {
        print('Print attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    
    print('All print attempts failed');
    return false;
  }

  // Print a betting ticket
  Future<bool> printBettingTicket(BettingTicket ticket) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Initialize printer
      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      
      // Header with better formatting
      bytes += generator.text('TICKET RECEIPT', styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(1);
      bytes += generator.text('ID: ${ticket.id}', styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Event Details with better formatting
      bytes += generator.text('Event: ${ticket.event}', styles: PosStyles(bold: true));
      bytes += generator.feed(1);
      bytes += generator.text('Schedule #${ticket.scheduleNumber}');
      bytes += generator.feed(1);
      bytes += generator.text('Draw Time: ${ticket.drawTime}');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Bet Details with better formatting
      bytes += generator.text('BET DETAILS:', styles: PosStyles(bold: true));
      bytes += generator.feed(1);
      bytes += generator.text('${ticket.betType}: \$${ticket.betAmount.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('Selections: ${ticket.selections}');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Financial Summary with better formatting
      bytes += generator.text('FINANCIAL SUMMARY:', styles: PosStyles(bold: true));
      bytes += generator.feed(1);
      bytes += generator.text('Gross Amount: \$${ticket.grossAmount.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('TAX: \$${ticket.tax.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('Net Amount: \$${ticket.netAmount.toStringAsFixed(2)}', 
          styles: PosStyles(bold: true, underline: true));
      bytes += generator.feed(2);

      // Footer with timestamp
      bytes += generator.text('Thank you for betting!', styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('Printed: ${DateTime.now().toString().substring(0, 19)}', 
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send data with retry logic
      final success = await _sendDataWithRetry(Uint8List.fromList(bytes));
      
      // Mark ticket as printed if successful
      if (success) {
        await _apiService.markTicketAsPrinted(ticket.id);
      }
      
      return success;
    } catch (e) {
      print('Print betting ticket error: $e');
      return false;
    }
  }

  // Print multiple betting tickets
  Future<bool> printBettingTickets(List<BettingTicket> tickets) async {
    bool allSuccess = true;
    
    for (BettingTicket ticket in tickets) {
      final success = await printBettingTicket(ticket);
      if (!success) allSuccess = false;
      
      // Small delay between tickets
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return allSuccess;
  }

  // Print a test betting ticket
  Future<bool> printTestBettingTicket() async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      
      // Test betting ticket content
      bytes += generator.text('TEST BETTING TICKET');
      bytes += generator.feed(1);
      bytes += generator.text('ID: TEST-001');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Event: Horse Racing (Schedule #92)');
      bytes += generator.feed(1);
      bytes += generator.text('Draw Time: 05:50 PM');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Bet Details:');
      bytes += generator.feed(1);
      bytes += generator.text('Win: \$10.20');
      bytes += generator.feed(1);
      bytes += generator.text('Selections: 1 Engineer');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Gross Amount: \$12.00');
      bytes += generator.feed(1);
      bytes += generator.text('TAX: \$1.80');
      bytes += generator.feed(1);
      bytes += generator.text('Net Amount: \$10.20');
      bytes += generator.feed(2);
      bytes += generator.text('Test successful!');
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _sendDataWithRetry(Uint8List.fromList(bytes));
    } catch (e) {
      print('Test betting ticket print error: $e');
      return false;
    }
  }
}
