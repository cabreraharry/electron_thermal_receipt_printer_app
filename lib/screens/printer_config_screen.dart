import 'package:flutter/material.dart';
import '../services/printer_config_service.dart';

class PrinterConfigScreen extends StatefulWidget {
  const PrinterConfigScreen({super.key});

  @override
  State<PrinterConfigScreen> createState() => _PrinterConfigScreenState();
}

class _PrinterConfigScreenState extends State<PrinterConfigScreen> {
  final PrinterConfigService _configService = PrinterConfigService();
  List<PrinterConfig> _configs = [];
  PrinterConfig? _activeConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  Future<void> _loadConfigurations() async {
    await _configService.loadConfigurations();
    setState(() {
      _configs = _configService.configs;
      _activeConfig = _configService.activeConfig;
      _isLoading = false;
    });
  }

  Future<void> _setActiveConfig(PrinterConfig config) async {
    await _configService.setActiveConfig(config.name);
    setState(() {
      _activeConfig = config;
    });
    _showSnackBar('Active printer configuration changed to ${config.name}');
  }

  Future<void> _addNewConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPrinterConfigScreen(),
      ),
    );

    if (result == true) {
      await _loadConfigurations();
    }
  }

  Future<void> _editConfig(PrinterConfig config) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPrinterConfigScreen(editConfig: config),
      ),
    );

    if (result == true) {
      await _loadConfigurations();
    }
  }

  Future<void> _deleteConfig(PrinterConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text('Are you sure you want to delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _configService.removeConfig(config.name);
      await _loadConfigurations();
      _showSnackBar('Configuration deleted');
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
        title: const Text('Printer Configurations'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Active Configuration Card
                if (_activeConfig != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.print,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Configuration',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _activeConfig!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Type: ${_activeConfig!.type.toString().split('.').last} | '
                            'Format: ${_activeConfig!.format.toString().split('.').last}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Configurations List
                Expanded(
                  child: _configs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.print_disabled,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No printer configurations found',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add a new configuration to get started',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _configs.length,
                          itemBuilder: (context, index) {
                            final config = _configs[index];
                            final isActive = _activeConfig?.name == config.name;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isActive ? Theme.of(context).primaryColor : Colors.grey,
                                ),
                                title: Text(config.name),
                                subtitle: Text(
                                  'Type: ${config.type.toString().split('.').last} | '
                                  'Format: ${config.format.toString().split('.').last}',
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'activate',
                                      child: const Text('Set as Active'),
                                      enabled: !isActive,
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: const Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'activate':
                                        _setActiveConfig(config);
                                        break;
                                      case 'edit':
                                        _editConfig(config);
                                        break;
                                      case 'delete':
                                        _deleteConfig(config);
                                        break;
                                    }
                                  },
                                ),
                                onTap: () => _setActiveConfig(config),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewConfig,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddPrinterConfigScreen extends StatefulWidget {
  final PrinterConfig? editConfig;

  const AddPrinterConfigScreen({super.key, this.editConfig});

  @override
  State<AddPrinterConfigScreen> createState() => _AddPrinterConfigScreenState();
}

class _AddPrinterConfigScreenState extends State<AddPrinterConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final PrinterConfigService _configService = PrinterConfigService();

  PrinterType _selectedType = PrinterType.thermal80mm;
  TicketFormat _selectedFormat = TicketFormat.standard;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.editConfig != null) {
      _nameController.text = widget.editConfig!.name;
      _selectedType = widget.editConfig!.type;
      _selectedFormat = widget.editConfig!.format;
      _isDefault = widget.editConfig!.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = PrinterConfig(
      name: _nameController.text.trim(),
      type: _selectedType,
      format: _selectedFormat,
      isDefault: _isDefault,
    );

    if (widget.editConfig != null) {
      await _configService.updateConfig(widget.editConfig!.name, config);
    } else {
      await _configService.addConfig(config);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editConfig != null ? 'Edit Configuration' : 'Add Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Configuration Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Printer Type
              Text(
                'Printer Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrinterType>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedType,
                items: PrinterType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Ticket Format
              Text(
                'Ticket Format',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TicketFormat>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedFormat,
                items: TicketFormat.values.map((format) {
                  return DropdownMenuItem(
                    value: format,
                    child: Text(format.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFormat = value!;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Default checkbox
              CheckboxListTile(
                title: const Text('Set as Default'),
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value ?? false;
                  });
                },
              ),

              const Spacer(),

              // Save button
              ElevatedButton(
                onPressed: _saveConfig,
                child: Text(widget.editConfig != null ? 'Update Configuration' : 'Add Configuration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
