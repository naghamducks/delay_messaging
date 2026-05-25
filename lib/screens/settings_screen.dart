import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delay_messenger/services/service_locator.dart';
import '../providers/theme_provider.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _keyRelayMode     = 'relay_mode_enabled';
  static const _keyNotifMessages = 'notif_messages';
  static const _keyNotifRelay    = 'notif_relay';
  static const _keySosContacts   = 'sos_contacts';

  bool         _relayMode     = false;
  bool         _notifMessages = true;
  bool         _notifRelay    = false;
  List<String> _sosContacts   = [];

  int _myCount    = 0;
  int _relayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _refreshStorageCounts();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _relayMode     = prefs.getBool(_keyRelayMode)     ?? false;
      _notifMessages = prefs.getBool(_keyNotifMessages) ?? true;
      _notifRelay    = prefs.getBool(_keyNotifRelay)    ?? false;
      final raw = prefs.getString(_keySosContacts);
      if (raw != null) {
        _sosContacts = List<String>.from(jsonDecode(raw) as List);
      }
    });
  }

  void _refreshStorageCounts() {
    setState(() {
      _myCount    = ServiceLocator.storage.getMyMessages().length;
      _relayCount = ServiceLocator.storage.getRelayMessages().length;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveSosContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySosContacts, jsonEncode(_sosContacts));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────
          _sectionHeader(context, 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: themeProvider.isDarkMode,
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
          const Divider(),

          // ── DTN Settings ──────────────────────────────────────────────
          _sectionHeader(context, 'DTN Settings'),
          SwitchListTile(
            secondary: const Icon(Icons.router),
            title: const Text('Enable Relay Mode'),
            subtitle: const Text('Allow this device to relay messages'),
            value: _relayMode,
            onChanged: (v) {
              setState(() => _relayMode = v);
              _setBool(_keyRelayMode, v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Message Storage'),
            subtitle: Text(
              'My messages: $_myCount   •   Relay buffer: $_relayCount',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh counts',
              onPressed: _refreshStorageCounts,
            ),
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

          // ── Notifications ─────────────────────────────────────────────
          _sectionHeader(context, 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Message Notifications'),
            subtitle: const Text('Notify when messages are received'),
            value: _notifMessages,
            onChanged: (v) {
              setState(() => _notifMessages = v);
              _setBool(_keyNotifMessages, v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: const Text('Relay Notifications'),
            subtitle: const Text('Notify when relaying messages'),
            value: _notifRelay,
            onChanged: (v) {
              setState(() => _notifRelay = v);
              _setBool(_keyNotifRelay, v);
            },
          ),
          const Divider(),

          // ── Emergency ─────────────────────────────────────────────────
          _sectionHeader(context, 'Emergency'),
          ..._sosContacts.asMap().entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: Text(entry.value),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                tooltip: 'Remove',
                onPressed: () {
                  setState(() => _sosContacts.removeAt(entry.key));
                  _saveSosContacts();
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.emergency, color: Colors.red),
            title: const Text('SOS Contacts'),
            subtitle: Text(
              _sosContacts.isEmpty
                  ? 'No emergency contacts configured'
                  : '${_sosContacts.length} contact(s)',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add SOS contact',
              onPressed: _showAddSosContactDialog,
            ),
          ),
          const Divider(),

          // ── About ─────────────────────────────────────────────────────
          _sectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context),
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

  Widget _sectionHeader(BuildContext context, String title) {
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

  Future<void> _showAddSosContactDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add SOS Contact'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Node ID',
            hintText: 'e.g. node-alpha',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final nodeId = controller.text.trim();
      if (!_sosContacts.contains(nodeId)) {
        setState(() => _sosContacts.add(nodeId));
        await _saveSosContacts();
      }
    }
  }
}