import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../providers/theme_provider.dart';

class EAN8BarcodePage extends StatefulWidget {
  const EAN8BarcodePage({super.key});

  @override
  State<EAN8BarcodePage> createState() => _EAN8BarcodePageState();
}

class _EAN8BarcodePageState extends State<EAN8BarcodePage> {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EAN-8 barcode generated successfully!'),
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

  // Function to save barcode directly to gallery
  Future<void> _saveBarcode() async {
    if (!mounted) return;
    
    try {
      // Capture barcode
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

      // Check if gallery access is available
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        // Request permission
        final requestGranted = await Gal.requestAccess();
        if (!requestGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gallery access permission denied. Using share instead.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Fallback to share
          await _shareBarcode();
          return;
        }
      }

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ean8_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      // Write image to temporary file
      await tempFile.writeAsBytes(imageBytes);

      // Save to gallery using gal package
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EAN-8 barcode saved to gallery successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Clean up temporary file
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }

    } catch (e) {
      if (!mounted) return;
      debugPrint('Save error: $e');
      
      // Show error and fallback to share
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save to gallery. Using share instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Fallback to share functionality
      await _shareBarcode();
    }
  }

  // Function to share barcode
  Future<void> _shareBarcode() async {
    if (!mounted) return;
    
    try {
      // Capture barcode
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

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ean8_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      // Write image to file
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'EAN-8 Barcode: $_barcodeData',
        subject: 'My EAN-8 Barcode',
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

  Widget _buildBarcode() {
    try {
      final bc = Barcode.ean8();
      // Validate EAN-8 data
      if (!bc.isValid(_barcodeData)) {
        throw Exception('Invalid EAN-8 code');
      }
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // This RepaintBoundary captures only the barcode image without text
            RepaintBoundary(
              key: _barcodeKey,
              child: Container(
                width: 300,
                height: 100,
                color: Colors.white,
                child: CustomPaint(
                  painter: BarcodePainter(bc, _barcodeData),
                  size: const Size(300, 100),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _barcodeData,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              'Invalid EAN-8 code',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            Text(
              'Must be 7 or 8 digits',
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            title: const Text('EAN-8 Barcode'),
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
                            'EAN-8 Barcode Generator',
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
                              LengthLimitingTextInputFormatter(8),
                            ],
                            decoration: InputDecoration(
                              labelText: 'EAN-8 Code',
                              hintText: '12345678',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.numbers),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter EAN-8 code';
                              }
                              if (value.length < 7 || value.length > 8) {
                                return 'EAN-8 code must be 7 or 8 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'EAN-8 is used for small products. Enter 7 digits (8th will be calculated as check digit) or 8 digits including check digit.',
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
                                  child: const Text('Generate EAN-8'),
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
                              'EAN-8 Barcode Result:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              key: _barcodeKey,
                              child: _buildBarcode(),
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
      },
    );
  }
}

// Proper barcode painter using barcode library
class BarcodePainter extends CustomPainter {
  final Barcode barcode;
  final String data;
  
  BarcodePainter(this.barcode, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Create barcode using library
      final List<bool> barData = [];
      
      // Generate EAN-8 barcode pattern
      if (data.length >= 7) {
        String code = data;
        if (code.length == 7) {
          // Calculate check digit for EAN-8
          int sum = 0;
          for (int i = 0; i < 7; i++) {
            int digit = int.parse(code[i]);
            sum += (i % 2 == 0) ? digit * 3 : digit;
          }
          int checkDigit = (10 - (sum % 10)) % 10;
          code += checkDigit.toString();
        }
        
        // EAN-8 encoding patterns
        final List<String> leftPatterns = [
          '0001101', '0011001', '0010011', '0111101', '0100011',
          '0110001', '0101111', '0111011', '0110111', '0001011'
        ];
        final List<String> rightPatterns = [
          '1110010', '1100110', '1101100', '1000010', '1011100',
          '1001110', '1010000', '1000100', '1001000', '1110100'
        ];
        
        // Start guard
        barData.addAll([true, false, true]);
        
        // Left digits
        for (int i = 0; i < 4; i++) {
          int digit = int.parse(code[i]);
          String pattern = leftPatterns[digit];
          for (int j = 0; j < pattern.length; j++) {
            barData.add(pattern[j] == '1');
          }
        }
        
        // Center guard
        barData.addAll([false, true, false, true, false]);
        
        // Right digits
        for (int i = 4; i < 8; i++) {
          int digit = int.parse(code[i]);
          String pattern = rightPatterns[digit];
          for (int j = 0; j < pattern.length; j++) {
            barData.add(pattern[j] == '1');
          }
        }
        
        // End guard
        barData.addAll([true, false, true]);
      }
      
      // Draw barcode
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      
      final double barWidth = size.width / barData.length;
      
      for (int i = 0; i < barData.length; i++) {
        if (barData[i]) {
          final rect = Rect.fromLTWH(
            i * barWidth,
            0,
            barWidth,
            size.height,
          );
          canvas.drawRect(rect, paint);
        }
      }
    } catch (e) {
      // If barcode generation fails, draw error
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
