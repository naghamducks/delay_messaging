import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable, persistent identity for this DTN node.
/// Generates a random ID on first launch and reuses it forever.
/// Also stores a user-chosen display name.
class NodeIdentity {
  static const _keyId          = 'dtn_node_id';
  static const _keyDisplayName = 'dtn_display_name';

  static String? _cachedId;
  static String? _cachedDisplayName;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Node ID — generated once, never changes
    _cachedId = prefs.getString(_keyId);
    if (_cachedId == null) {
      _cachedId = 'node_${_randomSuffix()}';
      await prefs.setString(_keyId, _cachedId!);
    }

    // Display name — set by user on first launch, changeable in settings
    _cachedDisplayName = prefs.getString(_keyDisplayName);

    print('🆔 My node ID: $_cachedId');
    if (_cachedDisplayName != null) {
      print('👤 My display name: $_cachedDisplayName');
    }
  }

  /// The stable node ID (never changes).
  static String get id {
    assert(_cachedId != null, 'NodeIdentity.init() must be awaited before use');
    return _cachedId!;
  }

  /// The user's chosen display name, or null if not yet set.
  static String? get displayName => _cachedDisplayName;

  /// Display name if set, otherwise the node ID.
  static String get displayNameOrId => _cachedDisplayName ?? _cachedId!;

  /// True if the user has not yet set a display name.
  static bool get needsDisplayName => _cachedDisplayName == null;

  /// Save a new display name. Updates both cache and SharedPreferences.
  static Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _cachedDisplayName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, trimmed);
    print('👤 Display name set: $trimmed');
  }

  static String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}