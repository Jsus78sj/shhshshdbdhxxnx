import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/design_mode.dart';
import '../../data/bs8110/slab_moment_shear_tables.dart';
import '../../domain/engine/engineering_engine.dart';

/// حالة نموذج الإدخال السريع (بلاطة واحدة + جيرانها)
class SingleSlabFormState {
  final String slabId;
  final double widthXM;
  final double heightYM;
  final SlabCellType cellType;

  final EdgeCondition topEdge;
  final EdgeCondition bottomEdge;
  final EdgeCondition leftEdge;
  final EdgeCondition rightEdge;

  final NeighborSlabInput? topNeighbor;
  final NeighborSlabInput? bottomNeighbor;
  final NeighborSlabInput? leftNeighbor;
  final NeighborSlabInput? rightNeighbor;

  final CantileverAttachment? topCantilever;
  final CantileverAttachment? bottomCantilever;
  final CantileverAttachment? leftCantilever;
  final CantileverAttachment? rightCantilever;

  /// هل يدخل المستخدم الحمل التصميمي n مباشرة أم يحسبه من 1.4 Gk + 1.6 Qk؟
  final bool useDirectLoadN;
  final double designLoadN;
  final double characteristicDeadGk;
  final double characteristicImposedQk;

  final double overallDepthH;
  final double clearCoverC;
  final int barDiameterPhi;
  final int fcu;
  final double fy;

  final double fillDepthM;
  final double fillUnitWeightKnM3;
  final double additionalSupportMomentKnM;

  /// مصدر عزم الكابولي: ستاتيكي n·l²/2 أو عزم المسند المعطى في السؤال (additionalSupportMomentKnM)
  final CantileverMomentSource cantileverMomentSource;
  final bool autoAdjustDepthInStrictMode;

  /// عدّاد داخلي لتحديث حقول النصوص عند تحميل قالب جاهز
  final int presetRevision;

  const SingleSlabFormState({
    this.slabId = 'S7',
    this.widthXM = 4.10,
    this.heightYM = 4.20,
    this.cellType = SlabCellType.normalSolid,
    this.topEdge = EdgeCondition.continuous,
    this.bottomEdge = EdgeCondition.continuous,
    this.leftEdge = EdgeCondition.discontinuousFree,
    this.rightEdge = EdgeCondition.discontinuousDropped,
    this.topNeighbor = const NeighborSlabInput(
      label: 'S6',
      spanAlongStripM: 4.20,
      perpendicularSpanM: 4.10,
      isFarEndContinuous: false,
      panelCase: TwoWayPanelCase.oneShortEdgeDiscontinuous,
    ),
    this.bottomNeighbor = const NeighborSlabInput(
      label: 'S8',
      spanAlongStripM: 4.40,
      perpendicularSpanM: 4.10,
      isFarEndContinuous: true,
      panelCase: TwoWayPanelCase.oneLongEdgeDiscontinuous,
    ),
    this.leftNeighbor,
    this.rightNeighbor,
    this.topCantilever,
    this.bottomCantilever,
    this.leftCantilever,
    this.rightCantilever,
    this.useDirectLoadN = true,
    this.designLoadN = AppConstants.defaultDesignLoad,
    this.characteristicDeadGk = 6.50,
    this.characteristicImposedQk = 1.50,
    this.overallDepthH = AppConstants.defaultOverallDepth,
    this.clearCoverC = AppConstants.defaultClearCover,
    this.barDiameterPhi = 10,
    this.fcu = 25,
    this.fy = AppConstants.defaultFy,
    this.fillDepthM = 0.0,
    this.fillUnitWeightKnM3 = 18.5,
    this.additionalSupportMomentKnM = 0.0,
    this.cantileverMomentSource = CantileverMomentSource.statics,
    this.autoAdjustDepthInStrictMode = false,
    this.presetRevision = 0,
  });

  double get effectiveDesignLoadN => useDirectLoadN
      ? designLoadN
      : LoadCalculator.calculateFactoredUltimateLoad(
          characteristicDeadLoadGk: characteristicDeadGk,
          characteristicImposedLoadQk: characteristicImposedQk,
        );

  EdgeCondition edgeFor(EdgeSide side) {
    switch (side) {
      case EdgeSide.top:
        return topEdge;
      case EdgeSide.bottom:
        return bottomEdge;
      case EdgeSide.left:
        return leftEdge;
      case EdgeSide.right:
        return rightEdge;
    }
  }

  NeighborSlabInput? neighborFor(EdgeSide side) {
    switch (side) {
      case EdgeSide.top:
        return topNeighbor;
      case EdgeSide.bottom:
        return bottomNeighbor;
      case EdgeSide.left:
        return leftNeighbor;
      case EdgeSide.right:
        return rightNeighbor;
    }
  }

  CantileverAttachment? cantileverFor(EdgeSide side) {
    switch (side) {
      case EdgeSide.top:
        return topCantilever;
      case EdgeSide.bottom:
        return bottomCantilever;
      case EdgeSide.left:
        return leftCantilever;
      case EdgeSide.right:
        return rightCantilever;
    }
  }

  /// تحويل الحالة إلى مدخلات المحرك الهندسي [SingleSlabInput]
  SingleSlabInput toSingleSlabInput() {
    return SingleSlabInput(
      slabId: slabId.trim().isEmpty ? 'S1' : slabId.trim(),
      widthXM: widthXM,
      heightYM: heightYM,
      cellType: cellType,
      topEdge: topEdge,
      bottomEdge: bottomEdge,
      leftEdge: leftEdge,
      rightEdge: rightEdge,
      topNeighbor: topEdge == EdgeCondition.continuous ? topNeighbor : null,
      bottomNeighbor:
          bottomEdge == EdgeCondition.continuous ? bottomNeighbor : null,
      leftNeighbor: leftEdge == EdgeCondition.continuous ? leftNeighbor : null,
      rightNeighbor:
          rightEdge == EdgeCondition.continuous ? rightNeighbor : null,
      topCantilever: topEdge == EdgeCondition.cantilever ? topCantilever : null,
      bottomCantilever:
          bottomEdge == EdgeCondition.cantilever ? bottomCantilever : null,
      leftCantilever:
          leftEdge == EdgeCondition.cantilever ? leftCantilever : null,
      rightCantilever:
          rightEdge == EdgeCondition.cantilever ? rightCantilever : null,
      fillDepthM: cellType == SlabCellType.droppedSolid ? fillDepthM : 0.0,
      fillUnitWeightKnM3: fillUnitWeightKnM3,
      customDesignLoadN: effectiveDesignLoadN,
      additionalSupportMomentKnM: additionalSupportMomentKnM,
      cantileverMomentSource: cantileverMomentSource,
    );
  }

  SlabProjectSettings toSettings(DesignCalculationMode mode) {
    return SlabProjectSettings(
      designLoadN: effectiveDesignLoadN,
      overallDepthH: overallDepthH,
      clearCoverC: clearCoverC,
      barDiameterPhi: barDiameterPhi.toDouble(),
      fcu: fcu.toDouble(),
      fy: fy,
      calculationMode: mode,
    );
  }

  /// تحليل سريع مباشر للطوبولوجية لعرض التصنيف داخل الرسم التفاعلي أثناء الإدخال
  ResolvedTopology? tryResolvePreviewTopology() {
    if (widthXM <= 0 || heightYM <= 0) return null;
    return TopologyResolver.resolveFromEdges(
      slabId: slabId.trim().isEmpty ? 'S1' : slabId.trim(),
      cellType: cellType,
      widthXM: widthXM,
      heightYM: heightYM,
      topEdge: topEdge,
      bottomEdge: bottomEdge,
      leftEdge: leftEdge,
      rightEdge: rightEdge,
    );
  }

  SingleSlabFormState copyWith({
    String? slabId,
    double? widthXM,
    double? heightYM,
    SlabCellType? cellType,
    EdgeCondition? topEdge,
    EdgeCondition? bottomEdge,
    EdgeCondition? leftEdge,
    EdgeCondition? rightEdge,
    NeighborSlabInput? topNeighbor,
    NeighborSlabInput? bottomNeighbor,
    NeighborSlabInput? leftNeighbor,
    NeighborSlabInput? rightNeighbor,
    CantileverAttachment? topCantilever,
    CantileverAttachment? bottomCantilever,
    CantileverAttachment? leftCantilever,
    CantileverAttachment? rightCantilever,
    bool? useDirectLoadN,
    double? designLoadN,
    double? characteristicDeadGk,
    double? characteristicImposedQk,
    double? overallDepthH,
    double? clearCoverC,
    int? barDiameterPhi,
    int? fcu,
    double? fy,
    double? fillDepthM,
    double? fillUnitWeightKnM3,
    double? additionalSupportMomentKnM,
    CantileverMomentSource? cantileverMomentSource,
    bool? autoAdjustDepthInStrictMode,
    int? presetRevision,
  }) {
    return SingleSlabFormState(
      slabId: slabId ?? this.slabId,
      widthXM: widthXM ?? this.widthXM,
      heightYM: heightYM ?? this.heightYM,
      cellType: cellType ?? this.cellType,
      topEdge: topEdge ?? this.topEdge,
      bottomEdge: bottomEdge ?? this.bottomEdge,
      leftEdge: leftEdge ?? this.leftEdge,
      rightEdge: rightEdge ?? this.rightEdge,
      topNeighbor: topNeighbor ?? this.topNeighbor,
      bottomNeighbor: bottomNeighbor ?? this.bottomNeighbor,
      leftNeighbor: leftNeighbor ?? this.leftNeighbor,
      rightNeighbor: rightNeighbor ?? this.rightNeighbor,
      topCantilever: topCantilever ?? this.topCantilever,
      bottomCantilever: bottomCantilever ?? this.bottomCantilever,
      leftCantilever: leftCantilever ?? this.leftCantilever,
      rightCantilever: rightCantilever ?? this.rightCantilever,
      useDirectLoadN: useDirectLoadN ?? this.useDirectLoadN,
      designLoadN: designLoadN ?? this.designLoadN,
      characteristicDeadGk: characteristicDeadGk ?? this.characteristicDeadGk,
      characteristicImposedQk:
          characteristicImposedQk ?? this.characteristicImposedQk,
      overallDepthH: overallDepthH ?? this.overallDepthH,
      clearCoverC: clearCoverC ?? this.clearCoverC,
      barDiameterPhi: barDiameterPhi ?? this.barDiameterPhi,
      fcu: fcu ?? this.fcu,
      fy: fy ?? this.fy,
      fillDepthM: fillDepthM ?? this.fillDepthM,
      fillUnitWeightKnM3: fillUnitWeightKnM3 ?? this.fillUnitWeightKnM3,
      additionalSupportMomentKnM:
          additionalSupportMomentKnM ?? this.additionalSupportMomentKnM,
      cantileverMomentSource:
          cantileverMomentSource ?? this.cantileverMomentSource,
      autoAdjustDepthInStrictMode:
          autoAdjustDepthInStrictMode ?? this.autoAdjustDepthInStrictMode,
      presetRevision: presetRevision ?? this.presetRevision,
    );
  }
}

/// متحكم حالة نموذج الإدخال السريع (Riverpod)
class SingleSlabFormNotifier extends Notifier<SingleSlabFormState> {
  @override
  SingleSlabFormState build() {
    // يبدأ افتراضياً بمثال البلاطة S7 المرجعية لتسهيل التجربة الفورية
    return const SingleSlabFormState();
  }

  /// تحميل قالب مثال اختبار جامعة عدن — البلاطة S7 مع جارتيها S6 و S8
  void loadExamPresetS7() {
    state = SingleSlabFormState(
      slabId: 'S7',
      widthXM: 4.10,
      heightYM: 4.20,
      cellType: SlabCellType.normalSolid,
      topEdge: EdgeCondition.continuous,
      bottomEdge: EdgeCondition.continuous,
      leftEdge: EdgeCondition.discontinuousFree,
      rightEdge: EdgeCondition.discontinuousDropped,
      topNeighbor: const NeighborSlabInput(
        label: 'S6',
        spanAlongStripM: 4.20,
        perpendicularSpanM: 4.10,
        isFarEndContinuous: false,
        panelCase: TwoWayPanelCase.oneShortEdgeDiscontinuous,
      ),
      bottomNeighbor: const NeighborSlabInput(
        label: 'S8',
        spanAlongStripM: 4.40,
        perpendicularSpanM: 4.10,
        isFarEndContinuous: true,
        panelCase: TwoWayPanelCase.oneLongEdgeDiscontinuous,
      ),
      useDirectLoadN: true,
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10,
      fcu: 25,
      fy: 250.0,
      additionalSupportMomentKnM: 0.0,
      presetRevision: state.presetRevision + 1,
    );
  }

  /// تحميل قالب مثال البلاطة S6 المتصلة بكابولي يساري 1.60m وجارين (S4 يميناً و S7 أسفلاً)
  void loadExamPresetS6WithCantilever() {
    state = SingleSlabFormState(
      slabId: 'S6',
      widthXM: 4.10,
      heightYM: 4.20,
      cellType: SlabCellType.normalSolid,
      topEdge: EdgeCondition.discontinuousFree,
      bottomEdge: EdgeCondition.continuous,
      leftEdge: EdgeCondition.cantilever,
      rightEdge: EdgeCondition.continuous,
      bottomNeighbor: const NeighborSlabInput(
        label: 'S7',
        spanAlongStripM: 4.20,
        perpendicularSpanM: 4.10,
        isFarEndContinuous: true,
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
      ),
      rightNeighbor: const NeighborSlabInput(
        label: 'S4',
        spanAlongStripM: 3.70,
        perpendicularSpanM: 4.20,
        isFarEndContinuous: true,
        panelCase: TwoWayPanelCase.twoShortEdgesDiscontinuous,
      ),
      leftCantilever: const CantileverAttachment(
        side: EdgeSide.left,
        lengthM: 1.60,
        label: 'كابولي يسار S6',
      ),
      // ملاحظة المخطط: عزم مسند الكوابيل المعطى = 1 kN.m/m ويؤخذ عند الموازنة
      additionalSupportMomentKnM: 1.0,
      cantileverMomentSource: CantileverMomentSource.givenSupportMoment,
      useDirectLoadN: true,
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10,
      fcu: 25,
      fy: 250.0,
      presetRevision: state.presetRevision + 1,
    );
  }

  /// إعادة تعيين لنموذج بلاطة بسيطة نظيفة (4 × 4 متر)
  void resetToSimplePanel() {
    state = SingleSlabFormState(
      slabId: 'S1',
      widthXM: 4.00,
      heightYM: 4.50,
      cellType: SlabCellType.normalSolid,
      topEdge: EdgeCondition.discontinuousFree,
      bottomEdge: EdgeCondition.discontinuousFree,
      leftEdge: EdgeCondition.discontinuousFree,
      rightEdge: EdgeCondition.discontinuousFree,
      topNeighbor: null,
      bottomNeighbor: null,
      leftNeighbor: null,
      rightNeighbor: null,
      useDirectLoadN: true,
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10,
      fcu: 25,
      fy: 250.0,
      presetRevision: state.presetRevision + 1,
    );
  }

  void updateSlabId(String value) => state = state.copyWith(slabId: value);
  void updateWidthX(double value) => state = state.copyWith(widthXM: value);
  void updateHeightY(double value) => state = state.copyWith(heightYM: value);
  void updateCellType(SlabCellType type) =>
      state = state.copyWith(cellType: type);

  void updateUseDirectLoad(bool useDirect) =>
      state = state.copyWith(useDirectLoadN: useDirect);
  void updateDesignLoadN(double v) => state = state.copyWith(designLoadN: v);
  void updateGk(double v) => state = state.copyWith(characteristicDeadGk: v);
  void updateQk(double v) => state = state.copyWith(characteristicImposedQk: v);

  void updateOverallDepthH(double v) =>
      state = state.copyWith(overallDepthH: v);
  void updateClearCoverC(double v) => state = state.copyWith(clearCoverC: v);
  void updateBarDiameter(int d) => state = state.copyWith(barDiameterPhi: d);
  void updateFcu(int v) => state = state.copyWith(fcu: v);
  void updateFy(double v) => state = state.copyWith(fy: v);
  void updateFillDepth(double v) => state = state.copyWith(fillDepthM: v);
  void updateFillUnitWeight(double v) =>
      state = state.copyWith(fillUnitWeightKnM3: v);
  void updateAdditionalSupportMoment(double v) =>
      state = state.copyWith(additionalSupportMomentKnM: v);
  void updateCantileverMomentSource(CantileverMomentSource v) =>
      state = state.copyWith(cantileverMomentSource: v);
  void updateAutoAdjustDepth(bool v) =>
      state = state.copyWith(autoAdjustDepthInStrictMode: v);

  /// تحديث حالة حافة واحدة مع إنشاء بيانات جار أو كابولي افتراضية تلقائياً عند الحاجة
  void updateEdgeCondition(EdgeSide side, EdgeCondition condition) {
    final defaultNeighbor = NeighborSlabInput(
      label: 'جار ${side.titleAr}',
      spanAlongStripM:
          (side == EdgeSide.top || side == EdgeSide.bottom)
              ? state.heightYM
              : state.widthXM,
      perpendicularSpanM:
          (side == EdgeSide.top || side == EdgeSide.bottom)
              ? state.widthXM
              : state.heightYM,
      isFarEndContinuous: false,
    );

    final defaultCantilever = CantileverAttachment(
      side: side,
      lengthM: 1.50,
      label: 'كابولي (${side.titleAr})',
    );

    switch (side) {
      case EdgeSide.top:
        state = state.copyWith(
          topEdge: condition,
          topNeighbor: condition == EdgeCondition.continuous
              ? (state.topNeighbor ?? defaultNeighbor)
              : state.topNeighbor,
          topCantilever: condition == EdgeCondition.cantilever
              ? (state.topCantilever ?? defaultCantilever)
              : state.topCantilever,
        );
      case EdgeSide.bottom:
        state = state.copyWith(
          bottomEdge: condition,
          bottomNeighbor: condition == EdgeCondition.continuous
              ? (state.bottomNeighbor ?? defaultNeighbor)
              : state.bottomNeighbor,
          bottomCantilever: condition == EdgeCondition.cantilever
              ? (state.bottomCantilever ?? defaultCantilever)
              : state.bottomCantilever,
        );
      case EdgeSide.left:
        state = state.copyWith(
          leftEdge: condition,
          leftNeighbor: condition == EdgeCondition.continuous
              ? (state.leftNeighbor ?? defaultNeighbor)
              : state.leftNeighbor,
          leftCantilever: condition == EdgeCondition.cantilever
              ? (state.leftCantilever ?? defaultCantilever)
              : state.leftCantilever,
        );
      case EdgeSide.right:
        state = state.copyWith(
          rightEdge: condition,
          rightNeighbor: condition == EdgeCondition.continuous
              ? (state.rightNeighbor ?? defaultNeighbor)
              : state.rightNeighbor,
          rightCantilever: condition == EdgeCondition.cantilever
              ? (state.rightCantilever ?? defaultCantilever)
              : state.rightCantilever,
        );
    }
  }

  void updateNeighbor(EdgeSide side, NeighborSlabInput neighbor) {
    switch (side) {
      case EdgeSide.top:
        state = state.copyWith(topNeighbor: neighbor);
      case EdgeSide.bottom:
        state = state.copyWith(bottomNeighbor: neighbor);
      case EdgeSide.left:
        state = state.copyWith(leftNeighbor: neighbor);
      case EdgeSide.right:
        state = state.copyWith(rightNeighbor: neighbor);
    }
  }

  void updateCantilever(EdgeSide side, CantileverAttachment cantilever) {
    switch (side) {
      case EdgeSide.top:
        state = state.copyWith(topCantilever: cantilever);
      case EdgeSide.bottom:
        state = state.copyWith(bottomCantilever: cantilever);
      case EdgeSide.left:
        state = state.copyWith(leftCantilever: cantilever);
      case EdgeSide.right:
        state = state.copyWith(rightCantilever: cantilever);
    }
  }

  SlabDesignReport runDesign(
    DesignCalculationMode mode, {
    double? overrideDepthHMm,
    bool? overrideAutoAdjust,
  }) {
    final input = state.toSingleSlabInput();
    final baseSettings = state.toSettings(mode);
    final effectiveSettings = overrideDepthHMm != null
        ? baseSettings.copyWith(overallDepthH: overrideDepthHMm)
        : baseSettings;

    // في حال أُعيد التصميم بسماكة مقترحة جديدة، نضيف فرق الوزن الذاتي تلقائياً
    final double deltaSelfWeight = overrideDepthHMm != null
        ? LoadCalculator.calculateSelfWeightDeltaFactored(
            originalDepthHMm: baseSettings.overallDepthH,
            newDepthHMm: overrideDepthHMm,
          )
        : 0.0;

    final adjustedInput = deltaSelfWeight.abs() > 1e-6
        ? SingleSlabInput(
            slabId: input.slabId,
            widthXM: input.widthXM,
            heightYM: input.heightYM,
            cellType: input.cellType,
            topEdge: input.topEdge,
            bottomEdge: input.bottomEdge,
            leftEdge: input.leftEdge,
            rightEdge: input.rightEdge,
            topNeighbor: input.topNeighbor,
            bottomNeighbor: input.bottomNeighbor,
            leftNeighbor: input.leftNeighbor,
            rightNeighbor: input.rightNeighbor,
            topCantilever: input.topCantilever,
            bottomCantilever: input.bottomCantilever,
            leftCantilever: input.leftCantilever,
            rightCantilever: input.rightCantilever,
            fillDepthM: input.fillDepthM,
            fillUnitWeightKnM3: input.fillUnitWeightKnM3,
            customDesignLoadN:
                (input.customDesignLoadN ?? baseSettings.designLoadN) +
                    deltaSelfWeight,
            additionalSupportMomentKnM: input.additionalSupportMomentKnM,
            cantileverMomentSource: input.cantileverMomentSource,
          )
        : input;

    return SlabDesignPipeline.designSingleSlab(
      input: adjustedInput,
      settings: effectiveSettings,
      autoAdjustDepthIfUnsafeInStrictMode:
          overrideAutoAdjust ?? state.autoAdjustDepthInStrictMode,
    );
  }
}

final singleSlabFormProvider =
    NotifierProvider<SingleSlabFormNotifier, SingleSlabFormState>(
  SingleSlabFormNotifier.new,
);

/// سياق التقرير المعروض حالياً في شاشة النتائج (يدعم إعادة الحساب الفوري عند تبديل الوضع أو السماكة)
class ActiveReportContext {
  final SlabDesignReport report;
  final String sourceLabelAr;
  final SlabDesignReport Function(
    DesignCalculationMode newMode, {
    bool autoAdjustDepth,
  }) recompute;

  const ActiveReportContext({
    required this.report,
    required this.sourceLabelAr,
    required this.recompute,
  });
}

class ActiveReportNotifier extends Notifier<ActiveReportContext?> {
  @override
  ActiveReportContext? build() => null;

  void setReport(ActiveReportContext context) {
    state = context;
  }

  void recomputeWithMode(
    DesignCalculationMode newMode, {
    bool autoAdjustDepth = false,
  }) {
    final current = state;
    if (current == null) return;
    final updated = current.recompute(
      newMode,
      autoAdjustDepth: autoAdjustDepth,
    );
    state = ActiveReportContext(
      report: updated,
      sourceLabelAr: current.sourceLabelAr,
      recompute: current.recompute,
    );
  }

  void clear() {
    state = null;
  }
}

final activeReportProvider =
    NotifierProvider<ActiveReportNotifier, ActiveReportContext?>(
  ActiveReportNotifier.new,
);
