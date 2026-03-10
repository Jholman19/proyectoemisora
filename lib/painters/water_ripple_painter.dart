import 'package:flutter/material.dart';

class WaterRipplePainter extends CustomPainter {
  final double progress;
  WaterRipplePainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 2; i >= 1; i--) {
      final double waveProgress = (progress + (i / 2)) % 1.0;
      final int alpha = ((1.0 - waveProgress) * 255).round();
      final paint = Paint()
        ..color = Colors.purpleAccent.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 110 + (waveProgress * 50), paint);
    }
  }
  @override
  bool shouldRepaint(WaterRipplePainter oldDelegate) => true;
}
