import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'session_page.dart';

const _defaultServer = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'wss://hamjam.anisharaz.com.np',
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _session = Session.instance;
  final _server = TextEditingController(text: _defaultServer);
  final _code = TextEditingController();
  String _busy = ''; // '', 'host' or 'join': which action is in flight

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

  void _say(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _openSession() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SessionPage()),
  );

  Future<void> _host() async {
    setState(() => _busy = 'host');
    final ok = await _session.host(_server.text.trim()).whenComplete(() {
      if (mounted) setState(() => _busy = '');
    });
    if (!mounted) return;
    ok ? _openSession() : _say('Permission was not granted.');
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) return _say('Enter the 6-character code.');
    FocusScope.of(context).unfocus();
    setState(() => _busy = 'join');
    final ok = await _session.join(_server.text.trim(), code).whenComplete(() {
      if (mounted) setState(() => _busy = '');
    });
    if (!mounted) return;
    if (ok) {
      _code.clear();
      _openSession();
    } else {
      _say('Permission was not granted.');
    }
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server',
              style: Theme.of(ctx).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Address of the HamJam relay. Applies to the next jam.',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(
                hint: 'wss://hamjam.anisharaz.com.np',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idle = _busy.isEmpty;
    return AppScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'HamJam',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _settings,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Server settings',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Listen together,',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const Text(
            'from anywhere.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
              color: Palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Share the sound of any music app with someone far away. They just enter a code.',
            style: TextStyle(fontSize: 16, height: 1.4, color: Palette.muted),
          ),
          const SizedBox(height: 28),
          if (_session.active)
            _ActiveCard(session: _session, onOpen: _openSession)
          else ...[
            _Section(
              title: 'Host a jam',
              subtitle: 'Share the audio playing on this phone.',
              child: PrimaryButton(
                label: 'Start hosting',
                icon: Icons.podcasts_rounded,
                loading: _busy == 'host',
                loadingLabel: 'Starting…',
                onTap: idle ? _host : null,
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Join a jam',
              subtitle: 'Enter the 6-character code your partner shares.',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      enabled: idle,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(6),
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9]'),
                        ),
                        TextInputFormatter.withFunction(
                          (o, n) => n.copyWith(text: n.text.toUpperCase()),
                        ),
                      ],
                      onSubmitted: (_) => idle ? _join() : null,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                      decoration: _fieldDecoration(hint: 'CODE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Material(
                      color: Palette.primary,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                      child: InkWell(
                        onTap: idle ? _join : null,
                        child: Center(
                          child: _busy == 'join'
                              ? const Spinner(size: 22, color: Colors.white)
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(
    color: Palette.ink.withValues(alpha: 0.28),
    fontWeight: FontWeight.w600,
  ),
  filled: true,
  fillColor: Palette.bg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.button),
    borderSide: const BorderSide(color: Palette.border),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.button),
    borderSide: const BorderSide(color: Palette.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.button),
    borderSide: const BorderSide(color: Palette.primary, width: 2),
  ),
);

/// Titled white card holding one action.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Palette.muted)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.session, required this.onOpen});
  final Session session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Palette.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Palette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.isHost ? 'You are hosting' : 'You are listening',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code ${session.code}',
                  style: TextStyle(color: Palette.muted),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: onOpen, child: const Text('Open')),
        ],
      ),
    );
  }
}
