# Thermal Printer App

A Flutter application for connecting to thermal receipt printers via Bluetooth and printing receipts.

## Features

- **Bluetooth Connectivity**: Connect to thermal printers via Bluetooth
- **Device Discovery**: Scan and discover nearby Bluetooth devices
- **Print Options**: 
  - Test page printing
  - Sample receipt printing
  - Custom text printing
- **ESC/POS Support**: Full support for ESC/POS thermal printer commands
- **Modern UI**: Clean and intuitive user interface

## Supported Printers

This app works with thermal receipt printers that support:
- Bluetooth connectivity
- ESC/POS command set
- 80mm paper width (configurable)

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Make sure you have Flutter installed (version 3.0.0 or higher)
2. **Android Studio**: For Android development
3. **Physical Device**: Bluetooth functionality requires a physical device (not emulator)

### Installation

1. **Clone or download this project**

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### Permissions

The app requires the following permissions:
- Bluetooth
- Bluetooth Connect
- Bluetooth Scan
- Location (required for Bluetooth scanning on Android)

These permissions are automatically requested when you first run the app.

## Usage

### Connecting to a Printer

1. **Enable Bluetooth**: Tap "Enable Bluetooth" if not already enabled
2. **Scan for Devices**: Tap "Scan Devices" to discover nearby Bluetooth devices
3. **Select Printer**: Tap on your thermal printer from the device list
4. **Wait for Connection**: The app will attempt to connect to the selected printer

### Printing

Once connected, you can:

1. **Print Test Page**: Sends a comprehensive test page with various fonts, styles, and features
2. **Print Sample Receipt**: Prints a sample receipt with items and total
3. **Print Custom Text**: Enter custom text to print

### Troubleshooting

**Connection Issues**:
- Ensure the printer is powered on and in pairing mode
- Make sure the printer is within Bluetooth range
- Try restarting Bluetooth on your device
- Check if the printer is already paired in your device's Bluetooth settings

**Printing Issues**:
- Verify the printer is connected (green indicator)
- Check if the printer has paper
- Ensure the printer supports ESC/POS commands
- Try printing a test page first

## Technical Details

### Dependencies

- `flutter_bluetooth_serial`: Bluetooth connectivity
- `esc_pos_utils`: ESC/POS command generation
- `permission_handler`: Permission management
- `image`: Image processing for advanced printing

### Architecture

- **BluetoothService**: Handles all Bluetooth operations
- **ThermalPrinterService**: Manages printing operations and ESC/POS commands
- **HomeScreen**: Main UI with device management and print controls

### ESC/POS Commands

The app generates ESC/POS commands for:
- Text formatting (bold, underline, size)
- Alignment (left, center, right)
- Barcodes and QR codes
- Paper cutting
- Line feeds and spacing

## Customization

### Adding New Print Functions

To add custom print functions, extend the `ThermalPrinterService` class:

```dart
Future<bool> printCustomReceipt(CustomData data) async {
  // Generate ESC/POS commands
  // Send to printer via BluetoothService
}
```

### Modifying Printer Settings

Edit the `Generator` configuration in `ThermalPrinterService`:

```dart
final generator = Generator(
  PaperSize.mm80,  // Change paper size
  profile,         // Capability profile
);
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the Flutter Bluetooth Serial documentation
3. Open an issue on the project repository
