import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:barcode/barcode.dart';
import '../../providers/theme_provider.dart';
import '../../services/history_service.dart';

class EAN8BarcodePage extends StatefulWidget {
  const EAN8BarcodePage({super.key});

  @override
  State<EAN8BarcodePage> createState() => _EAN8BarcodePageState();
}

class _EAN8BarcodePageState extends State<EAN8BarcodePage> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey _barcodeKeyEan8 = GlobalKey();
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
      final inputText = _codeController.text.trim();
      final cleanText = inputText.replaceAll(RegExp(r'[^0-9]'), '');
      
      String finalData = cleanText;
      
      // Validate 8-digit input and show warning if check digit might be wrong
      if (cleanText.length == 8) {
        String first7 = cleanText.substring(0, 7);
        int expectedCheckDigit = _calculateCheckDigit(first7);
        int actualCheckDigit = int.parse(cleanText[7]);
        
        if (expectedCheckDigit != actualCheckDigit) {
          // Show warning but still generate barcode
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: Check digit might be incorrect. Expected: $expectedCheckDigit, but got: ${cleanText[7]}. Barcode generated anyway.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      
      setState(() {
        _barcodeData = finalData;
        _showBarcode = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'EAN_8');

      if (cleanText.length == 8) {
        String first7 = cleanText.substring(0, 7);
        int expectedCheckDigit = _calculateCheckDigit(first7);
        int actualCheckDigit = int.parse(cleanText[7]);
        
        if (expectedCheckDigit == actualCheckDigit) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('EAN-8 barcode generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EAN-8 barcode generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _clearBarcode() {
    setState(() {
      _codeController.clear();
      _barcodeData = '';
      _showBarcode = false;
    });
  }

  // Calculate EAN-8 check digit
  // Function to capture barcode as image
  Future<Uint8List?> _captureBarcode() async {
    try {
      RenderRepaintBoundary boundary =
          _barcodeKeyEan8.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing barcode: $e');
      return null;
    }
  }

  // Calculate EAN-8 check digit
  int _calculateCheckDigit(String code) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(code[i]);
      // EAN-8: multiply by 3 for odd positions (1st, 3rd, 5th, 7th), by 1 for even positions (2nd, 4th, 6th)
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    return (10 - (sum % 10)) % 10;
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
              content: Text(
                'Gallery access permission denied. Using share instead.',
              ),
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
      final fileName =
          'ean8_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
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
      final file = File(
        '${tempDir.path}/ean8_barcode_${DateTime.now().millisecondsSinceEpoch}.png',
      );

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
      // Prepare data for EAN-8
      String cleanData = _barcodeData.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Handle 7-digit input (calculate check digit) or 8-digit input
      if (cleanData.length == 7) {
        int checkDigit = _calculateCheckDigit(cleanData);
        cleanData += checkDigit.toString();
      } else if (cleanData.length != 8) {
        throw Exception('EAN-8 must be 7 or 8 digits');
      }
      
      // Use EAN8Painter which has better scanning compatibility
      return Container(
        width: 300,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: EAN8Painter(cleanData),
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
              'Invalid EAN-8: ${e.toString()}',
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _generateBarcode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  RepaintBoundary(
                                    key: _barcodeKeyEan8,
                                    child: _buildBarcode(),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _barcodeData.length == 7
                                        ? '${_barcodeData.substring(0, 7)}${_calculateCheckDigit(_barcodeData).toString()}'
                                        : _barcodeData,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        onPressed: _saveBarcode,
                                        icon: Icon(
                                          Icons.save_alt,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                        iconSize: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        onPressed: _shareBarcode,
                                        icon: Icon(
                                          Icons.share,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                        iconSize: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Share',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
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

// Custom painter using proper EAN-8 standard implementation
class EAN8BarcodeCustomPainter extends CustomPainter {
  final Barcode barcode;
  final String data;

  EAN8BarcodeCustomPainter(this.barcode, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Prepare and validate data
      String cleanData = data.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Handle 7-digit input (calculate check digit) or 8-digit input
      if (cleanData.length == 7) {
        int checkDigit = _calculateEAN8CheckDigit(cleanData);
        cleanData += checkDigit.toString();
      } else if (cleanData.length == 8) {
        // For 8-digit input, accept it as is
      } else {
        throw Exception('EAN-8 must be 7 or 8 digits');
      }

      // Use the barcode library to generate proper EAN-8
      _drawBarcodeFromLibrary(canvas, size, cleanData);

    } catch (e) {
      // Draw error message
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Error: ${e.toString()}',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
    }
  }

  void _drawBarcodeFromLibrary(Canvas canvas, Size size, String data) {
    // Use the barcode library's built-in method to ensure proper EAN-8 encoding
    final bc = Barcode.ean8();
    
    // Draw white background
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    // Use built-in barcode generation
    try {
      // Generate proper EAN-8 pattern using library
      final barcodeData = bc.make(data, width: size.width, height: size.height);
      
      // Draw the barcode elements
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      
      for (final element in barcodeData) {
        if (element is BarcodeBar) {
          final rect = Rect.fromLTWH(
            element.left * size.width,
            element.top * size.height,
            element.width * size.width,
            element.height * size.height,
          );
          canvas.drawRect(rect, paint);
        }
      }
    } catch (e) {
      // Fallback to manual implementation if library fails
      _drawManualEAN8(canvas, size, data);
    }
  }

  void _drawManualEAN8(Canvas canvas, Size size, String data) {
    // Manual EAN-8 implementation as fallback
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // EAN-8 patterns (L-patterns for left, R-patterns for right)
    final leftPatterns = [
      '0001101', '0011001', '0010011', '0111101', '0100011',
      '0110001', '0101111', '0111011', '0110111', '0001011'
    ];

    final rightPatterns = [
      '1110010', '1100110', '1101100', '1000010', '1011100',
      '1001110', '1010000', '1000100', '1001000', '1110100'
    ];

    String pattern = '101'; // Start guard
    
    // Left group (4 digits)
    for (int i = 0; i < 4; i++) {
      int digit = int.parse(data[i]);
      pattern += leftPatterns[digit];
    }
    
    pattern += '01010'; // Center guard
    
    // Right group (4 digits)
    for (int i = 4; i < 8; i++) {
      int digit = int.parse(data[i]);
      pattern += rightPatterns[digit];
    }
    
    pattern += '101'; // End guard

    // Draw with proper quiet zones (7 modules each side for EAN-8)
    final int totalModules = pattern.length + 14; // barcode + quiet zones
    final double moduleWidth = size.width / totalModules;
    final double quietZoneWidth = 7 * moduleWidth;
    
    double currentX = quietZoneWidth; // Start after left quiet zone
    
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i] == '1') {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, moduleWidth, size.height),
          paint,
        );
      }
      currentX += moduleWidth;
    }
  }

  int _calculateEAN8CheckDigit(String code) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(code[i]);
      // EAN-8: multiply by 3 for odd positions (1st, 3rd, 5th, 7th), by 1 for even positions (2nd, 4th, 6th)
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    return (10 - (sum % 10)) % 10;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter untuk EAN-8 barcode yang dapat di-scan dengan implementasi yang benar
class EAN8Painter extends CustomPainter {
  final String data;

  EAN8Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Validate and prepare data
      String code = data.replaceAll(RegExp(r'[^0-9]'), '');
      if (code.length < 7 || code.length > 8) {
        throw Exception('Invalid EAN-8 length');
      }

      // Calculate check digit if needed
      if (code.length == 7) {
        code = code.substring(0, 7);
        int sum = 0;
        for (int i = 0; i < 7; i++) {
          int digit = int.parse(code[i]);
          // EAN-8: multiply by 3 for odd positions, by 1 for even positions
          sum += (i % 2 == 0) ? digit * 3 : digit;
        }
        int checkDigit = (10 - (sum % 10)) % 10;
        code += checkDigit.toString();
      }

      // Generate barcode pattern using standard EAN-8 encoding
      List<bool> barPattern = _generateEAN8Pattern(code);
      
      // Draw barcode dengan dimensi yang benar dan quiet zones
      _drawBarsWithQuietZones(canvas, size, barPattern);

    } catch (e) {
      // Draw error indicator
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Draw X to indicate error
      canvas.drawLine(
        const Offset(0, 0),
        Offset(size.width, size.height),
        paint,
      );
      canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
    }
  }

  List<bool> _generateEAN8Pattern(String code) {
    // EAN-8 encoding patterns sesuai standar
    final List<String> leftPatterns = [
      '0001101', // 0
      '0011001', // 1
      '0010011', // 2
      '0111101', // 3
      '0100011', // 4
      '0110001', // 5
      '0101111', // 6
      '0111011', // 7
      '0110111', // 8
      '0001011', // 9
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
      '1110100', // 9
    ];

    List<bool> pattern = [];

    // Start guard: 101
    pattern.addAll([true, false, true]);

    // Left group (first 4 digits using left patterns)
    for (int i = 0; i < 4; i++) {
      int digit = int.parse(code[i]);
      String digitPattern = leftPatterns[digit];
      
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }

    // Center guard: 01010
    pattern.addAll([false, true, false, true, false]);

    // Right group (last 4 digits using right patterns)
    for (int i = 4; i < 8; i++) {
      int digit = int.parse(code[i]);
      String digitPattern = rightPatterns[digit];
      
      for (int j = 0; j < digitPattern.length; j++) {
        pattern.add(digitPattern[j] == '1');
      }
    }

    // End guard: 101
    pattern.addAll([true, false, true]);

    return pattern;
  }

  void _drawBarsWithQuietZones(Canvas canvas, Size size, List<bool> pattern) {
    // Draw white background
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // EAN-8 requires quiet zones: 7 modules on each side
    // Total modules: 7 (quiet) + 67 (barcode) + 7 (quiet) = 81
    const int quietZoneModules = 7;
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is EAN8Painter && oldDelegate.data != data;
  }
}
