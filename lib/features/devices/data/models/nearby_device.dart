class NearbyDevice {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.isConnectable,
    required this.lastSeen,
    this.rssi,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final bool isConnectable;
  final DateTime lastSeen;
  final int? rssi;
  final bool isAvailable;

  NearbyDevice copyWith({
    String? id,
    String? name,
    bool? isConnectable,
    DateTime? lastSeen,
    int? rssi,
    bool? isAvailable,
  }) {
    return NearbyDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnectable: isConnectable ?? this.isConnectable,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  factory NearbyDevice.fromMap(Map<Object?, Object?> map) => NearbyDevice(
    id: map['id']! as String,
    name: (map['name'] as String?)?.trim().isNotEmpty == true
        ? (map['name']! as String).trim()
        : 'MeshLink User',
    isConnectable: map['isConnectable'] as bool? ?? false,
    rssi: (map['rssi'] as num?)?.toInt(),
    lastSeen: DateTime.now(),
    isAvailable: true,
  );
}
