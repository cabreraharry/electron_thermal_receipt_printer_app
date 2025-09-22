import 'package:flutter/material.dart';
import 'screens/betting_login_screen.dart';

void main() {
  runApp(const BettingTicketApp());
}

class BettingTicketApp extends StatelessWidget {
  const BettingTicketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Betting Ticket Printer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BettingLoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
