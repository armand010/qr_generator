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

class GenericBarcodePage extends StatefulWidget {
  final String barcodeType;
  final String title;
  final String description;
  final String hintText;
  final IconData icon;

  const GenericBarcodePage({
    super.key,
    required this.barcodeType,
    required this.title,
    required this.description,
    required this.hintText,
    required this.icon,
  });

  @override
  State<GenericBarcodePage> createState() => _GenericBarcodePageState();
}

class _GenericBarcodePageState extends State<GenericBarcodePage> {
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
        SnackBar(
          content: Text('${widget.barcodeType} barcode generated successfully!'),
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
      final fileName = '${widget.barcodeType.toLowerCase()}_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.barcodeType} barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/${widget.barcodeType.toLowerCase()}_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.barcodeType} Barcode: $_barcodeData',
        subject: 'My ${widget.barcodeType} Barcode',
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
        width: 320,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: GenericBarcodePainter(_barcodeData, widget.barcodeType),
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
              'Invalid ${widget.barcodeType}',
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
            title: Text('${widget.barcodeType} Barcode'),
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
                            widget.title,
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
                              labelText: '${widget.barcodeType} Code',
                              hintText: widget.hintText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Icon(widget.icon),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter ${widget.barcodeType} code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.description,
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
                                  child: Text('Generate ${widget.barcodeType}'),
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
                              '${widget.barcodeType} Barcode Result:',
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

// Generic barcode painter with simple scannable patterns
class GenericBarcodePainter extends CustomPainter {
  final String data;
  final String barcodeType;
  
  GenericBarcodePainter(this.data, this.barcodeType);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Draw white background first
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      // Use simplified CODE-128 implementation for all generic barcodes
      List<bool> barPattern = _generateSimpleCode128Pattern();
      
      // Draw barcode with proper quiet zones
      final int totalModules = barPattern.length + 20; // 10 modules each side
      final double moduleWidth = size.width / totalModules;
      final double barHeight = size.height;
      
      double currentX = 10 * moduleWidth; // Start after left quiet zone
      
      for (int i = 0; i < barPattern.length; i++) {
        if (barPattern[i]) {
          canvas.drawRect(
            Rect.fromLTWH(currentX, 0, moduleWidth, barHeight),
            paint,
          );
        }
        currentX += moduleWidth;
      }
      
    } catch (e) {
      // Draw error pattern if something goes wrong
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
      
      // Draw X to indicate error
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

  List<bool> _generateSimpleCode128Pattern() {
    // Simplified CODE-128 implementation yang lebih mudah di-scan
    List<bool> pattern = [];
    
    // Start Code B: 11010010000 (pattern untuk value 104)
    pattern.addAll([true, true, false, true, false, false, true, false, false, false, false]);
    
    // Code 128 patterns untuk karakter ASCII 32-127 (Code Set B)
    final List<String> code128Patterns = [
      '11011001100', // 32 (space)
      '11001101100', // 33 !
      '11001100110', // 34 "
      '10010011000', // 35 #
      '10010001100', // 36 $
      '10001001100', // 37 %
      '10011001000', // 38 &
      '10011000100', // 39 '
      '10001100100', // 40 (
      '11001001000', // 41 )
      '11001000100', // 42 *
      '11000100100', // 43 +
      '10110011100', // 44 ,
      '10011011100', // 45 -
      '10011001110', // 46 .
      '10111001100', // 47 /
      '10011101100', // 48 0
      '10011100110', // 49 1
      '11001110010', // 50 2
      '11001011100', // 51 3
      '11001001110', // 52 4
      '11011100100', // 53 5
      '11001110100', // 54 6
      '11101101110', // 55 7
      '11101001100', // 56 8
      '11100101100', // 57 9
      '11100100110', // 58 :
      '11101100100', // 59 ;
      '11100110100', // 60 <
      '11100110010', // 61 =
      '11011011000', // 62 >
      '11011000110', // 63 ?
      '11000110110', // 64 @
      '10100011000', // 65 A
      '10001011000', // 66 B
      '10001000110', // 67 C
      '10110001000', // 68 D
      '10001101000', // 69 E
      '10001100010', // 70 F
      '11010001000', // 71 G
      '11000101000', // 72 H
      '11000100010', // 73 I
      '10110111000', // 74 J
      '10110001110', // 75 K
      '10001101110', // 76 L
      '10111011000', // 77 M
      '10111000110', // 78 N
      '10001110110', // 79 O
      '11101110110', // 80 P
      '11010001110', // 81 Q
      '11000101110', // 82 R
      '11011101000', // 83 S
      '11011100010', // 84 T
      '11011101110', // 85 U
      '11101011000', // 86 V
      '11101000110', // 87 W
      '11100010110', // 88 X
      '11101101000', // 89 Y
      '11101100010', // 90 Z
    ];
    
    int checksum = 104; // Start Code B value
    
    // Encode each character
    for (int i = 0; i < data.length && i < 20; i++) {
      int charCode = data[i].codeUnitAt(0);
      int patternIndex;
      
      // Convert to Code 128 Set B index (ASCII 32-127 -> index 0-95)
      if (charCode >= 32 && charCode <= 127) {
        patternIndex = charCode - 32;
      } else {
        // Fallback for non-ASCII characters
        patternIndex = (charCode % 96);
      }
      
      // Ensure we have a pattern for this index
      if (patternIndex < code128Patterns.length) {
        String digitPattern = code128Patterns[patternIndex];
        for (int j = 0; j < digitPattern.length; j++) {
          pattern.add(digitPattern[j] == '1');
        }
        
        // Add to checksum
        checksum += patternIndex * (i + 1);
      }
    }
    
    // Calculate final checksum
    checksum = checksum % 103;
    
    // Add checksum pattern
    if (checksum < code128Patterns.length) {
      String checksumPattern = code128Patterns[checksum];
      for (int j = 0; j < checksumPattern.length; j++) {
        pattern.add(checksumPattern[j] == '1');
      }
    }
    
    // Stop pattern: 1100011101011
    pattern.addAll([true, true, false, false, false, true, true, true, false, true, false, true, true]);
    
    return pattern;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is GenericBarcodePainter && 
           (oldDelegate.data != data || oldDelegate.barcodeType != barcodeType);
  }
}
