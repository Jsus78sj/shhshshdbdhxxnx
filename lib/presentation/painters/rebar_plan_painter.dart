import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/engine/engineering_engine.dart';

/// حالة إظهار أو إخفاء طبقات التسليح على المسقط الأفقي للبلاطة
class RebarLayerVisibility {
  final bool showBottomShort;
  final bool showBottomLong;
  final bool showTopContinuous;
  final bool showTopDiscontinuous;
  final bool showCornerTorsion;

  const RebarLayerVisibility({
    this.showBottomShort = true,
    this.showBottomLong = true,
    this.showTopContinuous = true,
    this.showTopDiscontinuous = true,
    this.showCornerTorsion = true,
  });

  RebarLayerVisibility copyWith({
    bool? showBottomShort,
    bool? showBottomLong,
    bool? showTopContinuous,
    bool? showTopDiscontinuous,
    bool? showCornerTorsion,
  }) {
    return RebarLayerVisibility(
      showBottomShort: showBottomShort ?? this.showBottomShort,
      showBottomLong: showBottomLong ?? this.showBottomLong,
      showTopContinuous: showTopContinuous ?? this.showTopContinuous,
      showTopDiscontinuous: showTopDiscontinuous ?? this.showTopDiscontinuous,
      showCornerTorsion: showCornerTorsion ?? this.showCornerTorsion,
    );
  }
}

/// رسّام المسقط الأفقي لتفاصيل حديد التسليح للبلاطة المصمتة (Rebar Plan Sketch)
class RebarPlanPainter extends CustomPainter {
  final SlabDesignReport report;
  final RebarLayerVisibility layers;
  final bool useLectureNotation;
  final bool isDark;

  RebarPlanPainter({
    required this.report,
    required this.layers,
    required this.useLectureNotation,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topo = report.topology;
    final summary = report.summaryRow;

    // خلفية هندسية
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()
        ..color = isDark ? const Color(0xFF0E1826) : const Color(0xFFFAFBFD),
    );

    const double padX = 56.0;
    const double padY = 48.0;
    final double availW = size.width - (2 * padX);
    final double availH = size.height - (2 * padY);

    // الكوابيل المتصلة تُرسم خارج حدود البلاطة فتدخل في مقياس الرسم وتوسيط المسقط
    final double cantL = _cantileverLengthM(EdgeSide.left);
    final double cantR = _cantileverLengthM(EdgeSide.right);
    final double cantT = _cantileverLengthM(EdgeSide.top);
    final double cantB = _cantileverLengthM(EdgeSide.bottom);

    final double scale = math.min(
      availW / (topo.widthXM + cantL + cantR),
      availH / (topo.heightYM + cantT + cantB),
    );
    final double rectW = topo.widthXM * scale;
    final double rectH = topo.heightYM * scale;
    final Rect slabRect = Rect.fromCenter(
      center: Offset(
        size.width / 2 + (cantL - cantR) * scale / 2,
        size.height / 2 + (cantT - cantB) * scale / 2,
      ),
      width: rectW,
      height: rectH,
    );

    // 1. تعبئة جسم البلاطة وحدود الكمرات
    canvas.drawRect(
      slabRect,
      Paint()
        ..color = isDark ? const Color(0xFF132538) : const Color(0xFFF0F7FF),
    );
    final beamPaint = Paint()
      ..color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(slabRect, beamPaint);
    canvas.drawRect(
      slabRect.deflate(4),
      Paint()
        ..color = beamPaint.color.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // 1-ب. الكوابيل المتصلة (مستطيل الكابولي + حديد التوزيع + بياناته)
    _drawCantilevers(canvas, slabRect, scale);

    // 2. تسليح الالتواء عند الأركان (Corner Torsion Mesh)
    if (layers.showCornerTorsion && report.torsionDetail.isRequired) {
      final double cornerLenPx = (topo.shortSpanLxM / 5.0) * scale;
      final cornerEdges = [
        (topo.topEdge, topo.leftEdge, Offset(slabRect.left, slabRect.top), 1.0, 1.0),
        (topo.topEdge, topo.rightEdge, Offset(slabRect.right, slabRect.top), -1.0, 1.0),
        (topo.bottomEdge, topo.leftEdge, Offset(slabRect.left, slabRect.bottom), 1.0, -1.0),
        (topo.bottomEdge, topo.rightEdge, Offset(slabRect.right, slabRect.bottom), -1.0, -1.0),
      ];
      const torsionColor = Color(0xFF7C3AED);
      for (final (e1, e2, origin, dxSign, dySign) in cornerEdges) {
        if (e1.isDiscontinuous || e2.isDiscontinuous) {
          final r = Rect.fromPoints(
            origin,
            Offset(
              origin.dx + dxSign * cornerLenPx,
              origin.dy + dySign * cornerLenPx,
            ),
          );
          canvas.drawRect(r, Paint()..color = torsionColor.withAlpha(35));
          canvas.drawRect(
            r,
            Paint()
              ..color = torsionColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
          _drawText(
            canvas,
            'T',
            r.center,
            const TextStyle(
              color: torsionColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
        }
      }
    }

    // النصوص الخاصة بكل طبقة
    final shortMidLabel = useLectureNotation
        ? summary.shortMidLecture
        : summary.shortMidSpacing;
    final longMidLabel = useLectureNotation
        ? summary.longMidLecture
        : summary.longMidSpacing;

    // 3. الفرش السفلي (الاتجاه القصير — Bottom Short)
    if (layers.showBottomShort) {
      final p = Paint()
        ..color = AppColors.rebarBottomX
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      if (topo.isShortSpanHorizontal) {
        final y = slabRect.center.dy - 14;
        _drawRebarWithTicks(
          canvas,
          Offset(slabRect.left + 8, y),
          Offset(slabRect.right - 8, y),
          p,
          isHorizontal: true,
        );
        _drawBadge(
          canvas,
          'B1 (X): $shortMidLabel',
          Offset(slabRect.center.dx, y - 14),
          AppColors.rebarBottomX,
        );
      } else {
        final x = slabRect.center.dx - 16;
        _drawRebarWithTicks(
          canvas,
          Offset(x, slabRect.top + 8),
          Offset(x, slabRect.bottom - 8),
          p,
          isHorizontal: false,
        );
        _drawBadge(
          canvas,
          'B1 (Y): $shortMidLabel',
          Offset(x, slabRect.center.dy - 16),
          AppColors.rebarBottomX,
        );
      }
    }

    // 4. الغطاء السفلي (الاتجاه الطويل — Bottom Long)
    if (layers.showBottomLong) {
      final p = Paint()
        ..color = AppColors.rebarBottomY
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      if (topo.isShortSpanHorizontal) {
        final x = slabRect.center.dx + 16;
        _drawRebarWithTicks(
          canvas,
          Offset(x, slabRect.top + 8),
          Offset(x, slabRect.bottom - 8),
          p,
          isHorizontal: false,
        );
        _drawBadge(
          canvas,
          'B2 (Y): $longMidLabel',
          Offset(x, slabRect.center.dy + 20),
          AppColors.rebarBottomY,
        );
      } else {
        final y = slabRect.center.dy + 16;
        _drawRebarWithTicks(
          canvas,
          Offset(slabRect.left + 8, y),
          Offset(slabRect.right - 8, y),
          p,
          isHorizontal: true,
        );
        _drawBadge(
          canvas,
          'B2 (X): $longMidLabel',
          Offset(slabRect.center.dx, y + 14),
          AppColors.rebarBottomY,
        );
      }
    }

    // 5. الحديد العلوي على الحواف الأربع (مستمرة 0.3L أو غير مستمرة 0.15L)
    for (final side in EdgeSide.values) {
      final cond = topo.edgeFor(side);
      final bool isCont = cond.isContinuous;
      if (isCont && !layers.showTopContinuous) continue;
      if (!isCont && !layers.showTopDiscontinuous) continue;

      final bool isHorizontalBar =
          side == EdgeSide.left || side == EdgeSide.right;
      // وسم كل حافة بتصميمها الخاص: المستمرة/الكابولي بحديد المسند المستمر، وغير المستمرة
      // بقاعدة 50% As,mid ≥ As,min (حتى لو كان الاتجاه مختلطاً: حافة مستمرة + حافة غير مستمرة).
      final String label =
          report.topLabelForEdge(side, lecture: useLectureNotation);
      final Color barColor = isCont
          ? AppColors.rebarTopContinuous
          : AppColors.rebarTopDiscontinuous;

      final double extFactor = isCont ? 0.30 : 0.15;
      final double alongPx = isHorizontalBar ? slabRect.width : slabRect.height;
      double extPx = alongPx * extFactor;

      // حافة الكابولي: يبدأ الحديد العلوي من طرف الكابولي الحر، ويمتد داخل البلاطة
      // بما لا يقل عن 1.5 lc (وفق الشرح) وبما لا يقل عن 0.3 l.
      final CantileverAttachment? cant = report.cantilevers[side];
      if (cant != null) {
        extPx = math.min(
          math.max(extPx, cant.anchorExtensionInsideSlabM * scale),
          alongPx * 0.95,
        );
      }
      final double outward =
          cant != null ? math.max(cant.lengthM * scale - 6.0, 0.0) : (isCont ? 14.0 : 0.0);
      final String tag = cant != null ? 'CT' : 'T';
      final double extM = extPx / scale;

      final paint = Paint()
        ..color = barColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      switch (side) {
        case EdgeSide.top:
          final xPos = slabRect.center.dx - 28;
          _drawDashedLine(
            canvas,
            Offset(xPos, slabRect.top - outward),
            Offset(xPos, slabRect.top + extPx),
            paint,
          );
          _drawBadge(
            canvas,
            '$tag: $label (${extM.toStringAsFixed(2)}m)',
            Offset(slabRect.center.dx, slabRect.top + 14),
            barColor,
          );
        case EdgeSide.bottom:
          final xPos = slabRect.center.dx - 28;
          _drawDashedLine(
            canvas,
            Offset(xPos, slabRect.bottom + outward),
            Offset(xPos, slabRect.bottom - extPx),
            paint,
          );
          _drawBadge(
            canvas,
            '$tag: $label (${extM.toStringAsFixed(2)}m)',
            Offset(slabRect.center.dx, slabRect.bottom - 14),
            barColor,
          );
        case EdgeSide.left:
          final yPos = slabRect.center.dy + 22;
          _drawDashedLine(
            canvas,
            Offset(slabRect.left - outward, yPos),
            Offset(slabRect.left + extPx, yPos),
            paint,
          );
          _drawBadge(
            canvas,
            '$tag: $label',
            Offset(slabRect.left + math.max(extPx / 2, 34), yPos - 13),
            barColor,
          );
        case EdgeSide.right:
          final yPos = slabRect.center.dy + 22;
          _drawDashedLine(
            canvas,
            Offset(slabRect.right + outward, yPos),
            Offset(slabRect.right - extPx, yPos),
            paint,
          );
          _drawBadge(
            canvas,
            '$tag: $label',
            Offset(slabRect.right - math.max(extPx / 2, 34), yPos - 13),
            barColor,
          );
      }
    }

    // 6. الأبعاد الخارجية وتسميات الحواف
    final dimColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    _drawText(
      canvas,
      '${topo.topEdge.isContinuous ? "مستمرة (Continuous)" : "غير مستمرة"} • X = ${topo.widthXM.toStringAsFixed(2)} m',
      Offset(slabRect.center.dx, slabRect.top - 22 - cantT * scale),
      TextStyle(color: dimColor, fontSize: 10, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      '${topo.bottomEdge.isContinuous ? "مستمرة (Continuous)" : "غير مستمرة"} • h = ${report.loadResult.overallDepthHMm.toStringAsFixed(0)} mm',
      Offset(slabRect.center.dx, slabRect.bottom + 24 + cantB * scale),
      TextStyle(color: dimColor, fontSize: 10, fontWeight: FontWeight.bold),
    );
    if (cantL <= 0) {
      _drawText(
        canvas,
        'Y=${topo.heightYM.toStringAsFixed(2)}m\n${topo.leftEdge.isContinuous ? "Cont." : "Disc."}',
        Offset(slabRect.left - 28, slabRect.center.dy),
        TextStyle(color: dimColor, fontSize: 9, fontWeight: FontWeight.bold),
      );
    }
    if (cantR <= 0) {
      _drawText(
        canvas,
        '${topo.rightEdge == EdgeCondition.discontinuousDropped ? "Dropped" : (topo.rightEdge.isContinuous ? "Cont." : "Disc.")}',
        Offset(slabRect.right + 28, slabRect.center.dy),
        TextStyle(color: dimColor, fontSize: 9, fontWeight: FontWeight.bold),
      );
    }
  }

  /// طول الكابولي المتصل بحافة معينة (0 إن لم يوجد)
  double _cantileverLengthM(EdgeSide side) =>
      report.cantilevers[side]?.lengthM ?? 0.0;

  /// رسم الكوابيل خارج حدود البلاطة: المستطيل، حديد التوزيع (موازٍ للمسند)، وبيانات الكابولي.
  /// الحديد العلوي الرئيسي (عمودي على المسند) يُرسم مع حديد حواف البلاطة في الخطوة 5.
  void _drawCantilevers(Canvas canvas, Rect slabRect, double scale) {
    const Color cantColor = Color(0xFF64748B);
    for (final entry in report.cantilevers.entries) {
      final EdgeSide side = entry.key;
      final CantileverAttachment cant = entry.value;
      final CantileverDesignReport? cr = report.cantileverReports[side];
      final double lenPx = cant.lengthM * scale;
      if (lenPx <= 0) continue;

      final Rect r;
      switch (side) {
        case EdgeSide.left:
          r = Rect.fromLTRB(
              slabRect.left - lenPx, slabRect.top, slabRect.left, slabRect.bottom);
        case EdgeSide.right:
          r = Rect.fromLTRB(
              slabRect.right, slabRect.top, slabRect.right + lenPx, slabRect.bottom);
        case EdgeSide.top:
          r = Rect.fromLTRB(
              slabRect.left, slabRect.top - lenPx, slabRect.right, slabRect.top);
        case EdgeSide.bottom:
          r = Rect.fromLTRB(
              slabRect.left, slabRect.bottom, slabRect.right, slabRect.bottom + lenPx);
      }

      canvas.drawRect(r, Paint()..color = cantColor.withAlpha(32));
      canvas.drawRect(
        r,
        Paint()
          ..color = cantColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      // حديد التوزيع (As,min) موازٍ للمسند في منتصف عرض الكابولي
      final bool supportIsVerticalLine =
          side == EdgeSide.left || side == EdgeSide.right;
      final Paint distPaint = Paint()
        ..color = AppColors.rebarBottomY
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      if (supportIsVerticalLine) {
        final double x = r.center.dx;
        canvas.drawLine(Offset(x, r.top + 8), Offset(x, r.bottom - 8), distPaint);
      } else {
        final double y = r.center.dy;
        canvas.drawLine(Offset(r.left + 8, y), Offset(r.right - 8, y), distPaint);
      }

      final List<String> lines = ['Cant. L=${cant.lengthM.toStringAsFixed(2)}m'];
      if (cr != null) {
        lines.add('M=${cr.supportMomentKnM.toStringAsFixed(2)}');
        final String distLabel = useLectureNotation
            ? cr.distributionSteel.barCountSelection.lectureNotation
            : (cr.distributionSteel.barSpacingSelection?.standardNotation ??
                cr.distributionSteel.barCountSelection.lectureNotation);
        lines.add('Dist: $distLabel');
        if (!cr.deflectionCheck.isSafe) {
          final double? h = cr.deflectionCheck.suggestedOverallDepthHMm;
          lines.add('Defl X h>=${h == null ? "-" : h.toStringAsFixed(0)}');
        }
        if (!cr.shearCheck.isSafe) lines.add('Shear X');
      }
      _drawText(
        canvas,
        lines.join('\n'),
        Offset(r.center.dx, r.center.dy - (supportIsVerticalLine ? 28 : 0)),
        TextStyle(
          color: (cr != null && !cr.overallIsSafe)
              ? AppColors.dangerRed
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  void _drawRebarWithTicks(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required bool isHorizontal,
  }) {
    canvas.drawLine(start, end, paint);
    // عكفات طرفية صغيرة (End Hooks)
    const hook = 7.0;
    if (isHorizontal) {
      canvas.drawLine(start, Offset(start.dx, start.dy - hook), paint);
      canvas.drawLine(end, Offset(end.dx, end.dy - hook), paint);
    } else {
      canvas.drawLine(start, Offset(start.dx + hook, start.dy), paint);
      canvas.drawLine(end, Offset(end.dx + hook, end.dy), paint);
    }
    // دائرة منتصف السيخ
    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    canvas.drawCircle(mid, 3.2, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final total = (p2 - p1).distance;
    if (total < 1) return;
    final dir = (p2 - p1) / total;
    double d = 0;
    while (d < total) {
      final endD = math.min(d + 6.0, total);
      canvas.drawLine(p1 + dir * d, p1 + dir * endD, paint);
      d = endD + 4.0;
    }
    canvas.drawCircle(p2, 2.5, Paint()..color = paint.color);
  }

  void _drawBadge(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()
        ..color = (isDark ? const Color(0xFF0B131E) : Colors.white)
            .withAlpha(230),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()
        ..color = color.withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
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
  bool shouldRepaint(covariant RebarPlanPainter oldDelegate) {
    return oldDelegate.report != report ||
        oldDelegate.layers != layers ||
        oldDelegate.useLectureNotation != useLectureNotation ||
        oldDelegate.isDark != isDark;
  }
}
