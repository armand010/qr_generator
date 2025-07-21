import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/theme_provider.dart';

// Import dari scan_code_page.dart
enum QRDataType {
  text,
  wifi,
  url,
  email,
  sms,
  phone,
  contact,
  location,
  event,
}

class ParsedQRData {
  final QRDataType type;
  final String rawData;
  final Map<String, String> parsedData;

  ParsedQRData({
    required this.type,
    required this.rawData,
    required this.parsedData,
  });
}

class QRResultPage extends StatelessWidget {
  final ParsedQRData parsedData;
  final Uint8List? qrImage;

  const QRResultPage({
    super.key,
    required this.parsedData,
    this.qrImage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            title: Text(_getPageTitle()),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              // Content section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Content display
                      _buildContentSection(context),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      _buildActionButtons(context),
                      
                      const SizedBox(height: 24),
                      
                      // QR Code image (if available)
                      if (qrImage != null) _buildQRImage(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPageTitle() {
    switch (parsedData.type) {
      case QRDataType.wifi:
        return 'WiFi Network';
      case QRDataType.url:
        return 'URL';
      case QRDataType.email:
        return 'Email Address';
      case QRDataType.sms:
        return 'SMS';
      case QRDataType.phone:
        return 'Phone Number';
      case QRDataType.contact:
        return 'Contact';
      case QRDataType.location:
        return 'Location';
      case QRDataType.event:
        return 'Event';
      case QRDataType.text:
        return 'Text';
    }
  }

  Widget _buildContentSection(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getFormattedDate(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _buildTypeSpecificContent(context),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.day} ${_getMonthName(now.month)} ${now.year} ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}, QR_CODE';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  Widget _buildTypeSpecificContent(BuildContext context) {
    switch (parsedData.type) {
      case QRDataType.wifi:
        return _buildWiFiContent(context);
      case QRDataType.url:
        return _buildUrlContent(context);
      case QRDataType.email:
        return _buildEmailContent(context);
      case QRDataType.sms:
        return _buildSmsContent(context);
      case QRDataType.phone:
        return _buildPhoneContent(context);
      case QRDataType.contact:
        return _buildContactContent(context);
      case QRDataType.location:
        return _buildLocationContent(context);
      case QRDataType.event:
        return _buildEventContent(context);
      case QRDataType.text:
        return _buildTextContent(context);
    }
  }

  Widget _buildWiFiContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parsedData.parsedData['ssid'] ?? 'Unknown Network',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (parsedData.parsedData['password']?.isNotEmpty == true) ...[
          Text(
            'Password: ${parsedData.parsedData['password']}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Security: ${parsedData.parsedData['security'] ?? 'Unknown'}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildUrlContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          parsedData.parsedData['url'] ?? parsedData.rawData,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          parsedData.parsedData['email'] ?? parsedData.rawData,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        if (parsedData.parsedData['subject']?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Subject: ${parsedData.parsedData['subject']}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
        if (parsedData.parsedData['body']?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Message: ${parsedData.parsedData['body']}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ],
    );
  }

  Widget _buildSmsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          parsedData.parsedData['phone'] ?? parsedData.rawData,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (parsedData.parsedData['message']?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            parsedData.parsedData['message']!,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneContent(BuildContext context) {
    return SelectableText(
      parsedData.parsedData['phone'] ?? parsedData.rawData,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContactContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        if (parsedData.parsedData['name']?.isNotEmpty == true) ...[
          Text(
            parsedData.parsedData['name']!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Title/Position
        if (parsedData.parsedData['title']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.work, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['title']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Organization
        if (parsedData.parsedData['organization']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.business, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['organization']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Phone
        if (parsedData.parsedData['phone']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.phone, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  parsedData.parsedData['phone']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Email
        if (parsedData.parsedData['email']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.email, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  parsedData.parsedData['email']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Website
        if (parsedData.parsedData['website']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  parsedData.parsedData['website']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Address
        if (parsedData.parsedData['address']?.isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['address']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Note
        if (parsedData.parsedData['note']?.isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.note, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['note']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show place name if available (from maps URL)
        if (parsedData.parsedData['place_name']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.place, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['place_name']!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        
        // Show coordinates if available
        if (parsedData.parsedData['latitude']?.isNotEmpty == true && 
            parsedData.parsedData['longitude']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.gps_fixed, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      'Latitude: ${parsedData.parsedData['latitude']}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      'Longitude: ${parsedData.parsedData['longitude']}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Show original URL if it's a maps URL
        if (parsedData.parsedData['url']?.isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  parsedData.parsedData['url']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
        
        // If no specific data, show raw data
        if (parsedData.parsedData['latitude'] == null && 
            parsedData.parsedData['place_name'] == null &&
            parsedData.parsedData['url'] == null) ...[
          SelectableText(
            parsedData.rawData,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
          ),
        ],
      ],
    );
  }

  Widget _buildEventContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event Title
        if (parsedData.parsedData['title']?.isNotEmpty == true) ...[
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['title']!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        
        // Date and Time
        if (parsedData.parsedData['start']?.isNotEmpty == true) ...[
          Row(
            children: [
              Icon(Icons.schedule, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start: ${_formatEventDateTime(parsedData.parsedData['start']!)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    ),
                    if (parsedData.parsedData['end']?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        'End: ${_formatEventDateTime(parsedData.parsedData['end']!)}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Location
        if (parsedData.parsedData['location']?.isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['location']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Description
        if (parsedData.parsedData['description']?.isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsedData.parsedData['description']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  // Helper method to format event date/time
  String _formatEventDateTime(String dateTime) {
    try {
      // vCalendar format: YYYYMMDDTHHMMSS or YYYYMMDD
      if (dateTime.length >= 8) {
        String year = dateTime.substring(0, 4);
        String month = dateTime.substring(4, 6);
        String day = dateTime.substring(6, 8);
        
        if (dateTime.length >= 15 && dateTime.contains('T')) {
          // Has time component
          String hour = dateTime.substring(9, 11);
          String minute = dateTime.substring(11, 13);
          return '$day/${month}/$year $hour:$minute';
        } else {
          // Date only
          return '$day/${month}/$year';
        }
      }
      return dateTime; // Return as-is if format is unexpected
    } catch (e) {
      return dateTime; // Return as-is if parsing fails
    }
  }

  Widget _buildTextContent(BuildContext context) {
    return SelectableText(
      parsedData.rawData,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    List<Widget> buttons = [];
    
    // Add type-specific action buttons
    switch (parsedData.type) {
      case QRDataType.wifi:
        buttons.add(_buildActionButton(
          icon: Icons.wifi,
          label: 'Connect',
          onPressed: () => _connectToWiFi(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.copy,
          label: 'Copy Password',
          onPressed: () => _copyWiFiPassword(context),
        ));
        break;
      case QRDataType.url:
        buttons.add(_buildActionButton(
          icon: Icons.open_in_browser,
          label: 'Open Browser',
          onPressed: () => _openURL(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.copy,
          label: 'Copy URL',
          onPressed: () => _copyUrl(context),
        ));
        break;
      case QRDataType.phone:
        buttons.add(_buildActionButton(
          icon: Icons.phone,
          label: 'Call',
          onPressed: () => _makeCall(context),
        ));
        break;
      case QRDataType.email:
        buttons.add(_buildActionButton(
          icon: Icons.email,
          label: 'Open Email',
          onPressed: () => _openEmail(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.copy,
          label: 'Copy Email',
          onPressed: () => _copyEmail(context),
        ));
        break;
      case QRDataType.sms:
        buttons.add(_buildActionButton(
          icon: Icons.sms,
          label: 'Send SMS',
          onPressed: () => _openSMS(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.mms,
          label: 'Send MMS',
          onPressed: () => _openSMS(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.copy,
          label: 'Copy Phone Number',
          onPressed: () => _copyPhoneNumber(context),
        ));
        break;
      case QRDataType.contact:
        buttons.add(_buildActionButton(
          icon: Icons.person_add,
          label: 'Add Contact',
          onPressed: () => _addContact(context),
        ));
        // Only show phone button if contact has phone
        if (parsedData.parsedData['phone']?.isNotEmpty == true) {
          buttons.add(_buildActionButton(
            icon: Icons.call,
            label: 'Calling',
            onPressed: () => _makeCall(context),
          ));
        }
        // Only show email button if contact has email
        if (parsedData.parsedData['email']?.isNotEmpty == true) {
          buttons.add(_buildActionButton(
            icon: Icons.email,
            label: 'Email',
            onPressed: () => _openEmail(context),
          ));
        }
        // Only show website button if contact has website
        if (parsedData.parsedData['website']?.isNotEmpty == true) {
          buttons.add(_buildActionButton(
            icon: Icons.language,
            label: 'Website',
            onPressed: () => _openWebsite(context),
          ));
        }
        // Only show location button if contact has address
        if (parsedData.parsedData['address']?.isNotEmpty == true) {
          buttons.add(_buildActionButton(
            icon: Icons.location_on,
            label: 'Lihat peta',
            onPressed: () => _viewLocation(context),
          ));
        }
        break;
      case QRDataType.location:
        buttons.add(_buildActionButton(
          icon: Icons.map,
          label: 'Open Map',
          onPressed: () => _openLocation(context),
        ));
        buttons.add(_buildActionButton(
          icon: Icons.copy,
          label: 'Copy URL',
          onPressed: () => _copyUrl(context),
        ));
        break;
      case QRDataType.event:
        buttons.add(_buildActionButton(
          icon: Icons.event,
          label: 'Tambah Event',
          onPressed: () => _addEvent(context),
        ));
        break;
      case QRDataType.text:
        buttons.add(_buildActionButton(
          icon: Icons.text_fields,
          label: 'Copy Text',
          onPressed: () => _copyToClipboard(context),
        ));
        break;
    }

    // Arrange buttons in wrap layout with better spacing
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      alignment: WrapAlignment.start,
      children: buttons,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 22),
                  onPressed: onPressed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQRImage() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Image.memory(
                  qrImage!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Action methods
  Future<void> _connectToWiFi(BuildContext context) async {
    Map<String, String> wifiData = parsedData.parsedData;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to WiFi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Network: ${wifiData['ssid'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            const Text('To connect to this WiFi network:'),
            const SizedBox(height: 8),
            const Text('1. Go to WiFi settings'),
            const Text('2. Select the network'),
            const Text('3. Enter the password if required'),
            const SizedBox(height: 16),
            if (wifiData['password']?.isNotEmpty == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Password:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      wifiData['password']!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (wifiData['password']?.isNotEmpty == true)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: wifiData['password']!));
                Navigator.pop(context);
                _showSuccessSnackBar(context, 'Password copied to clipboard');
              },
              child: const Text('Copy Password'),
            ),
        ],
      ),
    );
  }

  Future<void> _openURL(BuildContext context) async {
    try {
      String url = parsedData.parsedData['url'] ?? parsedData.rawData;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open URL');
      }
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    try {
      String email = parsedData.parsedData['email'] ?? '';
      String emailUrl = 'mailto:$email';
      if (parsedData.parsedData['subject']?.isNotEmpty == true) {
        emailUrl += '?subject=${Uri.encodeComponent(parsedData.parsedData['subject']!)}';
      }
      final Uri uri = Uri.parse(emailUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open email');
      }
    }
  }

  Future<void> _openSMS(BuildContext context) async {
    try {
      String phone = parsedData.parsedData['phone'] ?? '';
      String smsUrl = 'sms:$phone';
      if (parsedData.parsedData['message']?.isNotEmpty == true) {
        smsUrl += '?body=${Uri.encodeComponent(parsedData.parsedData['message']!)}';
      }
      final Uri uri = Uri.parse(smsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open SMS');
      }
    }
  }

  Future<void> _makeCall(BuildContext context) async {
    try {
      String phone = parsedData.parsedData['phone'] ?? '';
      final Uri uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not make call');
      }
    }
  }

  Future<void> _openLocation(BuildContext context) async {
    try {
      String? url = parsedData.parsedData['url'];
      String lat = parsedData.parsedData['latitude'] ?? '';
      String lng = parsedData.parsedData['longitude'] ?? '';
      
      // If it's originally a maps URL, use that directly
      if (url != null && url.isNotEmpty) {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // Otherwise, use coordinates to create Google Maps URL
      if (lat.isNotEmpty && lng.isNotEmpty) {
        final Uri uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // Fallback: try to open raw data as URL if it looks like a maps link
      if (parsedData.rawData.contains('http') && parsedData.rawData.contains('maps')) {
        final Uri uri = Uri.parse(parsedData.rawData);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open map');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open map');
      }
    }
  }

  Future<void> _addContact(BuildContext context) async {
    if (context.mounted) {
      _showErrorSnackBar(context, 'Add contact feature coming soon');
    }
  }

  Future<void> _addEvent(BuildContext context) async {
    if (context.mounted) {
      _showErrorSnackBar(context, 'Add event feature coming soon');
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    try {
      String website = parsedData.parsedData['website'] ?? '';
      if (website.isEmpty) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'No website found');
        }
        return;
      }
      
      String url = website;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open website');
      }
    }
  }

  Future<void> _viewLocation(BuildContext context) async {
    _openLocation(context);
  }

  Future<void> _copyWiFiPassword(BuildContext context) async {
    String password = parsedData.parsedData['password'] ?? '';
    if (password.isEmpty) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'No password found');
      }
      return;
    }
    
    await Clipboard.setData(ClipboardData(text: password));
    if (context.mounted) {
      _showSuccessSnackBar(context, 'WiFi password copied to clipboard');
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    String url = parsedData.parsedData['url'] ?? parsedData.rawData;
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _showSuccessSnackBar(context, 'URL copied to clipboard');
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: parsedData.rawData));
    if (context.mounted) {
      _showSuccessSnackBar(context, 'Copied to clipboard');
    }
  }

  Future<void> _copyPhoneNumber(BuildContext context) async {
    String phone = parsedData.parsedData['phone'] ?? '';
    if (phone.isEmpty) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'No phone number found');
      }
      return;
    }
    
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      _showSuccessSnackBar(context, 'Phone number copied to clipboard');
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    String email = parsedData.parsedData['email'] ?? '';
    if (email.isEmpty) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'No email found');
      }
      return;
    }
    
    await Clipboard.setData(ClipboardData(text: email));
    if (context.mounted) {
      _showSuccessSnackBar(context, 'Email copied to clipboard');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
