import 'dart:convert';

/// Live state reported by the ESP32 on diyamithuru/<id>/status
class DeviceStatus {
  final bool cup;
  final int level;
  final double distance;
  final bool levelValid;
  final bool pump;
  final String mode; // AUTO | PAUSED
  final bool fill;
  final String fault; // "" | TIMEOUT | SENSOR
  final int rssi;
  final double temp;

  const DeviceStatus({
    this.cup = false,
    this.level = 0,
    this.distance = -1,
    this.levelValid = false,
    this.pump = false,
    this.mode = 'AUTO',
    this.fill = false,
    this.fault = '',
    this.rssi = 0,
    this.temp = 0.0,
  });

  bool get paused => mode == 'PAUSED';

  static DeviceStatus? tryParse(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DeviceStatus(
        cup: j['cup'] == true,
        level: (j['level'] as num?)?.toInt() ?? 0,
        distance: (j['distance'] as num?)?.toDouble() ?? -1,
        levelValid: j['levelValid'] == true,
        pump: j['pump'] == true,
        mode: (j['mode'] as String?) ?? 'AUTO',
        fill: j['fill'] == true,
        fault: (j['fault'] as String?) ?? '',
        rssi: (j['rssi'] as num?)?.toInt() ?? 0,
        temp: (j['temp'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }
}
