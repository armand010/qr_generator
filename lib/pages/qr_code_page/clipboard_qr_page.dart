import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../services/history_service.dart';
import '../../providers/theme_provider.dart';

class ClipBoardQRPage extends StatefulWidget {
  const ClipBoardQRPage({super.key});

  @override
  State<ClipBoardQRPage> createState() => _ClipBoardQRPageState();
}

class _ClipBoardQRPageState extends State<ClipBoardQRPage> {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = '';
  bool _showQR = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _generateQR() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        _qrData = _textController.text.trim();
        _showQR = true;
      });
      
      // Add to history
      HistoryService().addGeneratedItem(content: _qrData, format: 'QR_CODE');
      
      //Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or paste text to generate QR code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearQR() {
    setState(() {
      _textController.clear();
      _qrData = '';
      _showQR = false;
    });
  }

  // Function to capture QR code as image
  Future<Uint8List?> _captureQRCode() async {
    try {
      RenderRepaintBoundary boundary = 
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR code: $e');
      return null;
    }
  }

  // Function to save QR code directly to gallery
  Future<void> _saveQRCode() async {
    if (!mounted) return;
    
    try {
      // Capture QR code
      Uint8List? imageBytes = await _captureQRCode();
      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture QR code'),
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
              content: Text('Gallery access permission denied. Using share instead.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Fallback to share
          await _shareQRCode();
          return;
        }
      }

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName = 'qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      
      // Write image to temporary file
      await tempFile.writeAsBytes(imageBytes);

      // Save to gallery using gal package
      await Gal.putImage(tempFile.path, album: 'QR Codes');

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code saved to gallery successfully!'),
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
      await _shareQRCode();
    }
  }

  // Function to share QR code
  Future<void> _shareQRCode() async {
    if (!mounted) return;
    
    try {
      // Capture QR code
      Uint8List? imageBytes = await _captureQRCode();
      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture QR code'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png');
      
      // Write image to file
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code: $_qrData',
        subject: 'My QR Code',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Clipboard QR Code'),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Input/Paste Text:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type or Paste your text here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _generateQR,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                            child: Text('Generate QR Code'),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearQR,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          child: Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_showQR && _qrData.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'QR Result:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // QR Code with themed border
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            height: 200,
                            width: 200,
                            child: PrettyQrView.data(
                              data: _qrData,
                              decoration: const PrettyQrDecoration(
                                shape: PrettyQrSmoothSymbol(color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Data display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _qrData,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
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
                                  onPressed: _saveQRCode,
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
                                  onPressed: _shareQRCode,
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
                      const SizedBox(height: 8),
                      // Information text
                      Text(
                        'Tip: "Save" stores to gallery, "Share" sends to other apps',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
        );
      },
    );
  }
}
