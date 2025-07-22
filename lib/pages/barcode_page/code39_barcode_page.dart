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
      final fileName = 'code39_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-39 barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/code39_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'CODE-39 Barcode: $_barcodeData',
        subject: 'My CODE-39 Barcode',
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
                  painter: Code39Painter(_barcodeData),
                  size: const Size(300, 100),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '*$_barcodeData*',
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
              'Invalid CODE-39',
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
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-\.\s\$\/\+%]')),
                              LengthLimitingTextInputFormatter(30),
                            ],
                            decoration: InputDecoration(
                              labelText: 'CODE-39 Text',
                              hintText: 'HELLO WORLD 123',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.code),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter text for CODE-39';
                              }
                              if (value.length > 30) {
                                return 'CODE-39 text must be 30 characters or less';
                              }
                              // Check for valid CODE-39 characters
                              final validChars = RegExp(r'^[A-Z0-9\-\.\s\$\/\+%]*$');
                              if (!validChars.hasMatch(value.toUpperCase())) {
                                return 'Only letters, numbers, space, -, ., \$, /, +, % allowed';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CODE-39 supports uppercase letters (A-Z), numbers (0-9), and special characters: - . space \$ / + %',
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

      // CODE-39 encoding patterns (narrow=0, wide=1)
      final Map<String, String> patterns = {
        'A': '100101001', 'B': '001101001', 'C': '101101001',
        'D': '000111001', 'E': '100111001', 'F': '001111001',
        'G': '000101101', 'H': '100101101', 'I': '001101101',
        'J': '000111101', 'K': '100100011', 'L': '001100011',
        'M': '101100011', 'N': '000110011', 'O': '100110011',
        'P': '001110011', 'Q': '000100111', 'R': '100100111',
        'S': '001100111', 'T': '000110111', 'U': '110000001',
        'V': '011000001', 'W': '111000001', 'X': '010010001',
        'Y': '110010001', 'Z': '011010001',
        '0': '000110100', '1': '100100001', '2': '001100001',
        '3': '101100001', '4': '000110001', '5': '100110001',
        '6': '001110001', '7': '000100101', '8': '100100101',
        '9': '001100101',
        '-': '010000101', '.': '110000101', ' ': '011000101',
        '*': '010010100', // Start/Stop character
      };

      final fullData = '*$data*'; // Add start/stop characters
      final List<bool> barData = [];
      
      for (int i = 0; i < fullData.length; i++) {
        final char = fullData[i];
        final pattern = patterns[char];
        if (pattern != null) {
          // Add bars for this character
          for (int j = 0; j < pattern.length; j++) {
            if (j % 2 == 0) { // Bar
              if (pattern[j] == '1') {
                // Wide bar
                barData.addAll([true, true, true]);
              } else {
                // Narrow bar
                barData.add(true);
              }
            } else { // Space
              if (pattern[j] == '1') {
                // Wide space
                barData.addAll([false, false, false]);
              } else {
                // Narrow space
                barData.add(false);
              }
            }
          }
          // Inter-character gap (if not last character)
          if (i < fullData.length - 1) {
            barData.add(false);
          }
        }
      }
      
      // Draw barcode
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
