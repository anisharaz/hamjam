import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  static const _liveStates = {
    'connecting',
    'capturing',
    'connected',
    'listening',
  };

  String role = ''; // '' when there is no active jam
  String state = 'idle';
  String code = '';
  int guests = 0;
  bool playing = false;
  String swapIn = ''; // partner asked to switch roles: 'host' | 'guest' | ''
  bool swapOut = false; // we asked and are waiting for an answer
  bool swapBusy = false; // our side of a switch is in progress (permission prompt, handshake)
  final List<ChatMessage> chat = [];

  /// One-shot messages for the UI to show as a snackbar.
  final ValueNotifier<String?> toast = ValueNotifier(null);

  /// Audio level 0..1 (10 Hz). Separate so the equalizer repaints without rebuilding pages.
  final ValueNotifier<double> level = ValueNotifier(0);

  bool get active => role.isNotEmpty;
  bool get isHost => role == 'host';

  void _onEvent(dynamic e) {
    final m = e as Map;
    if (m['level'] != null) {
      level.value = m['level'];
      return;
    }
    if (m['role'] != null) {
      final before = role;
      role = m['role'];
      swapIn = '';
      swapOut = false;
      swapBusy = false;
      if (before.isNotEmpty && before != role) {
        toast.value = role == 'host'
            ? 'You are now the host'
            : 'You are now a listener';
      }
    }
    if (m['swap'] != null) _onSwap(m['swap']);
    if (m['state'] != null) {
      state = m['state'];
      if (!_liveStates.contains(state)) {
        role = '';
        playing = false;
        swapIn = '';
        swapOut = false;
        swapBusy = false;
        level.value = 0;
      }
    }
    if (m['code'] != null) code = m['code'];
    if (m['guests'] != null) guests = m['guests'];
    if (m['playing'] != null) playing = m['playing'];
    if (m['chat'] != null) chat.add(_msg(m['chat']));
    notifyListeners();
  }

  void _onSwap(Map s) {
    switch (s['kind']) {
      case 'request':
        swapIn = s['from'];
      case 'cancelled':
        swapIn = '';
      case 'waiting':
        swapOut = true;
      case 'declined':
        swapOut = false;
        swapBusy = false;
        toast.value = 'Switch request declined';
    }
  }

  ChatMessage _msg(dynamic m) => ChatMessage(m['from'], m['text']);

  Future<void> refresh() async {
    final s = await _method.invokeMapMethod<String, dynamic>('status');
    if (s == null) return;
    role = s['role'];
    state = s['state'];
    code = s['code'];
    guests = s['guests'];
    playing = s['playing'];
    swapIn = s['swapIn'];
    swapOut = s['swapOut'];
    chat
      ..clear()
      ..addAll((s['chat'] as List).map(_msg));
    notifyListeners();
  }

  Future<bool> host(String url) async {
    final ok = await _method.invokeMethod<bool>('host', {'url': url}) ?? false;
    if (ok) _begin('host');
    return ok;
  }

  Future<bool> join(String url, String code) async {
    final ok =
        await _method.invokeMethod<bool>('join', {'url': url, 'code': code}) ??
        false;
    if (ok) {
      this.code = code;
      _begin('guest');
    }
    return ok;
  }

  void _begin(String r) {
    role = r;
    state = 'connecting';
    guests = 0;
    playing = false;
    level.value = 0;
    chat.clear();
    notifyListeners();
  }

  Future<void> end() => _method.invokeMethod(isHost ? 'stopHost' : 'leave');

  /// Guests ask the host's phone; the host controls their own player directly.
  Future<void> control(String key) => isHost
      ? _method.invokeMethod('mediaKey', {'key': key})
      : _method.invokeMethod('control', {'key': key});

  /// Ask to swap roles. Guests are asked for screen-capture consent first.
  Future<bool> requestSwap() async {
    swapBusy = true;
    notifyListeners();
    final ok = await _method.invokeMethod<bool>('swapRequest') ?? false;
    swapBusy = false;
    if (!ok) toast.value = 'Could not start the switch';
    notifyListeners();
    return ok;
  }

  Future<void> respondSwap(bool accept) async {
    swapIn = '';
    swapBusy = accept; // stays on until the roles actually switch (or it fails)
    notifyListeners();
    final ok =
        await _method.invokeMethod<bool>('swapRespond', {'accept': accept}) ??
        false;
    if (accept && !ok) {
      swapBusy = false;
      toast.value = 'Could not switch roles';
      notifyListeners();
    }
  }

  Future<void> sendChat(String text) =>
      _method.invokeMethod('chat', {'text': text});
}
