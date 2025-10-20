import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/square_integration_service.dart';

/// Admin page for managing restaurant prep schedules
class AdminRestaurantPrepPage extends StatefulWidget {
  const AdminRestaurantPrepPage({Key? key}) : super(key: key);

  @override
  State<AdminRestaurantPrepPage> createState() => _AdminRestaurantPrepPageState();
}

class _AdminRestaurantPrepPageState extends State<AdminRestaurantPrepPage> {
  bool _isLoading = false;
  String _statusMessage = '';
  DateTime? _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = SquareIntegrationServiceExtensions.getCurrentWeekStart();
  }

  Future<void> _sendWeeklyPrepSchedules() async {
    if (_selectedWeekStart == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending weekly prep schedules to restaurants...';
    });

    try {
      final result = await SquareIntegrationServiceExtensions.sendWeeklyPrepSchedules(
        weekStartDate: _selectedWeekStart!,
      );

      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _statusMessage = 'Successfully sent prep schedules to ${result['restaurantsNotified']} restaurants';
        } else {
          _statusMessage = 'Error: ${result['error']}';
        }
      });

      if (result['success'] == true) {
        _showResultDialog(result);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error sending prep schedules: $e';
      });
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Prep Schedules Sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Week: ${result['weekStart']}'),
              Text('Restaurants Notified: ${result['restaurantsNotified']}'),
              const SizedBox(height: 16),
              if (result['results'] != null) ...[
                const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...((result['results'] as List).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${r['restaurantName']}: ${r['itemsSent']} items (${r['totalQuantity']} total)'),
                ))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Select Week Start Date',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedWeekStart != null 
                    ? 'Week of: ${_formatDate(_selectedWeekStart!)}'
                    : 'No week selected',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _selectWeekStart(),
                child: const Text('Choose Date'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedWeekStart = SquareIntegrationServiceExtensions.getCurrentWeekStart();
                    });
                  },
                  child: const Text('Current Week'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedWeekStart = SquareIntegrationServiceExtensions.getNextWeekStart();
                    });
                  },
                  child: const Text('Next Week'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectWeekStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      // Convert to Monday of that week
      final monday = picked.subtract(Duration(days: picked.weekday - 1));
      setState(() {
        _selectedWeekStart = DateTime(monday.year, monday.month, monday.day);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${_getWeekdayName(date.weekday)}, ${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getWeekdayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Prep Schedules'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Restaurant Prep Schedule Manager',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Send filtered weekly prep schedules to restaurant partners. Each restaurant will only receive schedule portions that use their specific meals.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildWeekSelector(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading || _selectedWeekStart == null ? null : _sendWeeklyPrepSchedules,
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
              label: Text(_isLoading ? 'Sending...' : 'Send Prep Schedules'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (_statusMessage.isNotEmpty) ...[
              Card(
                color: _statusMessage.contains('Error') 
                  ? Colors.red.shade50 
                  : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('Error') 
                          ? Icons.error_outline 
                          : Icons.check_circle_outline,
                        color: _statusMessage.contains('Error') 
                          ? Colors.red 
                          : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('Error') 
                              ? Colors.red.shade800 
                              : Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 How It Works:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. System analyzes scheduled orders for the selected week'),
                    Text('2. Filters meals by restaurant to avoid information overload'),
                    Text('3. Groups prep items by meal type (breakfast, lunch, dinner)'),
                    Text('4. Sends clean, organized prep schedules to relevant restaurants only'),
                    Text('5. Individual confirmed orders are sent separately when customers confirm'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}