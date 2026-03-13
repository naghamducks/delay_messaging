import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance section
          _buildSectionHeader(context, 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
          const Divider(),

          // DTN Settings section
          _buildSectionHeader(context, 'DTN Settings'),
          ListTile(
            leading: const Icon(Icons.router),
            title: const Text('Enable Relay Mode'),
            subtitle: const Text('Allow this device to relay messages'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // TODO: Implement relay mode toggle
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Message Storage'),
            subtitle: const Text('500 MB / 2 GB used'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to storage settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text('Network Priority'),
            subtitle: const Text('WiFi Direct, Bluetooth, LoRa'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to network priority settings
            },
          ),
          const Divider(),

          // Notifications section
          _buildSectionHeader(context, 'Notifications'),
          SwitchListTile(
            title: const Text('Message Notifications'),
            subtitle: const Text('Notify when messages are received'),
            value: true,
            onChanged: (value) {
              // TODO: Implement notification toggle
            },
            secondary: const Icon(Icons.notifications),
          ),
          SwitchListTile(
            title: const Text('Relay Notifications'),
            subtitle: const Text('Notify when relaying messages'),
            value: false,
            onChanged: (value) {
              // TODO: Implement relay notification toggle
            },
            secondary: const Icon(Icons.sync),
          ),
          const Divider(),

          // Emergency section
          _buildSectionHeader(context, 'Emergency'),
          ListTile(
            leading: const Icon(Icons.emergency, color: Colors.red),
            title: const Text('SOS Contacts'),
            subtitle: const Text('Configure emergency contacts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to SOS contacts
            },
          ),
          const Divider(),

          // About section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Documentation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to help
            },
          ),
        ],
      ),
    );
  }

  /// Build a section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
