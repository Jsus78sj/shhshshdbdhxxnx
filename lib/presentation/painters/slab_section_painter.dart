import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/engine/engineering_engine.dart';

/// رسّام القطاعات العرضية الإنشائية (Section X-X و Section Y-Y)
/// يوضح سماكة البلاطة h، الكمرات الطرفية، الهبوط عند البلاطة المهبطة، الكابولي، وأطوال التوقف 0.3L / 0.15L
class SlabSectionPainter extends CustomPainter {
  final SlabDesignReport report;
  final SlabAxisDirection axis;
  final bool useLectureNotation;
  final bool isDark;

  SlabSectionPainter({
    required this.report,
    required this.axis,
    required this.useLectureNotation,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topo = report.topology;
    final summary = report.summaryRow;

    final EdgeSide startSide =
        axis == SlabAxisDirection.horizontalX ? EdgeSide.left : EdgeSide.top;
    final EdgeSide endSide =
        axis == SlabAxisDirection.horizontalX ? EdgeSide.right : EdgeSide.bottom;
    final EdgeCondition startCond = topo.edgeFor(startSide);
    final EdgeCondition endCond = topo.edgeFor(endSide);

    final double spanM = axis == SlabAxisDirection.horizontalX
        ? topo.widthXM
        : topo.heightYM;

    final bool isShortAxis =
        (topo.isShortSpanHorizontal && axis == SlabAxisDirection.horizontalX) ||
            (!topo.isShortSpanHorizontal &&
                axis == SlabAxisDirection.verticalY);

    final String bottomLabel = isShortAxis
        ? (useLectureNotation ? summary.shortMidLecture : summary.shortMidSpacing)
        : (useLectureNotation ? summary.longMidLecture : summary.longMidSpacing);
    // كل طرف بتصميمه الخاص: الحافة المستمرة (أو الكابولي) بحديد المسند، وغير المستمرة بقاعدة
    // 50% As,mid ≥ As,min، حتى في الاتجاه المختلط (طرف مستمر + طرف غير مستمر).
    final String startTopLabel =
        report.topLabelForEdge(startSide, lecture: useLectureNotation);
    final String endTopLabel =
        report.topLabelForEdge(endSide, lecture: useLectureNotation);

    // خلفية القطاع
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()
        ..color = isDark ? const Color(0xFF0E1826) : const Color(0xFFFAFBFD),
    );

    final double slabTopY = size.height * 0.34;
    const double slabH = 34.0;
    final double slabBotY = slabTopY + slabH;
    const double beamW = 24.0;
    const double beamDrop = 40.0;

    final double leftBeamX = 56.0;
    final double rightBeamX = size.width - 56.0 - beamW;
    final double innerLeftX = leftBeamX + beamW;
    final double innerRightX = rightBeamX;
    final double clearSpanPx = innerRightX - innerLeftX;

    final concreteFill = Paint()
      ..color = isDark ? const Color(0xFF223449) : const Color(0xFFE2E8F0);
    final concreteStroke = Paint()
      ..color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // 1. رسم البلاطة الرئيسية وكمرتي الاستناد
    final mainPath = Path()
      ..moveTo(leftBeamX, slabTopY)
      ..lineTo(rightBeamX + beamW, slabTopY)
      ..lineTo(rightBeamX + beamW, slabBotY + beamDrop)
      ..lineTo(rightBeamX, slabBotY + beamDrop)
      ..lineTo(rightBeamX, slabBotY)
      ..lineTo(innerLeftX, slabBotY)
      ..lineTo(innerLeftX, slabBotY + beamDrop)
      ..lineTo(leftBeamX, slabBotY + beamDrop)
      ..close();

    canvas.drawPath(mainPath, concreteFill);
    canvas.drawPath(mainPath, concreteStroke);

    // 2. رسم الامتدادات المجاورة (مستمرة، كابولي، أو بلاطة مهبطة Dropped Slab)
    _drawAdjacentExtension(
      canvas,
      condition: startCond,
      isLeft: true,
      beamEdgeX: leftBeamX,
      slabTopY: slabTopY,
      slabH: slabH,
      concreteFill: concreteFill,
      concreteStroke: concreteStroke,
    );
    _drawAdjacentExtension(
      canvas,
      condition: endCond,
      isLeft: false,
      beamEdgeX: rightBeamX + beamW,
      slabTopY: slabTopY,
      slabH: slabH,
      concreteFill: concreteFill,
      concreteStroke: concreteStroke,
    );

    // 3. الحديد السفلي الرئيسي (خط متصل + نقاط التوزيع العرضي)
    final double botBarY = slabBotY - 7.0;
    final botColor =
        isShortAxis ? AppColors.rebarBottomX : AppColors.rebarBottomY;
    final botPaint = Paint()
      ..color = botColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftBeamX + 6, botBarY),
      Offset(rightBeamX + beamW - 6, botBarY),
      botPaint,
    );
    // عكفات طرفية داخل الكمرتين
    canvas.drawLine(
      Offset(leftBeamX + 6, botBarY),
      Offset(leftBeamX + 6, botBarY - 12),
      botPaint,
    );
    canvas.drawLine(
      Offset(rightBeamX + beamW - 6, botBarY),
      Offset(rightBeamX + beamW - 6, botBarY - 12),
      botPaint,
    );

    // نقاط حديد الاتجاه العمودي
    final dotColor =
        isShortAxis ? AppColors.rebarBottomY : AppColors.rebarBottomX;
    for (int i = 1; i <= 7; i++) {
      final dx = innerLeftX + (clearSpanPx * i / 8);
      canvas.drawCircle(
        Offset(dx, botBarY - 4.0),
        2.1,
        Paint()..color = dotColor,
      );
    }

    // 4. الحديد العلوي عند المسند الأيسر/العلوي
    final double topBarY = slabTopY + 7.0;
    final double leftExtPx = clearSpanPx * (startCond.isContinuous ? 0.30 : 0.15);
    final Color leftTopColor = startCond.isContinuous
        ? AppColors.rebarTopContinuous
        : AppColors.rebarTopDiscontinuous;
    final leftTopPaint = Paint()
      ..color = leftTopColor
      ..strokeWidth = 2.5;
    final double leftStartX =
        startCond.isContinuous ? (leftBeamX - 36.0) : (leftBeamX + 6.0);
    canvas.drawLine(
      Offset(leftStartX, topBarY),
      Offset(innerLeftX + leftExtPx, topBarY),
      leftTopPaint,
    );
    if (!startCond.isContinuous) {
      canvas.drawLine(
        Offset(leftStartX, topBarY),
        Offset(leftStartX, topBarY + 14),
        leftTopPaint,
      );
    }

    // 5. الحديد العلوي عند المسند الأيمن/السفلي
    final double rightExtPx = clearSpanPx * (endCond.isContinuous ? 0.30 : 0.15);
    final Color rightTopColor = endCond.isContinuous
        ? AppColors.rebarTopContinuous
        : AppColors.rebarTopDiscontinuous;
    final rightTopPaint = Paint()
      ..color = rightTopColor
      ..strokeWidth = 2.5;
    final double rightEndX =
        endCond.isContinuous ? (rightBeamX + beamW + 36.0) : (rightBeamX + beamW - 6.0);
    canvas.drawLine(
      Offset(innerRightX - rightExtPx, topBarY),
      Offset(rightEndX, topBarY),
      rightTopPaint,
    );
    if (!endCond.isContinuous) {
      canvas.drawLine(
        Offset(rightEndX, topBarY),
        Offset(rightEndX, topBarY + 14),
        rightTopPaint,
      );
    }

    // 6. النصوص والأبعاد (h, L, 0.3L / 0.15L, التسليح)
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    _drawText(
      canvas,
      'Section ${axis.symbol}–${axis.symbol}  (L = ${spanM.toStringAsFixed(2)} m • h = ${report.loadResult.overallDepthHMm.toStringAsFixed(0)} mm • d = ${(isShortAxis ? report.loadResult.dxMm : report.loadResult.dyMm).toStringAsFixed(0)} mm)',
      Offset(size.width / 2, 16),
      TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
    );

    // تسميات الحديد العلوي وأطوال الامتداد
    final leftExtM = (startCond.isContinuous ? 0.30 : 0.15) * spanM;
    final rightExtM = (endCond.isContinuous ? 0.30 : 0.15) * spanM;
    _drawText(
      canvas,
      '$startTopLabel\n(${leftExtM.toStringAsFixed(2)}m)',
      Offset(innerLeftX + leftExtPx * 0.55, slabTopY - 22),
      TextStyle(color: leftTopColor, fontSize: 9.2, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      '$endTopLabel\n(${rightExtM.toStringAsFixed(2)}m)',
      Offset(innerRightX - rightExtPx * 0.55, slabTopY - 22),
      TextStyle(
          color: rightTopColor, fontSize: 9.2, fontWeight: FontWeight.bold),
    );

    // تسمية الحديد السفلي
    _drawText(
      canvas,
      'Bottom: $bottomLabel  (Cover = ${report.settingsUsed.clearCoverC.toStringAsFixed(0)} mm)',
      Offset(size.width / 2, slabBotY + 22),
      TextStyle(color: botColor, fontSize: 10.5, fontWeight: FontWeight.bold),
    );

    // تسمية الحواف السفلية
    _drawText(
      canvas,
      _edgeShortNote(startCond),
      Offset(leftBeamX + beamW / 2, slabBotY + beamDrop + 14),
      TextStyle(color: subColor, fontSize: 8.8, fontWeight: FontWeight.bold),
    );
    _drawText(
      canvas,
      _edgeShortNote(endCond),
      Offset(rightBeamX + beamW / 2, slabBotY + beamDrop + 14),
      TextStyle(color: subColor, fontSize: 8.8, fontWeight: FontWeight.bold),
    );
  }

  void _drawAdjacentExtension(
    Canvas canvas, {
    required EdgeCondition condition,
    required bool isLeft,
    required double beamEdgeX,
    required double slabTopY,
    required double slabH,
    required Paint concreteFill,
    required Paint concreteStroke,
  }) {
    const double extW = 42.0;
    final double x1 = isLeft ? beamEdgeX - extW : beamEdgeX;

    if (condition == EdgeCondition.continuous) {
      final r = Rect.fromLTWH(x1, slabTopY, extW, slabH);
      canvas.drawRect(r, concreteFill);
      canvas.drawRect(r, concreteStroke);
    } else if (condition == EdgeCondition.cantilever) {
      final r = Rect.fromLTWH(x1, slabTopY, extW, slabH);
      canvas.drawRect(
        r,
        Paint()..color = AppColors.safeGreen.withAlpha(45),
      );
      canvas.drawRect(r, concreteStroke);
      _drawText(
        canvas,
        'Cant.',
        r.center,
        const TextStyle(
          color: AppColors.safeGreen,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (condition == EdgeCondition.discontinuousDropped) {
      // رسم هبوط البلاطة المهبطة بمقدار 22 px لإيضاح انقطاع الحديد العلوي
      final droppedTop = slabTopY + 22.0;
      final r = Rect.fromLTWH(x1, droppedTop, extW, slabH);
      canvas.drawRect(
        r,
        Paint()..color = AppColors.accentAmber.withAlpha(55),
      );
      canvas.drawRect(r, concreteStroke);
      _drawText(
        canvas,
        'Drop',
        r.center,
        const TextStyle(
          color: AppColors.warningAmber,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  String _edgeShortNote(EdgeCondition c) {
    switch (c) {
      case EdgeCondition.continuous:
        return 'مستمر (0.3L)';
      case EdgeCondition.cantilever:
        return 'كابولي (1.5Lc)';
      case EdgeCondition.discontinuousDropped:
        return 'بلاطة مهبطة';
      case EdgeCondition.discontinuousStairwell:
        return 'بيت درج';
      case EdgeCondition.discontinuousFree:
        return 'طرفي (0.15L)';
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
  bool shouldRepaint(covariant SlabSectionPainter oldDelegate) {
    return oldDelegate.report != report ||
        oldDelegate.axis != axis ||
        oldDelegate.useLectureNotation != useLectureNotation ||
        oldDelegate.isDark != isDark;
  }
}
