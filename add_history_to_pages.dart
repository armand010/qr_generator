import 'dart:io';

void main() async {
  // QR Code pages that need history tracking
  final qrPages = [
    'lib/pages/qr_code_page/sms_qr_page.dart',
    'lib/pages/qr_code_page/phone_qr_page.dart', 
    'lib/pages/qr_code_page/email_qr_page.dart',
    'lib/pages/qr_code_page/location_qr_page.dart',
    'lib/pages/qr_code_page/event_qr_page.dart',
    'lib/pages/qr_code_page/clipboard_qr_page.dart',
  ];

  // Barcode pages that need history tracking  
  final barcodePages = [
    'lib/pages/barcode_page/itf_barcode_page.dart',
    'lib/pages/barcode_page/pdf417_barcode_page.dart', 
    'lib/pages/barcode_page/codabar_barcode_page.dart',
    'lib/pages/barcode_page/ean8_barcode_page.dart',
    'lib/pages/barcode_page/generic_barcode_page.dart',
  ];

  print('Adding history service to QR pages...');
  for (String pagePath in qrPages) {
    await addHistoryToQRPage(pagePath);
  }

  print('Adding history service to Barcode pages...');
  for (String pagePath in barcodePages) {
    await addHistoryToBarcodePage(pagePath);
  }

  print('Done! All pages now have history tracking.');
}

Future<void> addHistoryToQRPage(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File not found: $filePath');
      return;
    }

    String content = await file.readAsString();
    
    // Add import if not present
    if (!content.contains('import \'../../services/history_service.dart\';')) {
      content = content.replaceFirst(
        RegExp(r'import \'package:gal/gal\.dart\';'),
        'import \'package:gal/gal.dart\';\nimport \'../../services/history_service.dart\';'
      );
    }

    // Add history tracking to generate methods
    content = content.replaceAllMapped(
      RegExp(r'setState\(\(\) \{\s*_qrData = ([^;]+);\s*_showQR = true;\s*\}\);'),
      (match) {
        return '''setState(() {
        _qrData = ${match.group(1)};
        _showQR = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _qrData, format: 'QR_CODE');''';
      }
    );

    await file.writeAsString(content);
    print('Updated: $filePath');
  } catch (e) {
    print('Error updating $filePath: $e');
  }
}

Future<void> addHistoryToBarcodePage(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File not found: $filePath');
      return;
    }

    String content = await file.readAsString();
    
    // Add import if not present
    if (!content.contains('import \'../../services/history_service.dart\';')) {
      content = content.replaceFirst(
        RegExp(r'import \'../../providers/theme_provider\.dart\';'),
        'import \'../../providers/theme_provider.dart\';\nimport \'../../services/history_service.dart\';'
      );
    }

    // Get barcode format from filename
    String format = _getBarcodeFormat(filePath);

    // Add history tracking to generate methods
    content = content.replaceAllMapped(
      RegExp(r'setState\(\(\) \{\s*_barcodeData = ([^;]+);\s*_showBarcode = true;\s*\}\);'),
      (match) {
        return '''setState(() {
        _barcodeData = ${match.group(1)};
        _showBarcode = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: '$format');''';
      }
    );

    await file.writeAsString(content);
    print('Updated: $filePath');
  } catch (e) {
    print('Error updating $filePath: $e');
  }
}

String _getBarcodeFormat(String filePath) {
  if (filePath.contains('itf_')) return 'ITF';
  if (filePath.contains('pdf417_')) return 'PDF_417';
  if (filePath.contains('codabar_')) return 'CODABAR';
  if (filePath.contains('ean8_')) return 'EAN_8';
  return 'BARCODE';
}
