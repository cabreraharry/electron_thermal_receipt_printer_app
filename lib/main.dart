import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ThermalPrinterApp());
}

class ThermalPrinterApp extends StatelessWidget {
  const ThermalPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermal Printer App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
