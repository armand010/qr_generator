import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';
import '../providers/theme_provider.dart';
import 'qr_result_page.dart';
import 'scan_code_page.dart';

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
        _filteredHistory = history;
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
      
      switch (filter) {
        case 'all':
          _filteredHistory = _allHistory;
          break;
        case 'scanned':
          _filteredHistory = _allHistory.where((item) => item.isScanned).toList();
          break;
        case 'generated':
          _filteredHistory = _allHistory.where((item) => item.isGenerated).toList();
          break;
        case 'qr':
          _filteredHistory = _allHistory.where((item) => item.isQRCode).toList();
          break;
        case 'barcode':
          _filteredHistory = _allHistory.where((item) => item.isBarcode).toList();
          break;
      }
    });
  }

  void _searchHistory(String query) async {
    if (query.isEmpty) {
      _filterHistory(_selectedFilter);
      return;
    }

    final results = await _historyService.searchHistory(query);
    setState(() {
      _filteredHistory = results;
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
    if (item.isQRCode) {
      // Parse QR data for result page
      final parsedData = ParsedQRData(
        type: QRDataType.text, // Default to text for history items
        rawData: item.content,
        parsedData: {'text': item.content},
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRResultPage(parsedData: parsedData),
        ),
      );
    } else {
      // For barcode, show a simple dialog since we don't have BarResultPage
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${item.format} Barcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(item.content),
              const SizedBox(height: 16),
              Text('Format: ${item.format}'),
              Text('Type: ${item.isScanned ? 'Scanned' : 'Generated'}'),
              if (item.category != null)
                Text('Category: ${item.category}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _copyToClipboard(item.content),
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
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
              
              const SizedBox(height: 16),
              
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
