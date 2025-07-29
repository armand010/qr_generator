import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:barcode/barcode.dart';
import '../../services/history_service.dart';

class UPCABarcodePage extends StatefulWidget {
  const UPCABarcodePage({super.key});

  @override
  State<UPCABarcodePage> createState() => _UPCABarcodePageState();
}

class _UPCABarcodePageState extends State<UPCABarcodePage> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey _barcodeKey = GlobalKey();
  String _barcodeData = '';
  bool _showBarcode = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _barcodeData = _codeController.text.trim();
        _showBarcode = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'UPC_A');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPC-A barcode generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearBarcode() {
    setState(() {
      _codeController.clear();
      _barcodeData = '';
      _showBarcode = false;
    });
  }

  // Function to capture barcode as image
  Future<Uint8List?> _captureBarcode() async {
    try {
      RenderRepaintBoundary boundary = 
          _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing barcode: $e');
      return null;
    }
  }

  // Function to save barcode
  Future<void> _saveBarcode() async {
    if (!mounted) return;
    
    try {
      Uint8List? imageBytes = await _captureBarcode();
      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture barcode'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final requestGranted = await Gal.requestAccess();
        if (!requestGranted) {
          if (!mounted) return;
          await _shareBarcode();
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'upca_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPC-A barcode saved to gallery successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }

    } catch (e) {
      if (!mounted) return;
      await _shareBarcode();
    }
  }

  // Function to share barcode
  Future<void> _shareBarcode() async {
    if (!mounted) return;
    
    try {
      Uint8List? imageBytes = await _captureBarcode();
      if (imageBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/upca_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'UPC-A Barcode: $_barcodeData',
        subject: 'My UPC-A Barcode',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _validateUPCACode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter UPC-A code';
    }

    // Remove any spaces or dashes
    String cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');

    // UPC-A must be exactly 12 digits
    if (cleanValue.length != 12) {
      return 'UPC-A code must be exactly 12 digits';
    }

    // Must contain only digits
    if (!RegExp(r'^\d+$').hasMatch(cleanValue)) {
      return 'UPC-A code must contain only digits';
    }

    // Validate check digit
    if (!_isValidUPCACheckDigit(cleanValue)) {
      return 'Invalid UPC-A check digit';
    }

    return null;
  }

  bool _isValidUPCACheckDigit(String code) {
    if (code.length != 12) return false;

    int sum = 0;
    for (int i = 0; i < 11; i++) {
      int digit = int.parse(code[i]);
      if (i % 2 == 0) {
        sum += digit * 3; // Odd positions (1st, 3rd, 5th, etc.) multiply by 3
      } else {
        sum += digit; // Even positions multiply by 1
      }
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[11]);
  }

  Widget _buildBarcode() {
    try {
      // Create UPC-A barcode using the barcode library
      final bc = Barcode.upcA();
      
      // Validate the data first
      if (!bc.isValid(_barcodeData)) {
        throw Exception('Invalid UPC-A data');
      }
      
      return Container(
        width: 300,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: UPCALibraryPainter(_barcodeData),
          size: const Size(300, 100),
        ),
      );
    } catch (e) {
      return Container(
        width: 300,
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              'Invalid UPC-A: ${e.toString()}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: const Text('UPC-A Barcode'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'UPC-A Barcode Generator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: InputDecoration(
                          labelText: 'UPC-A Code',
                          hintText: 'Enter 12-digit UPC-A code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: const Icon(Icons.qr_code_2),
                        ),
                        validator: _validateUPCACode,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'UPC-A is used for retail products in North America. Enter exactly 12 digits with valid check digit.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _generateBarcode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Generate UPC-A'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _clearBarcode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_showBarcode && _barcodeData.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'UPC-A Barcode Result:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                key: _barcodeKey,
                                child: _buildBarcode(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _barcodeData,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Save and Share buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    onPressed: _saveBarcode,
                                    icon: Icon(Icons.save_alt, color: Theme.of(context).colorScheme.onPrimary),
                                    iconSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    onPressed: _shareBarcode,
                                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onPrimary),
                                    iconSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: "Save" stores to gallery, "Share" sends to other apps',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for UPC-A barcode using proven implementation  
class UPCALibraryPainter extends CustomPainter {
  final String data;

  UPCALibraryPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Draw white background
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      
      if (data.isEmpty || data.length != 12) {
        throw Exception('Invalid UPC-A data');
      }
      
      // Use proven manual implementation similar to EAN-8
      _drawUPCABarsManually(canvas, size);
      
    } catch (e) {
      _drawErrorPattern(canvas, size);
    }
  }
  
  void _drawUPCABarsManually(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // UPC-A left patterns for digits 0-9 (L-patterns)
    final List<String> leftPatterns = [
      '0001101', '0011001', '0010011', '0111101', '0100011',
      '0110001', '0101111', '0111011', '0110111', '0001011'
    ];
    
    // UPC-A right patterns for digits 0-9 (R-patterns)
    final List<String> rightPatterns = [
      '1110010', '1100110', '1101100', '1000010', '1011100',
      '1001110', '1010000', '1000100', '1001000', '1110100'
    ];

    // Build barcode pattern
    List<bool> pattern = [];
    
    // Start guard: 101
    pattern.addAll([true, false, true]);
    
    // Left group (first 6 digits)
    for (int i = 0; i < 6; i++) {
      int digit = int.parse(data[i]);
      String digitPattern = leftPatterns[digit];
      
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }
    
    // Center guard: 01010
    pattern.addAll([false, true, false, true, false]);
    
    // Right group (last 6 digits)
    for (int i = 6; i < 12; i++) {
      int digit = int.parse(data[i]);
      String digitPattern = rightPatterns[digit];
      
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }
    
    // End guard: 101
    pattern.addAll([true, false, true]);
    
    // Draw bars with proper quiet zones
    const int quietZoneModules = 9; // UPC-A requires 9 modules quiet zone
    final int totalModules = pattern.length + (quietZoneModules * 2);
    final double moduleWidth = size.width / totalModules;
    final double barHeight = size.height;
    
    // Start drawing after left quiet zone
    double currentX = quietZoneModules * moduleWidth;
    
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i]) {
        // Draw black bar
        canvas.drawRect(
          Rect.fromLTWH(
            currentX,
            0,
            moduleWidth,
            barHeight
          ),
          paint,
        );
      }
      currentX += moduleWidth;
    }
  }
  
  void _drawErrorPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // Draw X pattern to indicate error
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is UPCALibraryPainter && oldDelegate.data != data;
  }
}
