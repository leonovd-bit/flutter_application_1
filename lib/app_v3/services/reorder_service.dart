import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/meal_model_v3.dart';

class ReorderService {
  static const String _reorderHistoryKey = 'reorder_history';
  
  // Save a reorder to history
  static Future<void> saveReorder({
    required String originalOrderId,
    required MealPlanType mealPlanType,
    required double totalAmount,
    required String deliveryAddress,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final reorderEntry = {
      'id': 'reorder_${DateTime.now().millisecondsSinceEpoch}',
      'originalOrderId': originalOrderId,
      'reorderDate': DateTime.now().millisecondsSinceEpoch,
      'mealPlanType': mealPlanType.toString().split('.').last,
      'totalAmount': totalAmount,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'isFavorite': false,
    };
    
    final reorderHistory = prefs.getStringList(_reorderHistoryKey) ?? [];
    reorderHistory.add(json.encode(reorderEntry));
    
    // Keep only last 20 reorders
    if (reorderHistory.length > 20) {
      reorderHistory.removeRange(0, reorderHistory.length - 20);
    }
    
    await prefs.setStringList(_reorderHistoryKey, reorderHistory);
  }
  
  // Get all reorder history
  static Future<List<Map<String, dynamic>>> getReorderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final reorderHistory = prefs.getStringList(_reorderHistoryKey) ?? [];
    
    return reorderHistory
        .map((reorderJson) => json.decode(reorderJson) as Map<String, dynamic>)
        .toList()
        .reversed // Most recent first
        .toList();
  }
  
  // Get recent reorders for quick access
  static Future<List<Map<String, dynamic>>> getRecentReorders({int limit = 5}) async {
    final allReorders = await getReorderHistory();
    return allReorders.take(limit).toList();
  }
  
  // Mark a reorder as favorite
  static Future<void> toggleFavoriteReorder(String reorderId) async {
    final prefs = await SharedPreferences.getInstance();
    final reorderHistory = prefs.getStringList(_reorderHistoryKey) ?? [];
    
    final updatedHistory = reorderHistory.map((reorderJson) {
      final reorder = json.decode(reorderJson) as Map<String, dynamic>;
      if (reorder['id'] == reorderId) {
        reorder['isFavorite'] = !(reorder['isFavorite'] ?? false);
      }
      return json.encode(reorder);
    }).toList();
    
    await prefs.setStringList(_reorderHistoryKey, updatedHistory);
  }
  
  // Get favorite reorders
  static Future<List<Map<String, dynamic>>> getFavoriteReorders() async {
    final allReorders = await getReorderHistory();
    return allReorders.where((reorder) => reorder['isFavorite'] == true).toList();
  }
  
  // Clear all reorder history
  static Future<void> clearReorderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reorderHistoryKey);
  }
  
  // Get reorder statistics
  static Future<Map<String, dynamic>> getReorderStats() async {
    final allReorders = await getReorderHistory();
    
    if (allReorders.isEmpty) {
      return {
        'totalReorders': 0,
        'totalSpent': 0.0,
        'mostReorderedPlan': null,
        'averageOrderValue': 0.0,
      };
    }
    
    final totalReorders = allReorders.length;
    final totalSpent = allReorders.fold(0.0, (sum, reorder) => sum + (reorder['totalAmount'] ?? 0.0));
    
    // Count meal plan types
    final planCounts = <String, int>{};
    for (final reorder in allReorders) {
      final planType = reorder['mealPlanType'] as String?;
      if (planType != null) {
        planCounts[planType] = (planCounts[planType] ?? 0) + 1;
      }
    }
    
    String? mostReorderedPlan;
    int maxCount = 0;
    planCounts.forEach((plan, count) {
      if (count > maxCount) {
        maxCount = count;
        mostReorderedPlan = plan;
      }
    });
    
    return {
      'totalReorders': totalReorders,
      'totalSpent': totalSpent,
      'mostReorderedPlan': mostReorderedPlan,
      'averageOrderValue': totalSpent / totalReorders,
      'planCounts': planCounts,
    };
  }
  
  // Check if an order has been reordered before
  static Future<bool> hasBeenReordered(String originalOrderId) async {
    final allReorders = await getReorderHistory();
    return allReorders.any((reorder) => reorder['originalOrderId'] == originalOrderId);
  }
  
  // Get reorder count for a specific order
  static Future<int> getReorderCount(String originalOrderId) async {
    final allReorders = await getReorderHistory();
    return allReorders.where((reorder) => reorder['originalOrderId'] == originalOrderId).length;
  }
}
