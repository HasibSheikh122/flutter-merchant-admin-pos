// lib/widgets/overview/overview_charts.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class DynamicRevenueChartPainter extends CustomPainter {
  final List<double> monthlyRevenues;
  final Color color;
  final Color labelColor;

  DynamicRevenueChartPainter({
    required this.monthlyRevenues,
    required this.color,
    this.labelColor = const Color(0xFF1E3A1A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (monthlyRevenues.isEmpty) return;

    final double maxRev = monthlyRevenues.reduce(math.max);
    final double safeMax = maxRev > 0 ? maxRev : 1.0;

    final List<Offset> points = [];
    for (int i = 0; i < monthlyRevenues.length; i++) {
      final double x = (i / (monthlyRevenues.length - 1)) * size.width;
      final double normalizedY = (monthlyRevenues[i] / safeMax).clamp(0.0, 1.0);
      final double y = size.height - (normalizedY * (size.height - 22)) - 6;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (var p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 3.8, dotPaint);

      if (monthlyRevenues[i] > 0) {
        final textSpan = TextSpan(
          text: '৳${monthlyRevenues[i].toStringAsFixed(0)}',
          style: TextStyle(
            color: labelColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
          ),
        );
        final tp =
            TextPainter(text: textSpan, textDirection: TextDirection.ltr)
              ..layout();
        tp.paint(
          canvas,
          Offset(
            (p.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
            p.dy - 14,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DynamicRevenueChartPainter oldDelegate) => true;
}

class DynamicDonutChartPainter extends CustomPainter {
  final List<double> shares;
  final List<Color> colors;

  DynamicDonutChartPainter({required this.shares, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 26.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final activeShares = shares.isNotEmpty ? shares : [0.4, 0.3, 0.3];
    double startAngle = -math.pi / 2;

    for (int i = 0; i < activeShares.length; i++) {
      final sweep = activeShares[i] * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DynamicDonutChartPainter oldDelegate) => true;
}