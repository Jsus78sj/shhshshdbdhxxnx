import '../../core/constants/design_mode.dart';
import '../../core/math/math_utils.dart';
import '../../data/bs8110/bs8110_tables.dart';
import 'slab_enums.dart';
import 'slab_geometry_models.dart';
import 'slab_project_settings.dart';

/// سجل خطوة واحدة من خطوات الحل الأكاديمي التفصيلي (جاهز للعرض في الواجهة والـ PDF)
class DesignStepRecord {
  final int stepNumber;
  final String titleAr;
  final String subtitleEn;
  final String descriptionAr;
  final List<String> latexFormulas;
  final String? tableReference;
  final Map<String, String> keyValues;
  final String? warningNoteAr;

  const DesignStepRecord({
    required this.stepNumber,
    required this.titleAr,
    required this.subtitleEn,
    required this.descriptionAr,
    this.latexFormulas = const [],
    this.tableReference,
    this.keyValues = const {},
    this.warningNoteAr,
  });
}

/// نتيجة تحليل الطوبولوجية وشروط الاستناد للبلاطة
class ResolvedTopology {
  final String slabId;
  final SlabCellType cellType;
  final double widthXM;
  final double heightYM;
  final double shortSpanLxM;
  final double longSpanLyM;
  final double lyOverLx;

  /// هل البحر القصير lx يقع على المحور الأفقي (X) أم الرأسي (Y)؟
  final bool isShortSpanHorizontal;
  final SlabSpanningType spanningType;
  final TwoWayPanelCase? twoWayCase;

  final EdgeCondition topEdge;
  final EdgeCondition bottomEdge;
  final EdgeCondition leftEdge;
  final EdgeCondition rightEdge;

  /// عدد الأركان المختلطة (حافة مستمرة + حافة غير مستمرة) والأركان الحرة (حافتان غير مستمرتين)
  final int mixedCornersCount;
  final int freeCornersCount;

  /// ملاحظة تُملأ للبلاطة المربعة عندما تختلف الحالة باختلاف تسمية الحواف.
  final String? squareOrientationNoteAr;

  const ResolvedTopology({
    required this.slabId,
    required this.cellType,
    required this.widthXM,
    required this.heightYM,
    required this.shortSpanLxM,
    required this.longSpanLyM,
    required this.lyOverLx,
    required this.isShortSpanHorizontal,
    required this.spanningType,
    required this.twoWayCase,
    required this.topEdge,
    required this.bottomEdge,
    required this.leftEdge,
    required this.rightEdge,
    required this.mixedCornersCount,
    required this.freeCornersCount,
    this.squareOrientationNoteAr,
  });

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

  /// عدد الحواف المستمرة الكلي
  int get continuousEdgesCount {
    int count = 0;
    if (topEdge.isContinuous) count++;
    if (bottomEdge.isContinuous) count++;
    if (leftEdge.isContinuous) count++;
    if (rightEdge.isContinuous) count++;
    return count;
  }

  /// هل البحر القصير lx مستمر على أحد طرفيه (أي هل إحدى الحافتين الطويلتين مستمرة)؟
  bool get isShortSpanContinuous {
    if (isShortSpanHorizontal) {
      // البحر القصير أفقي => طرفاه هما الحافة اليسرى واليمنى (الحافتان الطويلتان)
      return leftEdge.isContinuous || rightEdge.isContinuous;
    } else {
      // البحر القصير رأسي => طرفاه هما الحافة العلوية والسفلية (الحافتان الطويلتان)
      return topEdge.isContinuous || bottomEdge.isContinuous;
    }
  }

  /// هل البحر الطويل ly مستمر على أحد طرفيه (أي هل إحدى الحافتين القصيرتين مستمرة)؟
  bool get isLongSpanContinuous {
    if (isShortSpanHorizontal) {
      return topEdge.isContinuous || bottomEdge.isContinuous;
    } else {
      return leftEdge.isContinuous || rightEdge.isContinuous;
    }
  }
}

/// نتيجة حساب الأحمال والأعماق الفعالة
class LoadCalculationResult {
  final double baseDesignLoadN;
  final double fillLoadAddedN;
  final double selfWeightDeltaN;
  final double finalDesignLoadN;
  final double overallDepthHMm;
  final double dxMm;
  final double dyMm;

  const LoadCalculationResult({
    required this.baseDesignLoadN,
    required this.fillLoadAddedN,
    required this.selfWeightDeltaN,
    required this.finalDesignLoadN,
    required this.overallDepthHMm,
    required this.dxMm,
    required this.dyMm,
  });
}

/// نتيجة حساب العزوم الأولية قبل الموازنة
class InitialMomentsResult {
  final double? betaSxNeg;
  final double betaSxPos;
  final double? betaSyNeg;
  final double betaSyPos;
  final InterpolationTrace? betaSxNegTrace;
  final InterpolationTrace? betaSxPosTrace;

  final double nLx2;
  final double msxPos;
  final double msxNeg;
  final double msyPos;
  final double msyNeg;

  /// عزوم الكوابيل المجاورة (إن وُجدت) لكل حافة
  final Map<EdgeSide, double> cantileverMomentsBySide;

  const InitialMomentsResult({
    required this.betaSxNeg,
    required this.betaSxPos,
    required this.betaSyNeg,
    required this.betaSyPos,
    required this.betaSxNegTrace,
    required this.betaSxPosTrace,
    required this.nLx2,
    required this.msxPos,
    required this.msxNeg,
    required this.msyPos,
    required this.msyNeg,
    this.cantileverMomentsBySide = const {},
  });
}

/// تفاصيل موازنة العزم السالب عند مسند مستمر واحد
class SupportBalanceDetail {
  final EdgeSide side;
  final SlabAxisDirection axisDirection;
  final String neighborLabel;
  final bool isCantileverSupport;

  final double mSlabInitial;
  final double mNeighborInitial;
  final double kSlab;
  final double kNeighbor;
  final double mUnbalanced;
  final double mBalancedSupport;

  /// مقدار انخفاض العزم السالب للبلاطة المدروسة (>= 0؛ وإذا ارتفع يكون 0)
  final double slabNegativeReduction;

  /// الزيادة المضافة إلى العزم الموجب بمنتصف البحر (= 0.5 * slabNegativeReduction)
  final double midSpanMomentIncrease;

  /// رقم Case المفترض للجار في الوضع السريع عندما لم يحدّده المستخدم (null = محدّد أو غير لازم)
  final int? assumedNeighborCaseNumber;

  const SupportBalanceDetail({
    required this.side,
    required this.axisDirection,
    required this.neighborLabel,
    this.isCantileverSupport = false,
    required this.mSlabInitial,
    required this.mNeighborInitial,
    required this.kSlab,
    required this.kNeighbor,
    required this.mUnbalanced,
    required this.mBalancedSupport,
    required this.slabNegativeReduction,
    required this.midSpanMomentIncrease,
    this.assumedNeighborCaseNumber,
  });
}

/// العزوم النهائية بعد موازنة جميع المساند المستمرة
class BalancedMomentsResult {
  final double shortMidMomentFinal;
  final double shortSupportMomentFinal;
  final double longMidMomentFinal;
  final double longSupportMomentFinal;

  /// العزوم السالبة النهائية لكل حافة على حدة (لعرض مخطط الشرائح بدقة)
  final Map<EdgeSide, double> supportMomentBySide;
  final List<SupportBalanceDetail> supportBalances;

  const BalancedMomentsResult({
    required this.shortMidMomentFinal,
    required this.shortSupportMomentFinal,
    required this.longMidMomentFinal,
    required this.longSupportMomentFinal,
    required this.supportMomentBySide,
    required this.supportBalances,
  });
}

/// نتيجة تصميم حديد التسليح لمقطع واحد (منتصف بحر أو مسند)
class SectionReinforcementDesign {
  final String zoneId;
  final String zoneTitleAr;
  final String directionAr;
  final bool isTopSteel;
  final bool isDiscontinuousSupportRule;

  final double designMomentKnM;
  final double effectiveDepthMm;
  final double mOverBd2;
  final double fyAsOverBd;
  final bool usedLimitingFormula;
  final bool requiresDoublyReinforced;

  final double asRequiredMm2;
  final double asMinMm2;
  final double asGoverningMm2;
  final double compressionSteelMm2;

  /// أسياخ حديد الضغط المختارة (Table 1) عند تجاوز M/bd² للحد الأقصى؛ null إن لم يلزم
  final BarCountSelection? compressionBarSelection;

  /// d'/d أكبر من الحد المسموح في Table 5 (حديد الضغط قد لا يصل إلى الخضوع)
  final bool compressionSteelMayNotYield;

  final BarCountSelection barCountSelection;
  final BarSpacingSelection? barSpacingSelection;
  final double maxSpacingAllowedMm;
  final bool isSpacingSafe;

  /// false إذا كان أقصى عدد أسياخ لا يكفي لتوفير المساحة المطلوبة (شد أو ضغط)
  final bool isAreaSufficient;

  const SectionReinforcementDesign({
    required this.zoneId,
    required this.zoneTitleAr,
    required this.directionAr,
    required this.isTopSteel,
    this.isDiscontinuousSupportRule = false,
    required this.designMomentKnM,
    required this.effectiveDepthMm,
    required this.mOverBd2,
    required this.fyAsOverBd,
    required this.usedLimitingFormula,
    required this.requiresDoublyReinforced,
    required this.asRequiredMm2,
    required this.asMinMm2,
    required this.asGoverningMm2,
    this.compressionSteelMm2 = 0.0,
    this.compressionBarSelection,
    this.compressionSteelMayNotYield = false,
    required this.barCountSelection,
    required this.barSpacingSelection,
    required this.maxSpacingAllowedMm,
    required this.isSpacingSafe,
    this.isAreaSufficient = true,
  });

  /// نسبة حديد الضغط المقدَّم 100·A's,prov/(b·d) (0 إذا لا يوجد حديد ضغط)
  double get compressionSteelProvidedPercent {
    final sel = compressionBarSelection;
    if (sel == null || effectiveDepthMm <= 0) return 0.0;
    return (100.0 * sel.areaProvidedMm2) / (1000.0 * effectiveDepthMm);
  }
}

/// تفاصيل تسليح الالتواء عند أركان البلاطة (BS 8110 Clause 3.5.3.5)
class TorsionReinforcementDetail {
  final bool isRequired;
  final int mixedCornersCount;
  final int freeCornersCount;
  final double stripLengthMm; // lx / 5
  final double asMixedCornerMm2; // 3/8 Asx_mid
  final double asFreeCornerMm2; // 3/4 Asx_mid
  final String recommendedTopMeshNotation;

  const TorsionReinforcementDetail({
    required this.isRequired,
    required this.mixedCornersCount,
    required this.freeCornersCount,
    required this.stripLengthMm,
    required this.asMixedCornerMm2,
    required this.asFreeCornerMm2,
    required this.recommendedTopMeshNotation,
  });
}

/// نتيجة فحص الهطول (Serviceability Limit State — Deflection)
class DeflectionCheckResult {
  final DesignCalculationMode modeUsed;
  final double spanMm;
  final double effectiveDepthMm;
  final double mOverBd2;
  final double serviceStressFs;
  final double rawModificationFactor;
  final double tensionModificationFactor;
  final double compressionModificationFactor;
  final double basicRatioBR;
  final double allowableSpanDepthRatio;
  final double actualSpanDepthRatio;
  final double dMinRequiredMm;
  final bool isSafe;

  /// السماكة المقترحة (مقربة لأعلى 10 mm) إذا كان الهطول غير آمن
  final double? suggestedOverallDepthHMm;

  /// نسبة حديد الضغط البديلة المقترحة من Table 3.11 في حال الإبقاء على السماكة
  final double? suggestedCompressionSteelPercent;

  /// ملاحظة مقارنة بين وضع الشرح ووضع الكود الصارم عند وجود فرق
  final String? comparativeModeNoteAr;

  const DeflectionCheckResult({
    required this.modeUsed,
    required this.spanMm,
    required this.effectiveDepthMm,
    required this.mOverBd2,
    required this.serviceStressFs,
    required this.rawModificationFactor,
    required this.tensionModificationFactor,
    required this.compressionModificationFactor,
    required this.basicRatioBR,
    required this.allowableSpanDepthRatio,
    required this.actualSpanDepthRatio,
    required this.dMinRequiredMm,
    required this.isSafe,
    this.suggestedOverallDepthHMm,
    this.suggestedCompressionSteelPercent,
    this.comparativeModeNoteAr,
  });
}

/// نتيجة فحص القص (Ultimate Limit State — Shear)
class ShearCheckResult {
  final double? betaVxCont;
  final double? betaVxDisc;
  final double? betaVyCont;
  final double? betaVyDisc;
  final double governingBetaV;
  final String governingEdgeAr;

  final double vMaxKnPerM;
  final double governingDepthMm;
  final double designShearStressV;
  final double tensionSteelPercent;
  final double concreteShearStressVc;
  final SolidSlabShearCheckResult table316Result;

  const ShearCheckResult({
    required this.betaVxCont,
    required this.betaVxDisc,
    required this.betaVyCont,
    required this.betaVyDisc,
    required this.governingBetaV,
    required this.governingEdgeAr,
    required this.vMaxKnPerM,
    required this.governingDepthMm,
    required this.designShearStressV,
    required this.tensionSteelPercent,
    required this.concreteShearStressVc,
    required this.table316Result,
  });

  bool get isSafe => table316Result.isSafeWithoutShearSteel;
}

/// صف ملخص التسليح المطابق لجدول الشرح الجامعي
class SlabReinforcementSummaryRow {
  final String slabId;
  final String shortMidLecture;
  final String shortSupportLecture;
  final String longMidLecture;
  final String longSupportLecture;

  final String shortMidSpacing;
  final String shortSupportSpacing;
  final String longMidSpacing;
  final String longSupportSpacing;

  /// حديد الحافة غير المستمرة عندما يكون الاتجاه مختلطاً (حافة مستمرة + حافة غير مستمرة).
  /// null إذا لم يكن الاتجاه مختلطاً.
  final String? shortSupportDiscLecture;
  final String? shortSupportDiscSpacing;
  final String? longSupportDiscLecture;
  final String? longSupportDiscSpacing;

  const SlabReinforcementSummaryRow({
    required this.slabId,
    required this.shortMidLecture,
    required this.shortSupportLecture,
    required this.longMidLecture,
    required this.longSupportLecture,
    required this.shortMidSpacing,
    required this.shortSupportSpacing,
    required this.longMidSpacing,
    required this.longSupportSpacing,
    this.shortSupportDiscLecture,
    this.shortSupportDiscSpacing,
    this.longSupportDiscLecture,
    this.longSupportDiscSpacing,
  });

  /// نص حديد المسند القصير كاملاً: الحافة المستمرة، وإن وُجدت حافة غير مستمرة تُذكر معها
  String shortSupportAllLecture() => shortSupportDiscLecture == null
      ? shortSupportLecture
      : '$shortSupportLecture (Cont.) / $shortSupportDiscLecture (Disc.)';

  /// نص حديد المسند الطويل كاملاً (انظر [shortSupportAllLecture])
  String longSupportAllLecture() => longSupportDiscLecture == null
      ? longSupportLecture
      : '$longSupportLecture (Cont.) / $longSupportDiscLecture (Disc.)';
}

/// التقرير الهندسي المتكامل لتصميم بلاطة واحدة
class SlabDesignReport {
  final String slabId;
  final SlabProjectSettings settingsUsed;
  final ResolvedTopology topology;
  final LoadCalculationResult loadResult;
  final InitialMomentsResult initialMoments;
  final BalancedMomentsResult balancedMoments;

  final SectionReinforcementDesign shortMidSteel;
  final SectionReinforcementDesign shortSupportSteel;
  final SectionReinforcementDesign longMidSteel;
  final SectionReinforcementDesign longSupportSteel;

  /// حديد علوي للحافة غير المستمرة (50% As,mid ≥ As,min) عندما يكون اتجاه الشريحة
  /// مختلطاً (حافة مستمرة + حافة غير مستمرة). null إذا لم يكن الاتجاه مختلطاً؛
  /// وعند اتجاه كل حوافه غير مستمرة يكون [shortSupportSteel]/[longSupportSteel] نفسه قاعدة الحافة غير المستمرة.
  final SectionReinforcementDesign? shortDiscontinuousEdgeSteel;
  final SectionReinforcementDesign? longDiscontinuousEdgeSteel;

  /// الكوابيل المتصلة بحواف هذه البلاطة (لرسم المسقط وتصميم الكابولي)
  final Map<EdgeSide, CantileverAttachment> cantilevers;

  /// تصميم كل كابولي متصل (عزم، حديد علوي، هطول B.R = 7، قص V = n·lc) مفهرساً بحافة البلاطة
  final Map<EdgeSide, CantileverDesignReport> cantileverReports;

  final TorsionReinforcementDetail torsionDetail;
  final DeflectionCheckResult deflectionCheck;
  final ShearCheckResult shearCheck;
  final SlabReinforcementSummaryRow summaryRow;

  final List<DesignStepRecord> steps;
  final List<String> warningsAr;

  const SlabDesignReport({
    required this.slabId,
    required this.settingsUsed,
    required this.topology,
    required this.loadResult,
    required this.initialMoments,
    required this.balancedMoments,
    required this.shortMidSteel,
    required this.shortSupportSteel,
    required this.longMidSteel,
    required this.longSupportSteel,
    this.shortDiscontinuousEdgeSteel,
    this.longDiscontinuousEdgeSteel,
    this.cantilevers = const {},
    this.cantileverReports = const {},
    required this.torsionDetail,
    required this.deflectionCheck,
    required this.shearCheck,
    required this.summaryRow,
    required this.steps,
    this.warningsAr = const [],
  });

  /// جميع تصاميم الحديد (تشمل حديد الحافة غير المستمرة في الاتجاهات المختلطة)
  List<SectionReinforcementDesign> get allSteelDesigns => [
        shortMidSteel,
        shortSupportSteel,
        if (shortDiscontinuousEdgeSteel != null) shortDiscontinuousEdgeSteel!,
        longMidSteel,
        longSupportSteel,
        if (longDiscontinuousEdgeSteel != null) longDiscontinuousEdgeSteel!,
      ];

  bool get isFlexureSpacingSafe =>
      allSteelDesigns.every((d) => d.isSpacingSafe);

  /// هل تكفي أقصى أعداد الأسياخ لتوفير المساحات المطلوبة (شد وضغط) في كل المقاطع؟
  bool get isFlexureAreaSufficient =>
      allSteelDesigns.every((d) => d.isAreaSufficient);

  /// التفاصيل الإنشائية سليمة: المسافات ≤ 3d والمساحات المقدَّمة كافية
  bool get isFlexureDetailingSafe =>
      isFlexureSpacingSafe && isFlexureAreaSufficient;

  /// هل يوجد أي مقطع يحتاج حديد ضغط (M/bd² تجاوز الحد الأقصى لـ Table 4)؟
  bool get requiresCompressionSteel =>
      allSteelDesigns.any((d) => d.requiresDoublyReinforced);

  bool get overallIsSafe =>
      deflectionCheck.isSafe && shearCheck.isSafe && isFlexureDetailingSafe;

  /// هل كل الكوابيل المتصلة بالبلاطة آمنة (هطول وقص وتفاصيل تسليح)؟ true إن لم يوجد كابولي.
  /// منفصلة عن [overallIsSafe] التي تخص البلاطة نفسها؛ وتظهر نتائجها في [warningsAr].
  bool get cantileversAreSafe =>
      cantileverReports.values.every((r) => r.overallIsSafe);

  /// الكابولي المتصل بحافة معينة (إن وُجد)
  CantileverDesignReport? cantileverReportOn(EdgeSide side) =>
      cantileverReports[side];

  /// هل الحافة تقع على اتجاه البحر القصير (أي أن حديدها العلوي يعمل بالاتجاه القصير)؟
  bool isShortDirectionEdge(EdgeSide side) {
    final bool isHorizontalBar =
        side == EdgeSide.left || side == EdgeSide.right;
    return (topology.isShortSpanHorizontal && isHorizontalBar) ||
        (!topology.isShortSpanHorizontal && !isHorizontalBar);
  }

  /// تصميم الحديد العلوي الخاص بحافة معينة:
  /// - حافة مستمرة (أو كابولي): تصميم المساند المستمرة للاتجاه
  /// - حافة غير مستمرة: قاعدة 50% As,mid ≥ As,min (حتى عندما يكون الاتجاه مختلطاً)
  SectionReinforcementDesign topSteelForEdge(EdgeSide side) {
    final bool isShort = isShortDirectionEdge(side);
    final SectionReinforcementDesign main =
        isShort ? shortSupportSteel : longSupportSteel;
    final SectionReinforcementDesign? disc =
        isShort ? shortDiscontinuousEdgeSteel : longDiscontinuousEdgeSteel;

    if (topology.edgeFor(side).isContinuous) return main;
    if (main.isDiscontinuousSupportRule) return main;
    return disc ?? main;
  }

  /// نص التسليح العلوي لحافة معينة بالصيغة المطلوبة (عدد الأسياخ أو المسافات)
  String topLabelForEdge(EdgeSide side, {required bool lecture}) {
    final d = topSteelForEdge(side);
    if (lecture) return d.barCountSelection.lectureNotation;
    return d.barSpacingSelection?.standardNotation ??
        d.barCountSelection.lectureNotation;
  }
}

/// نتيجة تصميم كابولي (شريحة بعرض 1 m) مستقل: عزم، حديد علوي، هطول، قص
class CantileverDesignReport {
  final String label;
  final CantileverAttachment cantilever;
  final SlabProjectSettings settingsUsed;
  final ResolvedTopology topology;
  final LoadCalculationResult loadResult;
  final CantileverMomentSource momentSource;

  /// العزم التصميمي عند مسند الكابولي (kN.m/m)
  final double supportMomentKnM;

  /// العزم الستاتيكي n·lc²/2 للمقارنة (kN.m/m)
  final double staticMomentKnM;

  final SectionReinforcementDesign topSteel;

  /// حديد التوزيع السفلي/العرضي (الحد الأدنى As,min)
  final SectionReinforcementDesign distributionSteel;

  final DeflectionCheckResult deflectionCheck;
  final ShearCheckResult shearCheck;

  /// طول امتداد الحديد العلوي داخل البلاطة المجاورة (1.5 L)
  final double anchorageInsideSlabM;

  final List<String> warningsAr;

  const CantileverDesignReport({
    required this.label,
    required this.cantilever,
    required this.settingsUsed,
    required this.topology,
    required this.loadResult,
    required this.momentSource,
    required this.supportMomentKnM,
    required this.staticMomentKnM,
    required this.topSteel,
    required this.distributionSteel,
    required this.deflectionCheck,
    required this.shearCheck,
    required this.anchorageInsideSlabM,
    this.warningsAr = const [],
  });

  bool get overallIsSafe =>
      deflectionCheck.isSafe &&
      shearCheck.isSafe &&
      topSteel.isSpacingSafe &&
      topSteel.isAreaSufficient &&
      distributionSteel.isAreaSufficient;
}
