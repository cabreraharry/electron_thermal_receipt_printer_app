import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;

class DeviceListTile extends StatelessWidget {
  final blue_plus.BluetoothDevice device;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback onDisconnect;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected 
              ? Colors.green 
              : isSelected 
                  ? Colors.blue 
                  : Colors.grey,
          child: Icon(
            isConnected ? Icons.check : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.remoteId.toString()),
            if (device.isConnected)
              const Text(
                'Connected',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: isConnected
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: onDisconnect,
                tooltip: 'Disconnect',
              )
            : isSelected
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
        onTap: isConnected ? null : onTap,
        selected: isSelected,
      ),
    );
  }
}
