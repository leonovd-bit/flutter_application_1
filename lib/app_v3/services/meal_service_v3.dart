import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model_v3.dart';

class MealServiceV3 {
  static final _db = FirebaseFirestore.instance;

  // Local asset image URLs by meal type
  static const Map<String, List<String>> _imagesByType = {
    'breakfast': [
      'assets/images/meals/pancakes-with-berries.jpg',
      'assets/images/meals/french-toast.jpg',
      'assets/images/meals/eggs-benedict.jpg',
      'assets/images/meals/greek-yogurt-parfait.jpg',
      'assets/images/meals/ham-and-cheese-omelette.jpg',
      'assets/images/meals/spinach-omelette.jpg',
      'assets/images/meals/avocado-toast.jpg',
    ],
    'lunch': [
      'assets/images/meals/grilled-chicken-salad.jpg',
      'assets/images/meals/chicken-caesar-wrap.jpg',
      'assets/images/meals/turkey-sandwich.jpg',
      'assets/images/meals/quinoa-bowl.jpg',
      'assets/images/meals/lentil-soup.jpg',
      'assets/images/meals/grilled-cheese.jpg',
      'assets/images/meals/veggie-wrap.jpg',
      'assets/images/meals/fruit-salad.jpg',
    ],
    'dinner': [
      'assets/images/meals/chicken-alfredo.jpg',
      'assets/images/meals/roast-beef-dinner.jpg',
      'assets/images/meals/salmon-with-quinoa.jpg',
      'assets/images/meals/chicken-parmesan.jpg',
      'assets/images/meals/pasta-primavera.jpg',
      'assets/images/meals/beef-burger.jpg',
      'assets/images/meals/chicken-tikka-masala.jpg',
      'assets/images/meals/shrimp-scampi.jpg',
      'assets/images/meals/vegetable-lasagna.jpg',
      'assets/images/meals/mushroom-risotto.jpg',
    ],
  };

  static String _pickImage(String mealType, int index) {
    final key = mealType.toLowerCase();
    final list = _imagesByType[key] ?? _imagesByType['lunch']!;
    return list[index % list.length];
  }

  static String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"(^-|-$)"), '');
  }

  // Build meal list directly from local JSON asset (no Firestore writes)
  static Future<List<MealModelV3>> _mealsFromJsonAsset({String mealType = 'lunch', int limit = 50}) async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/gofresh_meals_final.json');
      final data = json.decode(jsonStr);
      if (data is! List || data.isEmpty) return [];
      final List<MealModelV3> out = [];
      for (var i = 0; i < data.length; i++) {
        final raw = data[i];
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final name = (map['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final description = (map['description'] ?? '').toString();
        final mtRaw = (map['category'] ?? map['mealType'] ?? '').toString().trim();
        final inferredType = mtRaw.isEmpty ? _inferMealType(name, description: description) : mtRaw.toLowerCase();
        if (inferredType != mealType.toLowerCase()) continue;
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
        final providedImage = (map['imageUrl'] ?? map['image'] ?? map['img'] ?? '').toString().trim();
        final imageUrl = _validImageUrl(providedImage) ? providedImage : _pickImage(inferredType, i);
        final price = _parsePrice(map['price']);
        final restaurant = (map['restaurant'] ?? '').toString().trim();
        final menuCategory = (map['menuCategory'] ?? '').toString().trim();

        out.add(MealModelV3(
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
          mealType: inferredType,
          price: price,
          restaurant: restaurant.isEmpty ? null : restaurant,
          menuCategory: menuCategory.isEmpty ? null : menuCategory,
        ));
        if (out.length >= limit) break;
      }
      return out;
    } catch (e) {
      debugPrint('[MealServiceV3] _mealsFromJsonAsset error: $e');
      return [];
    }
  }

  /// Public helper: load meals from bundled JSON with optional filters
  static Future<List<MealModelV3>> getMealsFromLocal({
    String mealType = 'lunch',
    String? menuCategory,
    int limit = 50,
  }) async {
    final base = await _mealsFromJsonAsset(mealType: mealType, limit: limit * 2);
    final filtered = menuCategory == null
        ? base
        : base.where((m) => (m.menuCategory ?? 'premade').toLowerCase() == menuCategory.toLowerCase()).toList();
    return filtered.take(limit).toList();
  }

  static bool _validImageUrl(String? url) {
    if (url == null) return false;
    final u = url.trim();
    if (u.isEmpty) return false;
    if (!(u.startsWith('http://') || u.startsWith('https://'))) return false;
    final parsed = Uri.tryParse(u);
    if (parsed == null || parsed.host.isEmpty) return false;
    // Reject known placeholder domains
    if (parsed.host.contains('example.com')) return false;
    return true;
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final s = value.toString().trim();
    if (s.isEmpty) return 0.0;
    // Strip $ and commas
    final cleaned = s.replaceAll(RegExp(r'[^0-9\.]'), '');
    final d = double.tryParse(cleaned);
    return d ?? 0.0;
  }

  // Infer mealType from the meal name/description when not provided by JSON
  static String _inferMealType(String name, {String description = ''}) {
    final text = ('$name ${description}').toLowerCase();
    // Breakfast keywords
    const breakfast = [
      'breakfast', 'pancake', 'omelette', 'omelet', 'toast', 'parfait', 'yogurt',
      'eggs benedict', 'french toast', 'cereal', 'oat', 'oatmeal', 'waffle', 'bagel'
    ];
    // Dinner-leaning keywords
    const dinner = [
      'steak', 'roast', 'risotto', 'parmesan', 'scampi', 'curry', 'fajita', 'lasagna',
      'salmon', 'shrimp', 'beef stew', 'burger', 'alfredo', 'pot pie'
    ];
    // Lunch-leaning keywords
    const lunch = [
      'salad', 'sandwich', 'wrap', 'burrito', 'quesadilla', 'soup', 'bowl', 'pizza', 'stir fry'
    ];

    bool containsAny(List<String> list) => list.any((k) => text.contains(k));
    if (containsAny(breakfast)) return 'breakfast';
    if (containsAny(dinner)) return 'dinner';
    if (containsAny(lunch)) return 'lunch';

    // Fallback based on typical dining pattern
    return 'lunch';
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
  // Prefer explicit category/mealType; otherwise infer from name/description
    String mealTypeRaw = (map['category'] ?? map['mealType'] ?? '').toString().trim();
    final description = (map['description'] ?? map['desc'] ?? '').toString();
    final mealType = mealTypeRaw.isEmpty
      ? _inferMealType(name, description: description)
      : mealTypeRaw.toLowerCase();
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
        final providedImage = (map['imageUrl'] ?? map['image'] ?? map['img'] ?? '').toString().trim();
        final imageUrl = _validImageUrl(providedImage) ? providedImage : _pickImage(mealType, i);
        final price = _parsePrice(map['price']);
        final restaurant = (map['restaurant'] ?? '').toString().trim();
        final menuCategory = (map['menuCategory'] ?? '').toString().trim();

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
          price: price,
          restaurant: restaurant.isEmpty ? null : restaurant,
          menuCategory: menuCategory.isEmpty ? null : menuCategory,
        );

        // Debug meal creation
        print('🍴 Created meal: $name');
        print('   📷 ImageUrl: "$imageUrl"');
        print('   📁 ImagePath: "${meal.imagePath}"');

        final doc = _db.collection('meals').doc(meal.id);
        final payload = {
          ...meal.toFirestore(),
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // Preserve extra metadata if present
        if (restaurant.isNotEmpty) payload['restaurant'] = restaurant;
        if (menuCategory.isNotEmpty) payload['menuCategory'] = menuCategory;
        batch.set(doc, payload, SetOptions(merge: true));
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

  // Update only the imageUrl field for meals that exist in Firestore, using the JSON as source.
  // It matches meals by the same id generation rule used in seeding: 'meal_' + slug(name).
  // Returns the number of documents updated. Skips entries with no provided image URL.
  static Future<int> updateImagesFromJsonAsset() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/gofresh_meals_final.json');
      final data = json.decode(jsonStr);
      if (data is! List || data.isEmpty) return 0;

      int updated = 0;
      int ops = 0;
      WriteBatch batch = _db.batch();
      for (var i = 0; i < data.length; i++) {
        final raw = data[i];
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final name = (map['name'] ?? map['title'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final description = (map['description'] ?? map['desc'] ?? '').toString();
        // Use JSON mealType if present for deterministic fallback; else infer
        String mealTypeRaw = (map['category'] ?? map['mealType'] ?? '').toString().trim();
        final mealType = mealTypeRaw.isEmpty
            ? _inferMealType(name, description: description)
            : mealTypeRaw.toLowerCase();
        final providedImage = (map['imageUrl'] ?? map['image'] ?? map['img'] ?? '').toString().trim();
        final finalImage = _validImageUrl(providedImage) ? providedImage : _pickImage(mealType, i);

        final id = 'meal_${_slug(name)}';
        final docRef = _db.collection('meals').doc(id);
        batch.set(docRef, {
          'id': id,
          'imageUrl': finalImage,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        updated++;
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
      debugPrint('[MealServiceV3] Updated images for $updated meals');
      return updated;
    } catch (e) {
      debugPrint('[MealServiceV3] updateImagesFromJsonAsset error: $e');
      return 0;
    }
  }

  /// Update the imageUrl for meals to point to bundled asset paths, similar to how the app logo is bundled.
  /// This assumes you've placed images at assets/images/meals/<meal-slug>.png (or .jpg).
  /// The slug uses the same rule as seeding: meal_<slug(name)>. We'll strip the 'meal_' prefix for file naming.
  /// If both .png and .jpg may exist, we default to .png path; the UI uses AppImage which handles asset paths.
  static Future<int> updateImagesToBundledAssets({String subdir = 'assets/images/meals', String ext = 'png'}) async {
    try {
      final snap = await _db.collection('meals').get();
      if (snap.docs.isEmpty) return 0;
      int updated = 0;
      int ops = 0;
      WriteBatch batch = _db.batch();
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['id'] ?? d.id).toString();
        final name = (data['name'] ?? '').toString();
        if (name.isEmpty) continue;
        // id format: meal_<slug>; derive file name from slug
        final slug = id.startsWith('meal_') ? id.substring(5) : _slug(name);
        final assetPath = '$subdir/$slug.$ext';
        batch.set(d.reference, {
          'imageUrl': assetPath,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        updated++;
        ops++;
        if (ops >= 400) {
          await batch.commit();
          ops = 0;
          batch = _db.batch();
        }
      }
      if (ops > 0) await batch.commit();
      debugPrint('[MealServiceV3] Updated $updated meals to asset images under $subdir');
      return updated;
    } catch (e) {
      debugPrint('[MealServiceV3] updateImagesToBundledAssets error: $e');
      return 0;
    }
  }

  /// Auto-detect existing bundled assets for each meal slug by reading AssetManifest.json.
  /// Supports mixed extensions (jpg, jfif, jpeg, png). Picks by priority: jpg > jfif > jpeg > png.
  static Future<int> updateImagesToExistingBundledAssetsFlexible({String subdir = 'assets/images/meals'}) async {
    try {
      // First try: read the asset manifest (older Flutter kept JSON, newer may use BIN only).
      // If manifest load fails or yields nothing, fall back to probing assets directly per slug.
      const priority = ['jpg', 'jfif', 'jpeg', 'png'];
      Map<String, String> slugToAsset = {};
      try {
        final manifestStr = await rootBundle.loadString('AssetManifest.json');
        final manifest = json.decode(manifestStr);
        final keys = (manifest as Map).keys.cast<String>();
        final mealsAssets = keys.where((k) => k.startsWith('$subdir/')).toList();
        for (final asset in mealsAssets) {
          final name = asset.split('/').last; // slug.ext
          final dot = name.lastIndexOf('.');
          if (dot <= 0) continue;
          final slug = name.substring(0, dot);
          final ext = name.substring(dot + 1).toLowerCase();
          final idx = priority.indexOf(ext);
          if (idx == -1) continue;
          final existing = slugToAsset[slug];
          if (existing == null) {
            slugToAsset[slug] = asset;
          } else {
            final existingExt = existing.substring(existing.lastIndexOf('.') + 1).toLowerCase();
            final existingIdx = priority.indexOf(existingExt);
            if (existingIdx == -1 || idx < existingIdx) {
              slugToAsset[slug] = asset;
            }
          }
        }
      } catch (_) {
        // Ignore manifest load errors; we'll probe directly below.
      }

      // Update Firestore meals to point to the found asset path for each slug
      final snap = await _db.collection('meals').get();
      if (snap.docs.isEmpty) return 0;
      int updated = 0;
      int ops = 0;
      WriteBatch batch = _db.batch();
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['id'] ?? d.id).toString();
        final name = (data['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final slug = id.startsWith('meal_') ? id.substring(5) : _slug(name);
        String? asset = slugToAsset[slug];
        // Fallback probe if manifest did not list this slug
        if (asset == null) {
          for (final ext in priority) {
            final candidate = '$subdir/$slug.$ext';
            try {
              await rootBundle.load(candidate);
              asset = candidate;
              break;
            } catch (_) {
              // Not found, continue to next ext
            }
          }
          if (asset != null) {
            slugToAsset[slug] = asset; // cache for potential reuse
          }
        }
        if (asset == null) continue; // no matching file present
        batch.set(d.reference, {
          'imageUrl': asset,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        updated++;
        ops++;
        if (ops >= 400) {
          await batch.commit();
          ops = 0;
          batch = _db.batch();
        }
      }
      if (ops > 0) await batch.commit();
      debugPrint('[MealServiceV3] Updated $updated meals to existing asset images (flexible)');
      return updated;
    } catch (e) {
      debugPrint('[MealServiceV3] updateImagesToExistingBundledAssetsFlexible error: $e');
      return 0;
    }
  }

  static Future<List<MealModelV3>> getMeals({String mealType = 'lunch', int limit = 50}) async {
    debugPrint('[MealServiceV3] getMeals called with mealType: "$mealType", limit: $limit');
    try {
      debugPrint('[MealServiceV3] Querying Firestore: collection("meals").where("mealType", isEqualTo: "${mealType.toLowerCase()}")');
      
      final snap = await _db
          .collection('meals')
          .where('mealType', isEqualTo: mealType.toLowerCase())
          .limit(limit)
          .get();
          
      debugPrint('[MealServiceV3] Firestore query returned ${snap.docs.length} documents');
      
      if (snap.docs.isEmpty) {
        debugPrint('[MealServiceV3] ⚠️ No meals found for mealType: "$mealType"');
        // Check if there are ANY meals in the collection
        final allSnap = await _db.collection('meals').limit(5).get();
        debugPrint('[MealServiceV3] Total meals in collection: ${allSnap.docs.length}');
        if (allSnap.docs.isNotEmpty) {
          debugPrint('[MealServiceV3] Sample meals in database:');
          for (final doc in allSnap.docs) {
            final data = doc.data();
            debugPrint('[MealServiceV3]   - ${data['name']} (mealType: "${data['mealType']}")');
          }
        }
      }
      
      List<MealModelV3> meals = snap.docs
          .map((d) => MealModelV3.fromJson(d.data()))
          .toList();
      // Filter to only Victus-provided premade meals (exclude custom)
      meals = meals.where((m) {
        final r = (m.restaurant ?? '').toLowerCase();
        final cat = (m.menuCategory ?? 'premade').toLowerCase();
        final isVictus = r == 'greenblend' || r == 'sen saigon';
        final isPremade = cat == 'premade';
        return isVictus && isPremade;
      }).toList();
          
      debugPrint('[MealServiceV3] Successfully converted ${meals.length} documents to MealModelV3 objects');
      if (meals.isNotEmpty) return meals;
      // Fallback to local JSON if Firestore is empty or unavailable
      final localMeals = await _mealsFromJsonAsset(mealType: mealType, limit: limit);
      if (localMeals.isNotEmpty) {
        debugPrint('[MealServiceV3] Using local JSON fallback for "$mealType" (${localMeals.length} meals)');
      }
      return localMeals;
    } catch (e) {
      debugPrint('[MealServiceV3] ❌ getMeals error: $e');
      debugPrint('[MealServiceV3] Error type: ${e.runtimeType}');
      // On error, attempt local JSON fallback
      final localMeals = await _mealsFromJsonAsset(mealType: mealType, limit: limit);
      return localMeals;
    }
  }

  // Get all meals without filtering by meal type
  static Future<List<MealModelV3>> getAllMeals({int limit = 50}) async {
    try {
      final snap = await _db
          .collection('meals')
          .limit(limit)
          .get();
      List<MealModelV3> list = snap.docs
          .map((d) => MealModelV3.fromJson(d.data()))
          .toList();
      // Filter to only Victus-provided premade meals (exclude custom)
      list = list.where((m) {
        final r = (m.restaurant ?? '').toLowerCase();
        final cat = (m.menuCategory ?? 'premade').toLowerCase();
        final isVictus = r == 'greenblend' || r == 'sen saigon';
        final isPremade = cat == 'premade';
        return isVictus && isPremade;
      }).toList();
      if (list.isNotEmpty) return list.take(limit).toList();
      // Fallback to JSON: return any meal types up to limit
      final jsonStr = await rootBundle.loadString('assets/data/gofresh_meals_final.json');
      final data = json.decode(jsonStr);
      if (data is! List || data.isEmpty) return [];
      final List<MealModelV3> out = [];
      for (var i = 0; i < data.length; i++) {
        final raw = data[i];
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final name = (map['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final description = (map['description'] ?? '').toString();
        final mtRaw = (map['category'] ?? map['mealType'] ?? '').toString().trim();
        final inferredType = mtRaw.isEmpty ? _inferMealType(name, description: description) : mtRaw.toLowerCase();
        final id = 'meal_${_slug(name)}';
        final providedImage = (map['imageUrl'] ?? map['image'] ?? map['img'] ?? '').toString().trim();
        final imageUrl = _validImageUrl(providedImage) ? providedImage : _pickImage(inferredType, i);
        final price = _parsePrice(map['price']);
        final ingredients = (map['ingredients'] is List) ? List<String>.from(map['ingredients']) : <String>[];
        final allergensSrc = (map['allergens'] ?? '').toString();
        final allergens = allergensSrc.isEmpty ? <String>[] : allergensSrc.split(RegExp('[,;]')).map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
        final calories = (map['calories'] is num) ? (map['calories'] as num).toInt() : 0;
        final protein = (map['protein'] is num) ? (map['protein'] as num).toInt() : 0;
        final carbs = (map['carbs'] is num) ? (map['carbs'] as num).toInt() : 0;
        final fat = (map['fat'] is num) ? (map['fat'] as num).toInt() : 0;
        final restaurant = (map['restaurant'] ?? '').toString().trim();
        final menuCategory = (map['menuCategory'] ?? '').toString().trim();
        out.add(MealModelV3(
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
          mealType: inferredType,
          price: price,
          restaurant: restaurant.isEmpty ? null : restaurant,
          menuCategory: menuCategory.isEmpty ? null : menuCategory,
        ));
        if (out.length >= limit) break;
      }
      return out;
    } catch (e) {
      debugPrint('[MealServiceV3] getAllMeals error: $e');
      final local = await _mealsFromJsonAsset(mealType: 'lunch', limit: limit); // minimal fallback
      return local;
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
