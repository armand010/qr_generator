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

class EventQRPage extends StatefulWidget {
  const EventQRPage({super.key});

  @override
  State<EventQRPage> createState() => _EventQRPageState();
}

class _EventQRPageState extends State<EventQRPage> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = '';
  bool _showQR = false;

  @override
  void dispose() {
    _eventNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    TextEditingController controller,
    String label,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  void _generateEventQR() {
    // Validate required fields
    if (_eventNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event Name is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_startDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start Date is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_endDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End Date is required!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Function to parse date from DD/MM/YYYY format
    DateTime? _parseDate(String dateString) {
      try {
        List<String> parts = dateString.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
      return null;
    }

    // Handling start date must be before end date
    DateTime? startDate = _parseDate(_startDateController.text.trim());
    DateTime? endDate = _parseDate(_endDateController.text.trim());
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start Date must be before End Date!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Create event data in vCalendar format
    String eventData =
        'BEGIN:VEVENT\n'
        'SUMMARY:${_eventNameController.text.trim()}\n'
        'DESCRIPTION:${_descriptionController.text.trim()}\n'
        'LOCATION:${_locationController.text.trim()}\n'
        'DTSTART:${_formatDateForCalendar(_startDateController.text.trim())}\n'
        'DTEND:${_formatDateForCalendar(_endDateController.text.trim())}\n'
        'END:VEVENT';

    setState(() {
      _qrData = eventData;
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

  String _formatDateForCalendar(String dateString) {
    // Convert DD/MM/YYYY to YYYYMMDD format for calendar
    try {
      List<String> parts = dateString.split('/');
      if (parts.length == 3) {
        String day = parts[0].padLeft(2, '0');
        String month = parts[1].padLeft(2, '0');
        String year = parts[2];
        return '${year}${month}${day}';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return dateString.replaceAll('/', '');
  }

  void _clearQR() {
    setState(() {
      _eventNameController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _startDateController.clear();
      _endDateController.clear();
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
            title: const Text('Event QR Code'),
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
                      'Input Data:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _eventNameController,
                      decoration: InputDecoration(
                        labelText: 'Event Name',
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
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
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
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
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
                      controller: _startDateController,
                      readOnly: true,
                      onTap: () =>
                          _selectDate(_startDateController, 'Start Date'),
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        suffixIcon: const Icon(Icons.calendar_today),
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
                      controller: _endDateController,
                      readOnly: true,
                      onTap: () => _selectDate(_endDateController, 'End Date'),
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        suffixIcon: const Icon(Icons.calendar_today),
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
                            onPressed: _generateEventQR,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Create QR Code',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearQR,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
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
                              'Event Name: ${_eventNameController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Description: ${_descriptionController.text.trim().isEmpty ? "-" : _descriptionController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${_locationController.text.trim().isEmpty ? "-" : _locationController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start: ${_startDateController.text.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'End: ${_endDateController.text.trim()}',
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
