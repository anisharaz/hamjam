import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/equalizer.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final _s = Session.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _shown = 0;
  BuildContext? _dialogCtx;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
    _s.toast.addListener(_onToast);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDialog());
  }

  @override
  void dispose() {
    _s.removeListener(_onChange);
    _s.toast.removeListener(_onToast);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onToast() {
    final m = _s.toast.value;
    if (m == null || !mounted) return;
    _s.toast.value = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _syncDialog();
    if (_s.chat.length != _shown) {
      _shown = _s.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  /// Shows/dismisses the "partner wants to switch roles" dialog to match session state.
  void _syncDialog() {
    if (!mounted) return;
    if (_s.swapIn.isNotEmpty && _dialogCtx == null) {
      final fromGuest = _s.swapIn == 'guest';
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          _dialogCtx = ctx;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.swap_horiz_rounded, size: 32, color: Palette.pink),
            title: const Text('Switch roles?'),
            content: Text(fromGuest
                ? 'Your partner wants to host. You will become the listener.'
                : 'Your partner wants you to host. Your phone will share its audio, and you will be asked to allow screen capture.'),
            actions: [
              TextButton(onPressed: () => _answer(false), child: const Text('Decline')),
              FilledButton(onPressed: () => _answer(true), child: const Text('Accept')),
            ],
          );
        },
      ).whenComplete(() => _dialogCtx = null);
    } else if (_s.swapIn.isEmpty && _dialogCtx != null) {
      Navigator.of(_dialogCtx!).pop(); // partner withdrew the request
    }
  }

  void _answer(bool accept) {
    final ctx = _dialogCtx;
    if (ctx != null) Navigator.of(ctx).pop();
    _s.respondSwap(accept);
  }

  Future<void> _confirmEnd() async {
    final host = _s.isHost;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(host ? 'End this jam?' : 'Leave this jam?'),
        content: Text(host ? 'Your listener will be disconnected.' : 'You can rejoin with the same code while it is running.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.danger, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(host ? 'End jam' : 'Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    final live = _s.active;
    return GradientScaffold(
      child: Column(children: [
        _header(live),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: compact
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(children: [
                    if (_s.isHost) _codeCard(),
                    if (_s.isHost) const SizedBox(height: 12),
                    _playerCard(live),
                  ]),
                ),
        ),
        Expanded(child: _chatList(live)),
        _inputBar(live),
      ]),
    );
  }

  Widget _header(bool live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
        Expanded(
          child: Text(_s.isHost ? 'Hosting' : 'Listening',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        StatusChip(state: _s.state),
        if (live)
          PopupMenuButton<String>(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) {
              if (v == 'swap') _s.requestSwap();
              if (v == 'end') _confirmEnd();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'swap',
                enabled: !_s.swapOut,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(_s.isHost ? 'Hand over hosting' : 'Request to host'),
                ),
              ),
              PopupMenuItem(
                value: 'end',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout_rounded, color: Palette.danger),
                  title: Text(_s.isHost ? 'End jam' : 'Leave jam', style: const TextStyle(color: Palette.danger)),
                ),
              ),
            ],
          ),
      ]),
    );
  }

  Widget _codeCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: glass(),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('INVITE CODE',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Palette.ink.withValues(alpha: 0.55))),
            const SizedBox(height: 2),
            GradientText(_s.code.isEmpty ? '······' : _s.code,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 8)),
          ]),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Copy code',
            onPressed: _s.code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _s.code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.headphones_rounded, size: 14),
            const SizedBox(width: 4),
            Text('${_s.guests}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
          ]),
        ]),
      ]),
    );
  }

  Widget _playerCard(bool live) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: glass(radius: 28),
      child: Column(children: [
        Equalizer(level: _s.level, playing: live && _s.playing),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundIcon(icon: Icons.skip_previous_rounded, onTap: live ? () => _s.control('previous') : null),
          const SizedBox(width: 20),
          _PlayPause(playing: _s.playing, onTap: live ? () => _s.control('playPause') : null),
          const SizedBox(width: 20),
          _RoundIcon(icon: Icons.skip_next_rounded, onTap: live ? () => _s.control('next') : null),
        ]),
        if (live) ...[
          const SizedBox(height: 10),
          _swapLine(),
        ],
      ]),
    );
  }

  Widget _swapLine() {
    if (_s.swapOut) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('Waiting for your partner to approve…',
            style: TextStyle(fontSize: 13, color: Palette.ink.withValues(alpha: 0.7))),
      ]);
    }
    return TextButton.icon(
      onPressed: _s.requestSwap,
      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
      label: Text(_s.isHost ? 'Hand over hosting' : 'Request to host'),
    );
  }

  Widget _chatList(bool live) {
    if (_s.chat.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline_rounded, color: Palette.ink.withValues(alpha: 0.25), size: 32),
          const SizedBox(height: 8),
          Text('Live chat. Nothing is saved.', style: TextStyle(color: Palette.ink.withValues(alpha: 0.45))),
        ]),
      );
    }
    final me = _s.isHost ? 'host' : 'guest';
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _s.chat.length,
      itemBuilder: (_, i) {
        final m = _s.chat[i];
        final mine = m.from == me;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
            decoration: BoxDecoration(
              gradient: mine ? Palette.brand : null,
              color: mine ? null : Palette.ink.withValues(alpha: 0.09),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Text(m.text, style: TextStyle(fontSize: 15, color: mine ? Colors.white : Palette.ink)),
          ),
        );
      },
    );
  }

  Widget _inputBar(bool live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: glass(radius: 32),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: live,
              maxLength: 500,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: live ? 'Message' : 'Jam ended',
                hintStyle: TextStyle(color: Palette.ink.withValues(alpha: 0.4)),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Palette.violet),
            onPressed: live ? _send : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ]),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        iconSize: 36,
        onPressed: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        icon: Icon(icon),
      );
}

class _PlayPause extends StatefulWidget {
  const _PlayPause({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback? onTap;
  @override
  State<_PlayPause> createState() => _PlayPauseState();
}

class _PlayPauseState extends State<_PlayPause> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250), value: widget.playing ? 1 : 0);

  @override
  void didUpdateWidget(_PlayPause old) {
    super.didUpdateWidget(old);
    widget.playing ? _c.forward() : _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: Palette.brand,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Palette.violet.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: !enabled
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.onTap!();
                  },
            child: Center(
              child: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _c, size: 38, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
