import 'package:shared_preferences/shared_preferences.dart';

/// Broker + device settings, saved on the phone.
class AppSettings {
  String host;
  int port;
  String username;
  String password;
  String deviceId;

  AppSettings({
    this.host = '',
    this.port = 8883,
    this.username = '',
    this.password = '',
    this.deviceId = 'cup01',
  });

  bool get isComplete => host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      host: p.getString('host') ?? '',
      port: p.getInt('port') ?? 8883,
      username: p.getString('username') ?? '',
      password: p.getString('password') ?? '',
      deviceId: p.getString('deviceId') ?? 'cup01',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('host', host.trim());
    await p.setInt('port', port);
    await p.setString('username', username.trim());
    await p.setString('password', password);
    await p.setString('deviceId', deviceId.trim());
  }
}
