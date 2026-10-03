import 'dart:math';

import 'package:flutter/material.dart';

/// Animated cup showing the water level. Waves move while the pump runs.
class CupView extends StatefulWidget {
  final int level; // 0..100
  final bool cupPresent;
  final bool pumping;

  const CupView({super.key, required this.level, required this.cupPresent, required this.pumping});

  @override
  State<CupView> createState() => _CupViewState();
}

class _CupViewState extends State<CupView> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.cupPresent ? widget.level / 100 : 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, fill, _) => AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => CustomPaint(
          size: const Size(180, 210),
          painter: _CupPainter(
            fill: fill,
            phase: _wave.value * 2 * pi,
            waveHeight: widget.pumping ? 5 : 1.5,
            glass: widget.cupPresent ? scheme.onSurface.withOpacity(.55) : scheme.outline.withOpacity(.35),
            water: const Color(0xFF2E9BF0),
            dashed: !widget.cupPresent,
          ),
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  final double fill, phase, waveHeight;
  final Color glass, water;
  final bool dashed;

  _CupPainter({
    required this.fill,
    required this.phase,
    required this.waveHeight,
    required this.glass,
    required this.water,
    required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const inset = 22.0; // cup is narrower at the bottom
    final cup = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - inset, h)
      ..lineTo(inset, h)
      ..close();

    // Water
    if (fill > 0.001) {
      final top = h * (1 - fill.clamp(0.0, 1.0));
      final waterPath = Path()..moveTo(0, h);
      for (double x = 0; x <= w; x += 4) {
        waterPath.lineTo(x, top + sin(x / w * 2 * pi + phase) * waveHeight);
      }
      waterPath
        ..lineTo(w, h)
        ..close();
      canvas.save();
      canvas.clipPath(cup);
      canvas.drawPath(
        waterPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [water.withOpacity(.75), water],
          ).createShader(Offset.zero & size),
      );
      canvas.restore();
    }

    // Glass outline (dashed when no cup is on the switch)
    final stroke = Paint()
      ..color = glass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    if (!dashed) {
      canvas.drawPath(cup, stroke);
    } else {
      for (final metric in cup.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 16) {
          canvas.drawPath(metric.extractPath(d, d + 9), stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CupPainter old) =>
      old.fill != fill || old.phase != phase || old.glass != glass || old.dashed != dashed;
}
