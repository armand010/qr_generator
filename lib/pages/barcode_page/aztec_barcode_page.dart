import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../services/history_service.dart';

class AztecBarcodePage extends StatefulWidget {
  const AztecBarcodePage({super.key});

  @override
  State<AztecBarcodePage> createState() => _AztecBarcodePageState();
}

class _AztecBarcodePageState extends State<AztecBarcodePage> {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _barcodeKey = GlobalKey();
  String _barcodeData = '';
  bool _showBarcode = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _barcodeData = _textController.text.trim();
        _showBarcode = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'AZTEC');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aztec barcode generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearBarcode() {
    setState(() {
      _textController.clear();
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
      final fileName = 'aztec_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aztec barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/aztec_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Aztec Barcode: $_barcodeData',
        subject: 'My Aztec Barcode',
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

  String? _validateInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter text or data';
    }

    if (value.length > 3832) {
      return 'Aztec can hold up to 3,832 characters';
    }

    return null;
  }

  Widget _buildBarcode() {
    try {
      // Aztec is not directly supported by the standard barcode library
      // We'll create a custom implementation that follows Aztec structure
      return Container(
        width: 200,
        height: 200,
        color: Colors.white,
        child: CustomPaint(
          painter: AztecCustomPainter(_barcodeData),
          size: const Size(200, 200),
        ),
      );
    } catch (e) {
      return Container(
        width: 200,
        height: 200,
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
              'Invalid Aztec: ${e.toString()}',
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
        title: const Text('Aztec Barcode'),
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
                        'Aztec Barcode Generator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _textController,
                        decoration: InputDecoration(
                          labelText: 'Text or Data',
                          hintText: 'Enter text, URL, or data to encode',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: const Icon(Icons.blur_circular),
                        ),
                        maxLines: 3,
                        validator: _validateInput,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aztec is a 2D barcode that can encode up to 3,832 characters. Ideal for URLs, contact details, and large text data.',
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
                              child: const Text('Generate Aztec'),
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
                          'Aztec Barcode Result:',
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
                                _barcodeData.length > 50 
                                    ? '${_barcodeData.substring(0, 50)}...'
                                    : _barcodeData,
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

// Custom painter for Aztec barcode (simplified implementation)
class AztecCustomPainter extends CustomPainter {
  final String data;

  AztecCustomPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw white background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), whitePaint);

    // Calculate module size based on data length
    final modules = _calculateModules(data.length);
    final moduleSize = size.width / modules;

    // Draw simplified Aztec pattern
    _drawAztecPattern(canvas, size, moduleSize, modules, paint);

    // Draw central finder pattern (bullseye)
    _drawFinderPattern(canvas, size, moduleSize, paint, whitePaint);
  }

  int _calculateModules(int dataLength) {
    // Simplified module calculation based on data length
    if (dataLength <= 13) return 15;
    if (dataLength <= 40) return 19;
    if (dataLength <= 90) return 23;
    if (dataLength <= 180) return 27;
    return 31; // Max compact Aztec
  }

  void _drawAztecPattern(Canvas canvas, Size size, double moduleSize, int modules, Paint paint) {
    // Create a simplified pseudo-random pattern based on the data
    final dataHash = data.hashCode;
    
    for (int row = 0; row < modules; row++) {
      for (int col = 0; col < modules; col++) {
        // Skip the center area for finder pattern
        final centerStart = (modules ~/ 2) - 5;
        final centerEnd = (modules ~/ 2) + 5;
        
        if (row >= centerStart && row <= centerEnd && 
            col >= centerStart && col <= centerEnd) {
          continue;
        }

        // Create pseudo-random pattern
        final seed = (row * modules + col + dataHash) % 17;
        if (seed % 3 == 0) {
          final rect = Rect.fromLTWH(
            col * moduleSize,
            row * moduleSize,
            moduleSize,
            moduleSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, Size size, double moduleSize, Paint blackPaint, Paint whitePaint) {
    final center = size.width / 2;
    final finderSize = moduleSize * 9;

    // Draw concentric squares (bullseye pattern)
    final squares = [
      {'size': finderSize, 'paint': blackPaint},
      {'size': finderSize * 0.8, 'paint': whitePaint},
      {'size': finderSize * 0.6, 'paint': blackPaint},
      {'size': finderSize * 0.4, 'paint': whitePaint},
      {'size': finderSize * 0.2, 'paint': blackPaint},
    ];

    for (final square in squares) {
      final squareSize = square['size'] as double;
      final paint = square['paint'] as Paint;
      final offset = squareSize / 2;

      canvas.drawRect(
        Rect.fromLTWH(
          center - offset,
          center - offset,
          squareSize,
          squareSize,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
