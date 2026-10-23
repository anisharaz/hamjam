import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'session_page.dart';

const _defaultServer = String.fromEnvironment('SERVER_URL', defaultValue: 'ws://192.168.1.10:8080');

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _session = Session.instance;
  final _server = TextEditingController(text: _defaultServer);
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_rebuild);
    // The app may have been closed while a jam kept running: pick it back up.
    _session.refresh().then((_) {
      if (mounted && _session.active) _openSession();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_rebuild);
    _server.dispose();
    _code.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _session.refresh();
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _openSession() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionPage()));

  Future<void> _host() async {
    final ok = await _session.host(_server.text.trim());
    if (!mounted) return;
    if (ok) {
      _openSession();
    } else {
      _say('Allow the permissions, then tap again.');
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) return _say('Enter the 6-character code.');
    final ok = await _session.join(_server.text.trim(), code);
    if (!mounted) return;
    if (ok) {
      _code.clear();
      _openSession();
    } else {
      _say('Allow the permissions, then tap again.');
    }
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Server', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Address of the HamJam relay.', style: TextStyle(color: Palette.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              filled: true,
              fillColor: Palette.ink.withValues(alpha: 0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Palette.ink.withValues(alpha: 0.62);
    return GradientScaffold(
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), children: [
        Row(children: [
          const GradientText('HamJam', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const Spacer(),
          IconButton(onPressed: _settings, icon: const Icon(Icons.tune_rounded), tooltip: 'Server'),
        ]),
        const SizedBox(height: 36),
        Text('Listen together,', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.05)),
        const GradientText('from anywhere.', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 12),
        Text('Share the sound of any music app with someone far away. They just enter a code.',
            style: t.bodyLarge?.copyWith(color: muted)),
        const SizedBox(height: 36),
        if (_session.active)
          _ActiveCard(session: _session, onOpen: _openSession)
        else ...[
          GradientButton(label: 'Host a jam', icon: Icons.podcasts_rounded, onTap: _host),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: Divider(color: Palette.ink.withValues(alpha: 0.12))),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or join one', style: TextStyle(color: muted, fontSize: 13))),
            Expanded(child: Divider(color: Palette.ink.withValues(alpha: 0.12))),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(6),
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                ],
                onSubmitted: (_) => _join(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 10),
                decoration: InputDecoration(
                  hintText: 'CODE',
                  hintStyle: TextStyle(color: Palette.ink.withValues(alpha: 0.25), letterSpacing: 10),
                  filled: true,
                  fillColor: Palette.ink.withValues(alpha: 0.07),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Palette.ink.withValues(alpha: 0.10))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Palette.violet, width: 1.6)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(gradient: Palette.brand, borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _join,
                  child: const SizedBox(width: 64, height: 64, child: Icon(Icons.arrow_forward_rounded, size: 28, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.session, required this.onOpen});
  final Session session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glass(),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(gradient: Palette.brand, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.isHost ? 'You are hosting' : 'You are listening',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text('Code ${session.code}', style: TextStyle(color: Palette.ink.withValues(alpha: 0.6))),
          ]),
        ),
        FilledButton(onPressed: onOpen, child: const Text('Open')),
      ]),
    );
  }
}
