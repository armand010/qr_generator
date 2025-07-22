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

class EAN13BarcodePage extends StatefulWidget {
  const EAN13BarcodePage({super.key});

  @override
  State<EAN13BarcodePage> createState() => _EAN13BarcodePageState();
}

class _EAN13BarcodePageState extends State<EAN13BarcodePage> {
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
          content: Text('EAN-13 barcode generated successfully!'),
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
      final fileName = 'ean13_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EAN-13 barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/ean13_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'EAN-13 Barcode: $_barcodeData',
        subject: 'My EAN-13 Barcode',
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
                  painter: EAN13Painter(_barcodeData),
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
              'Invalid EAN-13 code',
              style: TextStyle(color: Colors.red, fontSize: 16),
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
            title: const Text('EAN-13 Barcode'),
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
                            'EAN-13 Barcode Generator',
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
                              LengthLimitingTextInputFormatter(13),
                            ],
                            decoration: InputDecoration(
                              labelText: 'EAN-13 Code',
                              hintText: '1234567890123',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.shopping_cart),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter EAN-13 code';
                              }
                              if (value.length < 12 || value.length > 13) {
                                return 'EAN-13 code must be 12 or 13 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'EAN-13 is the most common barcode for retail products. Enter 12 digits (13th will be calculated) or 13 digits including check digit.',
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
                                  child: const Text('Generate EAN-13'),
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
                              'EAN-13 Barcode Result:',
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

// Custom painter for EAN-13 barcode
class EAN13Painter extends CustomPainter {
  final String data;
  
  EAN13Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final List<bool> barData = [];
      
      // Generate EAN-13 barcode pattern
      if (data.length >= 12) {
        String code = data;
        if (code.length == 12) {
          // Calculate check digit for EAN-13
          int sum = 0;
          for (int i = 0; i < 12; i++) {
            int digit = int.parse(code[i]);
            sum += (i % 2 == 0) ? digit : digit * 3;
          }
          int checkDigit = (10 - (sum % 10)) % 10;
          code += checkDigit.toString();
        }
        
        // EAN-13 encoding patterns
        final List<String> leftOddPatterns = [
          '0001101', '0011001', '0010011', '0111101', '0100011',
          '0110001', '0101111', '0111011', '0110111', '0001011'
        ];
        final List<String> leftEvenPatterns = [
          '0100111', '0110011', '0011011', '0100001', '0011101',
          '0111001', '0000101', '0010001', '0001001', '0010111'
        ];
        final List<String> rightPatterns = [
          '1110010', '1100110', '1101100', '1000010', '1011100',
          '1001110', '1010000', '1000100', '1001000', '1110100'
        ];
        
        // First digit pattern
        final List<String> firstDigitPatterns = [
          'OOOOOO', 'OOEOEE', 'OOEEOE', 'OOEEEO', 'OEOOEE',
          'OEEOOE', 'OEEEOO', 'OEOEOE', 'OEOEEO', 'OEEOEO'
        ];
        
        int firstDigit = int.parse(code[0]);
        String pattern = firstDigitPatterns[firstDigit];
        
        // Start guard
        barData.addAll([true, false, true]);
        
        // Left digits (6 digits)
        for (int i = 1; i < 7; i++) {
          int digit = int.parse(code[i]);
          String digitPattern;
          if (pattern[i - 1] == 'O') {
            digitPattern = leftOddPatterns[digit];
          } else {
            digitPattern = leftEvenPatterns[digit];
          }
          for (int j = 0; j < digitPattern.length; j++) {
            barData.add(digitPattern[j] == '1');
          }
        }
        
        // Center guard
        barData.addAll([false, true, false, true, false]);
        
        // Right digits (6 digits)
        for (int i = 7; i < 13; i++) {
          int digit = int.parse(code[i]);
          String digitPattern = rightPatterns[digit];
          for (int j = 0; j < digitPattern.length; j++) {
            barData.add(digitPattern[j] == '1');
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
