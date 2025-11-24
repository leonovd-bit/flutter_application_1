import 'package:flutter/foundation.dart';
import '../../models/meal_model_v3.dart';

/// Simple in-memory cache to avoid repeated JSON parsing of the same meals.
/// Use [MealRepositoryV3.instance.fromJson] instead of directly calling
/// `MealModelV3.fromJson` in high-frequency parsing paths (home timeline,
/// schedule loading, upcoming orders).
class MealRepositoryV3 {
  MealRepositoryV3._();
  static final MealRepositoryV3 instance = MealRepositoryV3._();

  final Map<String, MealModelV3> _cache = <String, MealModelV3>{};

  /// Returns an existing cached meal or parses and stores a new instance.
  /// If the JSON lacks an id, a deterministic slug is generated from name.
  MealModelV3 fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      throw ArgumentError('Meal JSON cannot be empty');
    }
    String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString();
    if (id.isEmpty) {
      // Derive stable id from name to allow caching across different payloads.
      id = 'meal_${_slug(name)}';
      json = {...json, 'id': id};
    }
    final existing = _cache[id];
    if (existing != null) return existing;
    final meal = MealModelV3.fromJson(json);
    _cache[id] = meal;
    if (kDebugMode && _cache.length % 50 == 0) {
      // ignore: avoid_print
      print('[MealRepositoryV3] Cache size now ${_cache.length}');
    }
    return meal;
  }

  /// Batch helper.
  List<MealModelV3> fromJsonList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => fromJson(m))
        .toList();
  }

  bool containsId(String id) => _cache.containsKey(id);
  int get size => _cache.length;
  void clear() => _cache.clear();

  String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"(^-|-$)"), '');
  }
}
