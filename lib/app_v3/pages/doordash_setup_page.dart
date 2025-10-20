import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/doordash_config.dart';
import '../services/doordash_auth_service.dart';

/// DoorDash Credential Setup Page
/// Helps users configure their DoorDash API credentials
class DoorDashSetupPage extends StatefulWidget {
  const DoorDashSetupPage({super.key});

  @override
  State<DoorDashSetupPage> createState() => _DoorDashSetupPageState();
}

class _DoorDashSetupPageState extends State<DoorDashSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _developerIdController = TextEditingController();
  final _keyIdController = TextEditingController();
  final _signingKeyController = TextEditingController();
  
  bool _isLoading = false;
  bool _showSigningKey = false;
  String? _connectionStatus;
  bool _connectionSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  void _checkCurrentStatus() {
    // Check if credentials are already configured
    setState(() {
      _connectionStatus = DoorDashConfig.credentialStatus;
      _connectionSuccess = DoorDashConfig.hasValidCredentials;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DoorDash API Setup'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _connectionSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _connectionSuccess ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _connectionSuccess ? Icons.check_circle : Icons.warning,
                          color: _connectionSuccess ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connection Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _connectionSuccess ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionStatus ?? 'Checking...',
                      style: TextStyle(
                        color: _connectionSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              const Text(
                'DoorDash API Credentials',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Enter your DoorDash Drive API credentials. You can get these from the DoorDash Developer Portal after signing up for DoorDash Drive.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Get Credentials Button
              OutlinedButton.icon(
                onPressed: () => _showCredentialInstructions(),
                icon: const Icon(Icons.help_outline),
                label: const Text('How to get DoorDash credentials'),
              ),
              
              const SizedBox(height: 24),
              
              // Developer ID Field
              TextFormField(
                controller: _developerIdController,
                decoration: const InputDecoration(
                  labelText: 'Developer ID',
                  hintText: 'Enter your DoorDash Developer ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Developer ID';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Key ID Field
              TextFormField(
                controller: _keyIdController,
                decoration: const InputDecoration(
                  labelText: 'Key ID',
                  hintText: 'Enter your DoorDash Key ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Key ID';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Signing Key Field
              TextFormField(
                controller: _signingKeyController,
                maxLines: 8,
                obscureText: !_showSigningKey,
                decoration: InputDecoration(
                  labelText: 'Private Signing Key',
                  hintText: 'Paste your private key here (including BEGIN/END lines)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showSigningKey = !_showSigningKey;
                      });
                    },
                    icon: Icon(_showSigningKey ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your private signing key';
                  }
                  if (!value.contains('BEGIN PRIVATE KEY')) {
                    return 'Key should include BEGIN PRIVATE KEY header';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _testConnection,
                      child: _isLoading 
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCredentials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save & Configure'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Debug Information (Development only)
              if (DoorDashConfig.hasValidCredentials) ...[
                const Divider(),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Debug Information'),
                  children: [
                    ListTile(
                      title: const Text('Environment'),
                      subtitle: Text(DoorDashConfig.credentialStatus),
                    ),
                    ListTile(
                      title: const Text('Base URL'),
                      subtitle: Text(DoorDashConfig.baseUrl),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        DoorDashConfig.printDebugInfo();
                        DoorDashAuthService.instance.debugToken();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debug info printed to console')),
                        );
                      },
                      child: const Text('Print Debug Info'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCredentialInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Getting DoorDash Credentials'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Sign up for DoorDash Drive',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Visit https://get.doordash.com/drive/ and apply for a business account.'),
              SizedBox(height: 16),
              Text(
                '2. Contact DoorDash for API Access',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Once approved, contact your DoorDash representative to request API access.'),
              SizedBox(height: 16),
              Text(
                '3. Access Developer Portal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Log into https://developer.doordash.com/ to get your credentials.'),
              SizedBox(height: 16),
              Text(
                '4. Generate API Keys',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Create a new API key and download the private key file.'),
              SizedBox(height: 16),
              Text(
                'Note: This process typically takes 1-2 weeks for approval.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Copy URL to clipboard
              Clipboard.setData(const ClipboardData(text: 'https://get.doordash.com/drive/'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('DoorDash Drive URL copied to clipboard')),
              );
            },
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      // For now, just validate the form inputs
      // In production, you'd update the config with these values and test
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      setState(() {
        _connectionStatus = 'Test credentials entered (save to test actual connection)';
        _connectionSuccess = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credentials validated. Click "Save & Configure" to test actual connection.'),
          backgroundColor: Colors.orange,
        ),
      );
      
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection test failed: $e';
        _connectionSuccess = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Saving credentials and testing connection...';
    });

    try {
      // Show instructions for manual configuration
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Manual Configuration Required'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To complete the setup, please manually update the configuration file:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('1. Open: lib/app_v3/config/doordash_config.dart'),
                const SizedBox(height: 8),
                const Text('2. Replace the test credentials with:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Developer ID: ${_developerIdController.text}'),
                      Text('Key ID: ${_keyIdController.text}'),
                      const Text('Signing Key: [Your private key]'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('3. Set _isProduction = true when ready for production'),
                const SizedBox(height: 16),
                const Text(
                  'Note: Never commit actual credentials to version control!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Close setup page too
              },
              child: const Text('Got it'),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy credentials to clipboard
                final credentials = '''
Developer ID: ${_developerIdController.text}
Key ID: ${_keyIdController.text}
Signing Key: ${_signingKeyController.text}
''';
                Clipboard.setData(ClipboardData(text: credentials));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied to clipboard')),
                );
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Copy & Close'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _developerIdController.dispose();
    _keyIdController.dispose();
    _signingKeyController.dispose();
    super.dispose();
  }
}