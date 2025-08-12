import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model_v3.dart';

class MealServiceV3 {
  static final _db = FirebaseFirestore.instance;

  // Curated Unsplash image URLs by meal type keywords
  static const Map<String, List<String>> _imagesByType = {
    'breakfast': [
      'https://images.unsplash.com/photo-1490474504059-bf2db5ab2348',
      'https://images.unsplash.com/photo-1525351484163-7529414344d8',
      'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666',
      'https://images.unsplash.com/photo-1493770348161-369560ae357d',
    ],
    'lunch': [
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
      'https://images.unsplash.com/photo-1543339308-43e59d6b73a6',
      'https://images.unsplash.com/photo-1604909052743-94e838986d24',
    ],
    'dinner': [
      'https://images.unsplash.com/photo-1467003909585-2f8a72700288',
      'https://images.unsplash.com/photo-1516100882582-96c3a05fe590',
      'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
    ],
  };

  static String _pickImage(String mealType, int index) {
    final key = mealType.toLowerCase();
    final list = _imagesByType[key] ?? _imagesByType['lunch']!;
    return '${list[index % list.length]}?auto=format&fit=crop&w=1200&q=60';
    }

  static String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"(^-|-$)"), '');
  }

  static int _extractInt(String src, String label) {
    final m = RegExp('(\\d+)\\s*g\\s*$label').firstMatch(src.toLowerCase());
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }

  static int _extractCalories(String src) {
    final m = RegExp('(\\d+)\\s*(k?cal|calories?)').firstMatch(src.toLowerCase());
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }

  // Seed meals from bundled JSON asset. Safe to call multiple times; it upserts by id.
  // If the JSON asset is empty or missing, falls back to built-in sample meals.
  static Future<int> seedFromJsonAsset() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/gofresh_meals_final.json');
      final data = json.decode(jsonStr);
      if (data is! List) {
        debugPrint('[MealServiceV3] JSON root is not a list');
        return await _seedFromSamples();
      }

      if (data.isEmpty) {
        debugPrint('[MealServiceV3] JSON list is empty; seeding from samples');
        return await _seedFromSamples();
      }

      int total = 0;
      int ops = 0;
      WriteBatch batch = _db.batch();
      for (var i = 0; i < data.length; i++) {
        final raw = data[i];
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();

        final name = (map['name'] ?? map['title'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final mealType = (map['category'] ?? map['mealType'] ?? 'lunch').toString().toLowerCase();
        final description = (map['description'] ?? map['desc'] ?? '').toString();
        final ingredients = (map['ingredients'] is List)
            ? List<String>.from(map['ingredients'])
            : (map['ingredients'] is String)
                ? map['ingredients'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                : <String>[];
        final allergensSrc = (map['allergens'] ?? map['contains'] ?? '').toString();
        final allergens = allergensSrc.toLowerCase().contains('none')
            ? <String>[]
            : allergensSrc
                .split(RegExp('[,;]'))
                .map((e) => e.replaceAll(RegExp(r'\([^)]*\)'), '').trim())
                .where((e) => e.isNotEmpty)
                .toList();
        final nutrition = (map['nutrition'] ?? map['macros'] ?? '').toString();
        final calories = (map['calories'] is num)
            ? (map['calories'] as num).toInt()
            : _extractCalories(nutrition);
        final protein = (map['protein'] is num)
            ? (map['protein'] as num).toInt()
            : _extractInt(nutrition, 'protein');
        final carbs = (map['carbs'] is num)
            ? (map['carbs'] as num).toInt()
            : _extractInt(nutrition, 'carbs');
        final fat = (map['fat'] is num)
            ? (map['fat'] as num).toInt()
            : _extractInt(nutrition, 'fats');

        final id = 'meal_${_slug(name)}';
        final imageUrl = _pickImage(mealType, i);

        final meal = MealModelV3(
          id: id,
          name: name,
          description: description,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          ingredients: ingredients,
          allergens: allergens,
          icon: Icons.fastfood,
          imageUrl: imageUrl,
          mealType: mealType,
          price: 0.0,
        );

        final doc = _db.collection('meals').doc(meal.id);
        batch.set(doc, {
          ...meal.toFirestore(),
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        total++;
        ops++;

        // Commit in chunks to avoid 500 ops limit
        if (ops >= 400) {
          await batch.commit();
          ops = 0;
          batch = _db.batch();
        }
      }
      if (ops > 0) {
        await batch.commit();
      }
      debugPrint('[MealServiceV3] Seeded $total meals');
      return total;
    } catch (e) {
      debugPrint('[MealServiceV3] seedFromJsonAsset error: $e');
      // If asset read/parse fails, attempt to seed from samples as a fallback
      try {
        return await _seedFromSamples();
      } catch (_) {
        return 0;
      }
    }
  }

  static Future<List<MealModelV3>> getMeals({String mealType = 'lunch', int limit = 50}) async {
    try {
      final snap = await _db
          .collection('meals')
          .where('mealType', isEqualTo: mealType.toLowerCase())
          .limit(limit)
          .get();
    return snap.docs
      .map((d) => MealModelV3.fromJson(d.data()))
          .toList();
    } catch (e) {
      debugPrint('[MealServiceV3] getMeals error: $e');
      return [];
    }
  }

  // Seed a token-based plan metadata document and ensure user profile fields exist
  static Future<void> seedTokenPlanIfNeeded() async {
    try {
      final db = FirebaseFirestore.instance;
      final plans = db.collection('meal_plans');
      final tokenDoc = plans.doc('plan_tokens');
      final snap = await tokenDoc.get();
      if (!snap.exists) {
        await tokenDoc.set({
          'id': 'plan_tokens',
          'name': 'Flex Tokens',
          'description': 'Buy tokens and redeem any meal. 1 token = 1 meal.',
          'planType': 'token',
          'tokenPrice': 13.0,
          'tokensIncluded': 10,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[MealServiceV3] seedTokenPlanIfNeeded error: $e');
    }
  }

  // Fallback seeding from built-in sample meals
  static Future<int> _seedFromSamples() async {
    final samples = MealModelV3.getSampleMeals();
    if (samples.isEmpty) return 0;

    int total = 0;
    int ops = 0;
    WriteBatch batch = _db.batch();
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final id = 'meal_${_slug(s.name)}';
      final imageUrl = (s.imageUrl.isNotEmpty)
          ? s.imageUrl
          : _pickImage(s.mealType, i);

      final doc = _db.collection('meals').doc(id);
      final base = Map<String, dynamic>.from(s.toFirestore());
      base['id'] = id;
      base['imageUrl'] = imageUrl;
      batch.set(
        doc,
        {
          ...base,
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      total++;
      ops++;

      if (ops >= 400) {
        await batch.commit();
        ops = 0;
        batch = _db.batch();
      }
    }
    if (ops > 0) {
      await batch.commit();
    }
    debugPrint('[MealServiceV3] Seeded $total meals from samples');
    return total;
  }
}
