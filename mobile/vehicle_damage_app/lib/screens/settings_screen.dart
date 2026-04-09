/// Settings Screen - Configure app settings

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  double _confidenceThreshold = 0.25;
  bool _returnAnnotatedImage = true;
  bool _includeLabor = true;
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrlController.text = prefs.getString('server_url') ?? 'http://localhost:8000';
      _confidenceThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
      _returnAnnotatedImage = prefs.getBool('return_annotated') ?? true;
      _includeLabor = prefs.getBool('include_labor') ?? true;
      _currency = prefs.getString('currency') ?? 'USD';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrlController.text);
    await prefs.setDouble('confidence_threshold', _confidenceThreshold);
    await prefs.setBool('return_annotated', _returnAnnotatedImage);
    await prefs.setBool('include_labor', _includeLabor);
    await prefs.setString('currency', _currency);
    
    // Update API service base URL
    final api = context.read<ApiService>();
    api.baseUrl = _serverUrlController.text;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final api = context.read<ApiService>();
    final originalUrl = api.baseUrl;
    
    // Temporarily set URL to test
    api.baseUrl = _serverUrlController.text;
    final isConnected = await api.healthCheck();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(isConnected ? 'Connection successful!' : 'Connection failed'),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
    
    // Restore original URL if test failed
    if (!isConnected) {
      api.baseUrl = originalUrl;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server Configuration
          _SectionHeader(title: 'Server Configuration'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://localhost:8000',
                      prefixIcon: Icon(Icons.dns),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testConnection,
                          icon: const Icon(Icons.network_check),
                          label: const Text('Test Connection'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Detection Settings
          _SectionHeader(title: 'Detection Settings'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Confidence Threshold'),
                  subtitle: Text('${(_confidenceThreshold * 100).toInt()}%'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: _confidenceThreshold,
                      min: 0.1,
                      max: 0.9,
                      divisions: 16,
                      onChanged: (value) {
                        setState(() {
                          _confidenceThreshold = value;
                        });
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.image),
                  title: const Text('Return Annotated Image'),
                  subtitle: const Text('Show bounding boxes on image'),
                  value: _returnAnnotatedImage,
                  onChanged: (value) {
                    setState(() {
                      _returnAnnotatedImage = value;
                    });
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Cost Estimation Settings
          _SectionHeader(title: 'Cost Estimation'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.engineering),
                  title: const Text('Include Labor Costs'),
                  subtitle: const Text('Add labor costs to estimates'),
                  value: _includeLabor,
                  onChanged: (value) {
                    setState(() {
                      _includeLabor = value;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Currency'),
                  trailing: DropdownButton<String>(
                    value: _currency,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                      DropdownMenuItem(value: 'AUD', child: Text('AUD (A\$)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _currency = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Appearance
          _SectionHeader(title: 'Appearance'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.setDarkMode(value);
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // About
          _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Model'),
                  subtitle: const Text('YOLO / Faster R-CNN'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Damage Categories'),
                  subtitle: const Text('Dent, Scratch, Crack, Glass Shatter,\nLamp Broken, Tire Flat'),
                  isThreeLine: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
