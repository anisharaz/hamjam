import 'package:flutter/material.dart';

import '../theme.dart';

/// Page background: deep violet fading to near-black, with a soft pink glow.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.bgTop, Palette.bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Palette.pink.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: SafeArea(child: child),
          ),
        ],
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
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
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: Palette.brand,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Palette.violet.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Row(
                  key: ValueKey(loading),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    loading
                        ? const Spinner(size: 22, color: Colors.white)
                        : Icon(icon, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      loading ? (loadingLabel ?? 'Please wait…') : label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      color: color ?? Palette.violet,
    ),
  );
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (r) => Palette.brand.createShader(r),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

/// Small pill showing the connection state, with a pulsing dot when live.
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
    'stopped' || 'left' => 'Ended',
    _ => s.isEmpty ? 'Ended' : s[0].toUpperCase() + s.substring(1),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _look;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
