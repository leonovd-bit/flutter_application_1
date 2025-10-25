import 'package:flutter/foundation.dart';

class CustomOption {
  final String id;
  final String name;
  final double priceAdder; // additional cost when selected
  final bool isDefault;

  const CustomOption({
    required this.id,
    required this.name,
    this.priceAdder = 0.0,
    this.isDefault = false,
  });
}

class CustomOptionGroup {
  final String id;
  final String title;
  final int min;
  final int max; // use 1 for radio-style groups; >1 for multi-select
  final bool required;
  final List<CustomOption> options;

  const CustomOptionGroup({
    required this.id,
    required this.title,
    this.min = 0,
    this.max = 1,
    this.required = false,
    required this.options,
  });
}

class CustomizationConfig {
  final List<CustomOptionGroup> groups;
  final double basePrice;

  const CustomizationConfig({
    required this.groups,
    required this.basePrice,
  });

  double computePrice(Set<String> selectedOptionIds) {
    double price = basePrice;
    for (final g in groups) {
      for (final o in g.options) {
        if (selectedOptionIds.contains('${g.id}:${o.id}')) {
          price += o.priceAdder;
        }
      }
    }
    return price;
  }
}

// Default Greenblend customization groups
class GreenblendDefaults {
  static CustomizationConfig config({double basePrice = 12.99}) {
    return CustomizationConfig(
      basePrice: basePrice,
      groups: [
        const CustomOptionGroup(
          id: 'greens',
          title: 'Base Greens',
          min: 1,
          max: 1,
          required: true,
          options: [
            CustomOption(id: 'spring_mix', name: 'Spring Mix'),
            CustomOption(id: 'kale', name: 'Kale'),
            CustomOption(id: 'romaine', name: 'Romaine'),
            CustomOption(id: 'spinach', name: 'Spinach'),
          ],
        ),
        const CustomOptionGroup(
          id: 'grains',
          title: 'Grain Base (optional)',
          min: 0,
          max: 1,
          required: false,
          options: [
            CustomOption(id: 'quinoa', name: 'Quinoa'),
            CustomOption(id: 'brown_rice', name: 'Brown Rice'),
            CustomOption(id: 'farro', name: 'Farro'),
          ],
        ),
        const CustomOptionGroup(
          id: 'protein',
          title: 'Protein',
          min: 1,
          max: 1,
          required: true,
          options: [
            CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
            CustomOption(id: 'tofu', name: 'Tofu'),
            CustomOption(id: 'shrimp', name: 'Shrimp', priceAdder: 3.0),
            CustomOption(id: 'salmon', name: 'Salmon', priceAdder: 4.0),
            CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
          ],
        ),
        const CustomOptionGroup(
          id: 'veggies',
          title: 'Veggies (choose up to 4)',
          min: 0,
          max: 4,
          options: [
            CustomOption(id: 'tomato', name: 'Tomato'),
            CustomOption(id: 'cucumber', name: 'Cucumber'),
            CustomOption(id: 'corn', name: 'Corn'),
            CustomOption(id: 'carrot', name: 'Carrot'),
            CustomOption(id: 'onion', name: 'Red Onion'),
            CustomOption(id: 'pepper', name: 'Bell Pepper'),
            CustomOption(id: 'edamame', name: 'Edamame'),
            CustomOption(id: 'mushroom', name: 'Mushroom'),
          ],
        ),
        const CustomOptionGroup(
          id: 'toppings',
          title: 'Toppings (choose up to 3)',
          min: 0,
          max: 3,
          options: [
            CustomOption(id: 'avocado', name: 'Avocado', priceAdder: 1.5),
            CustomOption(id: 'egg', name: 'Boiled Egg', priceAdder: 1.0),
            CustomOption(id: 'cheese', name: 'Feta Cheese', priceAdder: 1.0),
            CustomOption(id: 'nuts', name: 'Mixed Nuts', priceAdder: 1.0),
            CustomOption(id: 'seeds', name: 'Seeds'),
            CustomOption(id: 'croutons', name: 'Croutons'),
          ],
        ),
        const CustomOptionGroup(
          id: 'dressing',
          title: 'Dressing',
          min: 1,
          max: 1,
          required: true,
          options: [
            CustomOption(id: 'balsamic', name: 'Balsamic Vinaigrette'),
            CustomOption(id: 'caesar', name: 'Caesar'),
            CustomOption(id: 'ranch', name: 'Ranch'),
            CustomOption(id: 'sesame', name: 'Sesame Ginger'),
            CustomOption(id: 'green_goddess', name: 'Green Goddess'),
          ],
        ),
        const CustomOptionGroup(
          id: 'extras',
          title: 'Extras',
          min: 0,
          max: 2,
          options: [
            CustomOption(id: 'double_protein', name: 'Double Protein', priceAdder: 3.0),
            CustomOption(id: 'side_bread', name: 'Side Bread', priceAdder: 1.0),
          ],
        ),
      ],
    );
  }
}

/// Registry of per-meal customization configurations.
/// Returns a tailored CustomizationConfig based on meal name/restaurant.
class CustomizationRegistry {
  static CustomizationConfig forMealName(
      {required String mealName, String? restaurant, double basePrice = 12.99}) {
    final name = mealName.toLowerCase();
    final brand = (restaurant ?? '').toLowerCase();

    // Greenblend customs
    if (brand.contains('greenblend')) {
      if (name.contains('salad')) return _greenblendSalad(basePrice);
      if (name.contains('grain') && name.contains('bowl')) {
        return _greenblendGrainBowl(basePrice);
      }
      if (name.contains('wrap')) return _greenblendWrap(basePrice);
      if (name.contains('quesadilla')) return _greenblendQuesadilla(basePrice);
      if (name.contains('burrito')) return _greenblendBurrito(basePrice);
      // Fallback to generic Greenblend builder
      return GreenblendDefaults.config(basePrice: basePrice);
    }

    // Sen Saigon (example variants)
    if (brand.contains('sen saigon') || brand.contains('saigon')) {
      if (name.contains('pho')) return _saigonPho(basePrice);
      if (name.contains('banh mi')) return _saigonBanhMi(basePrice);
      if (name.contains('vermicelli') || name.contains('bun')) {
        return _saigonVermicelli(basePrice);
      }
      // default Vietnamese bowl config
      return _saigonVermicelli(basePrice);
    }

    // Unknown brand/name: use sensible default
    return GreenblendDefaults.config(basePrice: basePrice);
  }

  // ---- Greenblend variants ----
  static CustomizationConfig _greenblendSalad(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'greens',
        title: 'Base Greens',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'spring_mix', name: 'Spring Mix'),
          CustomOption(id: 'kale', name: 'Kale'),
          CustomOption(id: 'romaine', name: 'Romaine'),
          CustomOption(id: 'spinach', name: 'Spinach'),
        ],
      ),
      CustomOptionGroup(
        id: 'grains',
        title: 'Grain Base (optional)',
        min: 0,
        max: 1,
        options: [
          CustomOption(id: 'quinoa', name: 'Quinoa'),
          CustomOption(id: 'brown_rice', name: 'Brown Rice'),
          CustomOption(id: 'farro', name: 'Farro'),
        ],
      ),
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
          CustomOption(id: 'tofu', name: 'Tofu'),
          CustomOption(id: 'shrimp', name: 'Shrimp', priceAdder: 3.0),
          CustomOption(id: 'salmon', name: 'Salmon', priceAdder: 4.0),
          CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
        ],
      ),
      CustomOptionGroup(
        id: 'veggies',
        title: 'Veggies (choose up to 4)',
        min: 0,
        max: 4,
        options: [
          CustomOption(id: 'tomato', name: 'Tomato'),
          CustomOption(id: 'cucumber', name: 'Cucumber'),
          CustomOption(id: 'corn', name: 'Corn'),
          CustomOption(id: 'carrot', name: 'Carrot'),
          CustomOption(id: 'onion', name: 'Red Onion'),
          CustomOption(id: 'pepper', name: 'Bell Pepper'),
          CustomOption(id: 'edamame', name: 'Edamame'),
          CustomOption(id: 'mushroom', name: 'Mushroom'),
        ],
      ),
      CustomOptionGroup(
        id: 'toppings',
        title: 'Toppings (choose up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'avocado', name: 'Avocado', priceAdder: 1.5),
          CustomOption(id: 'egg', name: 'Boiled Egg', priceAdder: 1.0),
          CustomOption(id: 'cheese', name: 'Feta Cheese', priceAdder: 1.0),
          CustomOption(id: 'nuts', name: 'Mixed Nuts', priceAdder: 1.0),
          CustomOption(id: 'seeds', name: 'Seeds'),
          CustomOption(id: 'croutons', name: 'Croutons'),
        ],
      ),
      CustomOptionGroup(
        id: 'dressing',
        title: 'Dressing',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'balsamic', name: 'Balsamic Vinaigrette'),
          CustomOption(id: 'caesar', name: 'Caesar'),
          CustomOption(id: 'ranch', name: 'Ranch'),
          CustomOption(id: 'sesame', name: 'Sesame Ginger'),
          CustomOption(id: 'green_goddess', name: 'Green Goddess'),
        ],
      ),
      CustomOptionGroup(
        id: 'extras',
        title: 'Extras',
        min: 0,
        max: 2,
        options: [
          CustomOption(id: 'double_protein', name: 'Double Protein', priceAdder: 3.0),
          CustomOption(id: 'side_bread', name: 'Side Bread', priceAdder: 1.0),
        ],
      ),
    ]);
  }

  static CustomizationConfig _greenblendGrainBowl(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'grains',
        title: 'Grain Base',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'brown_rice', name: 'Brown Rice'),
          CustomOption(id: 'quinoa', name: 'Quinoa'),
          CustomOption(id: 'farro', name: 'Farro'),
        ],
      ),
      CustomOptionGroup(
        id: 'greens',
        title: 'Add Greens (optional)',
        min: 0,
        max: 1,
        options: [
          CustomOption(id: 'spring_mix', name: 'Spring Mix'),
          CustomOption(id: 'kale', name: 'Kale'),
          CustomOption(id: 'spinach', name: 'Spinach'),
        ],
      ),
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
          CustomOption(id: 'tofu', name: 'Tofu'),
          CustomOption(id: 'shrimp', name: 'Shrimp', priceAdder: 3.0),
          CustomOption(id: 'salmon', name: 'Salmon', priceAdder: 4.0),
          CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
        ],
      ),
      CustomOptionGroup(
        id: 'warm_toppings',
        title: 'Warm Toppings (up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'roasted_sweet_potato', name: 'Roasted Sweet Potato'),
          CustomOption(id: 'broccoli', name: 'Broccoli'),
          CustomOption(id: 'brussels', name: 'Brussels Sprouts'),
          CustomOption(id: 'sauteed_mushroom', name: 'Sautéed Mushroom'),
          CustomOption(id: 'zucchini', name: 'Zucchini'),
        ],
      ),
      CustomOptionGroup(
        id: 'cold_veggies',
        title: 'Cold Veggies (up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'tomato', name: 'Tomato'),
          CustomOption(id: 'corn', name: 'Corn'),
          CustomOption(id: 'cucumber', name: 'Cucumber'),
          CustomOption(id: 'onion', name: 'Red Onion'),
        ],
      ),
      CustomOptionGroup(
        id: 'sauce',
        title: 'Sauce',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'garlic_aioli', name: 'Garlic Aioli'),
          CustomOption(id: 'chipotle', name: 'Chipotle Lime'),
          CustomOption(id: 'tahini', name: 'Lemon Tahini'),
          CustomOption(id: 'sesame', name: 'Sesame Ginger'),
        ],
      ),
      CustomOptionGroup(
        id: 'extras',
        title: 'Extras',
        min: 0,
        max: 2,
        options: [
          CustomOption(id: 'avocado', name: 'Avocado', priceAdder: 1.5),
          CustomOption(id: 'egg', name: 'Egg', priceAdder: 1.0),
        ],
      ),
    ]);
  }

  static CustomizationConfig _greenblendWrap(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'tortilla',
        title: 'Tortilla',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'flour', name: 'Flour'),
          CustomOption(id: 'whole_wheat', name: 'Whole Wheat'),
          CustomOption(id: 'spinach', name: 'Spinach Wrap'),
        ],
      ),
      CustomOptionGroup(
        id: 'greens',
        title: 'Greens',
        min: 0,
        max: 1,
        options: [
          CustomOption(id: 'romaine', name: 'Romaine'),
          CustomOption(id: 'spring_mix', name: 'Spring Mix'),
        ],
      ),
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
          CustomOption(id: 'tofu', name: 'Tofu'),
          CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
        ],
      ),
      CustomOptionGroup(
        id: 'veggies',
        title: 'Veggies (up to 4)',
        min: 0,
        max: 4,
        options: [
          CustomOption(id: 'tomato', name: 'Tomato'),
          CustomOption(id: 'onion', name: 'Red Onion'),
          CustomOption(id: 'pepper', name: 'Bell Pepper'),
          CustomOption(id: 'cucumber', name: 'Cucumber'),
          CustomOption(id: 'spinach', name: 'Spinach'),
        ],
      ),
      CustomOptionGroup(
        id: 'sauce',
        title: 'Sauce',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'ranch', name: 'Ranch'),
          CustomOption(id: 'chipotle', name: 'Chipotle Lime'),
          CustomOption(id: 'tahini', name: 'Tahini'),
        ],
      ),
      CustomOptionGroup(
        id: 'cheese',
        title: 'Cheese (optional)',
        min: 0,
        max: 1,
        options: [
          CustomOption(id: 'cheddar', name: 'Cheddar'),
          CustomOption(id: 'feta', name: 'Feta'),
          CustomOption(id: 'no_cheese', name: 'No Cheese'),
        ],
      ),
    ]);
  }

  static CustomizationConfig _greenblendQuesadilla(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
          CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
          CustomOption(id: 'veggie', name: 'Veggie'),
        ],
      ),
      CustomOptionGroup(
        id: 'cheese',
        title: 'Cheese',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'cheddar', name: 'Cheddar'),
          CustomOption(id: 'jack', name: 'Monterey Jack'),
        ],
      ),
      CustomOptionGroup(
        id: 'fillings',
        title: 'Fillings (up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'pepper', name: 'Bell Pepper'),
          CustomOption(id: 'onion', name: 'Onion'),
          CustomOption(id: 'corn', name: 'Corn'),
          CustomOption(id: 'mushroom', name: 'Mushroom'),
        ],
      ),
      CustomOptionGroup(
        id: 'salsa',
        title: 'Salsa',
        min: 0,
        max: 1,
        options: [
          CustomOption(id: 'mild', name: 'Mild Salsa'),
          CustomOption(id: 'spicy', name: 'Spicy Salsa'),
        ],
      ),
    ]);
  }

  static CustomizationConfig _greenblendBurrito(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'tortilla',
        title: 'Tortilla',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'flour', name: 'Flour'),
          CustomOption(id: 'whole_wheat', name: 'Whole Wheat'),
        ],
      ),
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'chicken', name: 'Grilled Chicken', priceAdder: 2.0),
          CustomOption(id: 'steak', name: 'Steak', priceAdder: 4.0),
          CustomOption(id: 'tofu', name: 'Tofu'),
        ],
      ),
      CustomOptionGroup(
        id: 'fillings',
        title: 'Fillings (up to 4)',
        min: 0,
        max: 4,
        options: [
          CustomOption(id: 'brown_rice', name: 'Brown Rice'),
          CustomOption(id: 'black_beans', name: 'Black Beans'),
          CustomOption(id: 'corn', name: 'Corn'),
          CustomOption(id: 'onion', name: 'Onion'),
          CustomOption(id: 'pepper', name: 'Bell Pepper'),
          CustomOption(id: 'lettuce', name: 'Lettuce'),
        ],
      ),
      CustomOptionGroup(
        id: 'sauce',
        title: 'Sauce',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'sour_cream', name: 'Sour Cream'),
          CustomOption(id: 'chipotle', name: 'Chipotle'),
          CustomOption(id: 'salsa', name: 'Salsa'),
        ],
      ),
    ]);
  }

  // ---- Sen Saigon variants (simple examples) ----
  static CustomizationConfig _saigonPho(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'broth',
        title: 'Broth',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'beef', name: 'Beef Broth'),
          CustomOption(id: 'chicken', name: 'Chicken Broth'),
          CustomOption(id: 'veggie', name: 'Vegetable Broth'),
        ],
      ),
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'beef', name: 'Beef'),
          CustomOption(id: 'chicken', name: 'Chicken'),
          CustomOption(id: 'tofu', name: 'Tofu'),
        ],
      ),
      CustomOptionGroup(
        id: 'add_ins',
        title: 'Add-ins (up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'bean_sprout', name: 'Bean Sprouts'),
          CustomOption(id: 'jalapeno', name: 'Jalapeño'),
          CustomOption(id: 'onion', name: 'Onion'),
          CustomOption(id: 'basil', name: 'Thai Basil'),
        ],
      ),
    ]);
  }

  static CustomizationConfig _saigonBanhMi(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'grilled_pork', name: 'Grilled Pork'),
          CustomOption(id: 'chicken', name: 'Chicken'),
          CustomOption(id: 'tofu', name: 'Tofu'),
        ],
      ),
      CustomOptionGroup(
        id: 'pickles',
        title: 'Pickled Veggies',
        min: 0,
        max: 2,
        options: [
          CustomOption(id: 'daikon', name: 'Daikon'),
          CustomOption(id: 'carrot', name: 'Carrot'),
        ],
      ),
      CustomOptionGroup(
        id: 'sauce',
        title: 'Sauce',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'mayo', name: 'Mayo'),
          CustomOption(id: 'sriracha', name: 'Sriracha'),
          CustomOption(id: 'house', name: 'House Sauce'),
        ],
      ),
    ]);
  }

  static CustomizationConfig _saigonVermicelli(double basePrice) {
    return CustomizationConfig(basePrice: basePrice, groups: const [
      CustomOptionGroup(
        id: 'protein',
        title: 'Protein',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'grilled_pork', name: 'Grilled Pork'),
          CustomOption(id: 'chicken', name: 'Chicken'),
          CustomOption(id: 'shrimp', name: 'Shrimp', priceAdder: 3.0),
          CustomOption(id: 'tofu', name: 'Tofu'),
        ],
      ),
      CustomOptionGroup(
        id: 'herbs',
        title: 'Herbs (up to 3)',
        min: 0,
        max: 3,
        options: [
          CustomOption(id: 'basil', name: 'Thai Basil'),
          CustomOption(id: 'mint', name: 'Mint'),
          CustomOption(id: 'cilantro', name: 'Cilantro'),
        ],
      ),
      CustomOptionGroup(
        id: 'sauce',
        title: 'Sauce',
        min: 1,
        max: 1,
        required: true,
        options: [
          CustomOption(id: 'nuoc_cham', name: 'Nuoc Cham'),
          CustomOption(id: 'peanut', name: 'Peanut Sauce'),
        ],
      ),
    ]);
  }
}
