import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'qr_result_page.dart';
import 'bar_result_page.dart';
import '../services/history_service.dart';

// QR Data Parser class
class QRDataParser {
  static ParsedQRData parseQRData(String data) {
    // WiFi QR Code format: WIFI:T:WPA;S:NetworkName;P:Password;H:false;;
    if (data.startsWith('WIFI:')) {
      return _parseWiFiData(data);
    }
    
    // Location detection (check before URL to catch maps links)
    if (data.startsWith('geo:')) {
      return _parseLocationData(data);
    }
    
    // Maps URL detection (Google Maps, Apple Maps, etc.)
    if (_isMapsUrl(data)) {
      return _parseMapsUrlData(data);
    }
    
    // URL detection
    if (data.startsWith('http://') || data.startsWith('https://') || data.startsWith('www.')) {
      return ParsedQRData(
        type: QRDataType.url,
        rawData: data,
        parsedData: {'url': data},
      );
    }
    
    // Contact/vCard detection (should come before email detection)
    if (data.startsWith('BEGIN:VCARD')) {
      return _parseContactData(data);
    }
    
    // Email detection
    if (data.startsWith('mailto:') || (_containsEmail(data) && !data.startsWith('BEGIN:'))) {
      return _parseEmailData(data);
    }
    
    // Phone detection (should come before SMS to avoid misdetection)
    if (data.startsWith('tel:') || data.startsWith('TEL:') ||
        data.startsWith('phone:') || data.startsWith('PHONE:')) {
      return _parsePhoneData(data);
    }
    
    // SMS detection (more specific patterns)
    if (data.startsWith('sms:') || data.startsWith('SMS:') || 
        data.startsWith('smsto:') || data.startsWith('SMSTO:')) {
      return _parseSMSData(data);
    }
    
    // Pure phone number detection (only if not SMS format)
    if (_isPhoneNumber(data) && !_looksLikeSMS(data)) {
      return _parsePhoneData(data);
    }
    
    // Event/vCalendar detection
    if (data.startsWith('BEGIN:VEVENT')) {
      return _parseEventData(data);
    }
    
    // Default to text
    return ParsedQRData(
      type: QRDataType.text,
      rawData: data,
      parsedData: {'text': data},
    );
  }
  
  // Helper method to detect phone numbers
  static bool _isPhoneNumber(String data) {
    // Remove common phone number characters
    String cleanData = data.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    // Check if it's mostly digits and starts with + or is 10-15 digits
    if (RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleanData)) {
      return true;
    }
    
    // Check common phone number patterns
    if (RegExp(r'^[\+]?[0-9]{1,4}[\s\-]?[\(]?[0-9]{1,4}[\)]?[\s\-]?[0-9]{1,4}[\s\-]?[0-9]{1,9}$').hasMatch(data)) {
      return true;
    }
    
    return false;
  }
  
  // Helper method to detect email in text (more restrictive than before)
  static bool _containsEmail(String data) {
    // Only detect simple email patterns, not vCard content
    return data.contains('@') && data.contains('.') && 
           !data.contains('\n') && // Not multiline like vCard
           data.length < 100; // Not too long like vCard
  }
  
  static ParsedQRData _parseWiFiData(String data) {
    Map<String, String> parsed = {};
    
    // Remove WIFI: prefix and split by semicolons
    String cleanData = data.substring(5); // Remove 'WIFI:'
    List<String> parts = cleanData.split(';');
    
    for (String part in parts) {
      if (part.contains(':')) {
        List<String> keyValue = part.split(':');
        if (keyValue.length >= 2) {
          String key = keyValue[0];
          String value = keyValue.sublist(1).join(':'); // Handle values with colons
          
          switch (key) {
            case 'T':
              parsed['security'] = value;
              break;
            case 'S':
              parsed['ssid'] = value;
              break;
            case 'P':
              parsed['password'] = value;
              break;
            case 'H':
              parsed['hidden'] = value;
              break;
          }
        }
      }
    }
    
    return ParsedQRData(
      type: QRDataType.wifi,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parseEmailData(String data) {
    Map<String, String> parsed = {};
    
    if (data.startsWith('mailto:')) {
      String email = data.substring(7);
      if (email.contains('?')) {
        List<String> parts = email.split('?');
        parsed['email'] = parts[0];
        // Parse query parameters like subject, body, etc.
        if (parts.length > 1) {
          List<String> params = parts[1].split('&');
          for (String param in params) {
            if (param.contains('=')) {
              List<String> keyValue = param.split('=');
              parsed[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
            }
          }
        }
      } else {
        parsed['email'] = email;
      }
    } else {
      parsed['email'] = data;
    }
    
    return ParsedQRData(
      type: QRDataType.email,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parseSMSData(String data) {
    Map<String, String> parsed = {};
    
    if (data.startsWith('sms:') || data.startsWith('SMS:')) {
      String smsData = data.substring(4);
      if (smsData.contains('?')) {
        List<String> parts = smsData.split('?');
        parsed['phone'] = parts[0];
        if (parts.length > 1 && parts[1].startsWith('body=')) {
          parsed['message'] = Uri.decodeComponent(parts[1].substring(5));
        }
      } else {
        parsed['phone'] = smsData;
      }
    } else if (data.startsWith('smsto:') || data.startsWith('SMSTO:')) {
      String smsData = data.substring(6);
      if (smsData.contains(':')) {
        List<String> parts = smsData.split(':');
        parsed['phone'] = parts[0];
        if (parts.length > 1) {
          parsed['message'] = parts[1];
        }
      } else {
        parsed['phone'] = smsData;
      }
    } else {
      // Handle other SMS-like formats or fallback
      parsed['phone'] = data;
    }
    
    return ParsedQRData(
      type: QRDataType.sms,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parsePhoneData(String data) {
    Map<String, String> parsed = {};
    
    if (data.startsWith('tel:') || data.startsWith('TEL:')) {
      parsed['phone'] = data.substring(4);
    } else if (data.startsWith('phone:') || data.startsWith('PHONE:')) {
      parsed['phone'] = data.substring(6);
    } else if (_isPhoneNumber(data)) {
      parsed['phone'] = data;
    } else {
      parsed['phone'] = data;
    }
    
    return ParsedQRData(
      type: QRDataType.phone,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parseContactData(String data) {
    Map<String, String> parsed = {};
    
    List<String> lines = data.split('\n');
    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.startsWith('FN:')) {
        parsed['name'] = cleanLine.substring(3);
      } else if (cleanLine.startsWith('N:')) {
        // Handle structured name (N:Last;First;Middle;Prefix;Suffix)
        String nameData = cleanLine.substring(2);
        List<String> nameParts = nameData.split(';');
        if (nameParts.isNotEmpty && parsed['name'] == null) {
          // If no FN field, construct name from N field
          String constructedName = '';
          if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
            constructedName += nameParts[1]; // First name
          }
          if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
            if (constructedName.isNotEmpty) constructedName += ' ';
            constructedName += nameParts[0]; // Last name
          }
          if (constructedName.isNotEmpty) {
            parsed['name'] = constructedName;
          }
        }
      } else if (cleanLine.startsWith('TEL:') || cleanLine.startsWith('TEL;')) {
        String phoneData = cleanLine.substring(4);
        // Handle TEL;TYPE=... format
        if (cleanLine.contains(':')) {
          phoneData = cleanLine.substring(cleanLine.indexOf(':') + 1);
        }
        parsed['phone'] = phoneData;
      } else if (cleanLine.startsWith('EMAIL:') || cleanLine.startsWith('EMAIL;')) {
        String emailData = cleanLine.substring(6);
        // Handle EMAIL;TYPE=... format
        if (cleanLine.contains(':')) {
          emailData = cleanLine.substring(cleanLine.indexOf(':') + 1);
        }
        parsed['email'] = emailData;
      } else if (cleanLine.startsWith('ORG:')) {
        parsed['organization'] = cleanLine.substring(4);
      } else if (cleanLine.startsWith('TITLE:')) {
        parsed['title'] = cleanLine.substring(6);
      } else if (cleanLine.startsWith('URL:')) {
        parsed['website'] = cleanLine.substring(4);
      } else if (cleanLine.startsWith('ADR:') || cleanLine.startsWith('ADR;')) {
        String addressData = cleanLine.substring(4);
        if (cleanLine.contains(':')) {
          addressData = cleanLine.substring(cleanLine.indexOf(':') + 1);
        }
        // vCard address format: ;;Street;City;State;PostalCode;Country
        List<String> addressParts = addressData.split(';');
        String address = '';
        for (int i = 2; i < addressParts.length; i++) {
          if (addressParts[i].isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += addressParts[i];
          }
        }
        if (address.isNotEmpty) {
          parsed['address'] = address;
        }
      } else if (cleanLine.startsWith('NOTE:')) {
        parsed['note'] = cleanLine.substring(5);
      }
    }
    
    return ParsedQRData(
      type: QRDataType.contact,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parseLocationData(String data) {
    Map<String, String> parsed = {};
    
    if (data.startsWith('geo:')) {
      String coords = data.substring(4);
      if (coords.contains(',')) {
        List<String> latLng = coords.split(',');
        if (latLng.length >= 2) {
          parsed['latitude'] = latLng[0];
          parsed['longitude'] = latLng[1];
        }
      }
    }
    
    return ParsedQRData(
      type: QRDataType.location,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  // Helper method to detect maps URLs
  static bool _isMapsUrl(String data) {
    String lowerData = data.toLowerCase();
    return lowerData.contains('maps.google.') ||
           lowerData.contains('goo.gl/maps') ||
           lowerData.contains('maps.apple.com') ||
           lowerData.contains('apple.com/maps') ||
           lowerData.contains('openstreetmap.org') ||
           lowerData.contains('waze.com') ||
           (lowerData.contains('maps') && lowerData.contains('http')) ||
           (lowerData.contains('q=') && lowerData.contains('http')) && (lowerData.contains('maps') || lowerData.contains('place'));
  }
  
  // Parse maps URL to extract location data
  static ParsedQRData _parseMapsUrlData(String data) {
    Map<String, String> parsed = {'url': data};
    
    try {
      Uri uri = Uri.parse(data);
      
      // Google Maps patterns
      if (uri.host.contains('google.') && uri.path.contains('maps')) {
        // Try to extract coordinates from various Google Maps URL formats
        String? q = uri.queryParameters['q'];
        if (q != null && q.contains(',')) {
          List<String> coords = q.split(',');
          if (coords.length >= 2) {
            // Check if they are valid coordinates
            double? lat = double.tryParse(coords[0].trim());
            double? lng = double.tryParse(coords[1].trim());
            if (lat != null && lng != null) {
              parsed['latitude'] = lat.toString();
              parsed['longitude'] = lng.toString();
            }
          }
        }
        
        // Try other Google Maps URL patterns
        if (parsed['latitude'] == null) {
          // Pattern: /@lat,lng,zoom
          String path = uri.path + uri.fragment;
          RegExp coordRegex = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)');
          Match? match = coordRegex.firstMatch(path);
          if (match != null) {
            parsed['latitude'] = match.group(1)!;
            parsed['longitude'] = match.group(2)!;
          }
        }
        
        // Try to extract place name from query
        if (q != null && !q.contains(',')) {
          parsed['place_name'] = q;
        }
      }
      
      // Apple Maps patterns
      else if (uri.host.contains('apple.com') || uri.host.contains('maps.apple.com')) {
        String? ll = uri.queryParameters['ll'];
        if (ll != null && ll.contains(',')) {
          List<String> coords = ll.split(',');
          if (coords.length >= 2) {
            parsed['latitude'] = coords[0].trim();
            parsed['longitude'] = coords[1].trim();
          }
        }
        
        String? q = uri.queryParameters['q'];
        if (q != null) {
          parsed['place_name'] = q;
        }
      }
    } catch (e) {
      // If URL parsing fails, just treat as a maps URL without coordinates
    }
    
    return ParsedQRData(
      type: QRDataType.location,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  static ParsedQRData _parseEventData(String data) {
    Map<String, String> parsed = {};
    
    List<String> lines = data.split('\n');
    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.startsWith('SUMMARY:')) {
        parsed['title'] = cleanLine.substring(8);
      } else if (cleanLine.startsWith('DESCRIPTION:')) {
        parsed['description'] = cleanLine.substring(12);
      } else if (cleanLine.startsWith('LOCATION:')) {
        parsed['location'] = cleanLine.substring(9);
      } else if (cleanLine.startsWith('DTSTART:')) {
        parsed['start'] = cleanLine.substring(8);
      } else if (cleanLine.startsWith('DTEND:')) {
        parsed['end'] = cleanLine.substring(6);
      }
    }
    
    return ParsedQRData(
      type: QRDataType.event,
      rawData: data,
      parsedData: parsed,
    );
  }
  
  // Helper method to detect if data looks like SMS format
  static bool _looksLikeSMS(String data) {
    // Check if data contains common SMS keywords or patterns
    String lowerData = data.toLowerCase();
    
    // Contains message separators or keywords
    if (lowerData.contains('body=') || 
        lowerData.contains('message=') ||
        lowerData.contains(':') && lowerData.length > 20) { // Colon with long text suggests message
      return true;
    }
    
    // Contains non-phone characters that suggest it's not just a phone number
    if (data.contains('?') || data.contains('&') || data.contains('=')) {
      return true;
    }
    
    return false;
  }
}

// Widget untuk konten scan saja (tanpa Scaffold)
class ScanCodePageContent extends StatefulWidget {
  const ScanCodePageContent({super.key});

  @override
  State<ScanCodePageContent> createState() => _ScanCodePageContentState();
}

class _ScanCodePageContentState extends State<ScanCodePageContent> {
  // Enhanced MobileScannerController with support for all major barcode formats
  // Supports: QR Code, EAN-8, EAN-13, UPC-E, UPC-A, CODE-39, CODE-93, 
  // CODE-128, ITF, PDF-417, CODABAR, Data Matrix, and Aztec
  MobileScannerController controller = MobileScannerController(
    formats: [
      // QR Code formats
      BarcodeFormat.qrCode,
      
      // 1D Barcode formats
      BarcodeFormat.ean8,       // EAN-8
      BarcodeFormat.ean13,      // EAN-13
      BarcodeFormat.upcE,       // UPC-E
      BarcodeFormat.upcA,       // UPC-A
      BarcodeFormat.code39,     // CODE-39
      BarcodeFormat.code93,     // CODE-93
      BarcodeFormat.code128,    // CODE-128
      BarcodeFormat.itf,        // ITF (Interleaved 2 of 5)
      BarcodeFormat.codabar,    // CODABAR
      
      // 2D Barcode formats
      BarcodeFormat.pdf417,     // PDF-417
      BarcodeFormat.dataMatrix, // DATA MATRIX
      BarcodeFormat.aztec,      // AZTEC
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 1000,
  );
  double _zoomFactor = 0.0;
  bool _isFlashOn = false;
  bool _isScanning = true;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  bool _dialogOpen = false; // Additional flag to track dialog state

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Analyzing image for QR codes...'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Analyze the selected image for QR codes
        await controller.analyzeImage(image.path);
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in the selected image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showResultDialog(String data, Uint8List? image, String? format) {
    // Prevent multiple dialogs
    if (_dialogOpen) return;
    
    setState(() {
      _isScanning = false;
      _dialogOpen = true;
    });
    
    // Determine if it's a QR code or barcode based on format
    bool isQRCode = format?.toLowerCase().contains('qr') ?? false;
    
    if (isQRCode) {
      // Add to history
      HistoryService().addScannedItem(content: data, format: 'QR_CODE');
      
      // Parse QR data and navigate to QR result page
      ParsedQRData parsedData = QRDataParser.parseQRData(data);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRResultPage(
            parsedData: parsedData,
            qrImage: image,
          ),
        ),
      ).then((_) {
        _resetScanningState();
      });
    } else {
      // Add to history
      HistoryService().addScannedItem(content: data, format: format ?? 'UNKNOWN');
      
      // Parse barcode data and navigate to barcode result page
      ParsedBarcodeData parsedData = BarcodeDataParser.parseBarcodeData(data, format);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeResultPage(
            parsedData: parsedData,
            barcodeImage: image,
          ),
        ),
      ).then((_) {
        _resetScanningState();
      });
    }
  }
  
  void _resetScanningState() {
    if (mounted) {
      setState(() {
        _dialogOpen = false;
        _lastScannedCode = null;
        _lastScanTime = null;
      });
      
      // Delay before resuming scanning
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_dialogOpen) {
          setState(() {
            _isScanning = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Scan QR/Barcode (All Formats)'),
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          actions: [
            IconButton(
              onPressed: _pickImageFromGallery,
              icon: const Icon(Icons.photo_library),
              tooltip: 'Pick from Gallery',
            ),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  // Multiple checks to prevent duplicate scanning
                  if (!_isScanning || _dialogOpen) return;
                  
                  final List<Barcode> barcodes = capture.barcodes;
                  final Uint8List? image = capture.image;
                  
                  if (barcodes.isNotEmpty) {
                    String currentCode = barcodes.first.rawValue ?? 'No Data';
                    String? format = barcodes.first.format.name;
                    DateTime now = DateTime.now();
                    
                    // Prevent duplicate scans of the same code within 5 seconds
                    if (_lastScannedCode == currentCode && 
                        _lastScanTime != null && 
                        now.difference(_lastScanTime!).inSeconds < 5) {
                      return;
                    }
                    
                    _lastScannedCode = currentCode;
                    _lastScanTime = now;
                    
                    _showResultDialog(currentCode, image, format);
                  }
                },
              ),
              // Camera controls overlay
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flash toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          await controller.toggleTorch();
                          setState(() {
                            _isFlashOn = !_isFlashOn;
                          });
                        },
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Camera flip
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          await controller.switchCamera();
                        },
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Zoom controls
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Zoom: ${(_zoomFactor * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: _zoomFactor,
                        min: 0.0,
                        max: 1.0,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Colors.white30,
                        onChanged: (value) {
                          setState(() {
                            _zoomFactor = value;
                          });
                          controller.setZoomScale(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Scan area frame
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Corner brackets
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                  left: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                  right: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                  left: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                  right: BorderSide(
                                    color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                    width: 4
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '📱 Point camera at QR Code or Barcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'Supports: QR, EAN-8/13, UPC-A/E, CODE-39/93/128, ITF, PDF-417, CODABAR, Data Matrix, Aztec',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Widget asli dengan Scaffold (untuk standalone use)
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  int _currentIndex = 0;
  // Enhanced MobileScannerController with support for all major barcode formats
  // Supports: QR Code, EAN-8, EAN-13, UPC-E, UPC-A, CODE-39, CODE-93, 
  // CODE-128, ITF, PDF-417, CODABAR, Data Matrix, and Aztec
  MobileScannerController controller = MobileScannerController(
    formats: [
      // QR Code formats
      BarcodeFormat.qrCode,
      
      // 1D Barcode formats
      BarcodeFormat.ean8,       // EAN-8
      BarcodeFormat.ean13,      // EAN-13
      BarcodeFormat.upcE,       // UPC-E
      BarcodeFormat.upcA,       // UPC-A
      BarcodeFormat.code39,     // CODE-39
      BarcodeFormat.code93,     // CODE-93
      BarcodeFormat.code128,    // CODE-128
      BarcodeFormat.itf,        // ITF (Interleaved 2 of 5)
      BarcodeFormat.codabar,    // CODABAR
      
      // 2D Barcode formats
      BarcodeFormat.pdf417,     // PDF-417
      BarcodeFormat.dataMatrix, // DATA MATRIX
      BarcodeFormat.aztec,      // AZTEC
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 1000,
  );
  double _zoomFactor = 0.0;
  bool _isFlashOn = false;
  bool _isScanning = true;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  bool _dialogOpen = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Analyzing image for QR codes...'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Analyze the selected image for QR codes
        await controller.analyzeImage(image.path);
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in the selected image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showResultDialog(String data, Uint8List? image, String? format) {
    if (_dialogOpen) return;
    
    setState(() {
      _isScanning = false;
      _dialogOpen = true;
    });
    
    // Determine if it's a QR code or barcode based on format
    bool isQRCode = format?.toLowerCase().contains('qr') ?? false;
    
    if (isQRCode) {
      // Add to history
      HistoryService().addScannedItem(content: data, format: 'QR_CODE');
      
      // Parse QR data and navigate to QR result page
      ParsedQRData parsedData = QRDataParser.parseQRData(data);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRResultPage(
            parsedData: parsedData,
            qrImage: image,
          ),
        ),
      ).then((_) {
        _resetScanningState();
      });
    } else {
      // Add to history
      HistoryService().addScannedItem(content: data, format: format ?? 'UNKNOWN');
      
      // Parse barcode data and navigate to barcode result page
      ParsedBarcodeData parsedData = BarcodeDataParser.parseBarcodeData(data, format);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeResultPage(
            parsedData: parsedData,
            barcodeImage: image,
          ),
        ),
      ).then((_) {
        _resetScanningState();
      });
    }
  }

  void _resetScanningState() {
    if (mounted) {
      setState(() {
        _dialogOpen = false;
        _lastScannedCode = null;
        _lastScanTime = null;
      });
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_dialogOpen) {
          setState(() {
            _isScanning = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR/Barcode (All Formats)'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            onPressed: _pickImageFromGallery,
            icon: const Icon(Icons.photo_library),
            tooltip: 'Pick from Gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!_isScanning || _dialogOpen) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              final Uint8List? image = capture.image;
              
              if (barcodes.isNotEmpty) {
                String currentCode = barcodes.first.rawValue ?? 'No Data';
                String? format = barcodes.first.format.name;
                DateTime now = DateTime.now();
                
                if (_lastScannedCode == currentCode && 
                    _lastScanTime != null && 
                    now.difference(_lastScanTime!).inSeconds < 5) {
                  return;
                }
                
                _lastScannedCode = currentCode;
                _lastScanTime = now;
                
                _showResultDialog(currentCode, image, format);
              }
            },
          ),
          // Camera controls overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flash toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      await controller.toggleTorch();
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                      });
                    },
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Camera flip
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      await controller.switchCamera();
                    },
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Zoom controls
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zoom: ${(_zoomFactor * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _zoomFactor,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Colors.white30,
                    onChanged: (value) {
                      setState(() {
                        _zoomFactor = value;
                      });
                      controller.setZoomScale(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Scan area frame
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Corner brackets
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                              left: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                              right: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                              left: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                              right: BorderSide(
                                color: _isScanning ? Theme.of(context).colorScheme.primary : Colors.orange, 
                                width: 4
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '📱 Point camera at QR Code or Barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Supports: QR, EAN-8/13, UPC-A/E, CODE-39/93/128, ITF, PDF-417, CODABAR, Data Matrix, Aztec',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Scanning status indicator
          if (!_isScanning)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Scanning paused - Processing result...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          if (index == 0) {
            Navigator.pop(context); 
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}
