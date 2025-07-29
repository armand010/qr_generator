import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:barcode/barcode.dart';
import '../../services/history_service.dart';

class DataMatrixBarcodePage extends StatefulWidget {
  const DataMatrixBarcodePage({super.key});

  @override
  State<DataMatrixBarcodePage> createState() => _DataMatrixBarcodePageState();
}

class _DataMatrixBarcodePageState extends State<DataMatrixBarcodePage> {
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
      HistoryService().addGeneratedItem(content: _barcodeData, format: 'DATA_MATRIX');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data Matrix barcode generated successfully!'),
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
      final fileName = 'datamatrix_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data Matrix barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/datamatrix_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Data Matrix Barcode: $_barcodeData',
        subject: 'My Data Matrix Barcode',
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

    if (value.length > 3116) {
      return 'Data Matrix can hold up to 3,116 characters';
    }

    return null;
  }

  Widget _buildBarcode() {
    try {
      // Create Data Matrix barcode using the barcode library
      final bc = Barcode.dataMatrix();
      
      // Validate the data first
      if (!bc.isValid(_barcodeData)) {
        throw Exception('Invalid Data Matrix data');
      }
      
      return Container(
        width: 200,
        height: 200,
        color: Colors.white,
        child: CustomPaint(
          painter: BarcodeLibraryPainter(bc, _barcodeData),
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
              'Invalid Data Matrix: ${e.toString()}',
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
        title: const Text('Data Matrix Barcode'),
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
                        'Data Matrix Barcode Generator',
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
                          prefixIcon: const Icon(Icons.grid_on),
                        ),
                        maxLines: 3,
                        validator: _validateInput,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Data Matrix is a 2D barcode that can encode up to 3,116 characters. Ideal for product information, URLs, and contact details.',
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
                              child: const Text('Generate Data Matrix'),
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
                          'Data Matrix Barcode Result:',
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

      // Only draw black rectangles (bars/modules)
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
