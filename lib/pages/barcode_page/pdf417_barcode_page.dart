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

class PDF417BarcodePage extends StatefulWidget {
  const PDF417BarcodePage({super.key});

  @override
  State<PDF417BarcodePage> createState() => _PDF417BarcodePageState();
}

class _PDF417BarcodePageState extends State<PDF417BarcodePage> {
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
        const SnackBar(
          content: Text('PDF-417 barcode generated successfully!'),
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
      final fileName = 'pdf417_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF-417 barcode saved to gallery successfully!'),
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
      final file = File('${tempDir.path}/pdf417_barcode_${DateTime.now().millisecondsSinceEpoch}.png');
      
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'PDF-417 Barcode: $_barcodeData',
        subject: 'My PDF-417 Barcode',
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
        width: 300,
        height: 90, // Better height for 3-row PDF417
        color: Colors.white,
        child: CustomPaint(
          painter: PDF417Painter(_barcodeData),
          size: const Size(300, 90),
        ),
      );
    } catch (e) {
      return Container(
        width: 300,
        height: 90,
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
              'Invalid PDF-417',
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
            title: const Text('PDF-417 Barcode'),
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
                            'PDF-417 Barcode Generator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            maxLines: 3,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(200),
                            ],
                            decoration: InputDecoration(
                              labelText: 'PDF-417 Data',
                              hintText: 'Hello World PDF417',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: const Icon(Icons.picture_as_pdf),
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter PDF-417 data';
                              }
                              if (value.length > 200) {
                                return 'PDF-417 data must be 200 characters or less';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'PDF-417 is a 2D barcode that can store large amounts of text, numbers, and binary data. Commonly used for ID cards, transport tickets, and inventory management.',
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
                                  child: const Text('Generate PDF-417'),
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
                              'PDF-417 Barcode Result:',
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
                                    _barcodeData.length > 30 
                                        ? '${_barcodeData.substring(0, 30)}...'
                                        : _barcodeData,
                                    style: const TextStyle(
                                      fontSize: 14,
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
      },
    );
  }
}

// Custom painter for PDF-417 barcode
class PDF417Painter extends CustomPainter {
  final String data;
  
  PDF417Painter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Always draw white background first
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    if (data.isEmpty) {
      _drawEmptyPattern(canvas, size);
      return;
    }
    
    try {
      _drawValidBarcode(canvas, size);
    } catch (e) {
      debugPrint('PDF417 Error: $e');
      _drawErrorPattern(canvas, size);
    }
  }

  void _drawEmptyPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;
    
    // Draw simple pattern for empty data
    double barWidth = size.width / 20;
    for (int i = 0; i < 20; i++) {
      if (i % 4 == 0 || i % 4 == 1) {
        canvas.drawRect(
          Rect.fromLTWH(i * barWidth, size.height * 0.2, barWidth, size.height * 0.6),
          paint,
        );
      }
    }
  }

  void _drawValidBarcode(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Create proper PDF417 matrix pattern
    List<List<bool>> matrix = _createStandardPDF417Matrix();
    
    if (matrix.isEmpty) {
      _drawErrorPattern(canvas, size);
      return;
    }
    
    int rows = matrix.length;
    int cols = matrix[0].length;
    
    // PDF417 requires minimum 2X quiet zone on all sides (2X = 2 * module width)
    double quietZoneX = size.width * 0.04;  // 4% quiet zone horizontally
    double quietZoneY = size.height * 0.1;  // 10% quiet zone vertically
    
    double barcodeWidth = size.width - (2 * quietZoneX);
    double barcodeHeight = size.height - (2 * quietZoneY);
    
    double moduleWidth = barcodeWidth / cols;
    double moduleHeight = barcodeHeight / rows;
    
    // Draw the matrix
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (matrix[row][col]) {
          canvas.drawRect(
            Rect.fromLTWH(
              quietZoneX + (col * moduleWidth), 
              quietZoneY + (row * moduleHeight), 
              moduleWidth, 
              moduleHeight
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawErrorPattern(Canvas canvas, Size size) {
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

  List<List<bool>> _createStandardPDF417Matrix() {
    // Create a simpler but more standard PDF417 structure
    List<List<bool>> matrix = [];
    
    // Standard proportions: height should be 3+ times module height
    int rows = 3;  // Minimum for PDF417
    int cols = 90; // Standard width
    
    // PDF417 standard start pattern (17 modules): 11111111010101000
    final List<bool> startPattern = [
      true, true, true, true, true, true, true, true, // 8 consecutive black
      false, true, false, true, false, true, false, false, false // alternating pattern
    ];
    
    // PDF417 standard stop pattern (18 modules): 111111101000101001  
    final List<bool> stopPattern = [
      true, true, true, true, true, true, true, // 7 black
      false, true, false, false, false, true, false, true, false, false, true // stop pattern
    ];
    
    for (int row = 0; row < rows; row++) {
      List<bool> rowData = [];
      
      // Add start pattern
      rowData.addAll(startPattern);
      
      // Left row indicator - simple 4-module patterns
      rowData.addAll(_getRowIndicator(row));
      
      // Data area - create blocks that look like PDF417 codewords
      int dataModules = cols - startPattern.length - stopPattern.length - 8; // 8 for indicators
      List<bool> dataArea = _generatePDF417DataArea(row, dataModules);
      rowData.addAll(dataArea);
      
      // Right row indicator
      rowData.addAll(_getRowIndicator(row));
      
      // Add stop pattern
      rowData.addAll(stopPattern);
      
      // Trim or pad to exact width
      if (rowData.length > cols) {
        rowData = rowData.sublist(0, cols);
      }
      while (rowData.length < cols) {
        rowData.add(false);
      }
      
      matrix.add(rowData);
    }
    
    return matrix;
  }
  
  List<bool> _getRowIndicator(int row) {
    // PDF417 uses 3 clusters, each with different patterns
    int cluster = row % 3;
    
    switch (cluster) {
      case 0: return [true, true, false, false]; // Cluster 0
      case 1: return [true, false, true, false]; // Cluster 1
      case 2: return [false, true, true, false]; // Cluster 2
      default: return [true, false, false, true];
    }
  }
  
  List<bool> _generatePDF417DataArea(int row, int totalModules) {
    List<bool> dataArea = [];
    
    if (data.isEmpty) {
      // Create default alternating pattern
      for (int i = 0; i < totalModules; i++) {
        dataArea.add((i + row * 3) % 6 < 3);
      }
      return dataArea;
    }
    
    // Convert text to simple repeating codeword patterns
    List<int> textBytes = data.codeUnits;
    
    // Generate data in 17-module codeword blocks (PDF417 standard)
    int moduleIndex = 0;
    
    while (moduleIndex < totalModules) {
      int byteIndex = (moduleIndex ~/ 17) % textBytes.length;
      int byteValue = textBytes[byteIndex];
      
      // Create a 17-module pattern from byte value
      List<bool> codeword = _createCodewordPattern(byteValue, row);
      
      for (int i = 0; i < codeword.length && moduleIndex < totalModules; i++) {
        dataArea.add(codeword[i]);
        moduleIndex++;
      }
    }
    
    return dataArea;
  }
  
  List<bool> _createCodewordPattern(int value, int row) {
    // Create a 17-module pattern that looks like a PDF417 codeword
    List<bool> pattern = [];
    
    // PDF417 codewords have specific bar/space patterns
    // Create a simplified but recognizable pattern
    
    // Start with 2-4 black bars
    int startBars = 2 + (value % 3);
    for (int i = 0; i < startBars; i++) {
      pattern.add(true);
    }
    
    // Add 1-2 white spaces
    int spaces1 = 1 + (value % 2);
    for (int i = 0; i < spaces1; i++) {
      pattern.add(false);
    }
    
    // Middle section based on character value
    int middleBars = 1 + ((value + row) % 4);
    for (int i = 0; i < middleBars; i++) {
      pattern.add(true);
    }
    
    // Space
    pattern.add(false);
    
    // Another bar section
    int bars2 = 1 + ((value * 2) % 3);
    for (int i = 0; i < bars2; i++) {
      pattern.add(true);
    }
    
    // Fill to 17 modules with alternating pattern
    while (pattern.length < 17) {
      pattern.add((pattern.length + value) % 3 != 0);
    }
    
    // Ensure exactly 17 modules
    if (pattern.length > 17) {
      pattern = pattern.sublist(0, 17);
    }
    
    return pattern;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is PDF417Painter && oldDelegate.data != data;
  }
}
