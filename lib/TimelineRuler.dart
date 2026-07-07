import 'package:flutter/material.dart';

class TimeRuler extends StatelessWidget {
  final double canvasOffsetY;   // viewPortState.y
  final double zoom;            // viewPortState.zoom
  final DateTime epoch;         // what date is canvas Y=0
  final double pxPerHour;       // how many canvas px = 1 hour

  const TimeRuler({
    super.key,
    required this.canvasOffsetY,
    required this.zoom,
    required this.epoch,
    required this.pxPerHour,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: CustomPaint(
        painter: _RulerPainter(
          canvasOffsetY: canvasOffsetY,
          zoom: zoom,
          epoch: epoch,
          pxPerHour: pxPerHour,
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double canvasOffsetY;
  final double zoom;
  final DateTime epoch;
  final double pxPerHour;

  _RulerPainter({
    required this.canvasOffsetY,
    required this.zoom,
    required this.epoch,
    required this.pxPerHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.shade300..strokeWidth = 1;
    final textStyle = TextStyle(color: Colors.grey.shade700, fontSize: 10);

    // how many screen px per hour at current zoom
    final screenPxPerHour = pxPerHour * zoom;

    // what hour is at the top of the screen
    final topHourFrac = -canvasOffsetY / (pxPerHour); // canvas coords
    
    // pick tick interval based on zoom
    final int tickIntervalHours = screenPxPerHour > 80 ? 1
        : screenPxPerHour > 30 ? 6
        : screenPxPerHour > 10 ? 24
        : 24 * 7;

    // first tick above screen top
    final firstTick = (topHourFrac / tickIntervalHours).floor() * tickIntervalHours;

    for (int i = 0; i < 200; i++) {
      final tickHour = firstTick + i * tickIntervalHours;
      final screenY = (tickHour - topHourFrac) * screenPxPerHour;
      if (screenY > size.height) break;

      final date = epoch.add(Duration(hours: tickHour));
      final isMidnight = date.hour == 0;

      canvas.drawLine(
        Offset(isMidnight ? 0 : 30, screenY),
        Offset(60, screenY),
        paint..strokeWidth = isMidnight ? 1.5 : 0.8,
      );

      if (isMidnight || tickIntervalHours >= 24) {
        final label = '${date.month}/${date.day}';
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(0, screenY - 6));
      } else {
        final label = '${date.hour}:00';
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 28);
        tp.paint(canvas, Offset(0, screenY - 6));
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.canvasOffsetY != canvasOffsetY || old.zoom != zoom;
}