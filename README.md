# 📱 QR Generator - Flutter App

A comprehensive QR Code generator and scanner application built with Flutter, featuring dynamic themes and multiple QR code types.

## ✨ Features

### 🎨 **Dynamic Theme System**
- 10 beautiful color themes to choose from
- Dark/Light mode switching
- Theme persistence across app sessions
- Material Design 3 implementation

### 🔍 **QR Code Scanning**
- Real-time camera scanning
- Support for various QR code formats
- Instant result display

### 🎯 **QR Code Generation** 
- **Text QR**: Generate QR from any text
- **WiFi QR**: Share WiFi credentials (WPA/WEP/Open)
- **URL QR**: Generate QR for websites with auto-https
- **Contact QR**: Share contact information (vCard format)
- **Phone QR**: Quick dial phone numbers
- **SMS QR**: Pre-filled SMS messages
- **Email QR**: Email with subject and body
- **Location QR**: GPS coordinates and place names
- **Event QR**: Calendar events with date/time
- **Clipboard QR**: Generate from clipboard content

### 💫 **User Experience**
- Card-based Material Design UI
- Form validation and error handling
- Save QR codes to device gallery
- Share QR codes with other apps
- Consistent theming across all pages

## 🛠️ Tech Stack

- **Framework**: Flutter SDK
- **State Management**: Provider pattern
- **QR Generation**: pretty_qr_code package
- **QR Scanning**: mobile_scanner package
- **Theme Management**: Custom ThemeProvider with SharedPreferences
- **File Operations**: path_provider, share_plus, gal packages

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5
  shared_preferences: ^2.0.15
  mobile_scanner: ^3.2.0
  pretty_qr_code: ^2.0.2
  image_picker: ^0.8.7+4
  path_provider: ^2.0.14
  share_plus: ^6.3.4
  gal: ^2.1.2
```

## 🚀 Installation & Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/qr_generator.git
cd qr_generator
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
flutter run
```

## 📸 Screenshots

### Theme Selection
- Multiple color themes with dark/light mode support
- Settings page with color picker

### QR Generation
- Various QR types with form validation
- Beautiful QR code display with save/share options

### QR Scanning
- Real-time camera scanning
- Result display with action buttons

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── providers/
│   └── theme_provider.dart   # Theme management
└── pages/
    ├── home_with_navigation.dart  # Main navigation
    ├── qr_scan_page.dart         # QR Scanner
    ├── settings_page.dart        # Theme settings
    ├── qr_result_page.dart       # Scan results
    └── qr_code_page/
        ├── text_qr_page.dart     # Text QR generator
        ├── wifi_qr_page.dart     # WiFi QR generator
        ├── url_qr_page.dart      # URL QR generator
        ├── contact_qr_page.dart  # Contact QR generator
        ├── phone_qr_page.dart    # Phone QR generator
        ├── sms_qr_page.dart      # SMS QR generator
        ├── email_qr_page.dart    # Email QR generator
        ├── location_qr_page.dart # Location QR generator
        ├── event_qr_page.dart    # Event QR generator
        └── clipboard_qr_page.dart # Clipboard QR generator
```

## 🎯 Key Features Implementation

### Theme System
- Custom `ThemeProvider` class using ChangeNotifier
- 10 predefined color schemes with Material Design colors
- Persistent theme storage using SharedPreferences
- Theme switching with smooth animations

### QR Generation
- Form validation for each QR type
- Consistent UI patterns across all generators
- Error handling and user feedback
- Gallery saving and social sharing

### QR Scanning
- Camera permission handling
- Real-time scan detection
- Result processing and display

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Developer

Created during **Semester 7 Internship Program** - Week 1 Project

## 🔗 Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Pretty QR Code](https://pub.dev/packages/pretty_qr_code)
- [Mobile Scanner](https://pub.dev/packages/mobile_scanner)
