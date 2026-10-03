import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../services/mqtt_service.dart';
import '../services/settings.dart';
import '../services/voice_service.dart';
import '../widgets/cup_view.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final mqtt = MqttService();
  late final VoiceService voice;
  AppSettings settings = AppSettings();

  @override
  void initState() {
    super.initState();
    voice = VoiceService(onCommand: _onVoiceCommand);
    _loadAndConnect();
  }

  Future<void> _loadAndConnect() async {
    settings = await AppSettings.load();
    if (!mounted) return;
    if (!settings.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSettings());
    }
    await mqtt.connect(settings);
  }

  Future<void> _openSettings() async {
    final saved = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(initial: settings)),
    );
    if (saved != null) {
      settings = saved;
      await mqtt.connect(settings);
    }
  }

  void _send(String cmd, {String? heard}) {
    final ok = mqtt.send(cmd);
    final label = {'ON': 'Auto-fill ON', 'STOP': 'Stopped', 'FILL': 'Filling now'}[cmd] ?? cmd;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(ok
            ? (heard != null ? '🎤 "$heard" → $label' : label)
            : 'Not connected - command not sent'),
      ));
  }

  void _onVoiceCommand(String cmd, String heard) {
    if (mounted) _send(cmd, heard: heard);
  }

  @override
  void dispose() {
    voice.dispose();
    mqtt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DiyaMithuru'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([mqtt, voice]),
        builder: (context, _) {
          final s = mqtt.status;
          return RefreshIndicator(
            onRefresh: () => mqtt.connect(settings),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _ConnectionBar(mqtt: mqtt),
                const SizedBox(height: 20),
                Center(child: CupView(level: s.level, cupPresent: s.cup, pumping: s.pump)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    s.cup ? (s.levelValid ? '${s.level}%' : '--') : 'No cup',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                _StatusChips(s: s),
                if (s.fault.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _FaultCard(fault: s.fault, onResume: () => _send('ON')),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _send('ON'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ON'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                      onPressed: () => _send('STOP'),
                      icon: const Icon(Icons.stop),
                      label: const Text('STOP'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _send('FILL'),
                      icon: const Icon(Icons.water_drop_outlined),
                      label: const Text('FILL'),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                _VoicePanel(voice: voice),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  final MqttService mqtt;
  const _ConnectionBar({required this.mqtt});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    switch (mqtt.conn) {
      case Conn.connected:
        color = mqtt.deviceOnline ? Colors.green : Colors.orange;
        text = mqtt.deviceOnline ? 'Cup online' : 'Connected - waiting for cup device';
      case Conn.connecting:
        color = Colors.orange;
        text = 'Connecting to HiveMQ...';
      case Conn.error:
        color = Colors.red;
        text = mqtt.error ?? 'Connection error';
      case Conn.disconnected:
        color = Colors.grey;
        text = 'Disconnected';
    }
    return Row(children: [
      Icon(Icons.circle, size: 12, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ]);
  }
}

class _StatusChips extends StatelessWidget {
  final DeviceStatus s;
  const _StatusChips({required this.s});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(s.cup ? Icons.local_cafe : Icons.local_cafe_outlined, size: 18),
          label: Text(s.cup ? 'Cup placed' : 'No cup'),
        ),
        Chip(
          avatar: Icon(Icons.water_drop, size: 18, color: s.pump ? Colors.blue : Colors.grey),
          label: Text(s.pump ? 'Pump ON' : 'Pump OFF'),
        ),
        Chip(
          avatar: Icon(s.paused ? Icons.pause_circle : Icons.autorenew, size: 18),
          label: Text(s.paused ? 'Paused' : 'Auto-fill'),
        ),
      ],
    );
  }
}

class _FaultCard extends StatelessWidget {
  final String fault;
  final VoidCallback onResume;
  const _FaultCard({required this.fault, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final msg = fault == 'TIMEOUT'
        ? 'Pump ran too long without the cup filling. Check the water tank and tube, then press ON.'
        : 'Level sensor is not reading. Check the ultrasonic sensor wiring.';
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: Text(msg),
        trailing: fault == 'TIMEOUT' ? TextButton(onPressed: onResume, child: const Text('ON')) : null,
      ),
    );
  }
}

class _VoicePanel extends StatelessWidget {
  final VoiceService voice;
  const _VoicePanel({required this.voice});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          GestureDetector(
            onTap: () => voice.listening ? voice.stop() : voice.start(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: voice.listening ? 92 : 80,
              height: voice.listening ? 92 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: voice.listening ? Colors.red.shade500 : scheme.primary,
                boxShadow: voice.listening
                    ? [BoxShadow(color: Colors.red.withOpacity(.4), blurRadius: 24, spreadRadius: 4)]
                    : null,
              ),
              child: Icon(voice.listening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            voice.listening
                ? (voice.heard.isEmpty ? 'Listening...' : '"${voice.heard}"')
                : 'Tap and say "stop", "on" or "fill"',
            textAlign: TextAlign.center,
          ),
          if (voice.error != null) ...[
            const SizedBox(height: 6),
            Text(voice.error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hands-free listening'),
            subtitle: const Text('Keep listening for commands while the app is open'),
            value: voice.handsFree,
            onChanged: voice.setHandsFree,
          ),
        ]),
      ),
    );
  }
}
