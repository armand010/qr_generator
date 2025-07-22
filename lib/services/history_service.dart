import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class HistoryService {
  static const String _historyKey = 'qr_barcode_history';
  static const int _maxHistoryItems = 100; // Limit to prevent storage overflow

  // Singleton pattern
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  // Get all history items
  Future<List<HistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) return [];
      
      final List<dynamic> historyList = json.decode(historyJson);
      
      return historyList
          .map((item) => HistoryItem.fromJson(item))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by newest first
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  // Add scanned item to history
  Future<void> addScannedItem({
    required String content,
    required String format,
  }) async {
    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: format == 'QR_CODE' ? 'qr_scan' : 'barcode_scan',
      format: format,
      timestamp: DateTime.now(),
    );
    
    await _addToHistory(item);
  }

  // Add generated item to history
  Future<void> addGeneratedItem({
    required String content,
    required String format,
    String? category,
  }) async {
    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: format == 'QR_CODE' ? 'qr_generate' : 'barcode_generate',
      format: format,
      timestamp: DateTime.now(),
      category: category,
    );
    
    await _addToHistory(item);
  }

  // Private method to add item to history
  Future<void> _addToHistory(HistoryItem item) async {
    try {
      final history = await getHistory();
      
      // Check if identical item already exists (avoid duplicates)
      final existingIndex = history.indexWhere((existingItem) => 
          existingItem.content == item.content && 
          existingItem.format == item.format &&
          existingItem.type == item.type);
      
      if (existingIndex != -1) {
        // Update timestamp of existing item
        history[existingIndex] = HistoryItem(
          id: history[existingIndex].id,
          content: item.content,
          type: item.type,
          format: item.format,
          timestamp: DateTime.now(),
          category: item.category,
        );
      } else {
        // Add new item to the beginning
        history.insert(0, item);
      }
      
      // Limit history size
      if (history.length > _maxHistoryItems) {
        history.removeRange(_maxHistoryItems, history.length);
      }
      
      await _saveHistory(history);
    } catch (e) {
      print('Error adding to history: $e');
    }
  }

  // Save history to SharedPreferences
  Future<void> _saveHistory(List<HistoryItem> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(history.map((item) => item.toJson()).toList());
      await prefs.setString(_historyKey, historyJson);
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  // Delete specific item from history
  Future<void> deleteItem(String id) async {
    try {
      final history = await getHistory();
      history.removeWhere((item) => item.id == id);
      await _saveHistory(history);
    } catch (e) {
      print('Error deleting item: $e');
    }
  }

  // Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  // Get history by type
  Future<List<HistoryItem>> getHistoryByType(String type) async {
    final history = await getHistory();
    return history.where((item) => item.type == type).toList();
  }

  // Get scanned items only
  Future<List<HistoryItem>> getScannedItems() async {
    final history = await getHistory();
    return history.where((item) => item.isScanned).toList();
  }

  // Get generated items only
  Future<List<HistoryItem>> getGeneratedItems() async {
    final history = await getHistory();
    return history.where((item) => item.isGenerated).toList();
  }

  // Search history
  Future<List<HistoryItem>> searchHistory(String query) async {
    if (query.trim().isEmpty) return await getHistory();
    
    final history = await getHistory();
    final lowercaseQuery = query.toLowerCase();
    
    return history.where((item) {
      return item.content.toLowerCase().contains(lowercaseQuery) ||
             item.format.toLowerCase().contains(lowercaseQuery) ||
             (item.category?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    final history = await getHistory();
    
    return {
      'total': history.length,
      'scanned': history.where((item) => item.isScanned).length,
      'generated': history.where((item) => item.isGenerated).length,
      'qr_codes': history.where((item) => item.isQRCode).length,
      'barcodes': history.where((item) => item.isBarcode).length,
    };
  }
}