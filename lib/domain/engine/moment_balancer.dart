import 'dart:math' as math;
import '../../data/bs8110/slab_moment_shear_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_geometry_models.dart';
import 'load_calculator.dart';
import 'moment_analyzer.dart';
import 'topology_resolver.dart';

/// محرك موازنة وتوزيع العزوم عند المساند المستمرة (Section A-A / Section B-B / Section Y-Y)
class MomentBalancer {
  MomentBalancer._();

  /// حساب الجساءة النسبية للبحر:
  /// k = 1.0 / L إذا كان البحر مستمراً من الطرفين (داخلي)، و k = 0.75 / L إذا كان طرفياً
  static double relativeStiffness({
    required double spanLengthM,
    required bool isBothEndsContinuous,
  }) {
    if (spanLengthM <= 0) {
      throw ArgumentError('طول البحر يجب أن يكون أكبر من الصفر.');
    }
    return (isBothEndsContinuous ? 1.0 : 0.75) / spanLengthM;
  }

  /// موازنة عزم مسند مستمر واحد بين بحرين وفق معادلة الشرح:
  /// M_UB = |M1 - M2|
  /// M_balanced = M_L - [M_UB * k_L / (k_L + k_other)]
  /// وتُضاف زيادة 0.5 * (M_slab - M_balanced) لمنتصف البحر فقط إذا انخفض عزم البلاطة المدروسة.
  static ({
    double mUnbalanced,
    double mBalanced,
    double slabReduction,
    double midSpanIncrease,
  }) balanceTwoSpanSupport({
    required double mSlabInitial,
    required double mNeighborInitial,
    required double kSlab,
    required double kNeighbor,
  }) {
    final mUb = (mSlabInitial - mNeighborInitial).abs();
    final denom = kSlab + kNeighbor;

    double mBalanced;
    if (denom <= 0 || mUb < 1e-9) {
      mBalanced = math.max(mSlabInitial, mNeighborInitial);
    } else if (mSlabInitial >= mNeighborInitial) {
      // البلاطة المدروسة هي صاحبة العزم الأكبر M_L
      mBalanced = mSlabInitial - (mUb * (kSlab / denom));
    } else {
      // الجار هو صاحب العزم الأكبر M_L
      mBalanced = mNeighborInitial - (mUb * (kNeighbor / denom));
    }

    final reduction =
        mSlabInitial > mBalanced ? (mSlabInitial - mBalanced) : 0.0;
    final midIncrease = 0.5 * reduction;

    return (
      mUnbalanced: mUb,
      mBalanced: mBalanced,
      slabReduction: reduction,
      midSpanIncrease: midIncrease,
    );
  }

  /// موازنة العزوم لبلاطة داخل مخطط شبكي كامل (FloorGridPlan)
  static BalancedMomentsResult balanceInFloorGrid({
    required FloorGridPlan plan,
    required FloorSlabCell cell,
    required ResolvedTopology topology,
    required InitialMomentsResult initialMoments,
    required double designLoadN,
  }) {
    final List<SupportBalanceDetail> balances = [];
    final Map<EdgeSide, double> supportMomentBySide = {};

    for (final side in EdgeSide.values) {
      final edge = topology.edgeFor(side);
      final axis = (side == EdgeSide.left || side == EdgeSide.right)
          ? SlabAxisDirection.horizontalX
          : SlabAxisDirection.verticalY;

      if (edge.isDiscontinuous) {
        supportMomentBySide[side] = plan.additionalSupportMomentKnM;
        continue;
      }

      final mSlabInit = MomentAnalyzer.initialNegativeMomentOnSide(
        topology: topology,
        initialMoments: initialMoments,
        side: side,
      );

      // حالة 1: مسند متصل بكابولي جانبي (عزم الكابولي محدد استاتيكياً ولا يُوزّع)
      if (edge == EdgeCondition.cantilever) {
        final cant = cell.cantileverOn(side)!;
        final mCant = cant.supportMomentKnPerM(
          designLoadN,
          source: plan.cantileverMomentSource,
          givenMomentKnM: plan.additionalSupportMomentKnM,
        );
        final governingM = math.max(
          math.max(mSlabInit, mCant),
          plan.additionalSupportMomentKnM,
        );
        supportMomentBySide[side] = governingM;
        balances.add(
          SupportBalanceDetail(
            side: side,
            axisDirection: axis,
            neighborLabel: cant.label,
            isCantileverSupport: true,
            mSlabInitial: mSlabInit,
            mNeighborInitial: mCant,
            kSlab: 0,
            kNeighbor: 0,
            mUnbalanced: (mSlabInit - mCant).abs(),
            mBalancedSupport: governingM,
            slabNegativeReduction: 0.0,
            midSpanMomentIncrease: 0.0,
          ),
        );
        continue;
      }

      // حالة 2: مسند مستمر مع بلاطة مجاورة في الشبكة
      final nRow = cell.row +
          (side == EdgeSide.top
              ? -1
              : side == EdgeSide.bottom
                  ? 1
                  : 0);
      final nCol = cell.col +
          (side == EdgeSide.left
              ? -1
              : side == EdgeSide.right
                  ? 1
                  : 0);
      final neighborCell = plan.cellAt(nRow, nCol);
      if (neighborCell == null || !neighborCell.cellType.isDesignableSlab) {
        supportMomentBySide[side] = mSlabInit;
        continue;
      }

      // تحليل الجار لاستخراج عزمه السالب الأولي عند الحافة المشتركة وجساءته
      final neighborTopo = TopologyResolver.resolveFromFloorGrid(
        plan: plan,
        cell: neighborCell,
      );
      // حمل الجار هو حمله الخاص (بسماكته الأصلية وردمه إن كان مهبطاً) ولا يتأثر بما أُضيف
      // على البلاطة المدروسة من وزن ذاتي إضافي بعد زيادة السماكة أو من ردم البلاطة المهبطة.
      final neighborLoad = LoadCalculator.compute(
        settings: plan.settings,
        cellType: neighborCell.cellType,
        customDesignLoadN: neighborCell.customDesignLoadN,
        fillDepthM: neighborCell.fillDepthM,
        fillUnitWeightKnM3: neighborCell.fillUnitWeightKnM3,
      ).finalDesignLoadN;
      final neighborMoments = MomentAnalyzer.analyze(
        topology: neighborTopo,
        designLoadN: neighborLoad,
        roundBetaDecimals: plan.settings.betaRoundDecimals,
      );
      final mNeighborInit = MomentAnalyzer.initialNegativeMomentOnSide(
        topology: neighborTopo,
        initialMoments: neighborMoments,
        side: side.opposite,
      );

      final double slabSpanAlongAxis = axis == SlabAxisDirection.horizontalX
          ? topology.widthXM
          : topology.heightYM;
      final bool slabBothContinuous = axis == SlabAxisDirection.horizontalX
          ? (topology.leftEdge.isContinuous && topology.rightEdge.isContinuous)
          : (topology.topEdge.isContinuous && topology.bottomEdge.isContinuous);

      final double neighborSpanAlongAxis =
          axis == SlabAxisDirection.horizontalX
              ? neighborTopo.widthXM
              : neighborTopo.heightYM;
      final bool neighborBothContinuous = axis == SlabAxisDirection.horizontalX
          ? (neighborTopo.leftEdge.isContinuous &&
              neighborTopo.rightEdge.isContinuous)
          : (neighborTopo.topEdge.isContinuous &&
              neighborTopo.bottomEdge.isContinuous);

      final kSlab = relativeStiffness(
        spanLengthM: slabSpanAlongAxis,
        isBothEndsContinuous: slabBothContinuous,
      );
      final kNeighbor = relativeStiffness(
        spanLengthM: neighborSpanAlongAxis,
        isBothEndsContinuous: neighborBothContinuous,
      );

      final bal = balanceTwoSpanSupport(
        mSlabInitial: mSlabInit,
        mNeighborInitial: mNeighborInit,
        kSlab: kSlab,
        kNeighbor: kNeighbor,
      );

      final finalSupportM =
          math.max(bal.mBalanced, plan.additionalSupportMomentKnM);
      supportMomentBySide[side] = finalSupportM;

      balances.add(
        SupportBalanceDetail(
          side: side,
          axisDirection: axis,
          neighborLabel: neighborCell.id,
          mSlabInitial: mSlabInit,
          mNeighborInitial: mNeighborInit,
          kSlab: kSlab,
          kNeighbor: kNeighbor,
          mUnbalanced: bal.mUnbalanced,
          mBalancedSupport: finalSupportM,
          slabNegativeReduction: bal.slabReduction,
          midSpanMomentIncrease: bal.midSpanIncrease,
        ),
      );
    }

    return _compileBalancedResult(
      topology: topology,
      initialMoments: initialMoments,
      supportMomentBySide: supportMomentBySide,
      balances: balances,
    );
  }

  /// موازنة العزوم في وضع الإدخال السريع (بلاطة واحدة + جيرانها)
  static BalancedMomentsResult balanceForSingleSlab({
    required SingleSlabInput input,
    required ResolvedTopology topology,
    required InitialMomentsResult initialMoments,
    required double designLoadN,

    /// الحمل الافتراضي للجار الذي لم يُحدَّد له حمل مخصص. يجب أن يكون الحمل الأساسي
    /// (بدون ردم البلاطة المدروسة ولا وزن ذاتي إضافي ناتج عن زيادة سماكتها).
    /// إن لم يُمرَّر يُستخدم [designLoadN].
    double? neighborFallbackLoadN,
    int? betaRoundDecimals,
  }) {
    final List<SupportBalanceDetail> balances = [];
    final Map<EdgeSide, double> supportMomentBySide = {};

    for (final side in EdgeSide.values) {
      final edge = topology.edgeFor(side);
      final axis = (side == EdgeSide.left || side == EdgeSide.right)
          ? SlabAxisDirection.horizontalX
          : SlabAxisDirection.verticalY;

      if (edge.isDiscontinuous) {
        supportMomentBySide[side] = input.additionalSupportMomentKnM;
        continue;
      }

      final mSlabInit = MomentAnalyzer.initialNegativeMomentOnSide(
        topology: topology,
        initialMoments: initialMoments,
        side: side,
      );

      // مسند متصل بكابولي
      if (edge == EdgeCondition.cantilever) {
        final cant = input.cantileverFor(side);
        if (cant != null) {
          final mCant = cant.supportMomentKnPerM(
            designLoadN,
            source: input.cantileverMomentSource,
            givenMomentKnM: input.additionalSupportMomentKnM,
          );
          final governingM = math.max(
            math.max(mSlabInit, mCant),
            input.additionalSupportMomentKnM,
          );
          supportMomentBySide[side] = governingM;
          balances.add(
            SupportBalanceDetail(
              side: side,
              axisDirection: axis,
              neighborLabel: cant.label,
              isCantileverSupport: true,
              mSlabInitial: mSlabInit,
              mNeighborInitial: mCant,
              kSlab: 0,
              kNeighbor: 0,
              mUnbalanced: (mSlabInit - mCant).abs(),
              mBalancedSupport: governingM,
              slabNegativeReduction: 0.0,
              midSpanMomentIncrease: 0.0,
            ),
          );
          continue;
        }
      }

      // مسند مستمر مع جار مُدخل في شاشة الإدخال السريع
      final neighbor = input.neighborFor(side);
      if (neighbor == null) {
        // إذا لم يُدخل المستخدم بيانات الجار، نُبقي العزم السالب الأولي كما هو دون موازنة
        supportMomentBySide[side] =
            math.max(mSlabInit, input.additionalSupportMomentKnM);
        continue;
      }

      final double mNeighborInit = _computeQuickNeighborNegativeMoment(
        neighbor: neighbor,
        fallbackLoadN: neighborFallbackLoadN ?? designLoadN,
        betaRoundDecimals: betaRoundDecimals,
      );

      final double slabSpanAlongAxis = axis == SlabAxisDirection.horizontalX
          ? topology.widthXM
          : topology.heightYM;
      final bool slabBothContinuous = axis == SlabAxisDirection.horizontalX
          ? (topology.leftEdge.isContinuous && topology.rightEdge.isContinuous)
          : (topology.topEdge.isContinuous && topology.bottomEdge.isContinuous);

      final kSlab = relativeStiffness(
        spanLengthM: slabSpanAlongAxis,
        isBothEndsContinuous: slabBothContinuous,
      );
      final kNeighbor = relativeStiffness(
        spanLengthM: neighbor.spanAlongStripM,
        isBothEndsContinuous: neighbor.isFarEndContinuous,
      );

      final bal = balanceTwoSpanSupport(
        mSlabInitial: mSlabInit,
        mNeighborInitial: mNeighborInit,
        kSlab: kSlab,
        kNeighbor: kNeighbor,
      );

      final finalSupportM =
          math.max(bal.mBalanced, input.additionalSupportMomentKnM);
      supportMomentBySide[side] = finalSupportM;

      balances.add(
        SupportBalanceDetail(
          side: side,
          axisDirection: axis,
          neighborLabel: neighbor.label,
          mSlabInitial: mSlabInit,
          mNeighborInitial: mNeighborInit,
          kSlab: kSlab,
          kNeighbor: kNeighbor,
          mUnbalanced: bal.mUnbalanced,
          mBalancedSupport: finalSupportM,
          slabNegativeReduction: bal.slabReduction,
          midSpanMomentIncrease: bal.midSpanIncrease,
          assumedNeighborCaseNumber: _assumedCaseNumber(neighbor),
        ),
      );
    }

    return _compileBalancedResult(
      topology: topology,
      initialMoments: initialMoments,
      supportMomentBySide: supportMomentBySide,
      balances: balances,
    );
  }

  /// رقم Case المفترض للجار (للتحذير) أو null إذا حدّده المستخدم أو أُدخل عزمه مباشرة أو كان اتجاه واحد
  static int? _assumedCaseNumber(NeighborSlabInput neighbor) {
    if (!neighbor.isPanelCaseAssumed ||
        neighbor.overrideNegativeMomentKnM != null) {
      return null;
    }
    final lo =
        math.min(neighbor.spanAlongStripM, neighbor.perpendicularSpanM);
    final hi =
        math.max(neighbor.spanAlongStripM, neighbor.perpendicularSpanM);
    if (hi / lo > 2.0) return null;
    return neighbor.effectivePanelCase.caseNumber;
  }

  /// تقدير العزم السالب الأولي للجار في وضع الإدخال السريع
  static double _computeQuickNeighborNegativeMoment({
    required NeighborSlabInput neighbor,
    required double fallbackLoadN,
    int? betaRoundDecimals,
  }) {
    if (neighbor.overrideNegativeMomentKnM != null) {
      return neighbor.overrideNegativeMomentKnM!;
    }

    final n = neighbor.customDesignLoadN ?? fallbackLoadN;
    final lx = math.min(neighbor.spanAlongStripM, neighbor.perpendicularSpanM);
    final ly = math.max(neighbor.spanAlongStripM, neighbor.perpendicularSpanM);
    final ratio = ly / lx;

    if (ratio > 2.0) {
      final coeff = neighbor.isFarEndContinuous ? 0.063 : 0.086;
      return coeff * n * lx * lx;
    }

    final bool stripIsAlongLongSpan =
        neighbor.spanAlongStripM >= neighbor.perpendicularSpanM;
    final panelCase = neighbor.effectivePanelCase;

    final coeffs = SlabMomentShearTables.getMomentCoefficients(
      panelCase: panelCase,
      lyOverLx: ratio,
      roundBetaDecimals: betaRoundDecimals,
    );
    final beta = stripIsAlongLongSpan
        ? (coeffs.betaSyNeg ?? coeffs.betaSxNeg ?? 0.037)
        : (coeffs.betaSxNeg ?? coeffs.betaSyNeg ?? 0.037);

    return beta * n * lx * lx;
  }

  /// تجميع العزوم النهائية بعد إضافة زيادات منتصف البحر في الاتجاهين القصير والطويل
  static BalancedMomentsResult _compileBalancedResult({
    required ResolvedTopology topology,
    required InitialMomentsResult initialMoments,
    required Map<EdgeSide, double> supportMomentBySide,
    required List<SupportBalanceDetail> balances,
  }) {
    double shortMidIncrease = 0.0;
    double longMidIncrease = 0.0;

    for (final b in balances) {
      final bool isShortSpanAxis =
          (topology.isShortSpanHorizontal &&
                  b.axisDirection == SlabAxisDirection.horizontalX) ||
              (!topology.isShortSpanHorizontal &&
                  b.axisDirection == SlabAxisDirection.verticalY);
      if (isShortSpanAxis) {
        shortMidIncrease += b.midSpanMomentIncrease;
      } else {
        longMidIncrease += b.midSpanMomentIncrease;
      }
    }

    // تحديد أكبر عزم سالب حاكم عند مساند الاتجاه القصير ومساند الاتجاه الطويل
    final List<EdgeSide> shortSpanSupportSides = topology.isShortSpanHorizontal
        ? [EdgeSide.left, EdgeSide.right]
        : [EdgeSide.top, EdgeSide.bottom];
    final List<EdgeSide> longSpanSupportSides = topology.isShortSpanHorizontal
        ? [EdgeSide.top, EdgeSide.bottom]
        : [EdgeSide.left, EdgeSide.right];

    double shortSupMax = 0.0;
    for (final s in shortSpanSupportSides) {
      shortSupMax = math.max(shortSupMax, supportMomentBySide[s] ?? 0.0);
    }

    double longSupMax = 0.0;
    for (final s in longSpanSupportSides) {
      longSupMax = math.max(longSupMax, supportMomentBySide[s] ?? 0.0);
    }

    return BalancedMomentsResult(
      shortMidMomentFinal: initialMoments.msxPos + shortMidIncrease,
      shortSupportMomentFinal: shortSupMax,
      longMidMomentFinal: initialMoments.msyPos + longMidIncrease,
      longSupportMomentFinal: longSupMax,
      supportMomentBySide: supportMomentBySide,
      supportBalances: balances,
    );
  }
}
