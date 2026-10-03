import 'package:flutter/material.dart';

import '../services/settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings initial;
  const SettingsScreen({super.key, required this.initial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final _host = TextEditingController(text: widget.initial.host);
  late final _port = TextEditingController(text: widget.initial.port.toString());
  late final _user = TextEditingController(text: widget.initial.username);
  late final _pass = TextEditingController(text: widget.initial.password);
  late final _device = TextEditingController(text: widget.initial.deviceId);
  bool _showPass = false;

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass, _device]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = AppSettings(
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _user.text.trim(),
      password: _pass.text,
      deviceId: _device.text.trim(),
    );
    await s.save();
    if (mounted) Navigator.pop(context, s);
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('HiveMQ Cloud', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Cluster URL',
                hintText: 'abc123.s1.eu.hivemq.cloud',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'Port (TLS)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              validator: _required,
            ),
            const SizedBox(height: 24),
            Text('Device', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _device,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                helperText: 'Same as DEVICE_ID in the ESP32 config.h',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('Save & connect')),
          ],
        ),
      ),
    );
  }
}
