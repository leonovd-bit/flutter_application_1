import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service_v3.dart';
import '../services/simple_google_maps_service.dart';
import '../services/order_notification_service.dart';
import '../theme/app_theme_v3.dart';
import '../models/meal_model_v3.dart';
import '../widgets/simple_address_input_widget.dart';
import 'meal_schedule_page_v3_fixed.dart';
import 'address_page_v3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'manage_subscription_page_v3.dart';
import 'choose_meal_plan_page_v3.dart';

class DeliverySchedulePageV4 extends StatefulWidget {
  final String? initialScheduleName;
  final bool isSignupFlow;
  const DeliverySchedulePageV4({
    super.key, 
    this.initialScheduleName,
    this.isSignupFlow = false,
  });

  @override
  State<DeliverySchedulePageV4> createState() => _DeliverySchedulePageV4State();
}

class _DeliverySchedulePageV4State extends State<DeliverySchedulePageV4> {
  // Basic setup
  MealPlanModelV3? _selectedMealPlan;
  String _scheduleName = '';
  final TextEditingController _scheduleNameController = TextEditingController();
  // Meal type selection (for plans with 1 or 2 meals/day)
  final List<String> _mealOptions = const ['Breakfast', 'Lunch', 'Dinner'];
  final Set<String> _selectedMealTypes = <String>{};
  
  // Days and meal types
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  // Selected days for configuration
  Set<String> _selectedDays = {};
  
  // Day configurations: Map<Day, Map<MealType, {time, address}>>
  Map<String, Map<String, Map<String, dynamic>>> _dayConfigurations = {};
  
  // Saved addresses - start empty; only user-created addresses will appear
  // Each entry: { 'name': <label>, 'address': <full address> }
  List<Map<String, String>> _savedAddresses = [];
  
  // Currently editing day (for individual day configuration)
  String? _editingDay;
  Map<String, TimeOfDay?> _tempMealTimes = {};
  // Temporary per-meal-type address selections while configuring (store full address value)
  Map<String, String?> _tempAddresses = {};

  @override
  void initState() {
    super.initState();
  // No default schedule name; require user input
  _scheduleName = widget.initialScheduleName ?? '';
  _scheduleNameController.text = widget.initialScheduleName ?? '';
  _loadUserAddresses();
  _loadCurrentPlan();
  if ((widget.initialScheduleName ?? '').isNotEmpty) {
    _prefillFromSaved(widget.initialScheduleName!);
  }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh meal plan when page becomes active (e.g., when returning from meal plan selection)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentPlan();
      }
    });
  }

  @override
  void dispose() {
    _scheduleNameController.dispose();
    super.dispose();
  }
  Future<void> _prefillFromSaved(String name) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      final key = uid == null ? 'delivery_schedule_$name' : 'delivery_schedule_${uid}_$name';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final data = json.decode(raw) as Map<String, dynamic>;
      // Resolve meal plan
      try {
        final mealPlanId = (data['mealPlanId'] ?? '').toString();
        if (mealPlanId.isNotEmpty) {
          final plans = MealPlanModelV3.getAvailablePlans();
          final plan = plans.firstWhere((p) => p.id == mealPlanId, orElse: () => plans.first);
          setState(() => _selectedMealPlan = plan);
          if (plan.mealsPerDay >= 3) {
            _selectedMealTypes
              ..clear()
              ..addAll(_mealOptions);
          } else {
            final types = List<String>.from(data['selectedMealTypes'] ?? const <String>[]);
            _selectedMealTypes
              ..clear()
              ..addAll(types);
          }
        }
      } catch (_) {}
      // Weekly schedule -> _dayConfigurations (convert HH:mm to TimeOfDay)
      final weekly = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
      final Map<String, Map<String, Map<String, dynamic>>> rebuilt = {};
      TimeOfDay? _parse(String? hhmm) {
        if (hhmm == null || hhmm.isEmpty) return null;
        final parts = hhmm.split(':');
        if (parts.length != 2) return null;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) return null;
        return TimeOfDay(hour: h, minute: m);
      }
      weekly.forEach((day, mtVal) {
        final mtMap = Map<String, dynamic>.from(mtVal as Map);
        rebuilt[day] = {};
        mtMap.forEach((mt, cfg) {
          final c = Map<String, dynamic>.from(cfg as Map);
          rebuilt[day]![mt] = {
            'time': _parse((c['time'] ?? '').toString()),
            'address': (c['address'] ?? '').toString().trim().isEmpty ? null : (c['address'] ?? '').toString(),
          };
        });
      });
      if (mounted) {
        setState(() {
          _dayConfigurations = rebuilt;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      MealPlanModelV3? plan;
      
      // First check SharedPreferences for onboarding flow
      try {
        final prefs = await SharedPreferences.getInstance();
        final planId = prefs.getString('selected_meal_plan_id');
        if (planId != null && planId.isNotEmpty) {
          final available = MealPlanModelV3.getAvailablePlans();
          plan = available.firstWhere(
            (p) => p.id == planId,
            orElse: () => available.first,
          );
          debugPrint('[DeliverySchedule] Loaded plan from SharedPreferences: ${plan.displayName}');
        }
      } catch (e) {
        debugPrint('[DeliverySchedule] Error loading from SharedPreferences: $e');
      }

      // If not found in SharedPreferences, try Firestore
      if (plan == null) {
        plan = await FirestoreServiceV3.getCurrentMealPlan(uid);
      }

      // 2) Fallback: resolve from active subscription (set up during payment)
      if (plan == null) {
        try {
          final sub = await FirestoreServiceV3.getActiveSubscription(uid);
          final subPlanId = (sub?['mealPlanId'] ?? '').toString().trim();
          final subPlanName = (sub?['planName'] ?? '').toString().trim();
          if (subPlanId.isNotEmpty || subPlanName.isNotEmpty) {
            final available = MealPlanModelV3.getAvailablePlans();
            // Prefer ID match, else match by displayName/name (case-insensitive)
            plan = available.firstWhere(
              (p) => p.id == subPlanId,
              orElse: () {
                final lname = subPlanName.toLowerCase();
                return available.firstWhere(
                  (p) => p.displayName.toLowerCase() == lname || p.name.toLowerCase() == lname,
                  orElse: () => plan ?? available.first,
                );
              },
            );
          }
        } catch (_) {
          debugPrint('[DeliverySchedule] Could not resolve plan from subscription');
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedMealPlan = plan;
        _selectedMealTypes.clear();
        if (plan != null && plan.mealsPerDay >= 3) {
          _selectedMealTypes.addAll(_mealOptions);
        }
      });
      // Persist local plan info for display fallbacks across the app
      try {
        if (plan != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_meal_plan_id', plan.id);
          await prefs.setString('selected_meal_plan_name', plan.name);
          await prefs.setString('selected_meal_plan_display_name', plan.displayName);
        }
      } catch (_) {}
    } catch (_) {
      // Keep silent; plan UI will display a neutral summary without prompting.
    }
  }

  Future<void> _loadUserAddresses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Not signed in; try local fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_addresses') ?? [];
        final deduped = <Map<String, String>>[];
        final seen = <String>{};
        for (final jsonStr in list) {
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final label = (data['label'] ?? 'Address').toString().trim();
            final street = (data['streetAddress'] ?? '').toString().trim();
            final apt = (data['apartment'] ?? '').toString().trim();
            final city = (data['city'] ?? '').toString().trim();
            final state = (data['state'] ?? '').toString().trim();
            final zip = (data['zipCode'] ?? '').toString().trim();
            final full = [
              street,
              if (apt.isNotEmpty) apt,
              if (city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty)
                [city, state].where((s) => s.isNotEmpty).join(', ') + (zip.isNotEmpty ? ' $zip' : ''),
            ].where((s) => s.toString().trim().isNotEmpty).join(', ');
            final addr = full.trim();
            if (addr.isEmpty || seen.contains(addr)) continue;
            seen.add(addr);
            deduped.add({'name': label, 'address': addr});
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
  debugPrint('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from local (not signed in)');
      } catch (_) {
        // No local addresses available
      }
      return;
    }
    try {
      // 1) Attempt lightweight name/address pairs first
      final pairs = await FirestoreServiceV3.getUserAddressPairs(uid);
      final seen = <String>{};
      final deduped = <Map<String, String>>[];
      for (final p in pairs) {
        final addr = (p['address'] ?? '').trim();
        if (addr.isEmpty || seen.contains(addr)) continue;
        seen.add(addr);
        deduped.add({
          'name': (p['name'] ?? 'Address').trim(),
          'address': addr,
        });
      }

      if (deduped.isEmpty) {
        // 2) If no pairs exist yet, read the richer address docs and map to pairs
        try {
          final models = await FirestoreServiceV3.getUserAddresses(uid);
          final seen2 = <String>{};
          final mapped = <Map<String, String>>[];
          for (final a in models) {
            final addr = a.fullAddress.trim();
            if (addr.isEmpty || seen2.contains(addr)) continue;
            seen2.add(addr);
            mapped.add({'name': a.label.trim().isNotEmpty ? a.label.trim() : 'Address', 'address': addr});
          }
          if (mounted) {
            setState(() {
              _savedAddresses = mapped;
            });
          }
          debugPrint('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from Firestore (mapped from models)');
        } catch (e2) {
          debugPrint('[DeliverySchedule] Model fetch failed after empty pairs, falling back to local. Error: $e2');
          throw e2; // fall into the catch to use local
        }
      } else {
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
  debugPrint('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from Firestore (pairs)');
      }
    } catch (e) {
      // Firestore may be blocked by security rules; fall back to local addresses.
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_addresses') ?? [];
        final deduped = <Map<String, String>>[];
        final seen = <String>{};
        for (final jsonStr in list) {
          try {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final label = (data['label'] ?? 'Address').toString().trim();
            final street = (data['streetAddress'] ?? '').toString().trim();
            final apt = (data['apartment'] ?? '').toString().trim();
            final city = (data['city'] ?? '').toString().trim();
            final state = (data['state'] ?? '').toString().trim();
            final zip = (data['zipCode'] ?? '').toString().trim();
            final full = [
              street,
              if (apt.isNotEmpty) apt,
              if (city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty)
                [city, state].where((s) => s.isNotEmpty).join(', ') + (zip.isNotEmpty ? ' $zip' : ''),
            ].where((s) => s.toString().trim().isNotEmpty).join(', ');
            final addr = full.trim();
            if (addr.isEmpty || seen.contains(addr)) continue;
            seen.add(addr);
            deduped.add({'name': label, 'address': addr});
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _savedAddresses = deduped;
          });
        }
  debugPrint('[DeliverySchedule] Loaded ${_savedAddresses.length} addresses from local (fallback). Error: $e');
      } catch (_) {
        // Keep silent; no local addresses available.
      }
    }
  }

  List<String> _getMealTypesForPlan() {
    if (_selectedMealPlan == null) return [];
    final count = _selectedMealPlan!.mealsPerDay;
    if (count >= 3) {
      // All meals when plan has 3 per day
      return List<String>.from(_mealOptions);
    }
    // Use the user's chosen meals (for 1 or 2 per day)
    return _mealOptions.where((m) => _selectedMealTypes.contains(m)).toList();
  }

  bool _isDayConfigured(String day) {
    if (!_dayConfigurations.containsKey(day)) return false;
    
    final dayConfig = _dayConfigurations[day]!;
    final expectedMealTypes = _getMealTypesForPlan();
    
    // Check if all expected meal types have both time and address
    for (String mealType in expectedMealTypes) {
      if (!dayConfig.containsKey(mealType) ||
          dayConfig[mealType]!['time'] == null ||
          dayConfig[mealType]!['address'] == null) {
        return false;
      }
    }
    return true;
  }

  void _startEditingDay(String day) {
    setState(() {
      _editingDay = day;
      _tempMealTimes.clear();
  _tempAddresses.clear();
      
      // Load existing configuration if available
      if (_dayConfigurations.containsKey(day)) {
        final dayConfig = _dayConfigurations[day]!;
        for (String mealType in _getMealTypesForPlan()) {
          if (dayConfig.containsKey(mealType)) {
            _tempMealTimes[mealType] = dayConfig[mealType]!['time'] as TimeOfDay?;
    _tempAddresses[mealType] = dayConfig[mealType]!['address'] as String?;
          }
        }
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingDay = null;
      _tempMealTimes.clear();
  _tempAddresses.clear();
    });
  }

  void _saveCurrentDayConfiguration() {
    if (_editingDay == null) return;
    
    final mealTypes = _getMealTypesForPlan();
    
    // Validate that all meal types have both time and address
    for (String mealType in mealTypes) {
      if (_tempMealTimes[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set time for $mealType')),
        );
        return;
      }
      if (_tempAddresses[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select delivery address for $mealType')),
        );
        return;
      }
    }
    final savedDay = _editingDay!;

    setState(() {
      // Initialize day configuration if not exists
      if (!_dayConfigurations.containsKey(_editingDay!)) {
        _dayConfigurations[_editingDay!] = {};
      }
      
      // Save configuration for each meal type
      for (String mealType in mealTypes) {
        _dayConfigurations[_editingDay!]![mealType] = {
          'time': _tempMealTimes[mealType],
          'address': _tempAddresses[mealType],
        };
      }
      
      _editingDay = null;
      _tempMealTimes.clear();
      _tempAddresses.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration saved for $savedDay!')),
    );
  }

  void _applyToSelectedDays() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select days to configure')),
      );
      return;
    }
    // Validate meal type selection count for 1 or 2 meals/day plans
    final perDay = _selectedMealPlan?.mealsPerDay ?? 0;
    if (perDay > 0 && perDay < 3 && _selectedMealTypes.length != perDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please choose exactly $perDay meal${perDay == 1 ? '' : 's'} above')),
      );
      return;
    }

    final mealTypes = _getMealTypesForPlan();
    
    // Validate that all meal types have both time and address
    for (String mealType in mealTypes) {
      if (_tempMealTimes[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set time for $mealType')),
        );
        return;
      }
      if (_tempAddresses[mealType] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select delivery address for $mealType')),
        );
        return;
      }
    }

    final appliedCount = _selectedDays.length;

    setState(() {
      for (String day in _selectedDays) {
        // Initialize day configuration if not exists
        if (!_dayConfigurations.containsKey(day)) {
          _dayConfigurations[day] = {};
        }
        
        // Save configuration for each meal type
        for (String mealType in mealTypes) {
          _dayConfigurations[day]![mealType] = {
            'time': _tempMealTimes[mealType],
    'address': _tempAddresses[mealType],
          };
        }
      }
      
      _selectedDays.clear();
      _tempMealTimes.clear();
  _tempAddresses.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration applied to $appliedCount day${appliedCount == 1 ? '' : 's'}!')),
    );
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : hour;
    return '$displayHour:$minute $period';
  }

  // Helpers for address dropdown rendering

  /// Enhanced address selection with Google Places autocomplete
  Widget _buildEnhancedAddressSelection(String mealType) {
    final currentAddress = _tempAddresses[mealType];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show saved addresses if any exist
        if (_savedAddresses.isNotEmpty) ...[
          const Text(
            'Choose from saved addresses:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _savedAddresses.length,
              itemBuilder: (context, index) {
                final address = _savedAddresses[index];
                final addressValue = address['address'] ?? '';
                final isSelected = currentAddress == addressValue;
                
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? AppThemeV3.accent.withOpacity(0.1) : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _tempAddresses[mealType] = addressValue;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.location_on,
                                  color: isSelected ? AppThemeV3.accent : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    address['name'] ?? 'Address',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppThemeV3.accent : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                addressValue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppThemeV3.textSecondary,
                                ),
                                overflow: TextOverflow.fade,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
        ],
        
        // Simple address input
        Row(
          children: [
            const Icon(Icons.add_location_alt, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Or add a new address:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddressPageV3()),
                ).then((_) => _loadUserAddresses());
              },
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        SimpleAddressInputWidget(
          hintText: 'Enter delivery address...',
          label: null, // We have our own label above
          onAddressValidated: (addressResult) async {
            // Save the new address and select it
            final newAddress = addressResult.formattedAddress;
            final addressName = _generateAddressName(addressResult);
            
            setState(() {
              _tempAddresses[mealType] = newAddress;
            });
            
            // Save to user's address list
            await _saveNewAddress(addressName, addressResult);
          },
          onTextChanged: (text) {
            // Store text as it's being typed
            setState(() {
              _tempAddresses[mealType] = text;
            });
          },
        ),
      ],
    );
  }
  
  /// Generate a user-friendly name for an address
  String _generateAddressName(AddressResult addressResult) {
    // Try to create a meaningful name from address components
    final city = addressResult.city;
    final formattedAddress = addressResult.formattedAddress;
    
    // Extract street from formatted address
    final parts = formattedAddress.split(',');
    if (parts.isNotEmpty) {
      final streetPart = parts.first.trim();
      if (streetPart.isNotEmpty && !streetPart.toLowerCase().contains('unnamed')) {
        return streetPart;
      }
    }
    
    if (city.isNotEmpty) {
      return '$city Address';
    }
    
    return 'New Address';
  }
  
  /// Save a new address from Simple Google Maps
  Future<void> _saveNewAddress(String name, AddressResult addressResult) async {
    try {
      // Add to local list immediately
      final newAddressMap = {
        'name': name,
        'address': addressResult.formattedAddress,
      };
      
      if (!_savedAddresses.any((a) => a['address'] == addressResult.formattedAddress)) {
        setState(() {
          _savedAddresses.add(newAddressMap);
        });
      }
      
      // Save to Firestore if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Create AddressModelV3 from Simple Google Maps data
        final addressModel = AddressModelV3(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          label: name,
          streetAddress: addressResult.formattedAddress,
          apartment: '', // User can edit this later if needed
          city: addressResult.city,
          state: addressResult.state,
          zipCode: addressResult.zipCode,
          isDefault: _savedAddresses.length == 1, // First address is default
          createdAt: DateTime.now(),
        );
        
        await FirestoreServiceV3.saveAddress(addressModel);
      } else {
        // Save to SharedPreferences for unauthenticated users
        final prefs = await SharedPreferences.getInstance();
        final existingList = prefs.getStringList('user_addresses') ?? [];
        existingList.add(json.encode(newAddressMap));
        await prefs.setStringList('user_addresses', existingList);
      }
      
      debugPrint('[DeliverySchedule] Saved new address: $name');
    } catch (e) {
      debugPrint('[DeliverySchedule] Error saving address: $e');
    }
  }

  // (No-op) Removed unused name lookup; selectedItemBuilder provides compact display.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Delivery Schedule'),
        centerTitle: true,
        elevation: 2,
        leading: widget.isSignupFlow 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Navigate back to choose meal plan page during signup
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ChooseMealPlanPageV3()),
                );
              },
            )
          : null, // Use default back button for settings flow
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Meal Plan summary (Settings version is read-only; change via dedicated page)
            _buildPlanSummarySection(),
            
            if (_selectedMealPlan != null) ...[
              const SizedBox(height: 24),
              _buildScheduleNameSection(),
              const SizedBox(height: 24),
              _buildMealTypeSelectionSection(),
              
              const SizedBox(height: 24),
              _buildDaySelectionSection(),
              
              const SizedBox(height: 24),
              _buildConfigurationSection(),
              
              if (_dayConfigurations.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildConfiguredDaysSection(),
              ],
              
              const SizedBox(height: 24),
              _buildProceedButton(),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSummarySection() {
    final plan = _selectedMealPlan;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.subscriptions_outlined, color: AppThemeV3.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal Plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
          plan != null
            ? '${plan.displayName.isNotEmpty ? plan.displayName : plan.name} • ${plan.mealsPerDay} ${plan.mealsPerDay == 1 ? 'meal' : 'meals'}/day'
            : 'Plan unavailable — complete setup in Settings',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Only show Manage Plan button if NOT in signup flow
            if (!widget.isSignupFlow)
              TextButton(
        onPressed: _navigateToPlanSubscription,
        child: const Text('Manage Plan'),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlanSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageSubscriptionPageV3()),
    ).then((_) => _loadCurrentPlan());
  }

  Widget _buildScheduleNameSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Schedule Name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
              TextFormField(
              controller: _scheduleNameController,
                onChanged: (value) => setState(() {
                  _scheduleName = value;
                }),
              decoration: const InputDecoration(
                hintText: 'Enter schedule name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelectionSection() {
    if (_selectedMealPlan == null) return const SizedBox.shrink();
    final perDay = _selectedMealPlan!.mealsPerDay;
    if (perDay >= 3) {
      // No selection needed; all meals included
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meals Included',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _mealOptions.map((m) => Chip(label: Text(m))).toList(),
              ),
            ],
          ),
        ),
      );
    }

    final selectedCount = _selectedMealTypes.length;
    final allowed = perDay;
    final help = 'Select exactly $allowed meal${allowed == 1 ? '' : 's'} per day';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Meals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$help  •  $selectedCount/$allowed selected',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mealOptions.map((meal) {
                final isOn = _selectedMealTypes.contains(meal);
                return FilterChip(
                  label: Text(meal),
                  selected: isOn,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        if (_selectedMealTypes.length < allowed) {
                          _selectedMealTypes.add(meal);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('You can select only $allowed meal${allowed == 1 ? '' : 's'}')),
                          );
                        }
                      } else {
                        _selectedMealTypes.remove(meal);
                        // Clear temp selections for unselected meal type
                        _tempMealTimes.remove(meal);
                        _tempAddresses.remove(meal);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelectionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Days to Configure',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive columns: 3 on wide, otherwise 2
                final maxW = constraints.maxWidth;
                final cols = maxW >= 480 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2, // wider than tall for chip look
                  children: _daysOfWeek.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    final isConfigured = _isDayConfigured(day);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? Colors.green.withValues(alpha: 0.08)
                              : (isSelected
                                  ? AppThemeV3.accent.withValues(alpha: 0.12)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConfigured
                                ? Colors.green
                                : (isSelected ? AppThemeV3.accent : Colors.grey),
                          ),
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppThemeV3.accent : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    if (_selectedDays.isEmpty && _editingDay == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select days above to configure delivery times and address',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Ensure the correct number of meals is selected for 1 or 2 meals/day plans
    final perDay = _selectedMealPlan?.mealsPerDay ?? 0;
    if (perDay > 0 && perDay < 3 && _selectedMealTypes.length != perDay) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Please choose exactly $perDay meal${perDay == 1 ? '' : 's'} (Breakfast, Lunch, or Dinner) above before configuring.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                _editingDay != null 
                  ? 'Editing $_editingDay'
                  : 'Configure Selected Days (${_selectedDays.length})',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Per-meal-type time and address configuration
            ..._getMealTypesForPlan().map((mealType) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '$mealType:',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTimeForMealType(mealType),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatTimeOfDay(_tempMealTimes[mealType]),
                                  style: TextStyle(
                                    color: _tempMealTimes[mealType] != null
                                        ? Colors.black87
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildEnhancedAddressSelection(mealType),
                    ],
                  ),
                )),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                if (_editingDay != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCurrentDayConfiguration,
                      child: const Text('Save Day'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyToSelectedDays,
                      child: Text('Apply to ${_selectedDays.length} day${_selectedDays.length == 1 ? '' : 's'}'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguredDaysSection() {
    final configuredDays = _dayConfigurations.keys.toList()
      ..sort((a, b) => _daysOfWeek.indexOf(a).compareTo(_daysOfWeek.indexOf(b)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configured Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...configuredDays.map((day) {
              final dayConfig = _dayConfigurations[day]!;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...dayConfig.entries.map((entry) {
                            final mealType = entry.key;
                            final config = entry.value;
                            return Text(
                              '$mealType: ${_formatTimeOfDay(config['time'])} • ${config['address'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _startEditingDay(day),
                      icon: const Icon(Icons.edit, size: 20),
                      color: AppThemeV3.accent,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProceedButton() {
    final hasConfiguredDays = _dayConfigurations.isNotEmpty;
  final canProceed = hasConfiguredDays && _scheduleName.trim().isNotEmpty;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
    onPressed: canProceed ? _proceedToMealSelection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeV3.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Proceed to Meal Selection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _selectTimeForMealType(String mealType) async {
    final initialTime = _tempMealTimes[mealType] ?? TimeOfDay.now();
    final selectedTime = await _showCupertinoTimePicker(initialTime);
    if (selectedTime != null) {
      setState(() {
        _tempMealTimes[mealType] = selectedTime;
      });
    }
  }

  void _proceedToMealSelection() {
    if (_scheduleName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule name')),
      );
      return;
    }
    if (_selectedMealPlan == null) {
      // Block gracefully without asking the user to choose a plan
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your plan could not be loaded. Manage your plan in Settings.')),
      );
      return;
    }
    // Convert to the expected format for MealSchedulePageV3
    Map<String, Map<String, dynamic>> weeklySchedule = {};
    
    for (String day in _dayConfigurations.keys) {
      weeklySchedule[day] = {};
      final dayConfig = _dayConfigurations[day]!;
      
      for (String mealType in dayConfig.keys) {
        final config = dayConfig[mealType]!;
        weeklySchedule[day]![mealType] = {
          'time': config['time'],
          'address': config['address'],
          'enabled': true,
        };
      }
    }

    // Persist this schedule locally so it appears in Meal Schedule selector
    _saveScheduleLocally(weeklySchedule);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSchedulePageV3(
          mealPlan: _selectedMealPlan!,
          weeklySchedule: weeklySchedule,
          initialScheduleName: _scheduleName,
        ),
      ),
    );
  }

  Future<void> _saveScheduleLocally(Map<String, Map<String, dynamic>> weeklySchedule) async {
    try {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid;
      // Ensure name is trimmed and unique in the list
      final name = _scheduleName.trim();
  final listKey = uid == null ? 'saved_schedules' : 'saved_schedules_${uid}';
  final existing = prefs.getStringList(listKey) ?? [];
      final seen = <String>{};
      final cleaned = <String>[];
      for (final s in existing) {
        final t = s.trim();
        if (t.isEmpty) continue;
        if (seen.add(t)) cleaned.add(t);
      }
      if (!seen.contains(name)) {
        cleaned.add(name);
      }
  await prefs.setStringList(listKey, cleaned);

      // Serialize weekly schedule with time as "HH:mm"
      String _timeToStr(dynamic t) {
        if (t is TimeOfDay) {
          final hh = t.hour.toString().padLeft(2, '0');
          final mm = t.minute.toString().padLeft(2, '0');
          return '$hh:$mm';
        }
        return (t ?? '').toString();
      }

      final Map<String, Map<String, dynamic>> serializable = {};
      weeklySchedule.forEach((day, meals) {
        serializable[day] = {};
        meals.forEach((mealType, cfg) {
          serializable[day]![mealType] = {
            'time': _timeToStr(cfg['time']),
            'address': cfg['address'],
          };
        });
      });

      final data = {
        'mealPlanId': _selectedMealPlan!.id,
        // Prefer the current meal types used in the UI if available
        'selectedMealTypes': _getMealTypesForPlan(),
  // Save human-friendly plan names for overviews
  'mealPlanName': _selectedMealPlan!.name,
  'mealPlanDisplayName': _selectedMealPlan!.displayName,
        'weeklySchedule': serializable,
      };
  final key = uid == null ? 'delivery_schedule_$name' : 'delivery_schedule_${uid}_$name';
  await prefs.setString(key, json.encode(data));
  debugPrint('[DeliverySchedule] Saved schedule "$name" locally with ${serializable.length} days');
    } catch (e) {
  debugPrint('[DeliverySchedule] Failed to save schedule locally: $e');
    }
  }

  // Cupertino scroll-wheel time picker shown in a bottom sheet
  Future<TimeOfDay?> _showCupertinoTimePicker(TimeOfDay initial) async {
    TimeOfDay temp = initial;
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        DateTime initialDateTime = DateTime(0, 1, 1, initial.hour, initial.minute);
        return SafeArea(
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                // Action bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      Text(
                        'Select Time',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, temp),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: initialDateTime,
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    onDateTimeChanged: (dt) {
                      temp = TimeOfDay(hour: dt.hour, minute: dt.minute);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }
}
