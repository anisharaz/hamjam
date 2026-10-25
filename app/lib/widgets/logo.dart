import 'package:flutter/material.dart';

import '../theme.dart';

/// The HamJam mark: four rounded bars on a blue tile. Same geometry as the
/// launcher icon and the website logo (64x64 design grid).
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  // x, top, bottom on the 64x64 grid; every bar is 6 wide
  static const _bars = [
    (14.0, 26.0, 38.0),
    (24.0, 18.0, 46.0),
    (34.0, 12.0, 52.0),
    (44.0, 20.0, 44.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(16 * s)),
      Paint()..color = Palette.primary,
    );
    final white = Paint()..color = Colors.white;
    for (final (x, top, bottom) in _bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x * s, top * s, (x + 6) * s, bottom * s),
          Radius.circular(3 * s),
        ),
        white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
