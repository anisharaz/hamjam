import 'package:flutter/material.dart';

import '../theme.dart';

/// Page frame: flat light background and safe-area padding.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Palette.bg,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: child),
  );
}

/// Full-width solid button with a built-in loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.loadingLabel,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: onTap == null && !loading ? 0.5 : 1,
      child: Material(
        color: Palette.primary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 56,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Row(
                key: ValueKey(loading),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  loading
                      ? const Spinner(size: 20, color: Colors.white)
                      : Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      loading ? (loadingLabel ?? 'Please wait…') : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Perfectly round tappable button. [child] is usually an Icon.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 52,
    this.color = Palette.tint,
    this.elevation = 0,
    this.tooltip,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final double elevation;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: color,
          elevation: elevation,
          shadowColor: color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Small circular progress indicator with consistent sizing.
class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 18, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: 2.4,
      color: color ?? Palette.primary,
    ),
  );
}

/// Pill showing the connection state, with a pulsing dot when live.
class StatusChip extends StatefulWidget {
  const StatusChip({super.key, required this.state});
  final String state;
  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  (String, Color) get _look => switch (widget.state) {
    'capturing' || 'listening' => ('Live', Palette.live),
    'connected' => ('Waiting for audio', Palette.warn),
    'connecting' => ('Connecting', Palette.warn),
    final s => (_endedLabel(s), Palette.danger),
  };

  static String _endedLabel(String s) => switch (s) {
    'stopped' || 'left' || 'idle' || '' => 'Ended',
    _ => s[0].toUpperCase() + s.substring(1),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _look;
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
