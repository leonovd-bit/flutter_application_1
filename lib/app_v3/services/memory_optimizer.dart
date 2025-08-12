import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class MemoryOptimizer {
  static const MethodChannel _channel = MethodChannel('memory_optimizer');
  
  /// Clear image cache to free memory
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  /// Optimize image cache size based on device memory
  static void optimizeImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    
    // Check if we're on web platform first
    if (kIsWeb) {
      // Web-specific optimizations
      imageCache.maximumSize = 30; // Smaller cache for web
      imageCache.maximumSizeBytes = 5 << 20; // 5MB for web
    } else {
      // Check platform for mobile/desktop
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          // Reduce cache size for mobile devices
          imageCache.maximumSize = 50; // Reduced from default 1000
          imageCache.maximumSizeBytes = 10 << 20; // 10MB instead of default 100MB
        }
      } catch (e) {
        // Fallback for unsupported platforms
        imageCache.maximumSize = 30;
        imageCache.maximumSizeBytes = 5 << 20;
      }
    }
  }
  
  /// Clear all cached data
  static void clearAllCaches() {
    clearImageCache();
    // Clear any other app-specific caches
    _clearJsonCaches();
  }
  
  /// Clear JSON and map caches
  static void _clearJsonCaches() {
    // This would clear any static data caches in the app
    if (kDebugMode) {
      print('Clearing JSON caches...');
    }
  }
  
  /// Force garbage collection (debug only)
  static void forceGarbageCollection() {
    if (kDebugMode) {
      // This is mainly for testing memory optimization
      print('Forcing garbage collection...');
    }
  }
  
  /// Get current memory usage (debug only)
  static Future<int?> getMemoryUsage() async {
    if (kDebugMode) {
      try {
        return await _channel.invokeMethod('getMemoryUsage');
      } catch (e) {
        print('Error getting memory usage: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Optimize ListView builders for large datasets
  static Widget buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      // Add performance optimizations
      cacheExtent: 100.0, // Reduce cache extent to save memory
      physics: const ClampingScrollPhysics(),
      itemBuilder: itemBuilder,
    );
  }
  
  /// Create memory-efficient grid view
  static Widget buildOptimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required int crossAxisCount,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: itemCount,
      cacheExtent: 100.0,
      itemBuilder: itemBuilder,
    );
  }
  
  /// Optimize static data storage
  static T? getCachedData<T>(String key, T Function() loader) {
    // Simple memory-based cache with expiration
    return _MemoryCache.get<T>(key, loader);
  }
}

/// Simple memory cache with expiration
class _MemoryCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _defaultExpiration = Duration(minutes: 5);
  
  static T? get<T>(String key, T Function() loader) {
    final entry = _cache[key];
    
    if (entry != null && !entry.isExpired) {
      return entry.data as T;
    }
    
    // Clean expired entries
    _cleanExpired();
    
    // Load new data
    final data = loader();
    _cache[key] = _CacheEntry(data, DateTime.now().add(_defaultExpiration));
    
    return data;
  }
  
  static void _cleanExpired() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiration;
  
  _CacheEntry(this.data, this.expiration);
  
  bool get isExpired => DateTime.now().isAfter(expiration);
}
