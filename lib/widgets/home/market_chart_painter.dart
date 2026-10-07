import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/market_formatters.dart';
import '../../models/market_models.dart';
import '../../models/metal_price.dart';

class MarketChartPainter extends CustomPainter {
  const MarketChartPainter({
    required this.history,
    required this.unit,
    required this.lineColor,
  });

  final List<MetalPrice> history;
  final PriceUnit unit;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points();
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const leftPadding = 53.0;
    const rightPadding = 7.0;
    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final bounds = _ChartBounds.fromPoints(points);
    _drawGrid(canvas, chartRect, bounds);
    final linePath = _linePath(chartRect, bounds, points);

    canvas.save();
    canvas.clipRect(chartRect);
    final areaPath = Path.from(linePath)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = lineColor.withAlpha(34));
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _drawLastPoint(canvas, chartRect, bounds, points.last);
    canvas.restore();
  }

  List<_ChartPoint> _points() {
    final points = history
        .map(
          (entry) => _ChartPoint(
            timestamp: entry.timestamp.toDouble(),
            value: unit == PriceUnit.inr ? entry.pricePerKilo : entry.price,
          ),
        )
        .where((point) => point.value.isFinite)
        .toList();
    points.sort((first, second) => first.timestamp.compareTo(second.timestamp));
    return points;
  }

  Path _linePath(
    Rect chartRect,
    _ChartBounds bounds,
    List<_ChartPoint> points,
  ) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final offset = _offsetFor(chartRect, bounds, point);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    return path;
  }

  void _drawGrid(Canvas canvas, Rect chartRect, _ChartBounds bounds) {
    const gridLineCount = 4;
    final gridPaint = Paint()
      ..color = const Color(0xFF27313D)
      ..strokeWidth = 0.7;

    for (var index = 0; index <= gridLineCount; index++) {
      final progress = index / gridLineCount;
      final y = chartRect.top + (chartRect.height * progress);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        MarketFormatters.chartValue(
          bounds.max - (bounds.range * progress),
          unit,
        ),
        Offset(0, y - 5),
      );
    }
  }

  void _drawLastPoint(
    Canvas canvas,
    Rect chartRect,
    _ChartBounds bounds,
    _ChartPoint point,
  ) {
    final offset = _offsetFor(chartRect, bounds, point);
    canvas.drawCircle(offset, 4, Paint()..color = AppColors.surface);
    canvas.drawCircle(offset, 2.5, Paint()..color = lineColor);
  }

  Offset _offsetFor(Rect rect, _ChartBounds bounds, _ChartPoint point) {
    return Offset(
      rect.left + (rect.width * bounds.normalizedTime(point.timestamp)),
      rect.bottom - (rect.height * bounds.normalizedValue(point.value)),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF7E8997), fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 50);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MarketChartPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.unit != unit ||
        oldDelegate.lineColor != lineColor;
  }
}

class _ChartPoint {
  const _ChartPoint({required this.timestamp, required this.value});

  final double timestamp;
  final double value;
}

class _ChartBounds {
  const _ChartBounds({
    required this.min,
    required this.max,
    required this.firstTimestamp,
    required this.lastTimestamp,
  });

  factory _ChartBounds.fromPoints(List<_ChartPoint> points) {
    final values = points.map((point) => point.value);
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final rawRange = rawMax - rawMin;
    final safeRange = rawRange > 0
        ? rawRange
        : math.max(rawMax.abs() * 0.02, 1);
    final padding = safeRange * 0.15;
    return _ChartBounds(
      min: rawMin - padding,
      max: rawMax + padding,
      firstTimestamp: points.first.timestamp,
      lastTimestamp: points.last.timestamp,
    );
  }

  final double min;
  final double max;
  final double firstTimestamp;
  final double lastTimestamp;

  double get range => max - min;

  double normalizedValue(double value) {
    return ((value - min) / range).clamp(0.0, 1.0).toDouble();
  }

  double normalizedTime(double timestamp) {
    final duration = lastTimestamp - firstTimestamp;
    if (duration <= 0) {
      return 0.5;
    }
    return ((timestamp - firstTimestamp) / duration).clamp(0.0, 1.0).toDouble();
  }
}
