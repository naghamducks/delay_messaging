/// Represents a nearby DTN-capable device
class DTNDevice {
  final String id;
  final String name;
  final String deviceType;
  final double signalStrength; // 0.0 to 1.0
  final bool isConnected;
  final DateTime lastSeen;

  DTNDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.signalStrength,
    required this.isConnected,
    required this.lastSeen,
  });

  /// Create a copy of the device with updated fields
  DTNDevice copyWith({
    String? id,
    String? name,
    String? deviceType,
    double? signalStrength,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return DTNDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      signalStrength: signalStrength ?? this.signalStrength,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
