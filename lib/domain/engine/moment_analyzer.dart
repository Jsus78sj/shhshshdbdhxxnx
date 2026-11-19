import '../../data/bs8110/slab_moment_shear_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_geometry_models.dart';

/// محلل العزوم الأولية للبلاطات (اتجاهين Table 3.14، اتجاه واحد Table 3.12 / wl²/8، وكوابيل nl²/2)
class MomentAnalyzer {
  MomentAnalyzer._();

  /// حساب العزوم الأولية للبلاطة المدروسة.
  /// [roundBetaDecimals]: تقريب β الناتج عن التناسب الخطي (وضع الشرح = 3 خانات).
  static InitialMomentsResult analyze({
    required ResolvedTopology topology,
    required double designLoadN,
    Map<EdgeSide, CantileverAttachment> cantilevers = const {},
    int? roundBetaDecimals,
  }) {
    final lx = topology.shortSpanLxM;
    final nLx2 = designLoadN * lx * lx;

    // حساب عزوم الكوابيل المتصلة بالحواف (إن وُجدت)
    final Map<EdgeSide, double> cantMoments = {};
    for (final entry in cantilevers.entries) {
      cantMoments[entry.key] =
          entry.value.negativeMomentKnPerM(designLoadN);
    }

    // 1. البلاطة العاملة في اتجاهين (Two-Way Solid Slab — Table 3.14)
    if (topology.spanningType == SlabSpanningType.twoWay &&
        topology.twoWayCase != null) {
      final coeffs = SlabMomentShearTables.getMomentCoefficients(
        panelCase: topology.twoWayCase!,
        lyOverLx: topology.lyOverLx,
        roundBetaDecimals: roundBetaDecimals,
      );

      final msxPos = coeffs.betaSxPos * nLx2;
      final msxNeg = (coeffs.betaSxNeg ?? 0.0) * nLx2;
      final msyPos = coeffs.betaSyPos * nLx2;
      final msyNeg = (coeffs.betaSyNeg ?? 0.0) * nLx2;

      return InitialMomentsResult(
        betaSxNeg: coeffs.betaSxNeg,
        betaSxPos: coeffs.betaSxPos,
        betaSyNeg: coeffs.betaSyNeg,
        betaSyPos: coeffs.betaSyPos,
        betaSxNegTrace: coeffs.betaSxNegTrace,
        betaSxPosTrace: coeffs.betaSxPosTrace,
        nLx2: nLx2,
        msxPos: msxPos,
        msxNeg: msxNeg,
        msyPos: msyPos,
        msyNeg: msyNeg,
        cantileverMomentsBySide: cantMoments,
      );
    }

    // 1-ب. البلاطة الكابولية (Cantilever): M = n · lc² / 2 عند المسند، ولا عزم موجب
    if (topology.spanningType == SlabSpanningType.cantilever) {
      const double betaCantilever = 0.5;
      return InitialMomentsResult(
        betaSxNeg: betaCantilever,
        betaSxPos: 0.0,
        betaSyNeg: null,
        betaSyPos: 0.0,
        betaSxNegTrace: null,
        betaSxPosTrace: null,
        nLx2: nLx2,
        msxPos: 0.0,
        msxNeg: betaCantilever * nLx2,
        msyPos: 0.0,
        msyNeg: 0.0,
        cantileverMomentsBySide: cantMoments,
      );
    }

    // 2. البلاطة العاملة في اتجاه واحد (One-Way Solid Slab)
    // الحواف الطويلة هي التي تحمل البحر القصير lx
    final EdgeCondition startEnd =
        topology.isShortSpanHorizontal ? topology.leftEdge : topology.topEdge;
    final EdgeCondition farEnd = topology.isShortSpanHorizontal
        ? topology.rightEdge
        : topology.bottomEdge;

    double betaPos;
    double? betaNeg;

    if (startEnd.isDiscontinuous && farEnd.isDiscontinuous) {
      // بسيطة الارتكاز من الطرفين: M = n * lx² / 8 = 0.125 * n * lx²
      betaPos = 0.125;
      betaNeg = null;
    } else if (startEnd.isContinuous && farEnd.isContinuous) {
      // بحر داخلي مستمر (Table 3.12): Mid = 0.063 Fl , Support = -0.063 Fl
      betaPos = 0.063;
      betaNeg = 0.063;
    } else {
      // بحر طرفي مستمر من جهة واحدة (Table 3.12): Mid = 0.086 Fl , Interior Support = -0.086 Fl
      betaPos = 0.086;
      betaNeg = 0.086;
    }

    return InitialMomentsResult(
      betaSxNeg: betaNeg,
      betaSxPos: betaPos,
      betaSyNeg: null,
      betaSyPos: 0.0, // في الاتجاه الثانوي يُستخدم حديد التوزيع الأدنى As,min
      betaSxNegTrace: null,
      betaSxPosTrace: null,
      nLx2: nLx2,
      msxPos: betaPos * nLx2,
      msxNeg: (betaNeg ?? 0.0) * nLx2,
      msyPos: 0.0,
      msyNeg: 0.0,
      cantileverMomentsBySide: cantMoments,
    );
  }

  /// العزم السالب الأولي للبلاطة على حافة معينة
  static double initialNegativeMomentOnSide({
    required ResolvedTopology topology,
    required InitialMomentsResult initialMoments,
    required EdgeSide side,
  }) {
    final edge = topology.edgeFor(side);
    if (edge.isDiscontinuous) return 0.0;

    final bool isSidePerpToShortSpan = topology.isShortSpanHorizontal
        ? (side == EdgeSide.left || side == EdgeSide.right)
        : (side == EdgeSide.top || side == EdgeSide.bottom);

    return isSidePerpToShortSpan
        ? initialMoments.msxNeg
        : initialMoments.msyNeg;
  }
}
