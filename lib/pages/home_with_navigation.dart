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
// Import barcode pages
import 'barcode_page/ean8_barcode_page.dart';
import 'barcode_page/ean13_barcode_page.dart';
import 'barcode_page/code39_barcode_page.dart';
import 'barcode_page/code128_barcode_page.dart';
import 'barcode_page/generic_barcode_page.dart';

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
    _QRItem(icon: Icons.shopping_cart, label: 'EAN_8'),
    _QRItem(icon: Icons.shopping_cart, label: 'EAN_13'),
    _QRItem(icon: Icons.inventory, label: 'UPC_E'),
    _QRItem(icon: Icons.inventory, label: 'UPC_A'),
    _QRItem(icon: Icons.code, label: 'CODE_39'),
    _QRItem(icon: Icons.code, label: 'CODE_93'),
    _QRItem(icon: Icons.code, label: 'CODE_128'),
    _QRItem(icon: Icons.insert_drive_file, label: 'ITF'),
    _QRItem(icon: Icons.picture_as_pdf, label: 'PDF_417'),
    _QRItem(icon: Icons.qr_code_2, label: 'CODABAR'),
    _QRItem(icon: Icons.grid_view, label: 'DATA_MATRIX'),
    _QRItem(icon: Icons.crop_square, label: 'AZTEC'),
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
  final bool isBarcode;

  const QRCard({Key? key, required this.item, this.isBarcode = false}) : super(key: key);

  // Function to determine which page to navigate to based on item label
  Widget _getPageForType(String label, bool isBarcode) {
    if (isBarcode) {
      // Barcode pages
      switch (label.toUpperCase()) {
        case 'EAN_8':
          return const EAN8BarcodePage();
        case 'EAN_13':
          return const EAN13BarcodePage();
        case 'CODE_39':
          return const Code39BarcodePage();
        case 'CODE_128':
          return const Code128BarcodePage();
        case 'UPC_E':
          return GenericBarcodePage(
            barcodeType: 'UPC-E',
            title: 'UPC-E Barcode Generator',
            description: 'UPC-E is a compressed version of UPC-A for small packages.',
            hintText: '0123456',
            icon: Icons.inventory,
          );
        case 'UPC_A':
          return GenericBarcodePage(
            barcodeType: 'UPC-A',
            title: 'UPC-A Barcode Generator', 
            description: 'UPC-A is the standard barcode for retail products in North America.',
            hintText: '012345678901',
            icon: Icons.inventory,
          );
        case 'CODE_93':
          return GenericBarcodePage(
            barcodeType: 'CODE-93',
            title: 'CODE-93 Barcode Generator',
            description: 'CODE-93 is similar to CODE-39 but more compact and secure.',
            hintText: 'HELLO123',
            icon: Icons.code,
          );
        case 'ITF':
          return GenericBarcodePage(
            barcodeType: 'ITF',
            title: 'Interleaved 2 of 5 Barcode Generator',
            description: 'ITF is used for encoding pairs of digits in a compact format.',
            hintText: '1234567890',
            icon: Icons.insert_drive_file,
          );
        case 'PDF_417':
          return GenericBarcodePage(
            barcodeType: 'PDF-417',
            title: 'PDF-417 Barcode Generator',
            description: 'PDF-417 is a 2D barcode that can store large amounts of data.',
            hintText: 'Hello World PDF417',
            icon: Icons.picture_as_pdf,
          );
        case 'CODABAR':
          return GenericBarcodePage(
            barcodeType: 'CODABAR',
            title: 'CODABAR Barcode Generator',
            description: 'CODABAR is used in libraries, blood banks, and courier services.',
            hintText: 'A123456B',
            icon: Icons.qr_code_2,
          );
        case 'DATA_MATRIX':
          return GenericBarcodePage(
            barcodeType: 'Data Matrix',
            title: 'Data Matrix Barcode Generator',
            description: 'Data Matrix is a 2D barcode for small items and direct marking.',
            hintText: 'Hello DataMatrix',
            icon: Icons.grid_view,
          );
        case 'AZTEC':
          return GenericBarcodePage(
            barcodeType: 'AZTEC',
            title: 'AZTEC Barcode Generator',
            description: 'AZTEC is a 2D barcode with high data capacity and error correction.',
            hintText: 'AZTEC Code Data',
            icon: Icons.crop_square,
          );
        default:
          return GenericBarcodePage(
            barcodeType: label,
            title: '$label Barcode Generator',
            description: 'Generate $label barcode for your needs.',
            hintText: 'Enter data here',
            icon: Icons.qr_code,
          );
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
