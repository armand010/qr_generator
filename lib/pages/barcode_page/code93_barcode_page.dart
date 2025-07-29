import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../services/history_service.dart';

class Code93BarcodePage extends StatefulWidget {
  const Code93BarcodePage({super.key});

  @override
  State<Code93BarcodePage> createState() => _Code93BarcodePageState();
}

class _Code93BarcodePageState extends State<Code93BarcodePage> {
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
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'CODE_93');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-93 barcode generated successfully!'),
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
      final fileName = 'code93_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CODE-93 barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/code93_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'CODE-93 Barcode: $_barcodeData',
        subject: 'My CODE-93 Barcode',
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

  String? _validateCode93(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter CODE-93 data';
    }

    // CODE-93 supports: A-Z, 0-9, and symbols: - . $ / + % SPACE
    // Plus additional control characters but we'll keep it simple
    final validPattern = RegExp(r'^[A-Z0-9\-\.\$\/\+%\s]*$');
    
    if (!validPattern.hasMatch(value.toUpperCase())) {
      return 'CODE-93 supports only: A-Z, 0-9, -, ., \$, /, +, %, and space';
    }

    if (value.length > 47) {
      return 'CODE-93 typically supports up to 47 characters';
    }

    return null;
  }

  Widget _buildBarcode() {
    try {
      return Container(
        width: 350,
        height: 100,
        color: Colors.white,
        child: CustomPaint(
          painter: Code93Painter(_barcodeData),
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
              'Invalid CODE-93: ${e.toString()}',
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: const Text('CODE-93 Barcode'),
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
                        'CODE-93 Barcode Generator',
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
                          labelText: 'CODE-93 Data',
                          hintText: 'Enter alphanumeric data',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: const Icon(Icons.view_stream),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: _validateCode93,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CODE-93 supports alphanumeric characters (A-Z, 0-9) and symbols (-, ., \$, /, +, %, space). Up to 47 characters.',
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
                              child: const Text('Generate CODE-93'),
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
                          'CODE-93 Barcode Result:',
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

// Custom painter for CODE-93 barcode
class Code93Painter extends CustomPainter {
  final String data;
  
  Code93Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      // CODE-93 character patterns (correct patterns for each character)
      final Map<String, String> patterns = {
        '0': '100010100',  // 0
        '1': '101001000',  // 1
        '2': '101000100',  // 2
        '3': '101000010',  // 3
        '4': '100101000',  // 4
        '5': '100100100',  // 5
        '6': '100100010',  // 6
        '7': '101010000',  // 7
        '8': '100010010',  // 8
        '9': '100001010',  // 9
        'A': '110101000',  // A
        'B': '110100100',  // B
        'C': '110100010',  // C
        'D': '110010100',  // D
        'E': '110010010',  // E
        'F': '110001010',  // F
        'G': '101101000',  // G
        'H': '101100100',  // H
        'I': '101100010',  // I
        'J': '100110100',  // J
        'K': '100011010',  // K
        'L': '101011000',  // L
        'M': '101001100',  // M
        'N': '101001010',  // N
        'O': '100101100',  // O
        'P': '100010110',  // P
        'Q': '110110100',  // Q
        'R': '110110010',  // R
        'S': '110101100',  // S
        'T': '110100110',  // T
        'U': '110010110',  // U
        'V': '110011010',  // V
        'W': '101101100',  // W
        'X': '101100110',  // X
        'Y': '100110110',  // Y
        'Z': '100111010',  // Z
        '-': '100101001',  // -
        '.': '101010001',  // .
        ' ': '101001001',  // Space
        '\$': '101100001', // $
        '/': '100100001', // /
        '+': '100010001', // +
        '%': '110010001', // %
      };

      // Start/Stop pattern for CODE-93
      const String startStopPattern = '101011110';

      // Validate and clean data
      String cleanData = data.toUpperCase();
      
      // Check if all characters are valid
      for (String char in cleanData.split('')) {
        if (!patterns.containsKey(char)) {
          throw Exception('Invalid character: $char');
        }
      }

      if (cleanData.isEmpty) {
        throw Exception('No valid characters for CODE-93');
      }

      // Calculate check digits (C and K)
      String checkC = _calculateCheckDigit(cleanData, 1, 20);
      String checkK = _calculateCheckDigit(cleanData + checkC, 1, 15);

      // Build complete barcode pattern
      String fullPattern = '';
      
      // Start character
      fullPattern += startStopPattern;
      
      // Data characters
      for (String char in cleanData.split('')) {
        fullPattern += patterns[char]!;
      }
      
      // Check digits
      fullPattern += patterns[checkC]!;
      fullPattern += patterns[checkK]!;
      
      // Stop character
      fullPattern += startStopPattern;
      
      // Termination bar
      fullPattern += '1';

      // Draw bars with proper scaling
      final double totalBars = fullPattern.length.toDouble();
      final double barWidth = (size.width / totalBars).clamp(1.0, 4.0);
      
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

  // Calculate CODE-93 check digit using correct algorithm
  String _calculateCheckDigit(String data, int start, int modulo) {
    // Character value mapping for CODE-93
    final List<String> characters = [
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
      'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
      'U', 'V', 'W', 'X', 'Y', 'Z', '-', '.', ' ', '\$',
      '/', '+', '%'
    ];
    
    final Map<String, int> charToValue = {};
    for (int i = 0; i < characters.length; i++) {
      charToValue[characters[i]] = i;
    }

    int sum = 0;
    int weight = start;
    
    // Calculate from right to left
    for (int i = data.length - 1; i >= 0; i--) {
      String char = data[i];
      int value = charToValue[char] ?? 0;
      sum += value * weight;
      weight++;
      if (weight > modulo) {
        weight = 1;
      }
    }
    
    int checkValue = sum % 47;
    return characters[checkValue];
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
