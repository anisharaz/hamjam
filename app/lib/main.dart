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

/// Spike: capture all media audio (no calls) and drive any player via media keys.
class CaptureSpike extends StatefulWidget {
  const CaptureSpike({super.key});
  @override
  State<CaptureSpike> createState() => _CaptureSpikeState();
}

class _CaptureSpikeState extends State<CaptureSpike> {
  static const _method = MethodChannel('hamjam/capture');
  static const _events = EventChannel('hamjam/capture_events');

  String _state = 'idle';
  double _level = 0;
  double _peak = 0;

  @override
  void initState() {
    super.initState();
    _events.receiveBroadcastStream().listen((e) {
      final m = e as Map;
      setState(() {
        if (m.containsKey('level')) {
          _level = m['level'] as double;
          if (_level > _peak) _peak = _level;
        }
        if (m.containsKey('state')) {
          _state = m['state'] as String;
          if (_state != 'capturing') _level = 0;
        }
      });
    });
  }

  Future<void> _start() async {
    _peak = 0;
    final ok = await _method.invokeMethod<bool>('start');
    if (ok != true) setState(() => _state = 'grant permissions, then press Start again');
  }

  Future<void> _stop() => _method.invokeMethod('stop');
  Future<void> _key(String k) => _method.invokeMethod('mediaKey', {'key': k});

  @override
  Widget build(BuildContext context) {
    final capturing = _state == 'capturing';
    return Scaffold(
      appBar: AppBar(title: const Text('HamJam – spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('State: $_state'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_level * 4).clamp(0, 1), minHeight: 12),
          Text('Peak level: ${_peak.toStringAsFixed(3)}'),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton(onPressed: capturing ? null : _start, child: const Text('Start sharing')),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: capturing ? _stop : null, child: const Text('Stop')),
          ]),
          const SizedBox(height: 24),
          const Text('Media controls (act on whatever app is playing)'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(iconSize: 40, onPressed: () => _key('previous'), icon: const Icon(Icons.skip_previous)),
            IconButton(iconSize: 48, onPressed: () => _key('playPause'), icon: const Icon(Icons.play_arrow)),
            IconButton(iconSize: 40, onPressed: () => _key('next'), icon: const Icon(Icons.skip_next)),
          ]),
          const SizedBox(height: 16),
          const Text('Press Start, play a song in any app. The bar should move. '
              'Peak stays 0.000 if that app blocks capture.',
              style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
