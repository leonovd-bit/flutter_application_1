import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme_v3.dart';
import '../services/firestore_service_v3.dart';

class CircleOfHealthPageV3 extends StatefulWidget {
  const CircleOfHealthPageV3({super.key});

  @override
  State<CircleOfHealthPageV3> createState() => _CircleOfHealthPageV3State();
}

class _CircleOfHealthPageV3State extends State<CircleOfHealthPageV3> {
  final _auth = FirebaseAuth.instance;
  late final PageController _pageController;
  static const int _daysCount = 14; // today + previous 13 days
  String? _planName;
  bool _loadingHeader = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadHeader();
  }

  Future<void> _loadHeader() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loadingHeader = false);
      return;
    }
    try {
      final name = await FirestoreServiceV3.getDisplayPlanName(user.uid);
      setState(() {
        _planName = (name != null && name.isNotEmpty) ? name : 'Select a Plan';
        _loadingHeader = false;
      });
    } catch (_) {
      setState(() {
  // If loading fails, don't show the old 'Your Plan' text; keep it minimal
  _planName = 'Select a Plan';
        _loadingHeader = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Circle of Health',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            // Add more space at the top as requested
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
            child: _PlanHeader(planName: _loadingHeader ? null : _planName),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              reverse: true, // swipe left -> previous day
              itemCount: _daysCount,
              itemBuilder: (context, index) {
                final date = DateTime.now().subtract(Duration(days: index));
                return _DailyPage(date: date);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final String? planName;
  const _PlanHeader({required this.planName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        planName ?? '…',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _DailyPage extends StatefulWidget {
  final DateTime date;
  const _DailyPage({required this.date});

  @override
  State<_DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<_DailyPage> {
  late Future<_DailyNutrition> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DailyNutrition> _load() async {
    // Try to load Firestore data for the given date; fall back to deterministic demo values.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user');

      final data = await FirestoreServiceV3.getHealthDataForDate(user.uid, widget.date);
      final nutrition = (data?['nutrition'] as Map<String, dynamic>?) ?? const {};

      // Default daily targets (can be refined per plan later)
      const targets = {
        'calories': 2000.0, // kcal
        'protein': 75.0,    // g
        'fats': 70.0,       // g
        'carbs': 260.0,     // g
        'fiber': 28.0,      // g
        'sugar': 50.0,      // g (upper bound)
        'vitaminE': 15.0,   // mg
      };

      double _v(String k) => (nutrition[k] as num?)?.toDouble() ?? 0.0;
      double _pct(double val, double target) => target > 0 ? (val / target).clamp(0.0, 1.0) : 0.0;

      if (nutrition.isNotEmpty) {
        return _DailyNutrition(
          calories: _pct(_v('calories'), targets['calories']!),
          protein: _pct(_v('protein'), targets['protein']!),
          fats: _pct(_v('fats'), targets['fats']!),
          carbs: _pct(_v('carbs'), targets['carbs']!),
          fiber: _pct(_v('fiber'), targets['fiber']!),
          sugar: _pct(_v('sugar'), targets['sugar']!),
          vitaminE: _pct(_v('vitaminE'), targets['vitaminE']!),
        );
      }
    } catch (_) {
      // Ignore and fall back to demo values below
    }

    // Placeholder deterministic data
    final w = widget.date.weekday; // 1..7
    double pct(int base) => (base + (w * 7) % 30) / 100.0;
    return _DailyNutrition(
      calories: pct(55),
      protein: pct(60),
      fats: pct(50),
      carbs: pct(65),
      fiber: pct(58),
      sugar: pct(70),
      vitaminE: pct(52),
    );
  }

  String _weekday(DateTime d) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weekday(d), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Center(child: _MealChip(icon: Icons.free_breakfast, label: 'Breakfast'))),
                    SizedBox(width: 12),
                    Expanded(child: Center(child: _MealChip(icon: Icons.lunch_dining, label: 'Lunch'))),
                    SizedBox(width: 12),
                    Expanded(child: Center(child: _MealChip(icon: Icons.dinner_dining, label: 'Dinner'))),
                  ],
                ),
              ],
            ),
          ),

      const SizedBox(height: 100),
          const _SectionTitle('Daily Tracker'),

          FutureBuilder<_DailyNutrition>(
            future: _future,
            builder: (context, snap) {
              final n = snap.data;
              return Column(
                children: [
                  _MetricBar(label: 'Calorie Progress', value: n?.calories ?? 0, icon: Icons.local_fire_department, color: Colors.orange),
                  _MetricBar(label: 'Protein Progress', value: n?.protein ?? 0, icon: Icons.fitness_center, color: AppThemeV3.primaryGreen),
                  _MetricBar(label: 'Fats Progress', value: n?.fats ?? 0, icon: Icons.water_drop, color: Colors.amber),
                  _MetricBar(label: 'Carbs Progress', value: n?.carbs ?? 0, icon: Icons.grain, color: Colors.teal),
                  _MetricBar(label: 'Fibers Progress', value: n?.fiber ?? 0, icon: Icons.eco, color: Colors.green),
                  _MetricBar(label: 'Sugar Progress', value: n?.sugar ?? 0, icon: Icons.icecream, color: Colors.pinkAccent),
                  _MetricBar(label: 'Vitamin E', value: n?.vitaminE ?? 0, icon: Icons.medical_information_outlined, color: Colors.deepPurple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MealChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppThemeV3.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppThemeV3.primaryGreen),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final IconData icon;
  final Color color;
  const _MetricBar({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(value.clamp(0, 1) * 100).round()}%', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(width: 6),
                  Icon(icon, size: 18, color: Colors.black54),
                ],
              ),
            ],
          ),
      const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
        minHeight: 14,
              value: value.clamp(0, 1),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyNutrition {
  final double calories;
  final double protein;
  final double fats;
  final double carbs;
  final double fiber;
  final double sugar;
  final double vitaminE;

  _DailyNutrition({
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.fiber,
    required this.sugar,
    required this.vitaminE,
  });
}
