import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scan_code_page.dart';
import 'settings_page.dart';
import '../providers/theme_provider.dart';
// Import pages for QR code generation
import 'qr_code_page/text_qr_page.dart';
import 'qr_code_page/wifi_qr_page.dart';
import 'qr_code_page/clipboard_qr_page.dart';
import 'qr_code_page/url_qr_page.dart';
import 'qr_code_page/contact_qr_page.dart';
import 'qr_code_page/phone_qr_page.dart';
import 'qr_code_page/sms_qr_page.dart';
import 'qr_code_page/email_qr_page.dart';
import 'qr_code_page/location_qr_page.dart';
import 'qr_code_page/event_qr_page.dart';

class HomeWithNavigation extends StatefulWidget {
  final int initialIndex;
  
  const HomeWithNavigation({super.key, this.initialIndex = 1});

  @override
  State<HomeWithNavigation> createState() => _HomeWithNavigationState();
}

class _HomeWithNavigationState extends State<HomeWithNavigation> {
  late int _currentIndex;
  late PageController _pageController;

  final List<_QRItem> qrItems = [
    _QRItem(icon: Icons.text_fields, label: 'Text'),
    _QRItem(icon: Icons.wifi, label: 'Wifi'),
    _QRItem(icon: Icons.content_paste, label: 'Clipboard'),
    _QRItem(icon: Icons.link, label: 'URL'),
    _QRItem(icon: Icons.event, label: 'Event'),
    _QRItem(icon: Icons.location_pin, label: 'Location'),
    _QRItem(icon: Icons.sms, label: 'SMS'),
    _QRItem(icon: Icons.phone, label: 'Phone'),
    _QRItem(icon: Icons.person, label: 'Contact'),
    _QRItem(icon: Icons.email, label: 'Email'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildCreatePage() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            title: Text(
              'Create QR Code',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: qrItems.map((item) => QRCard(item: item)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanPage() {
    return const ScanCodePageContent(); // Content tanpa scaffold
  }

  Widget _buildSettingsPage() {
    return const SettingsPage();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              _buildScanPage(),
              _buildCreatePage(),
              _buildSettingsPage(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code),
                label: 'Create',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QRItem {
  final IconData icon;
  final String label;

  _QRItem({required this.icon, required this.label});
}

class QRCard extends StatelessWidget {
  final _QRItem item;

  const QRCard({Key? key, required this.item}) : super(key: key);

  // Function to determine which page to navigate to based on item label
  Widget _getPageForType(String label) {
    switch (label.toLowerCase()) {
      case 'text':
        return const TextQRPage();
      case 'wifi':
        return const WiFiQRPage();
      case 'url':
        return const URLQRPage();
      case 'contact':
        return const ContactQRPage();
      case 'sms':
        return const SMSQRPage();
      case 'phone':
        return const PhoneQRPage();
      case 'email':
        return const EmailQRPage(); 
      case 'location':
        return const LocationQRPage(); 
      case 'event':
        return const EventQRPage();
      case 'clipboard':
        return const ClipBoardQRPage();
      default:
        return const TextQRPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to different pages based on the QR type
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _getPageForType(item.label),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon, 
                size: 40, 
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                item.label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, 
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
