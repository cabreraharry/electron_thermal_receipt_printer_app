import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'bluetooth_service.dart';
import 'betting_api_service.dart';

class BettingTicketPrinter {
  static final BettingTicketPrinter _instance = BettingTicketPrinter._internal();
  factory BettingTicketPrinter() => _instance;
  BettingTicketPrinter._internal();

  final BluetoothService _bluetoothService = BluetoothService();

  // Print a betting ticket
  Future<bool> printBettingTicket(BettingTicket ticket) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Initialize printer
      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);
      
      // Header
      bytes += generator.text('Ticket Receipt');
      bytes += generator.feed(1);
      bytes += generator.text('ID: ${ticket.id}');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Event Details
      bytes += generator.text('Event: ${ticket.event} (Schedule #${ticket.scheduleNumber})');
      bytes += generator.feed(1);
      bytes += generator.text('Draw Time: ${ticket.drawTime}');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Bet Details
      bytes += generator.text('Bet Details:');
      bytes += generator.feed(1);
      bytes += generator.text('${ticket.betType}: \$${ticket.betAmount.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('Selections: ${ticket.selections}');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Financial Summary
      bytes += generator.text('Gross Amount: \$${ticket.grossAmount.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('TAX: \$${ticket.tax.toStringAsFixed(2)}');
      bytes += generator.feed(1);
      bytes += generator.text('Net Amount: \$${ticket.netAmount.toStringAsFixed(2)}');
      bytes += generator.feed(2);

      // Footer
      bytes += generator.text('Thank you for betting!');
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
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

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Test betting ticket print error: $e');
      return false;
    }
  }
}
