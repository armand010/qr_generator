import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../providers/theme_provider.dart';
import '../../services/history_service.dart';

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
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'EAN_13');
      
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

  // Calculate EAN-13 check digit
  String _calculateCheckDigit(String code) {
    if (code.length >= 12) {
      String twelveDigits = code.substring(0, 12);
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        int digit = int.parse(twelveDigits[i]);
        sum += (i % 2 == 0) ? digit : digit * 3;
      }
      int checkDigit = (10 - (sum % 10)) % 10;
      return checkDigit.toString();
    }
    return '0';
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
        width: 350, // Increased width for better scanning
        height: 120, // Increased height for better proportions
        color: Colors.white,
        child: CustomPaint(
          painter: EAN13Painter(_barcodeData),
          size: const Size(350, 120),
        ),
      );
    } catch (e) {
      return Container(
        width: 350,
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              'Invalid EAN-13',
              style: TextStyle(color: Colors.red, fontSize: 12),
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
                                    _barcodeData.length == 12 ? '${_barcodeData.substring(0, 12)}${_calculateCheckDigit(_barcodeData)}' : _barcodeData,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
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
      // Validate and prepare the data
      if (data.isEmpty || data.length < 12) {
        _drawError(canvas, size);
        return;
      }

      // Ensure we have exactly 13 digits
      String code = data.replaceAll(RegExp(r'[^0-9]'), ''); // Remove non-digits
      if (code.length < 12) {
        _drawError(canvas, size);
        return;
      }
      
      // Take first 12 digits and calculate check digit
      code = code.substring(0, 12);
      int checkDigit = _calculateCheckDigit(code);
      code += checkDigit.toString();

      // Generate barcode pattern
      List<bool> barPattern = _generateEAN13Pattern(code);
      
      // Draw barcode with proper dimensions
      _drawBars(canvas, size, barPattern);
      
    } catch (e) {
      debugPrint('EAN-13 generation error: $e');
      _drawError(canvas, size);
    }
  }

  int _calculateCheckDigit(String code) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(code[i]);
      // Multiply odd positions by 1, even positions by 3
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    return (10 - (sum % 10)) % 10;
  }

  List<bool> _generateEAN13Pattern(String code) {
    // EAN-13 encoding patterns - corrected for proper scanning
    final List<String> leftOddPatterns = [
      '0001101', // 0
      '0011001', // 1
      '0010011', // 2
      '0111101', // 3
      '0100011', // 4
      '0110001', // 5
      '0101111', // 6
      '0111011', // 7
      '0110111', // 8
      '0001011'  // 9
    ];
    
    final List<String> leftEvenPatterns = [
      '0100111', // 0
      '0110011', // 1
      '0011011', // 2
      '0100001', // 3
      '0011101', // 4
      '0111001', // 5
      '0000101', // 6
      '0010001', // 7
      '0001001', // 8
      '0010111'  // 9
    ];
    
    final List<String> rightPatterns = [
      '1110010', // 0
      '1100110', // 1
      '1101100', // 2
      '1000010', // 3
      '1011100', // 4
      '1001110', // 5
      '1010000', // 6
      '1000100', // 7
      '1001000', // 8
      '1110100'  // 9
    ];
    
    // First digit patterns (determines left half encoding) - corrected
    final List<String> firstDigitPatterns = [
      'LLLLLL', // 0
      'LLGLGG', // 1
      'LLGGLG', // 2
      'LLGGGL', // 3
      'LGLLGG', // 4
      'LGGLLG', // 5
      'LGGGLL', // 6
      'LGLGLG', // 7
      'LGLGGL', // 8
      'LGGLGL'  // 9
    ];
    
    List<bool> pattern = [];
    
    int firstDigit = int.parse(code[0]);
    String encodingPattern = firstDigitPatterns[firstDigit];
    
    // Start guard: 101
    pattern.addAll([true, false, true]);
    
    // Left group (digits 1-6) - Fixed indexing
    for (int i = 1; i <= 6; i++) {
      int digit = int.parse(code[i]);
      String digitPattern;
      
      if (encodingPattern[i - 1] == 'L') {
        // Use left odd patterns (L-patterns)
        digitPattern = leftOddPatterns[digit];
      } else {
        // Use left even patterns (G-patterns)
        digitPattern = leftEvenPatterns[digit];
      }
      
      // Add digit pattern
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }
    
    // Center guard: 01010
    pattern.addAll([false, true, false, true, false]);
    
    // Right group (digits 7-12) - Fixed to use proper right patterns
    for (int i = 7; i <= 12; i++) {
      int digit = int.parse(code[i]);
      String digitPattern = rightPatterns[digit];
      
      // Add digit pattern
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }
    
    // End guard: 101
    pattern.addAll([true, false, true]);
    
    return pattern;
  }

  void _drawBars(Canvas canvas, Size size, List<bool> pattern) {
    // Draw white background first
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // Calculate dimensions with proper quiet zones
    final int totalModules = pattern.length + 11 + 7; // bars + left quiet zone + right quiet zone
    final double moduleWidth = size.width / totalModules;
    final double barHeight = size.height;
    
    double currentX = 11 * moduleWidth; // Start after left quiet zone
    
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i]) {
        // Draw black bar with full height
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

  void _drawError(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw error rectangle
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // Draw X pattern
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}