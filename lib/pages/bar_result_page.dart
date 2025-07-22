import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';

// Enum for barcode data types
enum BarcodeDataType {
  text,
  product,
  isbn,
  issn,
  unknown,
}

// Class to hold parsed barcode data
class ParsedBarcodeData {
  final BarcodeDataType type;
  final String rawData;
  final Map<String, String> parsedData;

  ParsedBarcodeData({
    required this.type,
    required this.rawData,
    required this.parsedData,
  });
}

// Barcode Data Parser class
class BarcodeDataParser {
  static ParsedBarcodeData parseBarcodeData(String data, String? format) {
    // EAN/UPC codes are usually product codes
    if (format != null && (format.contains('EAN') || format.contains('UPC'))) {
      return _parseProductCode(data, format);
    }
    
    // ISBN detection (books)
    if (data.length == 10 || data.length == 13) {
      if (_isISBN(data)) {
        return _parseISBN(data);
      }
    }
    
    // ISSN detection (magazines/journals)
    if (data.length == 8 || (data.length == 9 && data.contains('-'))) {
      if (_isISSN(data)) {
        return _parseISSN(data);
      }
    }
    
    // Default to text/product
    return ParsedBarcodeData(
      type: BarcodeDataType.text,
      rawData: data,
      parsedData: {'text': data, 'format': format ?? 'Unknown'},
    );
  }
  
  static ParsedBarcodeData _parseProductCode(String data, String format) {
    return ParsedBarcodeData(
      type: BarcodeDataType.product,
      rawData: data,
      parsedData: {
        'code': data,
        'format': format,
        'type': 'Product Code',
      },
    );
  }
  
  static ParsedBarcodeData _parseISBN(String data) {
    return ParsedBarcodeData(
      type: BarcodeDataType.isbn,
      rawData: data,
      parsedData: {
        'isbn': data,
        'type': 'Book ISBN',
        'format': data.length == 10 ? 'ISBN-10' : 'ISBN-13',
      },
    );
  }
  
  static ParsedBarcodeData _parseISSN(String data) {
    return ParsedBarcodeData(
      type: BarcodeDataType.issn,
      rawData: data,
      parsedData: {
        'issn': data,
        'type': 'Journal/Magazine ISSN',
        'format': 'ISSN',
      },
    );
  }
  
  static bool _isISBN(String data) {
    // Basic ISBN validation
    if (data.length == 10) {
      return RegExp(r'^\d{9}[\dX]$').hasMatch(data);
    } else if (data.length == 13) {
      return RegExp(r'^97[89]\d{10}$').hasMatch(data) && data.startsWith('978') || data.startsWith('979');
    }
    return false;
  }
  
  static bool _isISSN(String data) {
    // Basic ISSN validation
    String clean = data.replaceAll('-', '');
    return clean.length == 8 && RegExp(r'^\d{7}[\dX]$').hasMatch(clean);
  }
}

class BarcodeResultPage extends StatelessWidget {
  final ParsedBarcodeData parsedData;
  final Uint8List? barcodeImage;

  const BarcodeResultPage({
    super.key,
    required this.parsedData,
    this.barcodeImage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            title: const Text('Barcode Result'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareResult(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barcode Image Card
                if (barcodeImage != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Scanned Barcode',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Image.memory(
                              barcodeImage!,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Barcode Type Info Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getTypeIcon(),
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _getTypeTitle(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTypeSpecificContent(context),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Raw Data Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raw Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: SelectableText(
                            parsedData.rawData,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Format: ${parsedData.parsedData["format"] ?? "Unknown"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getTypeIcon() {
    switch (parsedData.type) {
      case BarcodeDataType.product:
        return Icons.shopping_cart;
      case BarcodeDataType.isbn:
        return Icons.book;
      case BarcodeDataType.issn:
        return Icons.article;
      case BarcodeDataType.text:
      case BarcodeDataType.unknown:
      default:
        return Icons.qr_code_2;
    }
  }

  String _getTypeTitle() {
    switch (parsedData.type) {
      case BarcodeDataType.product:
        return 'Product Code';
      case BarcodeDataType.isbn:
        return 'Book ISBN';
      case BarcodeDataType.issn:
        return 'Journal/Magazine';
      case BarcodeDataType.text:
        return 'Text Data';
      case BarcodeDataType.unknown:
      default:
        return 'Barcode Data';
    }
  }

  Widget _buildTypeSpecificContent(BuildContext context) {
    switch (parsedData.type) {
      case BarcodeDataType.product:
        return _buildProductContent(context);
      case BarcodeDataType.isbn:
        return _buildISBNContent(context);
      case BarcodeDataType.issn:
        return _buildISSNContent(context);
      case BarcodeDataType.text:
      case BarcodeDataType.unknown:
      default:
        return _buildTextContent(context);
    }
  }

  Widget _buildProductContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Product Code:', parsedData.parsedData['code'] ?? ''),
        _buildInfoRow('Format:', parsedData.parsedData['format'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'This appears to be a product barcode. You can search for this product online using the code above.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildISBNContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('ISBN:', parsedData.parsedData['isbn'] ?? ''),
        _buildInfoRow('Format:', parsedData.parsedData['format'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'This is a book ISBN (International Standard Book Number). You can search for this book online or in library catalogs.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildISSNContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('ISSN:', parsedData.parsedData['issn'] ?? ''),
        _buildInfoRow('Format:', parsedData.parsedData['format'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'This is an ISSN (International Standard Serial Number) for a journal or magazine.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Data:', parsedData.parsedData['text'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'This barcode contains text or numeric data.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Copy button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _copyToClipboard(context),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Search online button (for products and books)
        if (parsedData.type == BarcodeDataType.product || parsedData.type == BarcodeDataType.isbn)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _searchOnline(context),
              icon: const Icon(Icons.search),
              label: Text(parsedData.type == BarcodeDataType.isbn ? 'Search Book' : 'Search Product'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: parsedData.rawData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Barcode data copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareResult(BuildContext context) {
    String shareText = 'Scanned Barcode:\n';
    shareText += 'Type: ${_getTypeTitle()}\n';
    shareText += 'Data: ${parsedData.rawData}\n';
    shareText += 'Format: ${parsedData.parsedData["format"] ?? "Unknown"}';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Barcode result copied to clipboard for sharing'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _searchOnline(BuildContext context) {
    String query = parsedData.rawData;
    String url;

    if (parsedData.type == BarcodeDataType.isbn) {
      // Search for book by ISBN
      url = 'https://www.google.com/search?q=ISBN+$query';
    } else {
      // Search for product by barcode
      url = 'https://www.google.com/search?q=barcode+$query';
    }

    _launchURL(context, url);
  }

  void _launchURL(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open search in browser'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
