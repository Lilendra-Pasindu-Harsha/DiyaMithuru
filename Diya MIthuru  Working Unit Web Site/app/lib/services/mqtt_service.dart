import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/device_status.dart';
import 'settings.dart';

enum Conn { disconnected, connecting, connected, error }

/// Talks to the ESP32 through HiveMQ Cloud.
///   publish   diyamithuru/<id>/cmd     "ON" | "STOP" | "FILL" | "PING"
///   subscribe diyamithuru/<id>/status  JSON status
///   subscribe diyamithuru/<id>/online  "1" / "0"
class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  StreamSubscription? _sub;
  AppSettings? _settings;

  Conn conn = Conn.disconnected;
  String? error;
  bool deviceOnline = false;
  DeviceStatus status = const DeviceStatus();
  DateTime? lastUpdate;

  String get _base => 'diyamithuru/${_settings!.deviceId}';

  Future<void> connect(AppSettings s) async {
    await disconnect();
    _settings = s;
    if (!s.isComplete) {
      conn = Conn.error;
      error = 'Open Settings and enter your HiveMQ details.';
      notifyListeners();
      return;
    }

    conn = Conn.connecting;
    error = null;
    notifyListeners();

    final clientId = 'diyamithuru-app-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    final c = MqttServerClient.withPort(s.host, clientId, s.port)
      ..secure = true
      ..securityContext = SecurityContext.defaultContext
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..setProtocolV311();

    c.connectionMessage = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    c.onConnected = () {
      conn = Conn.connected;
      notifyListeners();
    };
    c.onAutoReconnect = () {
      conn = Conn.connecting;
      notifyListeners();
    };
    c.onAutoReconnected = () {
      conn = Conn.connected;
      notifyListeners();
    };
    c.onDisconnected = () {
      if (conn != Conn.error) conn = Conn.disconnected;
      notifyListeners();
    };
    _client = c;

    try {
      await c.connect(s.username, s.password);
    } catch (e) {
      c.disconnect();
      conn = Conn.error;
      error = 'Could not connect: $e';
      notifyListeners();
      return;
    }

    if (c.connectionStatus?.state != MqttConnectionState.connected) {
      conn = Conn.error;
      error = 'Broker refused: ${c.connectionStatus?.returnCode}. Check username/password.';
      c.disconnect();
      notifyListeners();
      return;
    }

    c.subscribe('$_base/status', MqttQos.atLeastOnce);
    c.subscribe('$_base/online', MqttQos.atLeastOnce);
    _sub = c.updates?.listen(_onMessages);

    conn = Conn.connected;
    notifyListeners();
    send('PING');
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> msgs) {
    for (final m in msgs) {
      final pub = m.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(pub.payload.message);
      if (m.topic == '$_base/status') {
        final s = DeviceStatus.tryParse(text);
        if (s != null) {
          status = s;
          deviceOnline = true;
          lastUpdate = DateTime.now();
        }
      } else if (m.topic == '$_base/online') {
        deviceOnline = text.trim() == '1';
      }
    }
    notifyListeners();
  }

  /// Send a command to the cup. Returns false if not connected.
  bool send(String command) {
    final c = _client;
    if (c == null || conn != Conn.connected) return false;
    final b = MqttClientPayloadBuilder()..addString(command);
    c.publishMessage('$_base/cmd', MqttQos.atLeastOnce, b.payload!);
    return true;
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _client?.autoReconnect = false;
    _client?.disconnect();
    _client = null;
    conn = Conn.disconnected;
    deviceOnline = false;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
