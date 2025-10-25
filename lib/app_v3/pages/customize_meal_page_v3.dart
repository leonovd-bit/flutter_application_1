import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../models/customization_model_v3.dart';

class CustomizeMealPageV3 extends StatefulWidget {
  final MealModelV3 baseMeal; // Custom base item

  const CustomizeMealPageV3({super.key, required this.baseMeal});

  @override
  State<CustomizeMealPageV3> createState() => _CustomizeMealPageV3State();
}

class _CustomizeMealPageV3State extends State<CustomizeMealPageV3> {
  late final CustomizationConfig _config;
  late Set<String> _selected; // stores compound ids as groupId:optionId

  @override
  void initState() {
    super.initState();
    final basePrice = widget.baseMeal.price > 0 ? widget.baseMeal.price : 12.99;
    _config = CustomizationRegistry.forMealName(
      mealName: widget.baseMeal.name,
      restaurant: widget.baseMeal.restaurant,
      basePrice: basePrice,
    );
    _selected = _defaultSelected();
  }

  Set<String> _defaultSelected() {
    final s = <String>{};
    for (final g in _config.groups) {
      // No implicit defaults unless marked isDefault
      for (final o in g.options) {
        if (o.isDefault) s.add('${g.id}:${o.id}');
      }
    }
    return s;
  }

  double get _price => _config.computePrice(_selected);

  bool _isSelected(String gid, String oid) => _selected.contains('$gid:$oid');

  void _toggle(String gid, String oid, int max) {
    final key = '$gid:$oid';
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        // enforce group max
        final inGroup = _selected.where((e) => e.startsWith('$gid:')).toList();
        if (inGroup.length >= max) {
          // remove oldest selection in that group
          _selected.remove(inGroup.first);
        }
        _selected.add(key);
      }
    });
  }

  bool _validateRequired() {
    for (final g in _config.groups) {
      if (g.required) {
        final count = _selected.where((e) => e.startsWith('${g.id}:')).length;
        if (count < g.min || count == 0) return false;
      }
    }
    return true;
  }

  void _confirm() {
    if (!_validateRequired()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required selections.')),
      );
      return;
    }

    // Build a user-friendly name and description outline
    final parts = <String>[];
    String? protein;
    String? dressing;
    for (final g in _config.groups) {
      final sel = g.options.where((o) => _isSelected(g.id, o.id)).toList();
      if (sel.isEmpty) continue;
      if (g.id == 'protein') protein = sel.first.name;
      if (g.id == 'dressing') dressing = sel.first.name;
      parts.add('${g.title}: ${sel.map((o) => o.name).join(', ')}');
    }
    final nameSuffix = [protein, dressing].where((e) => e != null).map((e) => e!).join(', ');
    
    // Estimate macros based on selections
    final macros = _estimateMacros();
    
    final customized = MealModelV3(
      id: widget.baseMeal.id, // keep same id for schedule; details differ in name/description
      name: widget.baseMeal.name + (nameSuffix.isNotEmpty ? ' • $nameSuffix' : ''),
      description: parts.join(' | '),
      calories: macros['calories']!,
      protein: macros['protein']!,
      carbs: macros['carbs']!,
      fat: macros['fat']!,
      ingredients: const [],
      allergens: widget.baseMeal.allergens,
      icon: widget.baseMeal.icon,
      imageUrl: widget.baseMeal.imageUrl,
      mealType: widget.baseMeal.mealType,
      price: _price,
      restaurant: widget.baseMeal.restaurant,
      menuCategory: 'custom',
    );

    Navigator.pop(context, customized);
  }

  // Estimate macros based on selected options
  Map<String, int> _estimateMacros() {
    int calories = 0;
    int protein = 0;
    int carbs = 0;
    int fat = 0;

    for (final g in _config.groups) {
      final sel = g.options.where((o) => _isSelected(g.id, o.id)).toList();
      for (final opt in sel) {
        final macros = _getMacrosForOption(g.id, opt.id, opt.name);
        calories += macros['calories']!;
        protein += macros['protein']!;
        carbs += macros['carbs']!;
        fat += macros['fat']!;
      }
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  // Macro database for common ingredients
  Map<String, int> _getMacrosForOption(String groupId, String optionId, String optionName) {
    final name = optionName.toLowerCase();
    
    // Proteins
    if (groupId == 'protein') {
      if (name.contains('chicken')) return {'calories': 165, 'protein': 31, 'carbs': 0, 'fat': 4};
      if (name.contains('tofu')) return {'calories': 80, 'protein': 8, 'carbs': 2, 'fat': 5};
      if (name.contains('shrimp')) return {'calories': 100, 'protein': 24, 'carbs': 0, 'fat': 1};
      if (name.contains('salmon')) return {'calories': 180, 'protein': 25, 'carbs': 0, 'fat': 8};
      if (name.contains('steak') || name.contains('beef')) return {'calories': 210, 'protein': 26, 'carbs': 0, 'fat': 11};
      if (name.contains('pork')) return {'calories': 190, 'protein': 25, 'carbs': 0, 'fat': 9};
      if (name.contains('turkey')) return {'calories': 135, 'protein': 30, 'carbs': 0, 'fat': 1};
      if (name.contains('egg')) return {'calories': 70, 'protein': 6, 'carbs': 1, 'fat': 5};
    }
    
    // Grains/Bases
    if (groupId == 'grains' || groupId == 'grain') {
      if (name.contains('quinoa')) return {'calories': 120, 'protein': 4, 'carbs': 21, 'fat': 2};
      if (name.contains('rice')) return {'calories': 110, 'protein': 2, 'carbs': 24, 'fat': 0};
      if (name.contains('farro')) return {'calories': 100, 'protein': 3, 'carbs': 20, 'fat': 1};
      if (name.contains('pasta')) return {'calories': 130, 'protein': 5, 'carbs': 25, 'fat': 1};
    }
    
    // Greens (very low cal)
    if (groupId == 'greens') {
      return {'calories': 10, 'protein': 1, 'carbs': 2, 'fat': 0};
    }
    
    // Veggies
    if (groupId == 'veggies' || groupId == 'cold_veggies' || groupId == 'warm_toppings' || groupId == 'add_ins' || groupId == 'fillings') {
      if (name.contains('avocado')) return {'calories': 80, 'protein': 1, 'carbs': 4, 'fat': 7};
      if (name.contains('corn')) return {'calories': 30, 'protein': 1, 'carbs': 7, 'fat': 0};
      if (name.contains('beans')) return {'calories': 40, 'protein': 3, 'carbs': 7, 'fat': 0};
      if (name.contains('sweet potato')) return {'calories': 50, 'protein': 1, 'carbs': 12, 'fat': 0};
      // Most other veggies
      return {'calories': 15, 'protein': 1, 'carbs': 3, 'fat': 0};
    }
    
    // Toppings
    if (groupId == 'toppings') {
      if (name.contains('avocado')) return {'calories': 80, 'protein': 1, 'carbs': 4, 'fat': 7};
      if (name.contains('egg')) return {'calories': 70, 'protein': 6, 'carbs': 1, 'fat': 5};
      if (name.contains('cheese')) return {'calories': 50, 'protein': 3, 'carbs': 1, 'fat': 4};
      if (name.contains('nut')) return {'calories': 80, 'protein': 3, 'carbs': 3, 'fat': 7};
      if (name.contains('seed')) return {'calories': 50, 'protein': 2, 'carbs': 2, 'fat': 4};
      if (name.contains('crouton')) return {'calories': 30, 'protein': 1, 'carbs': 5, 'fat': 1};
    }
    
    // Cheese
    if (groupId == 'cheese') {
      return {'calories': 50, 'protein': 3, 'carbs': 1, 'fat': 4};
    }
    
    // Dressings/Sauces
    if (groupId == 'dressing' || groupId == 'sauce' || groupId == 'salsa') {
      if (name.contains('ranch')) return {'calories': 70, 'protein': 0, 'carbs': 2, 'fat': 7};
      if (name.contains('caesar')) return {'calories': 80, 'protein': 1, 'carbs': 1, 'fat': 8};
      if (name.contains('balsamic')) return {'calories': 45, 'protein': 0, 'carbs': 3, 'fat': 4};
      if (name.contains('sesame')) return {'calories': 60, 'protein': 1, 'carbs': 4, 'fat': 5};
      if (name.contains('tahini')) return {'calories': 70, 'protein': 2, 'carbs': 3, 'fat': 6};
      if (name.contains('chipotle')) return {'calories': 50, 'protein': 0, 'carbs': 2, 'fat': 5};
      if (name.contains('aioli') || name.contains('mayo')) return {'calories': 60, 'protein': 0, 'carbs': 1, 'fat': 7};
      // Light sauces
      return {'calories': 30, 'protein': 0, 'carbs': 3, 'fat': 2};
    }
    
    // Tortilla/Bread
    if (groupId == 'tortilla' || groupId == 'bagel') {
      return {'calories': 140, 'protein': 4, 'carbs': 24, 'fat': 3};
    }
    
    // Broth (pho, soup)
    if (groupId == 'broth') {
      return {'calories': 30, 'protein': 2, 'carbs': 4, 'fat': 1};
    }
    
    // Herbs/Pickles (minimal)
    if (groupId == 'herbs' || groupId == 'pickles') {
      return {'calories': 5, 'protein': 0, 'carbs': 1, 'fat': 0};
    }
    
    // Extras
    if (groupId == 'extras') {
      if (name.contains('double protein')) return {'calories': 165, 'protein': 31, 'carbs': 0, 'fat': 4};
      if (name.contains('bread')) return {'calories': 80, 'protein': 2, 'carbs': 15, 'fat': 1};
    }
    
    // Default fallback for unknown items
    return {'calories': 20, 'protein': 1, 'carbs': 3, 'fat': 0};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: Text('Customize ${widget.baseMeal.name}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeV3.surface,
            border: Border(top: BorderSide(color: AppThemeV3.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: \$${_price.toStringAsFixed(2)}',
                  style: AppThemeV3.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Explain nutrition behavior for custom
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeV3.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppThemeV3.border),
            ),
            child: Text(
              'Nutrition is estimated after selection. Allergens shown on base apply; confirm with kitchen if unsure.',
              style: AppThemeV3.textTheme.bodyMedium?.copyWith(color: AppThemeV3.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          for (final g in _config.groups) _buildGroup(g),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGroup(CustomOptionGroup g) {
    final selectedCount = _selected.where((e) => e.startsWith('${g.id}:')).length;
    final cap = g.max == 1 ? '' : ' ($selectedCount/${g.max})';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeV3.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV3.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    g.title + cap,
                    style: AppThemeV3.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (g.required)
                  Text('Required', style: AppThemeV3.textTheme.labelMedium?.copyWith(color: Colors.red[700])),
              ],
            ),
          ),
          const Divider(height: 1),
          ...g.options.map((o) => _buildOptionTile(g, o)).toList(),
        ],
      ),
    );
  }

  Widget _buildOptionTile(CustomOptionGroup g, CustomOption o) {
    final isOn = _isSelected(g.id, o.id);
    return InkWell(
      onTap: () => _toggle(g.id, o.id, g.max),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (g.max == 1)
              Icon(isOn ? Icons.radio_button_checked : Icons.radio_button_unchecked)
            else
              Icon(isOn ? Icons.check_box : Icons.check_box_outline_blank),
            const SizedBox(width: 12),
            Expanded(
              child: Text(o.name, style: AppThemeV3.textTheme.bodyLarge),
            ),
            if (o.priceAdder > 0)
              Text('+\$${o.priceAdder.toStringAsFixed(2)}', style: AppThemeV3.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
