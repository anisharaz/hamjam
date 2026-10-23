import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Mirrored bar visualizer. Bar height follows the real audio level; each bar
/// gets its own gentle wobble so it looks like a spectrum. Flat colour, no gradient.
class Equalizer extends StatefulWidget {
  const Equalizer({
    super.key,
    required this.level,
    required this.playing,
    this.height = 96,
  });
  final ValueListenable<double> level;
  final bool playing;
  final double height;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer>
    with SingleTickerProviderStateMixin {
  static const _bars = 30;
  final _v = List<double>.filled(_bars, 0.05);
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addListener(_step)
        ..repeat();

  void _step() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final lvl = (widget.level.value * 4.5).clamp(0.0, 1.0);
    for (var i = 0; i < _bars; i++) {
      final wobble = (math.sin(t * (2.2 + (i % 5) * 0.55) + i * 1.7) + 1) / 2;
      // centre bars react more, like a real spectrum
      final centre = 1 - ((i - _bars / 2).abs() / (_bars / 2)) * 0.55;
      final target = widget.playing
          ? 0.07 + 0.93 * lvl * (0.3 + 0.7 * wobble) * centre
          : 0.05;
      _v[i] += (target - _v[i]) * 0.28;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: CustomPaint(
      painter: _BarsPainter(_v, () => widget.playing, _ticker),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.v, this.playing, Listenable repaint)
    : super(repaint: repaint);
  final List<double> v;
  final ValueGetter<bool> playing;

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    final slot = size.width / n;
    final w = slot * 0.56;
    // idle bars are drawn pale so a paused jam looks calm
    final paint = Paint()
      ..color = playing()
          ? Palette.primary
          : Palette.primary.withValues(alpha: 0.28);
    for (var i = 0; i < n; i++) {
      final h = math.max(w, v[i] * size.height);
      final x = i * slot + (slot - w) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + w / 2, size.height / 2),
            width: w,
            height: h,
          ),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => false; // repaints via the ticker
}
