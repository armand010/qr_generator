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

class Code128BarcodePage extends StatefulWidget {
  const Code128BarcodePage({super.key});

  @override
  State<Code128BarcodePage> createState() => _Code128BarcodePageState();
}

class _Code128BarcodePageState extends State<Code128BarcodePage> {
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
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'CODE_128');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-128 barcode generated successfully!'),
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
      final fileName = 'code128_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-128 barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/code128_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'CODE-128 Barcode: $_barcodeData',
        subject: 'My CODE-128 Barcode',
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
            RepaintBoundary(
              key: _barcodeKey,
              child: Container(
                width: 320,
                height: 100,
                color: Colors.white,
                child: CustomPaint(
                  painter: Code128Painter(_barcodeData),
                  size: const Size(320, 100),
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
              'Invalid CODE-128',
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
            title: const Text('CODE-128 Barcode'),
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
                            'CODE-128 Barcode Generator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            maxLines: 2,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(80),
                            ],
                            decoration: InputDecoration(
                              labelText: 'CODE-128 Text',
                              hintText: 'Hello World 123!@#',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.code),
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter text for CODE-128';
                              }
                              if (value.length > 80) {
                                return 'CODE-128 text must be 80 characters or less';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CODE-128 supports all ASCII characters (0-127). Most compact barcode for alphanumeric data.',
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
                                  child: const Text('Generate CODE-128'),
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
                              'CODE-128 Barcode Result:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBarcode(),
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

// Custom painter for CODE-128 barcode
class Code128Painter extends CustomPainter {
  final String data;
  
  Code128Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      // CODE-128 Code Set B patterns (values 32-127)
      final List<String> patterns = [
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
        '11100011010', // 91 [
        '11101111010', // 92 \
        '11001000010', // 93 ]
        '11110001010', // 94 ^
        '10100110000', // 95 _
        '10100001100', // 96 `
        '10010110000', // 97 a
        '10010000110', // 98 b
        '10000101100', // 99 c
        '10000100110', // 100 d
        '10110010000', // 101 e
        '10110000100', // 102 f
        '10011010000', // 103 g
        '10011000010', // 104 h
        '10000110100', // 105 i
        '10000110010', // 106 j
        '11000010010', // 107 k
        '11001010000', // 108 l
        '11110111010', // 109 m
        '11000010100', // 110 n
        '10001111010', // 111 o
        '10100111100', // 112 p
        '10010111100', // 113 q
        '10010011110', // 114 r
        '10111100100', // 115 s
        '10011110100', // 116 t
        '10011110010', // 117 u
        '11110100100', // 118 v
        '11110010100', // 119 w
        '11110010010', // 120 x
        '11011011110', // 121 y
        '11011110110', // 122 z
        '11110110110', // 123 {
        '10101111000', // 124 |
        '10100011110', // 125 }
        '10001011110', // 126 ~
        '10111101000', // 127 DEL
      ];

      // Start Code B pattern (value 104)
      const String startB = '11010010000';
      // Stop pattern
      const String stop = '1100011101011';

      // Filter data to only include valid ASCII characters (32-126)
      String validData = '';
      for (int i = 0; i < data.length; i++) {
        final char = data[i];
        final ascii = char.codeUnitAt(0);
        if (ascii >= 32 && ascii <= 126) {
          validData += char;
        }
      }

      if (validData.isEmpty) {
        throw Exception('No valid characters for CODE-128');
      }

      // Calculate checksum
      int checksum = 104; // Start Code B value
      for (int i = 0; i < validData.length; i++) {
        final char = validData[i];
        int value = char.codeUnitAt(0) - 32; // Convert to pattern index
        checksum += value * (i + 1);
      }
      checksum = checksum % 103;

      // Build complete barcode pattern
      String fullPattern = startB;
      
      // Add data patterns
      for (String char in validData.split('')) {
        final ascii = char.codeUnitAt(0);
        final patternIndex = ascii - 32;
        if (patternIndex >= 0 && patternIndex < patterns.length) {
          fullPattern += patterns[patternIndex];
        }
      }
      
      // Add checksum pattern
      if (checksum < patterns.length) {
        fullPattern += patterns[checksum];
      }
      
      // Add stop pattern
      fullPattern += stop;

      // Draw bars with minimum width for readability
      final double totalBars = fullPattern.length.toDouble();
      final double barWidth = (size.width / totalBars).clamp(1.0, 5.0);
      
      double currentX = 0;
      for (int i = 0; i < fullPattern.length; i++) {
        if (fullPattern[i] == '1') {
          final rect = Rect.fromLTWH(
            currentX,
            0,
            barWidth,
            size.height,
          );
          canvas.drawRect(rect, paint);
        }
        currentX += barWidth;
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
