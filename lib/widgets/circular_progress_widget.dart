import 'dart:math';
import 'package:flutter/material.dart';

class CircularPowerIndicator extends StatelessWidget {
  final double value; // Custom progress (e.g., 0.0 to 1.0)
  final String title;
  final String mainValue;
  final String unit;
  final Color? color;
  final Color? textColor;
  final double diameter;

  const CircularPowerIndicator({
    super.key,
    required this.value,
    required this.title,
    required this.mainValue,
    required this.unit,
    this.color,
    this.textColor,
    this.diameter = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: diameter * 0.9,
            height: diameter * 0.9,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: value,
                activeColor: color ?? Theme.of(context).primaryColor,
                backgroundColor: Colors.grey.withOpacity(0.1),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: textColor != null ? textColor!.withOpacity(0.6) : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    mainValue,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 12.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Background circle (open at bottom)
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Front arc
    final Paint activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Start from bottom left (-225 degrees)
    const double startAngle = -225 * pi / 180;
    const double sweepAngle = 270 * pi / 180; // Total coverage

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Draw active progress
    final double activeSweep = sweepAngle * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
