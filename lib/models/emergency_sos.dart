class EmergencySOS {
  final String id;
  final String residentId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? emergencyType; // Optional quick-type chip (e.g., Fire, Being Followed)

  EmergencySOS({
    required this.id,
    required this.residentId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.emergencyType,
  });

  factory EmergencySOS.fromJson(Map<String, dynamic> json) {
    return EmergencySOS(
      id: json['id'] as String,
      residentId: json['residentId'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      emergencyType: json['emergencyType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentId': residentId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'emergencyType': emergencyType,
      'isCriticalOverride': true, // Always true for SOS module bypasses scoring math
    };
  }
}
