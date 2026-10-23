import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _defaultServer = String.fromEnvironment('SERVER_URL', defaultValue: 'ws://192.168.1.10:8080');

void main() => runApp(const HamJamApp());

class HamJamApp extends StatelessWidget {
  const HamJamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HamJam',
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const HomePage(),
      );
}

class ChatMessage {
  ChatMessage(this.from, this.text);
  final String from; // 'host' | 'guest'
  final String text;
}

/// Mirrors the native session. The native services own the real state and keep
/// running in the background; this is rebuilt from `status` whenever the UI returns.
class Session extends ChangeNotifier {
  Session._() {
    _events.receiveBroadcastStream().listen(_onEvent);
  }
  static final Session instance = Session._();

  static const _method = MethodChannel('hamjam/native');
  static const _events = EventChannel('hamjam/events');
  static const _liveStates = {'connecting', 'capturing', 'connected', 'listening'};

  String role = ''; // '' when there is no active jam
  String state = 'idle';
  String code = '';
  int guests = 0;
  double level = 0;
  final List<ChatMessage> chat = [];

  bool get active => role.isNotEmpty;

  void _onEvent(dynamic e) {
    final m = e as Map;
    if (m['state'] != null) {
      state = m['state'];
      if (!_liveStates.contains(state)) {
        role = '';
        level = 0;
      }
    }
    if (m['code'] != null) code = m['code'];
    if (m['guests'] != null) guests = m['guests'];
    if (m['level'] != null) level = m['level'];
    if (m['chat'] != null) chat.add(_msg(m['chat']));
    notifyListeners();
  }

  ChatMessage _msg(dynamic m) => ChatMessage(m['from'], m['text']);

  Future<void> refresh() async {
    final s = await _method.invokeMapMethod<String, dynamic>('status');
    if (s == null) return;
    role = s['role'];
    state = s['state'];
    code = s['code'];
    guests = s['guests'];
    chat
      ..clear()
      ..addAll((s['chat'] as List).map(_msg));
    notifyListeners();
  }

  Future<bool> host(String url) async {
    final ok = await _method.invokeMethod<bool>('host', {'url': url}) ?? false;
    if (ok) await _begin('host');
    return ok;
  }

  Future<bool> join(String url, String code) async {
    final ok = await _method.invokeMethod<bool>('join', {'url': url, 'code': code}) ?? false;
    if (ok) {
      this.code = code;
      await _begin('guest');
    }
    return ok;
  }

  Future<void> _begin(String r) async {
    role = r;
    state = 'connecting';
    guests = 0;
    level = 0;
    chat.clear();
    notifyListeners();
  }

  Future<void> end() => _method.invokeMethod(role == 'host' ? 'stopHost' : 'leave');
  Future<void> control(String key) => _method.invokeMethod('control', {'key': key});
  Future<void> sendChat(String text) => _method.invokeMethod('chat', {'text': text});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _session = Session.instance;
  final _server = TextEditingController(text: _defaultServer);
  final _code = TextEditingController();
  String? _hint;

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

  void _openSession() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => SessionPage(isHost: _session.role == 'host')));

  Future<void> _host() async {
    final ok = await _session.host(_server.text.trim());
    if (!mounted) return;
    setState(() => _hint = ok ? null : 'Allow the permissions, then tap again.');
    if (ok) _openSession();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) return setState(() => _hint = 'Enter the 6-character code.');
    final ok = await _session.join(_server.text.trim(), code);
    if (!mounted) return;
    setState(() => _hint = ok ? null : 'Allow the permissions, then tap again.');
    if (ok) _openSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HamJam')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (_session.active) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: Text(_session.role == 'host' ? 'You are hosting' : 'You are in a jam'),
              subtitle: Text('Code ${_session.code} · ${_session.state}'),
              trailing: FilledButton(onPressed: _openSession, child: const Text('Open')),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text('Listen together, from anywhere.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: _host, icon: const Icon(Icons.podcasts), label: const Text('Host a jam')),
          const SizedBox(height: 32),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Invite code', border: OutlineInputBorder()),
          ),
          OutlinedButton.icon(
              onPressed: _join, icon: const Icon(Icons.headphones), label: const Text('Join a jam')),
          if (_hint != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_hint!)),
          const SizedBox(height: 32),
          ExpansionTile(
            title: const Text('Server'),
            children: [
              TextField(controller: _server, decoration: const InputDecoration(border: OutlineInputBorder())),
            ],
          ),
        ],
        if (!_session.active && _session.state.isNotEmpty && !const {'idle', 'stopped', 'left'}.contains(_session.state))
          Padding(padding: const EdgeInsets.only(top: 16), child: Text('Last jam: ${_session.state}')),
      ]),
    );
  }
}

class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.isHost});
  final bool isHost;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final _s = Session.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
  }

  @override
  void dispose() {
    _s.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_s.chat.length != _shown) {
      _shown = _s.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _end() async {
    await _s.end();
    if (mounted) Navigator.pop(context);
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _s.sendChat(t);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final live = _s.active;
    final me = widget.isHost ? 'host' : 'guest';
    return Scaffold(
      appBar: AppBar(title: Text(widget.isHost ? 'Hosting' : 'Jam ${_s.code}')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.isHost) ...[
                Row(children: [
                  Text(_s.code.isEmpty ? '······' : _s.code,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 6)),
                  IconButton(
                    onPressed: _s.code.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _s.code));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Code copied')));
                          },
                    icon: const Icon(Icons.copy),
                  ),
                ]),
                Text('${_s.state} · listeners: ${_s.guests}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (_s.level * 4).clamp(0, 1), minHeight: 8),
              ] else ...[
                Text('Status: ${_s.state}'),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(iconSize: 44, onPressed: live ? () => _s.control('previous') : null,
                      icon: const Icon(Icons.skip_previous)),
                  IconButton.filled(iconSize: 52, onPressed: live ? () => _s.control('playPause') : null,
                      icon: const Icon(Icons.play_arrow)),
                  IconButton(iconSize: 44, onPressed: live ? () => _s.control('next') : null,
                      icon: const Icon(Icons.skip_next)),
                ]),
              ],
            ]),
          ),
          const Divider(),
          Expanded(
            child: _s.chat.isEmpty
                ? const Center(child: Text('Chat is live only: nothing is saved.'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _s.chat.length,
                    itemBuilder: (_, i) {
                      final m = _s.chat[i];
                      final mine = m.from == me;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(m.text),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: live,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Message', border: OutlineInputBorder()),
                ),
              ),
              IconButton(onPressed: live ? _send : null, icon: const Icon(Icons.send)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: live ? _end : () => Navigator.pop(context),
                child: Text(live ? (widget.isHost ? 'End jam' : 'Leave jam') : 'Back'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
