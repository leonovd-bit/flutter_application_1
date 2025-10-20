import 'package:flutter/material.dart';

/// DoorDash Connection Test Page
/// Minimal test page to verify basic functionality
class DoorDashTestPage extends StatefulWidget {
  const DoorDashTestPage({Key? key}) : super(key: key);

  @override
  State<DoorDashTestPage> createState() {
    print('[DoorDashTestPage] Creating state...');
    return _DoorDashTestPageState();
  }
}

class _DoorDashTestPageState extends State<DoorDashTestPage> {
  String _status = 'Initializing...';
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    print('[DoorDashTestPage] initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[DoorDashTestPage] Post frame callback');
      setState(() {
        _status = 'Page Loaded Successfully';
        _results.add('✅ Page initialized');
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('[DoorDashTestPage] didChangeDependencies called');
  }

  @override
  Widget build(BuildContext context) {
    print('[DoorDashTestPage] Build method called');
    print('[DoorDashTestPage] Status: $_status');
    print('[DoorDashTestPage] Results count: ${_results.length}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('DoorDash API Test'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delivery_dining,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Basic Test'),
              onPressed: () {
                print('[DoorDashTestPage] Test button pressed');
                setState(() {
                  _results.add('Test executed at ${DateTime.now()}');
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test executed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              margin: EdgeInsets.all(20),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This is a minimal test page.\nIf you can see this, the page is loading correctly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_results.isNotEmpty)
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Test Results:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  _results[index],
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}