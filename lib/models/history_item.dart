class HistoryItem {
  final String id;
  final String content;
  final String type; // 'qr_scan', 'barcode_scan', 'qr_generate', 'barcode_generate'
  final String format; // 'QR_CODE', 'EAN_13', 'CODE_128', etc.
  final DateTime timestamp;
  final String? category; // For generated items: 'text', 'wifi', 'url', etc.

  HistoryItem({
    required this.id,
    required this.content,
    required this.type,
    required this.format,
    required this.timestamp,
    this.category,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'format': format,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'category': category,
    };
  }

  // Create from JSON
  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      content: json['content'],
      type: json['type'],
      format: json['format'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      category: json['category'],
    );
  }

  // Helper getters
  bool get isScanned => type.contains('scan');
  bool get isGenerated => type.contains('generate');
  bool get isQRCode => format == 'QR_CODE';
  bool get isBarcode => !isQRCode;
  
  String get displayTitle {
    if (isQRCode) {
      return isScanned ? 'QR Code Scanned' : 'QR Code Generated';
    } else {
      return isScanned ? '$format Scanned' : '$format Generated';
    }
  }
  
  String get displaySubtitle {
    if (category != null) {
      return '${category!.toUpperCase()} • ${_formatTimestamp()}';
    }
    return _formatTimestamp();
  }
  
  String _formatTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
