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

class Code39BarcodePage extends StatefulWidget {
  const Code39BarcodePage({super.key});

  @override
  State<Code39BarcodePage> createState() => _Code39BarcodePageState();
}

class _Code39BarcodePageState extends State<Code39BarcodePage> {
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
        _barcodeData = _codeController.text.trim().toUpperCase();
        _showBarcode = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'CODE_39');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-39 barcode generated successfully!'),
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

  String? _validateCode39(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter CODE-39 data';
    }

    // CODE-39 supports: A-Z, 0-9, and symbols: - . $ / + % SPACE
    final validPattern = RegExp(r'^[A-Z0-9\-\.\$\/\+%\s]*$');
    
    if (!validPattern.hasMatch(value.toUpperCase())) {
      return 'CODE-39 supports only: A-Z, 0-9, -, ., \$, /, +, %, and space';
    }

    if (value.length > 43) {
      return 'CODE-39 typically supports up to 43 characters';
    }

    return null;
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

      await Gal.putImageBytes(imageBytes);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode saved to gallery successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save barcode: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to share barcode
  Future<void> _shareBarcode() async {
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

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/code39_barcode.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'CODE-39 Barcode: $_barcodeData',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share barcode: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBarcode() {
    try {
      return Container(
        width: 350,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: Code39Painter(_barcodeData),
          size: const Size(350, 100),
        ),
      );
    } catch (e) {
      return Container(
        width: 350,
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
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              'Invalid CODE-39: ${e.toString()}',
              style: TextStyle(color: Colors.red, fontSize: 12),
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
            title: const Text('CODE-39 Barcode'),
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
                            'CODE-39 Barcode Generator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'CODE-39 Data',
                              hintText: 'HELLO WORLD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.inventory_2),
                            ),
                            validator: _validateCode39,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CODE-39 supports A-Z, 0-9, and symbols: -, ., \$, /, +, %, and space. Maximum 43 characters.',
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
                                  child: const Text('Generate CODE-39'),
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
                              'CODE-39 Barcode Result:',
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
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
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

// Custom painter for CODE-39 barcode
class Code39Painter extends CustomPainter {
  final String data;
  
  Code39Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      // CODE-39 character patterns (wide = 1, narrow = 0)
      final Map<String, String> patterns = {
        '0': '000110100',  // 0
        '1': '100100001',  // 1
        '2': '001100001',  // 2
        '3': '101100000',  // 3
        '4': '000110001',  // 4
        '5': '100110000',  // 5
        '6': '001110000',  // 6
        '7': '000100101',  // 7
        '8': '100100100',  // 8
        '9': '001100100',  // 9
        'A': '100001001',  // A
        'B': '001001001',  // B
        'C': '101001000',  // C
        'D': '000011001',  // D
        'E': '100011000',  // E
        'F': '001011000',  // F
        'G': '000001101',  // G
        'H': '100001100',  // H
        'I': '001001100',  // I
        'J': '000011100',  // J
        'K': '100000011',  // K
        'L': '001000011',  // L
        'M': '101000010',  // M
        'N': '000010011',  // N
        'O': '100010010',  // O
        'P': '001010010',  // P
        'Q': '000000111',  // Q
        'R': '100000110',  // R
        'S': '001000110',  // S
        'T': '000010110',  // T
        'U': '110000001',  // U
        'V': '011000001',  // V
        'W': '111000000',  // W
        'X': '010010001',  // X
        'Y': '110010000',  // Y
        'Z': '011010000',  // Z
        '-': '010000101',  // -
        '.': '110000100',  // .
        ' ': '011000100',  // Space
        '\$': '010101000', // $
        '/': '010100010', // /
        '+': '010001010', // +
        '%': '000101010', // %
        '*': '010010100', // * (Start/Stop)
      };

      // Validate and clean data
      String cleanData = data.toUpperCase();
      
      // Check if all characters are valid
      for (String char in cleanData.split('')) {
        if (!patterns.containsKey(char)) {
          throw Exception('Invalid character: $char');
        }
      }

      if (cleanData.isEmpty) {
        throw Exception('No valid characters for CODE-39');
      }

      // Build complete barcode pattern with start/stop characters
      List<String> fullPattern = [];
      
      // Start character (*)
      fullPattern.add(patterns['*']!);
      fullPattern.add('0'); // Inter-character space
      
      // Data characters
      for (String char in cleanData.split('')) {
        fullPattern.add(patterns[char]!);
        fullPattern.add('0'); // Inter-character space
      }
      
      // Stop character (*)
      fullPattern.add(patterns['*']!);

      // Calculate bar dimensions
      final double narrowWidth = 2.0; // Narrow bar width
      final double wideWidth = 5.0;   // Wide bar width
      final double spaceWidth = 2.0;  // Inter-character space width
      
      // Calculate total width needed
      double totalWidth = 0;
      for (int i = 0; i < fullPattern.length; i++) {
        String pattern = fullPattern[i];
        if (pattern == '0') {
          totalWidth += spaceWidth;
        } else {
          for (String bit in pattern.split('')) {
            totalWidth += (bit == '1') ? wideWidth : narrowWidth;
          }
        }
      }
      
      // Scale to fit canvas
      final double scale = size.width / totalWidth;
      final double scaledNarrow = narrowWidth * scale;
      final double scaledWide = wideWidth * scale;
      final double scaledSpace = spaceWidth * scale;
      
      // Draw bars
      double currentX = 0;
      bool isBar = true; // CODE-39 starts with a bar
      
      for (int i = 0; i < fullPattern.length; i++) {
        String pattern = fullPattern[i];
        
        if (pattern == '0') {
          // Inter-character space (white)
          currentX += scaledSpace;
        } else {
          // Character pattern
          isBar = true; // Each character starts with a bar
          
          for (String bit in pattern.split('')) {
            double barWidth = (bit == '1') ? scaledWide : scaledNarrow;
            
            if (isBar) {
              // Draw black bar
              canvas.drawRect(
                Rect.fromLTWH(currentX, 0, barWidth, size.height),
                paint,
              );
            }
            // Space (white) - no drawing needed
            
            currentX += barWidth;
            isBar = !isBar; // Alternate between bar and space
          }
        }
      }
      
    } catch (e) {
      // If barcode generation fails, draw error pattern
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
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
