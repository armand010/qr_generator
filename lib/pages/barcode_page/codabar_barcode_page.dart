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

class CODABARBarcodePage extends StatefulWidget {
  const CODABARBarcodePage({super.key});

  @override
  State<CODABARBarcodePage> createState() => _CODABARBarcodePageState();
}

class _CODABARBarcodePageState extends State<CODABARBarcodePage> {
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
      HistoryService().addGeneratedItem(
        content: _barcodeData,
        format: 'CODABAR',
        category: 'barcode',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODABAR barcode generated successfully!'),
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
      final fileName = 'codabar_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODABAR barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/codabar_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'CODABAR Barcode: $_barcodeData',
        subject: 'My CODABAR Barcode',
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
      // Create CODABAR barcode using the barcode library
      final bc = Barcode.codabar();
      
      // Validate the data first
      if (!bc.isValid(_barcodeData)) {
        throw Exception('Invalid CODABAR data');
      }
      
      return Container(
        width: 320,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: BarcodeLibraryPainter(bc, _barcodeData),
          size: const Size(320, 100),
        ),
      );
    } catch (e) {
      return Container(
        width: 320,
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
              'Invalid CODABAR: ${e.toString()}',
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
            title: const Text('CODABAR Barcode'),
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
                            'CODABAR Barcode Generator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-dA-D0-9\$\-\+\.\/\:]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: InputDecoration(
                              labelText: 'CODABAR Data',
                              hintText: 'A1234567890B',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.medical_information),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CODABAR data';
                              }
                              
                              String upper = value.toUpperCase();
                              
                              // Check start and stop characters
                              if (!RegExp(r'^[A-D]').hasMatch(upper)) {
                                return 'Must start with A, B, C, or D';
                              }
                              if (!RegExp(r'[A-D]$').hasMatch(upper)) {
                                return 'Must end with A, B, C, or D';
                              }
                              
                              // Check valid characters
                              if (!RegExp(r'^[A-D0-9\$\-\+\.\/\:]+$').hasMatch(upper)) {
                                return 'Invalid characters. Use: 0-9, A-D, \$, -, +, ., /, :';
                              }
                              
                              if (value.length < 3) {
                                return 'CODABAR must be at least 3 characters';
                              }
                              
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CODABAR is used in libraries, blood banks, and photo labs. Format: [A-D][0-9/\$/-/+/./:/][A-D]\nExample: A123456789B',
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
                                  child: const Text('Generate CODABAR'),
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
                              'CODABAR Barcode Result:',
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
                                    key: _barcodeKey,
                                    child: _buildBarcode(),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _barcodeData,
                                    style: const TextStyle(
                                      fontSize: 14,
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

// Custom painter using the barcode library
class BarcodeLibraryPainter extends CustomPainter {
  final Barcode barcode;
  final String data;

  BarcodeLibraryPainter(this.barcode, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Generate the barcode data
      final svg = barcode.toSvg(data, width: size.width, height: size.height);
      
      // Parse and draw the barcode
      _drawBarcodeFromSvg(canvas, size, svg);
    } catch (e) {
      // Draw error message if barcode generation fails
      _drawError(canvas, size, e.toString());
    }
  }

  void _drawBarcodeFromSvg(Canvas canvas, Size size, String svg) {
    // Simple SVG parsing for barcode rectangles
    final rectPattern = RegExp(r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"[^>]*fill="([^"]*)"[^>]*/>');
    final matches = rectPattern.allMatches(svg);

    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (final match in matches) {
      final x = double.tryParse(match.group(1) ?? '0') ?? 0;
      final y = double.tryParse(match.group(2) ?? '0') ?? 0;
      final width = double.tryParse(match.group(3) ?? '0') ?? 0;
      final height = double.tryParse(match.group(4) ?? '0') ?? 0;
      final fill = match.group(5) ?? '#000000';

      // Only draw black rectangles (bars)
      if (fill == '#000000' || fill == 'black') {
        paint.color = Colors.black;
        canvas.drawRect(
          Rect.fromLTWH(x, y, width, height),
          paint,
        );
      }
    }
  }

  void _drawError(Canvas canvas, Size size, String error) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.red.shade100,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Error: $error',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter for CODABAR barcode
class CODABARPainter extends CustomPainter {
  final String data;
  
  CODABARPainter(this.data);

  // CODABAR standard character patterns according to ANSI/AIM BC3-1995
  // Each pattern: [bar, space, bar, space, bar, space, bar]
  // 0 = narrow (1x), 1 = wide (2.25x to 3x ratio)
  static const Map<String, String> _patterns = {
    '0': '0000011',  // NNNNNWW
    '1': '0000110',  // NNNNWWN  
    '2': '0001001',  // NNNWNWN
    '3': '1100000',  // WWNNNNN
    '4': '0010010',  // NNWNWNN
    '5': '1000010',  // WNNNWNN
    '6': '0100001',  // NWNNNNW
    '7': '0100100',  // NWNNWNN
    '8': '0110000',  // NWWNNNNN
    '9': '1001000',  // WNNWNNNN
    '-': '0001100',  // NNNWWNN
    '\$': '0011000',  // NNWWNNN
    ':': '1000101',  // WNNWNWN
    '/': '1010001',  // WNWNNNW
    '.': '1010100',  // WNWNWNN
    '+': '0010101',  // NNWNWNW
    'A': '0011001',  // NNWWNWN (start/stop)
    'B': '0101001',  // NWNWNWN (start/stop)
    'C': '0001011',  // NNNWNWW (start/stop)
    'D': '0001110',  // NNNWWWN (start/stop)
  };

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Draw white background
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      // Calculate dimensions with proper quiet zones
      double barHeight = size.height * 0.7;
      double startY = size.height * 0.15;
      
      // Draw barcode with proper CODABAR encoding
      _drawCODABARBarcode(canvas, size, paint, barHeight, startY);
      
    } catch (e) {
      _drawError(canvas, size);
    }
  }
  
  void _drawCODABARBarcode(Canvas canvas, Size size, Paint paint, double barHeight, double startY) {
    if (data.isEmpty) return;
    
    // Calculate total width units needed (considering wide/narrow ratios)
    double totalWidthUnits = 0;
    
    // Add quiet zones (10 narrow units each side)
    totalWidthUnits += 20;
    
    // Calculate width for each character
    for (int i = 0; i < data.length; i++) {
      String char = data[i].toUpperCase();
      if (_patterns.containsKey(char)) {
        String pattern = _patterns[char]!;
        
        // Each character has 7 elements, calculate total width units
        for (int j = 0; j < pattern.length; j++) {
          bool isWide = pattern[j] == '1';
          totalWidthUnits += isWide ? 2.5 : 1.0; // Wide:Narrow ratio = 2.5:1
        }
        
        // Add inter-character gap (1 narrow unit)
        if (i < data.length - 1) {
          totalWidthUnits += 1.0;
        }
      }
    }
    
    // Calculate narrow module width to fit within barcode area
    double availableWidth = size.width * 0.9; // Use 90% of width, leave 5% margin each side
    double narrowModuleWidth = availableWidth / totalWidthUnits;
    
    // Start drawing from left margin
    double currentX = size.width * 0.05; // 5% left margin
    
    // Add left quiet zone (10 narrow modules)
    currentX += narrowModuleWidth * 10;
    
    // Draw each character
    for (int i = 0; i < data.length; i++) {
      String char = data[i].toUpperCase();
      
      if (!_patterns.containsKey(char)) continue;
      
      String pattern = _patterns[char]!;
      
      // Draw the 7 elements (bar-space-bar-space-bar-space-bar)
      for (int j = 0; j < pattern.length; j++) {
        bool isWide = pattern[j] == '1';
        double elementWidth = narrowModuleWidth * (isWide ? 2.5 : 1.0);
        
        // Draw bars on even positions (0, 2, 4, 6) - bars
        // Skip odd positions (1, 3, 5) - spaces
        if (j % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(currentX, startY, elementWidth, barHeight),
            paint,
          );
        }
        
        currentX += elementWidth;
      }
      
      // Add inter-character gap (1 narrow module)
      if (i < data.length - 1) {
        currentX += narrowModuleWidth;
      }
    }
  }
  
  void _drawError(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CODABARPainter && oldDelegate.data != data;
  }
}
