import 'package:flutter/material.dart';

import '../../data/ipa_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Trapezoid geometry helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Maps [VowelHeight] to a Y fraction (0.0 = close/top, ~0.857 = open/bottom).
double vowelHeightToYFraction(VowelHeight height) {
  switch (height) {
    case VowelHeight.close:
      return 0.0;
    case VowelHeight.nearClose:
      return 1.0 / 7.0;
    case VowelHeight.closeMid:
      return 2.0 / 7.0;
    case VowelHeight.mid:
      return 3.0 / 7.0;
    case VowelHeight.openMid:
      return 4.0 / 7.0;
    case VowelHeight.nearOpen:
      return 5.0 / 7.0;
    case VowelHeight.open:
      return 6.0 / 7.0;
  }
}

/// Maps [VowelBackness] to an X fraction within the row (0.0=front, 1.0=back).
double vowelBacknessToXFraction(VowelBackness backness) {
  switch (backness) {
    case VowelBackness.front:
      return 0.0;
    case VowelBackness.nearFront:
      return 0.25;
    case VowelBackness.central:
      return 0.5;
    case VowelBackness.nearBack:
      return 0.75;
    case VowelBackness.back:
      return 1.0;
  }
}

/// Computes the pixel (x, y) position within [size] for a vowel at [height]/[backness].
///
/// The trapezoid:
///   - Left edge is vertical (front vowels always at x=0)
///   - Top edge spans full width (close row from 0 to width)
///   - Bottom edge is shorter on the right (open row from 0 to width*0.55)
///   - Right edge is diagonal connecting (width, 0) to (width*0.55, height)
Offset vowelPosition(
  VowelHeight height,
  VowelBackness backness,
  Size size,
) {
  final yFraction = vowelHeightToYFraction(height);
  final xFraction = vowelBacknessToXFraction(backness);

  final y = yFraction * size.height;

  // Right boundary of the trapezoid row at this y: lerp from width to width*0.55
  final rightBoundary = size.width * (1.0 - 0.45 * yFraction);
  final x = xFraction * rightBoundary;

  return Offset(x, y);
}

// ─────────────────────────────────────────────────────────────────────────────
// VowelTrapezoidPainter
// ─────────────────────────────────────────────────────────────────────────────

/// CustomPainter that draws the standard IPA vowel trapezoid outline and
/// optional horizontal guide lines.
///
/// The caller is responsible for positioning interactive vowel symbols on top
/// via a [Stack] + [Positioned] widgets.
class VowelTrapezoidPainter extends CustomPainter {
  const VowelTrapezoidPainter({
    required this.outlineColor,
    required this.guideColor,
  });

  /// Color of the trapezoid outline strokes.
  final Color outlineColor;

  /// Color of the horizontal guide lines (should be more transparent).
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = outlineColor;

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = guideColor;

    // Trapezoid corners
    const topLeft = Offset(0, 0);
    final topRight = Offset(size.width, 0);
    final bottomLeft = Offset(0, size.height);
    final bottomRight = Offset(size.width * 0.55, size.height);

    // Draw the four edges
    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy) // top edge
      ..lineTo(bottomRight.dx, bottomRight.dy) // right diagonal edge
      ..lineTo(bottomLeft.dx, bottomLeft.dy) // bottom edge
      ..lineTo(topLeft.dx, topLeft.dy); // left vertical edge
    canvas.drawPath(path, outlinePaint);

    // Horizontal guide lines at each VowelHeight level (skip topmost — that's the top edge)
    for (final height in VowelHeight.values) {
      final yFraction = vowelHeightToYFraction(height);
      if (yFraction == 0.0) continue; // already drawn as top edge

      final y = yFraction * size.height;
      final rightBoundary = size.width * (1.0 - 0.45 * yFraction);
      canvas.drawLine(Offset(0, y), Offset(rightBoundary, y), guidePaint);
    }
  }

  @override
  bool shouldRepaint(VowelTrapezoidPainter oldDelegate) =>
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.guideColor != guideColor;
}
