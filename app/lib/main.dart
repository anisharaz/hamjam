import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const HamJamApp());

class HamJamApp extends StatelessWidget {
  const HamJamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HamJam',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const CaptureSpike(),
      );
}

/// Milestone 1 spike: pick an app, capture only its audio, show a level meter.
class CaptureSpike extends StatefulWidget {
  const CaptureSpike({super.key});
  @override
  State<CaptureSpike> createState() => _CaptureSpikeState();
}

class _CaptureSpikeState extends State<CaptureSpike> {
  static const _method = MethodChannel('hamjam/capture');
  static const _events = EventChannel('hamjam/capture_events');

  List<Map> _apps = [];
  Map? _selected;
  String _state = 'idle';
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _events.receiveBroadcastStream().listen((e) {
      final m = e as Map;
      setState(() {
        if (m.containsKey('level')) _level = (m['level'] as double);
        if (m.containsKey('state')) {
          _state = m['state'] as String;
          if (_state != 'capturing') _level = 0;
        }
      });
    });
    _method.invokeListMethod<Map>('listApps').then((a) => setState(() => _apps = a ?? []));
  }

  Future<void> _start() async {
    if (_selected == null) return;
    final ok = await _method.invokeMethod<bool>('start', {'uid': _selected!['uid']});
    if (ok != true) setState(() => _state = 'grant permissions, then press Start again');
  }

  Future<void> _stop() => _method.invokeMethod('stop');

  @override
  Widget build(BuildContext context) {
    final capturing = _state == 'capturing';
    return Scaffold(
      appBar: AppBar(title: const Text('HamJam – capture spike')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Selected: ${_selected?['name'] ?? 'none'}'),
            Text('State: $_state'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_level * 4).clamp(0, 1), minHeight: 12),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton(
                  onPressed: capturing || _selected == null ? null : _start,
                  child: const Text('Start capture')),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: capturing ? _stop : null, child: const Text('Stop')),
            ]),
            const SizedBox(height: 8),
            const Text('Pick the music app, press Start, then play a song in that app. '
                'The bar should move only for that app\'s audio.',
                style: TextStyle(fontSize: 12)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _apps.length,
            itemBuilder: (_, i) {
              final a = _apps[i];
              return ListTile(
                dense: true,
                title: Text(a['name']),
                subtitle: Text(a['package']),
                selected: _selected?['package'] == a['package'],
                onTap: capturing ? null : () => setState(() => _selected = a),
              );
            },
          ),
        ),
      ]),
    );
  }
}
