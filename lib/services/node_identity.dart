import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable, persistent identity for this DTN node.
/// Generates a random ID on first launch and reuses it forever.
class NodeIdentity {
  static const _key = 'dtn_node_id';
  static String? _cached;

  static Future<String> init() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_key);
    if (_cached == null) {
      _cached = 'node_${_randomSuffix()}';
      await prefs.setString(_key, _cached!);
    }
    print('🆔 My node ID: $_cached');
    return _cached!;
  }

  /// Synchronous getter — only valid after init() has completed.
  static String get id {
    assert(_cached != null, 'NodeIdentity.init() must be awaited before use');
    return _cached!;
  }

  static String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}