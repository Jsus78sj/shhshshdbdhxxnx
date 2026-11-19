import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/engine/engineering_engine.dart';

/// إحداثيات تخطيط الشبكة على اللوحة لحساب الرسم واكتشاف النقر بدقة
class FloorCanvasLayoutMetrics {
  final double scalePxPerM;
  final Offset origin;
  final List<double> colLeftPx;
  final List<double> colWidthPx;
  final List<double> rowTopPx;
  final List<double> rowHeightPx;
  final Size totalCanvasSize;

  const FloorCanvasLayoutMetrics({
    required this.scalePxPerM,
    required this.origin,
    required this.colLeftPx,
    required this.colWidthPx,
    required this.rowTopPx,
    required this.rowHeightPx,
    required this.totalCanvasSize,
  });

  Rect cellRect(FloorGridPlan plan, FloorSlabCell cell) {
    final left = colLeftPx[cell.col];
    final top = rowTopPx[cell.row];
    final width = plan.widthOf(cell) * scalePxPerM;
    final height = plan.heightOf(cell) * scalePxPerM;
    return Rect.fromLTWH(left, top, width, height);
  }

  static FloorCanvasLayoutMetrics compute(
    FloorGridPlan plan, {
    double scalePxPerM = 46.0,
    double paddingPx = 88.0,
  }) {
    // حساب أقصى بروز للكوابيل على الجهات الأربع حتى لا تنقص من مساحة الرسم
    double leftExtraM = 0;
    double rightExtraM = 0;
    double topExtraM = 0;
    double bottomExtraM = 0;

    for (final c in plan.cells) {
      for (final cant in c.cantilevers) {
        switch (cant.side) {
          case EdgeSide.left:
            leftExtraM = math.max(leftExtraM, cant.lengthM);
          case EdgeSide.right:
            rightExtraM = math.max(rightExtraM, cant.lengthM);
          case EdgeSide.top:
            topExtraM = math.max(topExtraM, cant.lengthM);
          case EdgeSide.bottom:
            bottomExtraM = math.max(bottomExtraM, cant.lengthM);
        }
      }
    }

    // حساب أقصى عرض لكل عمود وأقصى ارتفاع لكل صف (مع مراعاة التجاوزات الفردية)
    final colMaxM = List<double>.from(plan.xSpansM);
    final rowMaxM = List<double>.from(plan.ySpansM);
    for (final c in plan.cells) {
      if (c.col < colMaxM.length) {
        colMaxM[c.col] = math.max(colMaxM[c.col], plan.widthOf(c));
      }
      if (c.row < rowMaxM.length) {
        rowMaxM[c.row] = math.max(rowMaxM[c.row], plan.heightOf(c));
      }
    }

    final originX = paddingPx + (leftExtraM * scalePxPerM);
    final originY = paddingPx + (topExtraM * scalePxPerM);

    final colLeft = <double>[];
    final colW = <double>[];
    double cursorX = originX;
    for (final wM in colMaxM) {
      colLeft.add(cursorX);
      final wPx = wM * scalePxPerM;
      colW.add(wPx);
      cursorX += wPx;
    }

    final rowTop = <double>[];
    final rowH = <double>[];
    double cursorY = originY;
    for (final hM in rowMaxM) {
      rowTop.add(cursorY);
      final hPx = hM * scalePxPerM;
      rowH.add(hPx);
      cursorY += hPx;
    }

    final totalW = cursorX + (rightExtraM * scalePxPerM) + paddingPx;
    final totalH = cursorY + (bottomExtraM * scalePxPerM) + paddingPx;

    return FloorCanvasLayoutMetrics(
      scalePxPerM: scalePxPerM,
      origin: Offset(originX, originY),
      colLeftPx: colLeft,
      colWidthPx: colW,
      rowTopPx: rowTop,
      rowHeightPx: rowH,
      totalCanvasSize: Size(totalW, totalH),
    );
  }
}

/// رسّام المخطط الإنشائي الكامل للسقف (CustomPainter)
class FloorPlanPainter extends CustomPainter {
  final FloorGridPlan plan;
  final FloorCanvasLayoutMetrics metrics;
  final int selectedRow;
  final int selectedCol;
  final String? highlightedSlabId;
  final bool isDark;

  FloorPlanPainter({
    required this.plan,
    required this.metrics,
    required this.selectedRow,
    required this.selectedCol,
    this.highlightedSlabId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBlueprintBackground(canvas, size);
    _drawDimensionLines(canvas);

    // 1. رسم الكوابيل أولاً خلف حدود الكمرات
    for (final cell in plan.cells) {
      if (cell.cantilevers.isEmpty) continue;
      final cellRect = metrics.cellRect(plan, cell);
      for (final cant in cell.cantilevers) {
        _drawCantilever(canvas, cellRect, cant);
      }
    }

    // 2. رسم جميع خانات الشبكة
    for (final cell in plan.cells) {
      final rect = metrics.cellRect(plan, cell);
      final isSelected = cell.row == selectedRow && cell.col == selectedCol;
      final isMagicHighlighted = highlightedSlabId != null &&
          cell.id.toLowerCase() == highlightedSlabId!.toLowerCase();

      _drawCell(
        canvas,
        cell,
        rect,
        isSelected: isSelected,
        isMagicHighlighted: isMagicHighlighted,
      );
    }

    // 3. إعادة رسم إطار التحديد فوق كل شيء ليكون بارزاً بوضوح
    final selected = plan.cellAt(selectedRow, selectedCol);
    if (selected != null) {
      final selRect = metrics.cellRect(plan, selected);
      final glowPaint = Paint()
        ..color = AppColors.rebarBottomX.withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0;
      canvas.drawRect(selRect.inflate(1.5), glowPaint);

      final borderPaint = Paint()
        ..color = AppColors.rebarBottomX
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(selRect, borderPaint);
    }
  }

  void _drawBlueprintBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0E1826) : const Color(0xFFF8FBFF);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1A2B40)
          : const Color(0xFFE6EEF7)
      ..strokeWidth = 0.8;

    const step = 24.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawDimensionLines(Canvas canvas) {
    final dimColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final linePaint = Paint()
      ..color = dimColor.withAlpha(180)
      ..strokeWidth = 1.2;

    // أبعاد المحاور الأفقية (أعلى المخطط)
    final topY = metrics.origin.dy - 30.0;
    for (int c = 0; c < plan.colsCount; c++) {
      final x1 = metrics.colLeftPx[c];
      final x2 = x1 + metrics.colWidthPx[c];
      canvas.drawLine(Offset(x1, topY), Offset(x2, topY), linePaint);
      canvas.drawLine(Offset(x1, topY - 6), Offset(x1, topY + 6), linePaint);
      canvas.drawLine(Offset(x2, topY - 6), Offset(x2, topY + 6), linePaint);

      _drawCenteredText(
        canvas,
        '${plan.xSpansM[c].toStringAsFixed(2)} m',
        Offset((x1 + x2) / 2, topY - 12),
        TextStyle(
          color: dimColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // أبعاد المحاور الرأسية (يسار المخطط)
    final leftX = 32.0;
    for (int r = 0; r < plan.rowsCount; r++) {
      final y1 = metrics.rowTopPx[r];
      final y2 = y1 + metrics.rowHeightPx[r];
      canvas.drawLine(Offset(leftX, y1), Offset(leftX, y2), linePaint);
      canvas.drawLine(Offset(leftX - 6, y1), Offset(leftX + 6, y1), linePaint);
      canvas.drawLine(Offset(leftX - 6, y2), Offset(leftX + 6, y2), linePaint);

      final leftCell = plan.cellAt(r, 0);
      final spanLabel = leftCell != null
          ? plan.heightOf(leftCell).toStringAsFixed(2)
          : plan.ySpansM[r].toStringAsFixed(2);

      _drawCenteredText(
        canvas,
        spanLabel,
        Offset(leftX, (y1 + y2) / 2),
        TextStyle(
          color: dimColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          backgroundColor:
              isDark ? const Color(0xFF0E1826) : const Color(0xFFF8FBFF),
        ),
      );
    }

    // أبعاد المحاور الرأسية على اليمين (مفيدة إذا اختلفت سماكة/طول العمود الأيمن مثل S3 = 4.20)
    final rightX = metrics.totalCanvasSize.width - 32.0;
    for (int r = 0; r < plan.rowsCount; r++) {
      final rightCell = plan.cellAt(r, plan.colsCount - 1);
      if (rightCell == null) continue;
      final y1 = metrics.rowTopPx[r];
      final y2 = y1 + (plan.heightOf(rightCell) * metrics.scalePxPerM);
      canvas.drawLine(Offset(rightX, y1), Offset(rightX, y2), linePaint);
      canvas.drawLine(
          Offset(rightX - 6, y1), Offset(rightX + 6, y1), linePaint);
      canvas.drawLine(
          Offset(rightX - 6, y2), Offset(rightX + 6, y2), linePaint);

      _drawCenteredText(
        canvas,
        plan.heightOf(rightCell).toStringAsFixed(2),
        Offset(rightX, (y1 + y2) / 2),
        TextStyle(
          color: dimColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          backgroundColor:
              isDark ? const Color(0xFF0E1826) : const Color(0xFFF8FBFF),
        ),
      );
    }
  }

  void _drawCantilever(
    Canvas canvas,
    Rect cellRect,
    CantileverAttachment cant,
  ) {
    final lenPx = cant.lengthM * metrics.scalePxPerM;
    late final Rect cantRect;

    switch (cant.side) {
      case EdgeSide.left:
        cantRect = Rect.fromLTWH(
          cellRect.left - lenPx,
          cellRect.top,
          lenPx,
          cellRect.height,
        );
      case EdgeSide.right:
        cantRect = Rect.fromLTWH(
          cellRect.right,
          cellRect.top,
          lenPx,
          cellRect.height,
        );
      case EdgeSide.top:
        cantRect = Rect.fromLTWH(
          cellRect.left,
          cellRect.top - lenPx,
          cellRect.width,
          lenPx,
        );
      case EdgeSide.bottom:
        cantRect = Rect.fromLTWH(
          cellRect.left,
          cellRect.bottom,
          cellRect.width,
          lenPx,
        );
    }

    final fillPaint = Paint()
      ..color = isDark
          ? const Color(0xFF133A2E)
          : const Color(0xFFDCFCE7);
    final borderPaint = Paint()
      ..color = AppColors.safeGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRect(cantRect, fillPaint);
    canvas.drawRect(cantRect, borderPaint);

    _drawCenteredText(
      canvas,
      'Cantilever\n${cant.lengthM.toStringAsFixed(2)} m',
      cantRect.center,
      TextStyle(
        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _drawCell(
    Canvas canvas,
    FloorSlabCell cell,
    Rect rect, {
    required bool isSelected,
    required bool isMagicHighlighted,
  }) {
    final beamColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF1E293B);

    // 1. تعبئة الخلفية حسب نوع البلاطة
    Color fillColor;
    switch (cell.cellType) {
      case SlabCellType.normalSolid:
        if (isMagicHighlighted) {
          fillColor = isDark
              ? const Color(0xFF3E2D0F)
              : const Color(0xFFFEF08A);
        } else {
          fillColor = isDark
              ? const Color(0xFF15293E)
              : const Color(0xFFEFF6FF);
        }
      case SlabCellType.droppedSolid:
        fillColor = isDark
            ? const Color(0xFF3B2810)
            : const Color(0xFFFEF3C7);
      case SlabCellType.stairwellOrVoid:
        fillColor = isDark
            ? const Color(0xFF222834)
            : const Color(0xFFE2E8F0);
      case SlabCellType.exteriorEmpty:
        fillColor = Colors.transparent;
    }

    if (cell.cellType != SlabCellType.exteriorEmpty) {
      canvas.drawRect(rect, Paint()..color = fillColor);
    }

    // 2. التهشير المتقاطع للبلاطة المهبطة (Dropped Solid Slab)
    if (cell.cellType == SlabCellType.droppedSolid) {
      canvas.save();
      canvas.clipRect(rect);
      final hatchPaint = Paint()
        ..color = AppColors.accentAmber.withAlpha(isDark ? 95 : 110)
        ..strokeWidth = 1.0;
      const spacing = 12.0;
      final diag = rect.width + rect.height;
      for (double d = -rect.height; d < diag; d += spacing) {
        canvas.drawLine(
          Offset(rect.left + d, rect.top),
          Offset(rect.left + d - rect.height, rect.bottom),
          hatchPaint,
        );
        canvas.drawLine(
          Offset(rect.left + d, rect.top),
          Offset(rect.left + d + rect.height, rect.bottom),
          hatchPaint,
        );
      }
      canvas.restore();
    }

    // 3. رسم درجات السلم لبيت الدرج
    if (cell.cellType == SlabCellType.stairwellOrVoid) {
      final stairPaint = Paint()
        ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF475569)
        ..strokeWidth = 1.1;
      final midX = rect.center.dx;
      final landingY = rect.top + rect.height * 0.25;
      canvas.drawLine(
        Offset(rect.left + 4, landingY),
        Offset(rect.right - 4, landingY),
        stairPaint,
      );
      canvas.drawLine(
        Offset(midX, landingY),
        Offset(midX, rect.bottom - 4),
        stairPaint,
      );
      const steps = 8;
      final stepGap = (rect.bottom - 4 - landingY) / steps;
      for (int i = 1; i < steps; i++) {
        final y = landingY + (i * stepGap);
        canvas.drawLine(
          Offset(rect.left + 4, y),
          Offset(rect.right - 4, y),
          stairPaint,
        );
      }
    }

    // 4. رسم حدود الكمرات (خط مزدوج للبلاطات، ومتقطع للفراغ)
    if (cell.cellType == SlabCellType.exteriorEmpty) {
      final voidPaint = Paint()
        ..color = beamColor.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(rect.deflate(2), voidPaint);
    } else {
      final outerBeam = Paint()
        ..color = beamColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      final innerBeam = Paint()
        ..color = beamColor.withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawRect(rect, outerBeam);
      canvas.drawRect(rect.deflate(4), innerBeam);
    }

    // 5. النصوص والتصنيف داخل الخانة
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    if (cell.cellType == SlabCellType.exteriorEmpty) {
      _drawCenteredText(
        canvas,
        'فراغ',
        rect.center,
        TextStyle(color: textSecondary.withAlpha(140), fontSize: 11),
      );
      return;
    }

    if (cell.cellType == SlabCellType.stairwellOrVoid) {
      _drawCenteredText(
        canvas,
        cell.label,
        Offset(rect.center.dx, rect.top + rect.height * 0.14),
        TextStyle(
          color: textPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      );
      return;
    }

    // استنتاج سريع لرقم الحالة لعرضه كبادج صغير داخل البلاطة
    final topo = TopologyResolver.resolveFromFloorGrid(plan: plan, cell: cell);
    final wM = plan.widthOf(cell);
    final hM = plan.heightOf(cell);

    final titleText = cell.cellType == SlabCellType.droppedSolid
        ? 'Dropped\nSolid Slab'
        : cell.id;

    _drawCenteredText(
      canvas,
      titleText,
      Offset(rect.center.dx, rect.center.dy - 14),
      TextStyle(
        color: cell.cellType == SlabCellType.droppedSolid
            ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
            : (isSelected ? AppColors.rebarBottomX : textPrimary),
        fontSize: cell.cellType == SlabCellType.droppedSolid ? 11.5 : 15,
        fontWeight: FontWeight.bold,
      ),
    );

    _drawCenteredText(
      canvas,
      '${wM.toStringAsFixed(2)} × ${hM.toStringAsFixed(2)} m',
      Offset(rect.center.dx, rect.center.dy + 10),
      TextStyle(color: textSecondary, fontSize: 10),
    );

    if (topo.twoWayCase != null) {
      _drawCenteredText(
        canvas,
        'Case ${topo.twoWayCase!.caseNumber}',
        Offset(rect.center.dx, rect.center.dy + 25),
        TextStyle(
          color: isDark ? const Color(0xFF5EEAD4) : AppColors.secondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      _drawCenteredText(
        canvas,
        'One-Way',
        Offset(rect.center.dx, rect.center.dy + 25),
        TextStyle(
          color: AppColors.accentAmber,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // شارة النجمة للبلاطة المميزة بالرقم السحري S_No.
    if (isMagicHighlighted) {
      final badgeRect = Rect.fromLTWH(rect.right - 30, rect.top + 6, 24, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
        Paint()..color = AppColors.accentAmber,
      );
      _drawCenteredText(
        canvas,
        '★',
        badgeRect.center,
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      center.dx - (painter.width / 2),
      center.dy - (painter.height / 2),
    );
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    return oldDelegate.plan != plan ||
        oldDelegate.selectedRow != selectedRow ||
        oldDelegate.selectedCol != selectedCol ||
        oldDelegate.highlightedSlabId != highlightedSlabId ||
        oldDelegate.isDark != isDark;
  }
}

/// عنصر لوحة الرسم التفاعلية مع التكبير والتحريك (Pinch & Pan) واكتشاف النقر على أي بلاطة
class FloorPlanCanvasWidget extends StatelessWidget {
  final FloorGridPlan plan;
  final int selectedRow;
  final int selectedCol;
  final String? highlightedSlabId;
  final void Function(int row, int col) onCellTapped;

  const FloorPlanCanvasWidget({
    super.key,
    required this.plan,
    required this.selectedRow,
    required this.selectedCol,
    this.highlightedSlabId,
    required this.onCellTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metrics = FloorCanvasLayoutMetrics.compute(plan);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: InteractiveViewer(
        minScale: 0.45,
        maxScale: 2.8,
        boundaryMargin: const EdgeInsets.all(60),
        constrained: false,
        child: GestureDetector(
          onTapUp: (details) {
            final localPos = details.localPosition;
            for (final cell in plan.cells) {
              final rect = metrics.cellRect(plan, cell);
              if (rect.contains(localPos)) {
                onCellTapped(cell.row, cell.col);
                return;
              }
            }
          },
          child: CustomPaint(
            size: metrics.totalCanvasSize,
            painter: FloorPlanPainter(
              plan: plan,
              metrics: metrics,
              selectedRow: selectedRow,
              selectedCol: selectedCol,
              highlightedSlabId: highlightedSlabId,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}
