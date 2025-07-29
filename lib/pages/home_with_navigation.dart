import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scan_code_page.dart';
import 'settings_page.dart';
import 'history_page.dart';
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
// Import barcode pages
import 'barcode_page/ean13_barcode_page.dart';
import 'barcode_page/ean8_barcode_page.dart';
import 'barcode_page/code128_barcode_page.dart';
import 'barcode_page/code39_barcode_page.dart';
import 'barcode_page/code93_barcode_page.dart';
import 'barcode_page/itf_barcode_page.dart';
import 'barcode_page/pdf417_barcode_page.dart';
import 'barcode_page/codabar_barcode_page.dart';
import 'barcode_page/upca_barcode_page.dart';
import 'barcode_page/upce_barcode_page.dart';
import 'barcode_page/datamatrix_barcode_page.dart';
import 'barcode_page/aztec_barcode_page.dart';

class HomeWithNavigation extends StatefulWidget {
  final int initialIndex;
  
  const HomeWithNavigation({super.key, this.initialIndex = 1});

  @override
  State<HomeWithNavigation> createState() => _HomeWithNavigationState();
}

class _HomeWithNavigationState extends State<HomeWithNavigation> {
  late int _currentIndex;
  late PageController _pageController;
  int _codeTypeIndex = 0; // 0 for QR Code, 1 for Bar Code

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

  final List<_QRItem> barcodeItems = [
    _QRItem(icon: Icons.shopping_cart, label: 'EAN_13'),
    _QRItem(icon: Icons.shopping_bag, label: 'EAN_8'),
    _QRItem(icon: Icons.code, label: 'CODE_128'),
    _QRItem(icon: Icons.barcode_reader, label: 'CODE_39'),
    _QRItem(icon: Icons.view_stream, label: 'CODE_93'),
    _QRItem(icon: Icons.receipt_long, label: 'ITF'),
    _QRItem(icon: Icons.picture_as_pdf, label: 'PDF_417'),
    _QRItem(icon: Icons.qr_code_2, label: 'CODABAR'),
    _QRItem(icon: Icons.qr_code, label: 'UPC_A'),
    _QRItem(icon: Icons.qr_code_scanner, label: 'UPC_E'),
    _QRItem(icon: Icons.grid_on, label: 'DATA_MATRIX'),
    _QRItem(icon: Icons.blur_circular, label: 'AZTEC'),
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
              'Create Code',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _codeTypeIndex = 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _codeTypeIndex == 0 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'QR code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _codeTypeIndex == 0 
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: _codeTypeIndex == 0 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _codeTypeIndex = 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _codeTypeIndex == 1 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'Bar code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _codeTypeIndex == 1 
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: _codeTypeIndex == 1 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: (_codeTypeIndex == 0 ? qrItems : barcodeItems)
                  .map((item) => QRCard(item: item, isBarcode: _codeTypeIndex == 1))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryPage() {
    return const HistoryPage();
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
              _buildHistoryPage(),
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
                icon: Icon(Icons.history),
                label: 'History',
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
  final bool isBarcode;

  const QRCard({Key? key, required this.item, this.isBarcode = false}) : super(key: key);

  // Function to determine which page to navigate to based on item label
  Widget _getPageForType(String label, bool isBarcode) {
    if (isBarcode) {
      // Barcode pages
      switch (label.toUpperCase()) {
        case 'EAN_13':
          return const EAN13BarcodePage();
        case 'EAN_8':
          return const EAN8BarcodePage();
        case 'CODE_128':
          return const Code128BarcodePage();
        case 'CODE_39':
          return const Code39BarcodePage();
        case 'CODE_93':
          return const Code93BarcodePage();
        case 'ITF':
          return const ITFBarcodePage();
        case 'PDF_417':
          return const PDF417BarcodePage();
        case 'CODABAR':
          return const CODABARBarcodePage();
        case 'UPC_A':
          return const UPCABarcodePage();
        case 'UPC_E':
          return const UPCEBarcodePage();
        case 'DATA_MATRIX':
          return const DataMatrixBarcodePage();
        case 'AZTEC':
          return const AztecBarcodePage();
        default:
          return const Code128BarcodePage(); // Fallback to working barcode
      }
    } else {
      // Existing QR code pages
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
              builder: (context) => _getPageForType(item.label, isBarcode),
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
