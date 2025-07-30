import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import '../../services/history_service.dart';
import '../../providers/theme_provider.dart';

class ContactQRPage extends StatefulWidget {
  const ContactQRPage({super.key});

  @override
  State<ContactQRPage> createState() => _ContactQRPageState();
}

class _ContactQRPageState extends State<ContactQRPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = '';
  bool _showQR = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _organizationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _generateContactQR() {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full Name is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone Number is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
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

    // Validate phone number format
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // vCard format
    String vCard =
        'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:${_nameController.text.trim()}\n'
        'TEL:${_phoneController.text.trim()}\n'
        'EMAIL:${_emailController.text.trim()}\n'
        'ADR:${_addressController.text.trim()}\n'
        'ORG:${_organizationController.text.trim()}\n'
        'NOTE:${_noteController.text.trim()}\n'
        'END:VCARD';

    setState(() {
      _qrData = vCard;
      _showQR = true;
    });

    // Add to history
    HistoryService().addGeneratedItem(content: _qrData, format: 'QR_CODE');

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
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
      _organizationController.clear();
      _noteController.clear();
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
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
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
              content: Text(
                'Gallery access permission denied. Using share instead.',
              ),
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
      final file = File(
        '${tempDir.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png',
      );

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
            title: const Text('Contact QR Code'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                          'Contact Information:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: '+1234567890',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address *',
                            hintText: 'example@example.com',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Address (Optional)',
                            hintText: '123 Main St, City, Country',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _organizationController,
                          decoration: InputDecoration(
                            labelText: 'Organization/Company (Optional)',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Note (Optional)',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _generateContactQR,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                                child: const Text('Generate QR Code'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _clearQR,
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
                                shape: PrettyQrSmoothSymbol(
                                  color: Colors.black,
                                ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${_nameController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: ${_phoneController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Email: ${_emailController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Address: ${_addressController.text.trim().isEmpty ? "-" : _addressController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Organization: ${_organizationController.text.trim().isEmpty ? "-" : _organizationController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Note: ${_noteController.text.trim().isEmpty ? "-" : _noteController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: _saveQRCode,
                                  icon: Icon(
                                    Icons.save_alt,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
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
                                  icon: Icon(
                                    Icons.share,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
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
