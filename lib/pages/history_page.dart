import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';
import '../providers/theme_provider.dart';
import 'qr_result_page.dart';
import 'bar_result_page.dart';
import 'scan_code_page.dart'; // For QRDataParser and ParsedQRData

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  final HistoryService _historyService = HistoryService();
  final TextEditingController _searchController = TextEditingController();
  
  List<HistoryItem> _allHistory = [];
  List<HistoryItem> _filteredHistory = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'scanned', 'generated', 'qr', 'barcode'
  static const int _maxDisplayItems = 20; // Limit display to 20 items
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await _historyService.getHistory();
      setState(() {
        _allHistory = history;
        // Apply current filter and limit to max display items
        _filterHistory(_selectedFilter);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  void _filterHistory(String filter) {
    setState(() {
      _selectedFilter = filter;
      
      List<HistoryItem> filtered;
      switch (filter) {
        case 'all':
          filtered = _allHistory;
          break;
        case 'scanned':
          filtered = _allHistory.where((item) => item.isScanned).toList();
          break;
        case 'generated':
          filtered = _allHistory.where((item) => item.isGenerated).toList();
          break;
        case 'qr':
          filtered = _allHistory.where((item) => item.isQRCode).toList();
          break;
        case 'barcode':
          filtered = _allHistory.where((item) => item.isBarcode).toList();
          break;
        default:
          filtered = _allHistory;
      }
      
      // Limit to maximum display items
      _filteredHistory = filtered.take(_maxDisplayItems).toList();
    });
  }

  void _searchHistory(String query) async {
    if (query.isEmpty) {
      _filterHistory(_selectedFilter);
      return;
    }

    final results = await _historyService.searchHistory(query);
    setState(() {
      // Limit search results to maximum display items
      _filteredHistory = results.take(_maxDisplayItems).toList();
    });
  }

  Future<void> _deleteItem(HistoryItem item) async {
    await _historyService.deleteItem(item.id);
    _loadHistory();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Add back to history
              if (item.isScanned) {
                _historyService.addScannedItem(
                  content: item.content,
                  format: item.format,
                );
              } else {
                _historyService.addGeneratedItem(
                  content: item.content,
                  format: item.format,
                  category: item.category,
                );
              }
              _loadHistory();
            },
          ),
        ),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      _loadHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _shareItem(HistoryItem item) {
    Share.share(
      item.content,
      subject: '${item.format} ${item.isScanned ? 'Scanned' : 'Generated'}',
    );
  }

  void _openItemDetails(HistoryItem item) {
    if (item.isScanned) {
      // For scanned items, show result pages as before
      if (item.isQRCode) {
        final parsedData = QRDataParser.parseQRData(item.content);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRResultPage(parsedData: parsedData),
          ),
        );
      } else {
        final parsedData = BarcodeDataParser.parseBarcodeData(item.content, item.format);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarcodeResultPage(parsedData: parsedData),
          ),
        );
      }
    } else {
      // For generated items, show the generator page with the content
      _showGeneratedItemPage(item);
    }
  }

  void _showGeneratedItemPage(HistoryItem item) {
    if (item.isQRCode) {
      // Navigate to appropriate QR generator page based on content type
      _navigateToQRGeneratorPage(item);
    } else {
      // Navigate to appropriate barcode generator page
      _navigateToBarcodeGeneratorPage(item);
    }
  }

  void _navigateToQRGeneratorPage(HistoryItem item) {
    // For now, navigate to Text QR page as default
    // You can enhance this to detect the type and navigate to specific pages
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _getQRGeneratorPage(item),
      ),
    );
  }

  void _navigateToBarcodeGeneratorPage(HistoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _getBarcodeGeneratorPage(item),
      ),
    );
  }

  Widget _getQRGeneratorPage(HistoryItem item) {
    // You'll need to import the QR generator pages
    // For now, return a simple page that shows the generated QR
    return _GeneratedQRDisplayPage(item: item);
  }

  Widget _getBarcodeGeneratorPage(HistoryItem item) {
    // Return a page that shows the generated barcode
    return _GeneratedBarcodeDisplayPage(item: item);
  }

  Widget _buildHistoryItem(HistoryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isScanned 
              ? Colors.blue.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Icon(
            item.isQRCode 
                ? (item.isScanned ? Icons.qr_code_scanner : Icons.qr_code)
                : (item.isScanned ? Icons.scanner : Icons.barcode_reader),
            color: item.isScanned ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          item.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.content.length > 50 
                  ? '${item.content.substring(0, 50)}...'
                  : item.content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.displaySubtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                _openItemDetails(item);
                break;
              case 'copy':
                _copyToClipboard(item.content);
                break;
              case 'share':
                _shareItem(item);
                break;
              case 'delete':
                _deleteItem(item);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: Text('Open')),
            const PopupMenuItem(value: 'copy', child: Text('Copy')),
            const PopupMenuItem(value: 'share', child: Text('Share')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => _openItemDetails(item),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: _selectedFilter == 'all',
            onTap: () => _filterHistory('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Scanned',
            isSelected: _selectedFilter == 'scanned',
            onTap: () => _filterHistory('scanned'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Generated',
            isSelected: _selectedFilter == 'generated',
            onTap: () => _filterHistory('generated'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'QR Codes',
            isSelected: _selectedFilter == 'qr',
            onTap: () => _filterHistory('qr'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Barcodes',
            isSelected: _selectedFilter == 'barcode',
            onTap: () => _filterHistory('barcode'),
          ),
        ],
      ),
    );
  }

  String _buildItemCountText() {
    int totalCount = 0;
    switch (_selectedFilter) {
      case 'all':
        totalCount = _allHistory.length;
        break;
      case 'scanned':
        totalCount = _allHistory.where((item) => item.isScanned).length;
        break;
      case 'generated':
        totalCount = _allHistory.where((item) => item.isGenerated).length;
        break;
      case 'qr':
        totalCount = _allHistory.where((item) => item.isQRCode).length;
        break;
      case 'barcode':
        totalCount = _allHistory.where((item) => item.isBarcode).length;
        break;
    }
    
    if (totalCount <= _maxDisplayItems) {
      return 'Showing $totalCount items';
    } else {
      return 'Showing ${_filteredHistory.length} of $totalCount items (limited to $_maxDisplayItems)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            centerTitle: true,
            actions: [
              if (_allHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _clearAllHistory,
                  tooltip: 'Clear All',
                ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search history...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterHistory(_selectedFilter);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _searchHistory,
                ),
              ),
              
              // Filter chips
              _buildFilterChips(),
              
              // Show item count info
              if (_allHistory.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _buildItemCountText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // History list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No items found'
                                      : 'No history yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                                if (_searchController.text.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Scan or generate QR codes and barcodes to see them here',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView.builder(
                              itemCount: _filteredHistory.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryItem(_filteredHistory[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }
}

// Page to display generated QR code
class _GeneratedQRDisplayPage extends StatelessWidget {
  final HistoryItem item;
  
  // Global key for RepaintBoundary
  final GlobalKey _qrKey = GlobalKey();

  _GeneratedQRDisplayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated QR Code'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR Code Display
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'QR Code Result:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: SizedBox(
                          height: 200,
                          width: 200,
                          child: PrettyQrView.data(
                            data: item.content,
                            decoration: const PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Data Display
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        item.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generated: ${item.displaySubtitle}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
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
                        onPressed: () => _saveQRToGallery(context),
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
                        onPressed: () => _shareContent(context, item.content),
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
            
            const SizedBox(height: 16),
            
            Text(
              'Tip: "Save" stores to gallery, "Share" sends to other apps',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
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
  Future<void> _saveQRToGallery(BuildContext context) async {
    if (!context.mounted) return;

    try {
      // Capture QR code
      Uint8List? imageBytes = await _captureQRCode();
      if (imageBytes == null) {
        if (!context.mounted) return;
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
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gallery access permission denied. Using share instead.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          // Fallback to share
          await _shareQRCode(context);
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

      if (!context.mounted) return;

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
      if (!context.mounted) return;
      debugPrint('Save error: $e');

      // Show error and fallback to share
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save to gallery. Using share instead.'),
          backgroundColor: Colors.orange,
        ),
      );

      // Fallback to share functionality
      await _shareQRCode(context);
    }
  }

  // Function to share QR code
  Future<void> _shareQRCode(BuildContext context) async {
    if (!context.mounted) return;

    try {
      // Capture QR code
      Uint8List? imageBytes = await _captureQRCode();
      if (imageBytes == null) {
        if (!context.mounted) return;
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
        text: 'Generated QR Code',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareContent(BuildContext context, String content) {
    Share.share(content, subject: 'Generated QR Code');
  }
}

// Page to display generated barcode
class _GeneratedBarcodeDisplayPage extends StatelessWidget {
  final HistoryItem item;
  
  // Global key for RepaintBoundary  
  final GlobalKey _barcodeKey = GlobalKey();

  _GeneratedBarcodeDisplayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${item.format} Barcode'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barcode Display
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${item.format} Barcode Result:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RepaintBoundary(
                      key: _barcodeKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildBarcodeWidget(item.format, item.content),
                            const SizedBox(height: 8),
                            Text(
                              item.content,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Data Display
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barcode Data:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        item.content,
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Format: ${item.format} • Generated: ${item.displaySubtitle}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
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
                        onPressed: () => _saveBarcodeToGallery(context),
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
                        onPressed: () => _shareContent(context, item.content),
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
    );
  }

  Widget _buildBarcodeWidget(String format, String data) {
    // For simplicity, show a placeholder barcode representation
    // In a real implementation, you would use the actual barcode generation logic
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple barcode representation with vertical lines
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(20, (index) => Container(
              width: index % 3 == 0 ? 3 : 1,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: Colors.black,
            )),
          ),
        ],
      ),
    );
  }

  // Function to capture barcode as image
  Future<Uint8List?> _captureBarcode() async {
    try {
      RenderRepaintBoundary boundary =
          _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing barcode: $e');
      return null;
    }
  }

  // Function to save barcode
  Future<void> _saveBarcodeToGallery(BuildContext context) async {
    if (!context.mounted) return;

    try {
      Uint8List? imageBytes = await _captureBarcode();
      if (imageBytes == null) {
        if (!context.mounted) return;
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
          if (!context.mounted) return;
          await _shareBarcode(context);
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = '${item.format.toLowerCase()}_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsBytes(imageBytes);
      await Gal.putImage(tempFile.path, album: 'Barcodes');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.format} barcode saved to gallery successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }
    } catch (e) {
      if (!context.mounted) return;
      await _shareBarcode(context);
    }
  }

  // Function to share barcode
  Future<void> _shareBarcode(BuildContext context) async {
    if (!context.mounted) return;

    try {
      Uint8List? imageBytes = await _captureBarcode();
      if (imageBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${item.format.toLowerCase()}_barcode_${DateTime.now().millisecondsSinceEpoch}.png');

      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${item.format} Barcode: ${item.content}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareContent(BuildContext context, String content) {
    Share.share(content, subject: 'Generated ${item.format} Barcode');
  }
}
