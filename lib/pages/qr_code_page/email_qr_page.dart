import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

class EmailQRPage extends StatefulWidget {
  const EmailQRPage({super.key});

  @override
  State<EmailQRPage> createState() => _EmailQRPageState();
}

class _EmailQRPageState extends State<EmailQRPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = '';
  bool _showQR = false;

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _generateEmailQR() {
    if (_emailController.text.trim().isEmpty) {
      // Show error message if email field is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email Address is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate email format
    String email = _emailController.text.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String subject = _subjectController.text.trim();
    String body = _bodyController.text.trim();

    String mailto = 'mailto:${email}';
    if (subject.isNotEmpty || body.isNotEmpty) {
      mailto += '?';
      if (subject.isNotEmpty) {
        mailto += 'subject=${Uri.encodeComponent(subject)}';
      }
      if (body.isNotEmpty) {
        if (subject.isNotEmpty) mailto += '&';
        mailto += 'body=${Uri.encodeComponent(body)}';
      }
    }

    setState(() {
      _qrData = mailto;
      _showQR = true;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code generated successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearQR() {
    setState(() {
      _emailController.clear();
      _subjectController.clear();
      _bodyController.clear();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email QR Code'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[200],
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
                      'Email Details:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'example@email.com',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.subject),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Message Body (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.message),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _generateEmailQR,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Generate QR Code'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearQR,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
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
                      // QR Code with green border
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.green, width: 2),
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email: ${_emailController.text.trim()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subject: ${_subjectController.text.trim().isEmpty ? "-" : _subjectController.text.trim()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Content: ${_bodyController.text.trim().isEmpty ? "-" : _bodyController.text.trim()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
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
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: _saveQRCode,
                                  icon: const Icon(Icons.save_alt, color: Colors.white),
                                  iconSize: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: _shareQRCode,
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  iconSize: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
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
                          color: Colors.grey[600],
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
  }
}
