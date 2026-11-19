import 'dart:math' as math;
import '../../data/bs8110/slab_moment_shear_tables.dart';
import '../models/slab_enums.dart';
import '../models/slab_geometry_models.dart';
import '../models/slab_design_report.dart';

/// محلل طوبولوجية البلاطة وشروط استناد حوافها الأربع وتحديد حالتها في Table 3.14
class TopologyResolver {
  TopologyResolver._();

  /// استنتاج حالة الحافة على مخطط شبكي كامل بالنسبة لخانة محددة
  static EdgeCondition resolveGridEdge({
    required FloorGridPlan plan,
    required FloorSlabCell cell,
    required EdgeSide side,
  }) {
    // 1. إذا كان هناك كابولي متصل بهذه الحافة مباشرة
    if (cell.cantileverOn(side) != null) {
      return EdgeCondition.cantilever;
    }

    // 2. فحص الخانة المجاورة في المصفوفة
    final targetRow = cell.row +
        (side == EdgeSide.top
            ? -1
            : side == EdgeSide.bottom
                ? 1
                : 0);
    final targetCol = cell.col +
        (side == EdgeSide.left
            ? -1
            : side == EdgeSide.right
                ? 1
                : 0);

    final neighbor = plan.cellAt(targetRow, targetCol);
    if (neighbor == null || neighbor.cellType == SlabCellType.exteriorEmpty) {
      return EdgeCondition.discontinuousFree;
    }

    if (neighbor.cellType == SlabCellType.stairwellOrVoid) {
      return EdgeCondition.discontinuousStairwell;
    }

    // إذا كانت البلاطة الحالية عادية والمجاورة مهبطة (أو العكس) ينقطع التسليح العلوي
    if (cell.cellType != neighbor.cellType) {
      return EdgeCondition.discontinuousDropped;
    }

    return EdgeCondition.continuous;
  }

  /// تحليل خلية داخل مخطط شبكي كامل
  static ResolvedTopology resolveFromFloorGrid({
    required FloorGridPlan plan,
    required FloorSlabCell cell,
  }) {
    final widthX = plan.widthOf(cell);
    final heightY = plan.heightOf(cell);

    final top = resolveGridEdge(plan: plan, cell: cell, side: EdgeSide.top);
    final bottom =
        resolveGridEdge(plan: plan, cell: cell, side: EdgeSide.bottom);
    final left = resolveGridEdge(plan: plan, cell: cell, side: EdgeSide.left);
    final right = resolveGridEdge(plan: plan, cell: cell, side: EdgeSide.right);

    return resolveFromEdges(
      slabId: cell.id,
      cellType: cell.cellType,
      widthXM: widthX,
      heightYM: heightY,
      topEdge: top,
      bottomEdge: bottom,
      leftEdge: left,
      rightEdge: right,
    );
  }

  /// تحليل بلاطة مفردة من وضع الإدخال السريع
  static ResolvedTopology resolveFromSingleSlab(SingleSlabInput input) {
    return resolveFromEdges(
      slabId: input.slabId,
      cellType: input.cellType,
      widthXM: input.widthXM,
      heightYM: input.heightYM,
      topEdge: input.topEdge,
      bottomEdge: input.bottomEdge,
      leftEdge: input.leftEdge,
      rightEdge: input.rightEdge,
    );
  }

  /// المنطق الموحّد لتصنيف البلاطة (اتجاه واحد / اتجاهين + إحدى الحالات التسع)
  static ResolvedTopology resolveFromEdges({
    required String slabId,
    required SlabCellType cellType,
    required double widthXM,
    required double heightYM,
    required EdgeCondition topEdge,
    required EdgeCondition bottomEdge,
    required EdgeCondition leftEdge,
    required EdgeCondition rightEdge,
  }) {
    if (widthXM <= 0 || heightYM <= 0) {
      throw ArgumentError('يجب أن تكون أبعاد البلاطة أكبر من الصفر.');
    }

    final double lx = math.min(widthXM, heightYM);
    final double ly = math.max(widthXM, heightYM);
    final double ratio = ly / lx;
    final bool isSquare = (widthXM - heightYM).abs() < 1e-9;

    bool isShortHorizontal = widthXM <= heightYM;

    final SlabSpanningType spanningType =
        ratio <= 2.0 ? SlabSpanningType.twoWay : SlabSpanningType.oneWay;

    // الحواف القصيرة هي التي طولها = lx، والطويلة طولها = ly
    TwoWayPanelCase? caseFor(bool shortHorizontal) {
      if (spanningType != SlabSpanningType.twoWay) return null;
      final List<EdgeCondition> shortEdges = shortHorizontal
          ? [topEdge, bottomEdge]
          : [leftEdge, rightEdge];
      final List<EdgeCondition> longEdges = shortHorizontal
          ? [leftEdge, rightEdge]
          : [topEdge, bottomEdge];
      return _mapDiscontinuousCountsToCase(
        discShort: shortEdges.where((e) => e.isDiscontinuous).length,
        discLong: longEdges.where((e) => e.isDiscontinuous).length,
      );
    }

    TwoWayPanelCase? panelCase = caseFor(isShortHorizontal);

    // البلاطة المربعة: لا يوجد بحر «قصير» حقيقي، فتسمية الحافتين قصيرة/طويلة اعتباطية.
    // إذا أعطى الاتجاهان حالتين مختلفتين في Table 3.14 (مثلاً Case 2 مقابل Case 3 لحافة
    // واحدة غير مستمرة، ومعاملاتهما غير متناظرة تماماً عند ly/lx = 1.0) نختار الأعلى
    // مجموعاً للمعاملات (الأكثر تحفظاً) بدل الاعتماد على ترتيب الأضلاع في الإدخال.
    String? squareNote;
    if (isSquare && spanningType == SlabSpanningType.twoWay) {
      final alt = caseFor(!isShortHorizontal);
      if (alt != null && panelCase != null && alt != panelCase) {
        final double scoreCurrent = _squareScore(panelCase);
        final double scoreAlt = _squareScore(alt);
        if (scoreAlt > scoreCurrent) {
          isShortHorizontal = !isShortHorizontal;
          panelCase = alt;
        }
        squareNote =
            'بلاطة مربعة (lx = ly): تسمية الحافتين «قصيرة/طويلة» اعتباطية فتعطي Case ${caseFor(true)!.caseNumber} أو Case ${caseFor(false)!.caseNumber}؛ '
            'اعتُمدت Case ${panelCase!.caseNumber} لأن معاملاتها أكبر (أكثر أماناً).';
      }
    }

    // فحص الأركان الأربعة لتسليح الالتواء:
    // ركن مختلط = حافة مستمرة + حافة غير مستمرة
    // ركن حر = حافتان غير مستمرتين
    final corners = [
      (topEdge, leftEdge),
      (topEdge, rightEdge),
      (bottomEdge, leftEdge),
      (bottomEdge, rightEdge),
    ];
    int mixedCorners = 0;
    int freeCorners = 0;
    for (final (e1, e2) in corners) {
      if (e1.isDiscontinuous && e2.isDiscontinuous) {
        freeCorners++;
      } else if (e1.isDiscontinuous || e2.isDiscontinuous) {
        mixedCorners++;
      }
    }

    return ResolvedTopology(
      slabId: slabId,
      cellType: cellType,
      widthXM: widthXM,
      heightYM: heightYM,
      shortSpanLxM: lx,
      longSpanLyM: ly,
      lyOverLx: ratio,
      isShortSpanHorizontal: isShortHorizontal,
      spanningType: spanningType,
      twoWayCase: panelCase,
      topEdge: topEdge,
      bottomEdge: bottomEdge,
      leftEdge: leftEdge,
      rightEdge: rightEdge,
      mixedCornersCount: mixedCorners,
      freeCornersCount: freeCorners,
      squareOrientationNoteAr: squareNote,
    );
  }

  /// مجموع معاملات Table 3.14 عند ly/lx = 1.0 (مقياس تحفظ لاختيار حالة البلاطة المربعة)
  static double _squareScore(TwoWayPanelCase c) {
    final row = SlabMomentShearTables.table314[c];
    if (row == null) return 0.0;
    return (row.betaSxNegative?[1.0] ?? 0.0) +
        (row.betaSxPositive[1.0] ?? 0.0) +
        (row.betaSyNegative ?? 0.0) +
        row.betaSyPositive;
  }

  /// تحويل عدد الحواف القصيرة والطويلة غير المستمرة إلى الحالة المطابقة في Table 3.14
  static TwoWayPanelCase _mapDiscontinuousCountsToCase({
    required int discShort,
    required int discLong,
  }) {
    if (discShort == 0 && discLong == 0) {
      return TwoWayPanelCase.interiorPanels; // Case 1
    }
    if (discShort == 1 && discLong == 0) {
      return TwoWayPanelCase.oneShortEdgeDiscontinuous; // Case 2
    }
    if (discShort == 0 && discLong == 1) {
      return TwoWayPanelCase.oneLongEdgeDiscontinuous; // Case 3
    }
    if (discShort == 1 && discLong == 1) {
      return TwoWayPanelCase.twoAdjacentEdgesDiscontinuous; // Case 4
    }
    if (discShort == 2 && discLong == 0) {
      return TwoWayPanelCase.twoShortEdgesDiscontinuous; // Case 5
    }
    if (discShort == 0 && discLong == 2) {
      return TwoWayPanelCase.twoLongEdgesDiscontinuous; // Case 6
    }
    if (discShort == 2 && discLong == 1) {
      return TwoWayPanelCase.threeEdgesDiscontinuousOneLongContinuous; // Case 7
    }
    if (discShort == 1 && discLong == 2) {
      return TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous; // Case 8
    }
    return TwoWayPanelCase.fourEdgesDiscontinuous; // Case 9
  }
}
