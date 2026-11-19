import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/engine/engineering_engine.dart';

/// أوضاع عرض مخطط عزوم الانحناء للشريحة
enum MomentDiagramDisplayMode {
  beforeBalancing('قبل الموازنة'),
  afterBalancing('بعد الموازنة'),
  comparison('مقارنة معاً');

  final String labelAr;
  const MomentDiagramDisplayMode(this.labelAr);
}

/// رسّام مخطط عزوم الانحناء للشريحة الإنشائية (قبل الموازنة / بعد الموازنة / مقارنة)
class MomentDiagramPainter extends CustomPainter {
  final SlabDesignReport report;
  final SlabAxisDirection axis;
  final MomentDiagramDisplayMode displayMode;
  final bool isDark;

  MomentDiagramPainter({
    required this.report,
    required this.axis,
    required this.displayMode,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topo = report.topology;
    final initM = report.initialMoments;
    final balM = report.balancedMoments;

    // تحديد الحافتين الطرفيتين للشريحة المختارة
    final EdgeSide startSide =
        axis == SlabAxisDirection.horizontalX ? EdgeSide.left : EdgeSide.top;
    final EdgeSide endSide =
        axis == SlabAxisDirection.horizontalX ? EdgeSide.right : EdgeSide.bottom;
    final double spanM = axis == SlabAxisDirection.horizontalX
        ? topo.widthXM
        : topo.heightYM;

    final bool isShortAxis =
        (topo.isShortSpanHorizontal && axis == SlabAxisDirection.horizontalX) ||
            (!topo.isShortSpanHorizontal &&
                axis == SlabAxisDirection.verticalY);

    // العزوم قبل الموازنة
    final double mMidBefore = isShortAxis ? initM.msxPos : initM.msyPos;
    final double mStartBefore = topo.edgeFor(startSide).isContinuous
        ? (isShortAxis ? initM.msxNeg : initM.msyNeg)
        : 0.0;
    final double mEndBefore = topo.edgeFor(endSide).isContinuous
        ? (isShortAxis ? initM.msxNeg : initM.msyNeg)
        : 0.0;

    // العزوم بعد الموازنة
    final double mMidAfter =
        isShortAxis ? balM.shortMidMomentFinal : balM.longMidMomentFinal;
    final double mStartAfter = balM.supportMomentBySide[startSide] ?? 0.0;
    final double mEndAfter = balM.supportMomentBySide[endSide] ?? 0.0;

    // خلفية اللوحة
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0E1826) : const Color(0xFFFAFBFD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );

    const double padX = 48.0;
    final double x1 = padX;
    final double x2 = size.width - padX;
    final double midX = (x1 + x2) / 2.0;
    final double baseY = size.height * 0.50;

    final double maxMoment = [
      mMidBefore,
      mStartBefore,
      mEndBefore,
      mMidAfter,
      mStartAfter,
      mEndAfter,
      1.0,
    ].reduce(math.max);

    final double maxAmpY = size.height * 0.31;
    double scaleY(double m) => (m / maxMoment) * maxAmpY;

    // خط المرجع الصفري (البلاطة)
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF334155)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(x1 - 14, baseY), Offset(x2 + 14, baseY), basePaint);

    // رسم مثلثات المساند
    _drawSupportTriangle(canvas, Offset(x1, baseY), basePaint.color);
    _drawSupportTriangle(canvas, Offset(x2, baseY), basePaint.color);

    // تسميات الحواف والبحر
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    _drawText(
      canvas,
      '${startSide.titleEn} (${topo.edgeFor(startSide).isContinuous ? "Cont." : "Disc."})',
      Offset(x1, baseY + 22),
      TextStyle(color: labelColor, fontSize: 9.5, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      '${endSide.titleEn} (${topo.edgeFor(endSide).isContinuous ? "Cont." : "Disc."})',
      Offset(x2, baseY + 22),
      TextStyle(color: labelColor, fontSize: 9.5, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      '${report.slabId} — L = ${spanM.toStringAsFixed(2)} m (${axis.symbol}-Axis)',
      Offset(midX, 14),
      TextStyle(
        color: isDark ? Colors.white : AppColors.primary,
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
      ),
    );

    // رسم منحنى "قبل الموازنة" (متقطع رمادي/برتقالي)
    if (displayMode == MomentDiagramDisplayMode.beforeBalancing ||
        displayMode == MomentDiagramDisplayMode.comparison) {
      final beforePath = _buildBmdPath(
        x1: x1,
        x2: x2,
        baseY: baseY,
        yStart: baseY - scaleY(mStartBefore),
        yMid: baseY + scaleY(mMidBefore),
        yEnd: baseY - scaleY(mEndBefore),
      );

      if (displayMode == MomentDiagramDisplayMode.beforeBalancing) {
        final fillPath = Path.from(beforePath)
          ..lineTo(x2, baseY)
          ..lineTo(x1, baseY)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()..color = AppColors.accentAmber.withAlpha(32),
        );
      }

      _drawDashedPath(
        canvas,
        beforePath,
        Paint()
          ..color = AppColors.accentAmber
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              displayMode == MomentDiagramDisplayMode.comparison ? 1.8 : 2.5,
        dashLen: 7,
        gapLen: 4,
      );

      if (displayMode == MomentDiagramDisplayMode.beforeBalancing) {
        _drawMomentBadges(
          canvas,
          x1: x1,
          x2: x2,
          midX: midX,
          baseY: baseY,
          mStart: mStartBefore,
          mMid: mMidBefore,
          mEnd: mEndBefore,
          scaleY: scaleY,
          negColor: AppColors.accentAmber,
          posColor: AppColors.accentAmber,
          prefix: '',
        );
      }
    }

    // رسم منحنى "بعد الموازنة" (متصل واضح مع تظليل)
    if (displayMode == MomentDiagramDisplayMode.afterBalancing ||
        displayMode == MomentDiagramDisplayMode.comparison) {
      final afterPath = _buildBmdPath(
        x1: x1,
        x2: x2,
        baseY: baseY,
        yStart: baseY - scaleY(mStartAfter),
        yMid: baseY + scaleY(mMidAfter),
        yEnd: baseY - scaleY(mEndAfter),
      );

      final fillPath = Path.from(afterPath)
        ..lineTo(x2, baseY)
        ..lineTo(x1, baseY)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()..color = AppColors.rebarBottomX.withAlpha(34),
      );

      canvas.drawPath(
        afterPath,
        Paint()
          ..color = AppColors.rebarBottomX
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );

      _drawMomentBadges(
        canvas,
        x1: x1,
        x2: x2,
        midX: midX,
        baseY: baseY,
        mStart: mStartAfter,
        mMid: mMidAfter,
        mEnd: mEndAfter,
        scaleY: scaleY,
        negColor: AppColors.rebarTopContinuous,
        posColor: AppColors.rebarBottomX,
        prefix: '',
      );
    }

    // في وضع المقارنة: نضع قيم ما قبل الموازنة بخط أصغر بجانب القيم النهائية
    if (displayMode == MomentDiagramDisplayMode.comparison) {
      if ((mStartBefore - mStartAfter).abs() > 0.01) {
        _drawText(
          canvas,
          'قبل: -${mStartBefore.toStringAsFixed(2)}',
          Offset(x1 + 26, baseY - scaleY(mStartBefore) - 18),
          const TextStyle(
            color: AppColors.accentAmber,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
      }
      if ((mEndBefore - mEndAfter).abs() > 0.01) {
        _drawText(
          canvas,
          'قبل: -${mEndBefore.toStringAsFixed(2)}',
          Offset(x2 - 26, baseY - scaleY(mEndBefore) - 18),
          const TextStyle(
            color: AppColors.accentAmber,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
      }
      if ((mMidBefore - mMidAfter).abs() > 0.01) {
        _drawText(
          canvas,
          'قبل: +${mMidBefore.toStringAsFixed(2)}',
          Offset(midX, baseY + scaleY(mMidBefore) - 10),
          const TextStyle(
            color: AppColors.accentAmber,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }
  }

  /// بناء منحنى قطع مكافئ يمر بالثلاث نقاط (x1, yStart), (midX, yMid), (x2, yEnd)
  Path _buildBmdPath({
    required double x1,
    required double x2,
    required double baseY,
    required double yStart,
    required double yMid,
    required double yEnd,
  }) {
    final path = Path()..moveTo(x1, yStart);
    const int segments = 40;
    for (int i = 1; i <= segments; i++) {
      final t = i / segments; // 0..1
      final x = x1 + (x2 - x1) * t;
      // استيفاء لاغرانج التربيعي الدقيق عبر t=0, t=0.5, t=1
      final l0 = (t - 0.5) * (t - 1.0) / ((0.0 - 0.5) * (0.0 - 1.0));
      final l1 = (t - 0.0) * (t - 1.0) / ((0.5 - 0.0) * (0.5 - 1.0));
      final l2 = (t - 0.0) * (t - 0.5) / ((1.0 - 0.0) * (1.0 - 0.5));
      final y = (l0 * yStart) + (l1 * yMid) + (l2 * yEnd);
      path.lineTo(x, y);
    }
    return path;
  }

  void _drawMomentBadges(
    Canvas canvas, {
    required double x1,
    required double x2,
    required double midX,
    required double baseY,
    required double mStart,
    required double mMid,
    required double mEnd,
    required double Function(double) scaleY,
    required Color negColor,
    required Color posColor,
    required String prefix,
  }) {
    if (mStart > 0.001) {
      final pt = Offset(x1, baseY - scaleY(mStart));
      canvas.drawCircle(pt, 3.8, Paint()..color = negColor);
      _drawText(
        canvas,
        '$prefix-${mStart.toStringAsFixed(2)}',
        Offset(x1 + 20, pt.dy - 10),
        TextStyle(color: negColor, fontSize: 10.5, fontWeight: FontWeight.bold),
      );
    }
    if (mEnd > 0.001) {
      final pt = Offset(x2, baseY - scaleY(mEnd));
      canvas.drawCircle(pt, 3.8, Paint()..color = negColor);
      _drawText(
        canvas,
        '$prefix-${mEnd.toStringAsFixed(2)}',
        Offset(x2 - 20, pt.dy - 10),
        TextStyle(color: negColor, fontSize: 10.5, fontWeight: FontWeight.bold),
      );
    }
    final midPt = Offset(midX, baseY + scaleY(mMid));
    canvas.drawCircle(midPt, 3.8, Paint()..color = posColor);
    _drawText(
      canvas,
      '$prefix+${mMid.toStringAsFixed(2)} kN.m/m',
      Offset(midX, midPt.dy + 13),
      TextStyle(color: posColor, fontSize: 11, fontWeight: FontWeight.bold),
    );
  }

  void _drawSupportTriangle(Canvas canvas, Offset apex, Color color) {
    final p = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx - 7, apex.dy + 11)
      ..lineTo(apex.dx + 7, apex.dy + 11)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashLen = 6,
    double gapLen = 4,
  }) {
    for (final metric in path.computeMetrics()) {
      double dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gapLen;
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MomentDiagramPainter oldDelegate) {
    return oldDelegate.report != report ||
        oldDelegate.axis != axis ||
        oldDelegate.displayMode != displayMode ||
        oldDelegate.isDark != isDark;
  }
}
