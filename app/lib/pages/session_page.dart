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
  bool _ending = false;

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _syncDialog();
    if (_s.chat.length != _shown) {
      _shown = _s.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
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
            icon: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Palette.tint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 28,
                color: Palette.primary,
              ),
            ),
            title: const Text('Switch roles?', textAlign: TextAlign.center),
            content: Text(
              fromGuest
                  ? 'Your partner wants to host. You will become the listener.'
                  : 'Your partner wants you to host. Your phone will share its audio, and you will be asked to allow screen capture.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => _answer(false),
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: () => _answer(true),
                child: const Text('Accept'),
              ),
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
        title: Text(host ? 'End this jam?' : 'Leave this jam?'),
        content: Text(
          host
              ? 'Your listener will be disconnected.'
              : 'You can rejoin with the same code while the jam is running.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(host ? 'End jam' : 'Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ending = true);
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
    return AppScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              _header(live),
              _progressBar(live),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: compact
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Column(
                          children: [
                            _s.isHost ? _hostCodeCard() : _guestCodeCard(),
                            const SizedBox(height: 12),
                            _playerCard(live),
                          ],
                        ),
                      ),
              ),
              Expanded(child: _chatList()),
              _inputBar(live),
            ],
          ),
          if (_ending)
            Positioned.fill(
              child: ColoredBox(
                color: Palette.bg.withValues(alpha: 0.8),
                child: const Center(child: Spinner(size: 36)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(bool live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              _s.isHost ? 'Hosting' : 'Listening',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          StatusChip(state: _s.state),
          if (live)
            PopupMenuButton<String>(
              tooltip: 'Menu',
              onSelected: (v) {
                if (v == 'swap') _s.requestSwap();
                if (v == 'end') _confirmEnd();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'swap',
                  enabled: !_s.swapOut && !_s.swapBusy,
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 22),
                      const SizedBox(width: 12),
                      Text(_s.isHost ? 'Hand over hosting' : 'Request to host'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'end',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 22,
                        color: Palette.danger,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _s.isHost ? 'End jam' : 'Leave jam',
                        style: const TextStyle(color: Palette.danger),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Thin bar under the header while connecting or switching roles.
  Widget _progressBar(bool live) {
    final busy = live && (_s.state == 'connecting' || _s.swapBusy);
    return SizedBox(
      height: 3,
      child: busy
          ? const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Palette.tint,
            )
          : null,
    );
  }

  Widget _hostCodeCard() {
    final n = _s.guests;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVITE CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Palette.muted,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _s.code.isEmpty ? '······' : _s.code,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 7,
                      color: Palette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 16,
                      color: Palette.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        n == 0
                            ? 'Waiting for someone to join'
                            : (n == 1
                                  ? '1 person listening'
                                  : '$n people listening'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Palette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleButton(
                size: 44,
                tooltip: 'Copy invite link',
                onTap: _s.inviteLink.isEmpty
                    ? null
                    : () => _copy(_s.inviteLink, 'Invite link copied'),
                child: const Icon(
                  Icons.link_rounded,
                  size: 22,
                  color: Palette.primary,
                ),
              ),
              const SizedBox(width: 8),
              CircleButton(
                size: 44,
                tooltip: 'Copy code',
                onTap: _s.code.isEmpty
                    ? null
                    : () => _copy(_s.code, 'Code copied'),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: Palette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guestCodeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded, color: Palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Listening to your partner',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _s.code,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerCard(bool live) {
    // small phones: shrink the visualizer and drop the inline switch link (it stays in the menu)
    final short = MediaQuery.sizeOf(context).height < 680;
    return Container(
      padding: EdgeInsets.fromLTRB(20, short ? 14 : 20, 20, short ? 12 : 12),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          Equalizer(level: _s.level, playing: live && _s.playing),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleButton(
                size: 56,
                tooltip: 'Previous',
                onTap: live ? () => _tap(() => _s.control('previous')) : null,
                child: const Icon(Icons.skip_previous_rounded, size: 30),
              ),
              const SizedBox(width: 20),
              _PlayPause(
                playing: _s.playing,
                onTap: live
                    ? () => _tap(() => _s.control('playPause'), heavy: true)
                    : null,
              ),
              const SizedBox(width: 20),
              CircleButton(
                size: 56,
                tooltip: 'Next',
                onTap: live ? () => _tap(() => _s.control('next')) : null,
                child: const Icon(Icons.skip_next_rounded, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 44, child: Center(child: live ? _swapLine() : null)),
        ],
      ),
    );
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _tap(VoidCallback action, {bool heavy = false}) {
    heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    action();
  }

  Widget _swapLine() {
    if (_s.swapOut || _s.swapBusy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Spinner(size: 14),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _s.swapOut
                  ? 'Waiting for your partner to approve…'
                  : 'Switching roles…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Palette.muted),
            ),
          ),
        ],
      );
    }
    return TextButton.icon(
      onPressed: _s.requestSwap,
      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
      label: Text(_s.isHost ? 'Hand over hosting' : 'Request to host'),
    );
  }

  Widget _chatList() {
    if (_s.chat.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Palette.ink.withValues(alpha: 0.22),
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              'Live chat. Nothing is saved.',
              style: TextStyle(color: Palette.muted),
            ),
          ],
        ),
      );
    }
    final me = _s.isHost ? 'host' : 'guest';
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _s.chat.length,
      itemBuilder: (_, i) {
        final m = _s.chat[i];
        final mine = m.from == me;
        final sameAsPrev = i > 0 && _s.chat[i - 1].from == m.from;
        const r = Radius.circular(Radii.bubble);
        const tail = Radius.circular(5);
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(top: sameAsPrev ? 2 : 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            decoration: BoxDecoration(
              color: mine ? Palette.primary : Palette.tint,
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : tail,
                bottomRight: mine ? tail : r,
              ),
            ),
            child: Text(
              m.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.3,
                color: mine ? Colors.white : Palette.ink,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _inputBar(bool live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Palette.border),
              ),
              child: TextField(
                controller: _input,
                enabled: live,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: live ? 'Message' : 'Jam ended',
                  hintStyle: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleButton(
            size: 48,
            color: Palette.primary,
            tooltip: 'Send',
            onTap: live ? _send : null,
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PlayPause extends StatefulWidget {
  const _PlayPause({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback? onTap;
  @override
  State<_PlayPause> createState() => _PlayPauseState();
}

class _PlayPauseState extends State<_PlayPause>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.playing ? 1 : 0,
  );

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
  Widget build(BuildContext context) => CircleButton(
    size: 76,
    color: Palette.primary,
    elevation: 3,
    tooltip: widget.playing ? 'Pause' : 'Play',
    onTap: widget.onTap,
    child: AnimatedIcon(
      icon: AnimatedIcons.play_pause,
      progress: _c,
      size: 38,
      color: Colors.white,
    ),
  );
}
