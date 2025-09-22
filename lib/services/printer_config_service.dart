import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType {
  thermal80mm,
  thermal58mm,
  dotMatrix,
  inkjet,
}

enum TicketFormat {
  standard,
  compact,
  detailed,
  custom,
}

class PrinterConfig {
  final String name;
  final PrinterType type;
  final TicketFormat format;
  final Map<String, dynamic> customSettings;
  final bool isDefault;

  PrinterConfig({
    required this.name,
    required this.type,
    required this.format,
    this.customSettings = const {},
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'format': format.toString().split('.').last,
      'customSettings': customSettings,
      'isDefault': isDefault,
    };
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      name: json['name'] ?? '',
      type: PrinterType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => PrinterType.thermal80mm,
      ),
      format: TicketFormat.values.firstWhere(
        (e) => e.toString().split('.').last == json['format'],
        orElse: () => TicketFormat.standard,
      ),
      customSettings: Map<String, dynamic>.from(json['customSettings'] ?? {}),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class PrinterConfigService {
  static final PrinterConfigService _instance = PrinterConfigService._internal();
  factory PrinterConfigService() => _instance;
  PrinterConfigService._internal();

  List<PrinterConfig> _configs = [];
  PrinterConfig? _activeConfig;

  // Get all printer configurations
  List<PrinterConfig> get configs => _configs;
  PrinterConfig? get activeConfig => _activeConfig;

  // Load configurations from storage
  Future<void> loadConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getString('printer_configs');
      
      if (configsJson != null) {
        final List<dynamic> configsList = jsonDecode(configsJson);
        _configs = configsList.map((config) => PrinterConfig.fromJson(config)).toList();
        
        // Load active config
        final activeConfigName = prefs.getString('active_printer_config');
        if (activeConfigName != null) {
          _activeConfig = _configs.firstWhere(
            (config) => config.name == activeConfigName,
            orElse: () => _configs.isNotEmpty ? _configs.first : _getDefaultConfig(),
          );
        } else if (_configs.isNotEmpty) {
          _activeConfig = _configs.first;
        } else {
          _activeConfig = _getDefaultConfig();
        }
      } else {
        // Initialize with default configs
        _initializeDefaultConfigs();
      }
    } catch (e) {
      print('Error loading printer configurations: $e');
      _initializeDefaultConfigs();
    }
  }

  // Save configurations to storage
  Future<void> saveConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = jsonEncode(_configs.map((config) => config.toJson()).toList());
      await prefs.setString('printer_configs', configsJson);
      
      if (_activeConfig != null) {
        await prefs.setString('active_printer_config', _activeConfig!.name);
      }
    } catch (e) {
      print('Error saving printer configurations: $e');
    }
  }

  // Add a new printer configuration
  Future<void> addConfig(PrinterConfig config) async {
    _configs.add(config);
    await saveConfigurations();
  }

  // Update an existing printer configuration
  Future<void> updateConfig(String name, PrinterConfig config) async {
    final index = _configs.indexWhere((c) => c.name == name);
    if (index != -1) {
      _configs[index] = config;
      await saveConfigurations();
    }
  }

  // Remove a printer configuration
  Future<void> removeConfig(String name) async {
    _configs.removeWhere((config) => config.name == name);
    if (_activeConfig?.name == name) {
      _activeConfig = _configs.isNotEmpty ? _configs.first : _getDefaultConfig();
    }
    await saveConfigurations();
  }

  // Set active printer configuration
  Future<void> setActiveConfig(String name) async {
    final config = _configs.firstWhere(
      (config) => config.name == name,
      orElse: () => _getDefaultConfig(),
    );
    _activeConfig = config;
    await saveConfigurations();
  }

  // Get printer settings for a specific type
  Map<String, dynamic> getPrinterSettings(PrinterType type) {
    switch (type) {
      case PrinterType.thermal80mm:
        return {
          'paperSize': '80mm',
          'maxWidth': 48,
          'fontSize': 'normal',
          'lineSpacing': 1,
        };
      case PrinterType.thermal58mm:
        return {
          'paperSize': '58mm',
          'maxWidth': 32,
          'fontSize': 'small',
          'lineSpacing': 1,
        };
      case PrinterType.dotMatrix:
        return {
          'paperSize': '80mm',
          'maxWidth': 80,
          'fontSize': 'normal',
          'lineSpacing': 1,
        };
      case PrinterType.inkjet:
        return {
          'paperSize': 'A4',
          'maxWidth': 80,
          'fontSize': 'normal',
          'lineSpacing': 1,
        };
    }
  }

  // Get ticket format settings
  Map<String, dynamic> getTicketFormatSettings(TicketFormat format) {
    switch (format) {
      case TicketFormat.standard:
        return {
          'showHeader': true,
          'showEventDetails': true,
          'showBetDetails': true,
          'showFinancialSummary': true,
          'showFooter': true,
          'showTimestamp': true,
        };
      case TicketFormat.compact:
        return {
          'showHeader': true,
          'showEventDetails': false,
          'showBetDetails': true,
          'showFinancialSummary': true,
          'showFooter': false,
          'showTimestamp': false,
        };
      case TicketFormat.detailed:
        return {
          'showHeader': true,
          'showEventDetails': true,
          'showBetDetails': true,
          'showFinancialSummary': true,
          'showFooter': true,
          'showTimestamp': true,
          'showMachineInfo': true,
          'showBarcode': true,
        };
      case TicketFormat.custom:
        return {
          'showHeader': true,
          'showEventDetails': true,
          'showBetDetails': true,
          'showFinancialSummary': true,
          'showFooter': true,
          'showTimestamp': true,
        };
    }
  }

  // Initialize default configurations
  void _initializeDefaultConfigs() {
    _configs = [
      PrinterConfig(
        name: 'Standard Thermal 80mm',
        type: PrinterType.thermal80mm,
        format: TicketFormat.standard,
        isDefault: true,
      ),
      PrinterConfig(
        name: 'Compact Thermal 58mm',
        type: PrinterType.thermal58mm,
        format: TicketFormat.compact,
      ),
      PrinterConfig(
        name: 'Detailed Thermal 80mm',
        type: PrinterType.thermal80mm,
        format: TicketFormat.detailed,
      ),
    ];
    _activeConfig = _configs.first;
  }

  // Get default configuration
  PrinterConfig _getDefaultConfig() {
    return PrinterConfig(
      name: 'Default',
      type: PrinterType.thermal80mm,
      format: TicketFormat.standard,
      isDefault: true,
    );
  }
}
