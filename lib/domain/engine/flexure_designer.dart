import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../../data/bs8110/bs8110_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_project_settings.dart';

/// مصمم حديد التسليح للانحناء والالتواء وفق Table 4, Table 5, Table 3.25, Table 1, Table 2
class FlexureDesigner {
  FlexureDesigner._();

  /// تصميم مقطع واحد (منتصف بحر أو مسند مستمر)
  static SectionReinforcementDesign designSection({
    required String zoneId,
    required String zoneTitleAr,
    required String directionAr,
    required bool isTopSteel,
    required double designMomentKnM,
    required double effectiveDepthMm,
    required double overallDepthHMm,
    required SlabProjectSettings settings,
  }) {
    const double b = AppConstants.stripWidth;
    final double fcu = settings.fcu;
    final double fy = settings.fy;
    final int barDia = settings.barDiameterPhi.round();

    final double asMin = FlexureTables.minSolidSlabSteelArea(
      bMm: b,
      hMm: overallDepthHMm,
      fy: fy,
    );

    final double mOverBd2 =
        (designMomentKnM * 1e6) / (b * effectiveDepthMm * effectiveDepthMm);
    final table4Row = FlexureTables.getTable4Row(fcu);

    double fyAsOverBd = 0.0;
    double asReq = 0.0;
    double asComp = 0.0;
    bool usedLimiting = true;
    bool isDoubly = false;
    bool compMayNotYield = false;

    if (designMomentKnM <= 1e-6) {
      fyAsOverBd = 0.0;
      asReq = 0.0;
    } else if (mOverBd2 <= table4Row.maxMOverBd2) {
      usedLimiting = mOverBd2 <= table4Row.limitingMOverBd2;
      fyAsOverBd = FlexureTables.calculateSinglyFyAsOverBd(
        fcu: fcu,
        mOverBd2: mOverBd2,
      )!;
      asReq = (fyAsOverBd * b * effectiveDepthMm) / fy;
    } else {
      // تجاوز الحد الأقصى لـ Table 4 -> التحويل لـ Table 5 (تسليح مزدوج عند x/d = 0.5)
      isDoubly = true;
      usedLimiting = false;
      final dPrime = settings.clearCoverC + (settings.barDiameterPhi / 2.0);
      final doubly = FlexureTables.calculateDoublyReinforced(
        xOverD: 0.5,
        fcu: fcu.round().clamp(20, 50),
        fy: fy,
        mOverBd2: mOverBd2,
        bMm: b,
        dMm: effectiveDepthMm,
        dPrimeMm: dPrime,
      );
      asComp = doubly.ascMm2;
      asReq = doubly.astMm2;
      fyAsOverBd = (fy * asReq) / (b * effectiveDepthMm);

      // Table 5 يفترض خضوع حديد الضغط: يجب ألا يتجاوز d'/d الحد المسموح عند x/d = 0.5
      final double maxDPrimeRatio =
          FlexureTables.maxDPrimeOverD(xOverD: 0.5, fy: fy);
      compMayNotYield = (dPrime / effectiveDepthMm) > maxDPrimeRatio + 1e-9;
    }

    final double asGov = math.max(asReq, asMin);
    final double maxSpacing = math.min(3.0 * effectiveDepthMm, 750.0);

    final countSel = ReinforcementTables.selectBarCount(
      requiredAreaMm2PerM: asGov,
      diameterMm: barDia,
      maxSpacingMm: maxSpacing,
      minCount: 4,
    );

    final spacingSel = ReinforcementTables.selectBarSpacing(
      requiredAreaMm2PerM: asGov,
      diameterMm: barDia,
      maxSpacingMm: maxSpacing,
    );

    final bool spacingSafe = countSel.approximateSpacingMm <= maxSpacing + 1e-6;

    // حديد الضغط (الوجه المقابل) عند تجاوز M/bd² للحد الأقصى في Table 4
    BarCountSelection? compSel;
    if (isDoubly && asComp > 1e-6) {
      compSel = ReinforcementTables.selectBarCount(
        requiredAreaMm2PerM: asComp,
        diameterMm: barDia,
        maxSpacingMm: maxSpacing,
        minCount: 4,
      );
    }

    return SectionReinforcementDesign(
      zoneId: zoneId,
      zoneTitleAr: zoneTitleAr,
      directionAr: directionAr,
      isTopSteel: isTopSteel,
      designMomentKnM: designMomentKnM,
      effectiveDepthMm: effectiveDepthMm,
      mOverBd2: mOverBd2,
      fyAsOverBd: fyAsOverBd,
      usedLimitingFormula: usedLimiting,
      requiresDoublyReinforced: isDoubly,
      asRequiredMm2: asReq,
      asMinMm2: asMin,
      asGoverningMm2: asGov,
      compressionSteelMm2: asComp,
      compressionBarSelection: compSel,
      compressionSteelMayNotYield: compMayNotYield,
      barCountSelection: countSel,
      barSpacingSelection: spacingSel,
      maxSpacingAllowedMm: maxSpacing,
      isSpacingSafe: spacingSafe,
      isAreaSufficient: countSel.isSufficient && (compSel?.isSufficient ?? true),
    );
  }

  /// تصميم الحديد العلوي عند المساند غير المستمرة وفق قاعدة الشرح والكود:
  /// As,sup = max(50% * As,mid , As,min)
  static SectionReinforcementDesign designDiscontinuousSupportSteel({
    required String zoneId,
    required String zoneTitleAr,
    required String directionAr,
    required double midSpanAsRequiredMm2,
    required double effectiveDepthMm,
    required double overallDepthHMm,
    required SlabProjectSettings settings,
  }) {
    const double b = AppConstants.stripWidth;
    final int barDia = settings.barDiameterPhi.round();

    final double asMin = FlexureTables.minSolidSlabSteelArea(
      bMm: b,
      hMm: overallDepthHMm,
      fy: settings.fy,
    );

    final double halfMid = 0.5 * midSpanAsRequiredMm2;
    final double asGov = math.max(halfMid, asMin);
    final double maxSpacing = math.min(3.0 * effectiveDepthMm, 750.0);

    final countSel = ReinforcementTables.selectBarCount(
      requiredAreaMm2PerM: asGov,
      diameterMm: barDia,
      maxSpacingMm: maxSpacing,
      minCount: 4,
    );

    final spacingSel = ReinforcementTables.selectBarSpacing(
      requiredAreaMm2PerM: asGov,
      diameterMm: barDia,
      maxSpacingMm: maxSpacing,
    );

    return SectionReinforcementDesign(
      zoneId: zoneId,
      zoneTitleAr: zoneTitleAr,
      directionAr: directionAr,
      isTopSteel: true,
      isDiscontinuousSupportRule: true,
      designMomentKnM: 0.0,
      effectiveDepthMm: effectiveDepthMm,
      mOverBd2: 0.0,
      fyAsOverBd: 0.0,
      usedLimitingFormula: true,
      requiresDoublyReinforced: false,
      asRequiredMm2: halfMid,
      asMinMm2: asMin,
      asGoverningMm2: asGov,
      barCountSelection: countSel,
      barSpacingSelection: spacingSel,
      maxSpacingAllowedMm: maxSpacing,
      isSpacingSafe: countSel.approximateSpacingMm <= maxSpacing + 1e-6,
      isAreaSufficient: countSel.isSufficient,
    );
  }

  /// حساب تفاصيل تسليح الالتواء عند الأركان وفق BS 8110 (Clause 3.5.3.5)
  static TorsionReinforcementDetail designCornerTorsion({
    required ResolvedTopology topology,
    required double shortMidAsGoverningMm2,
    required int barDiameterMm,
  }) {
    final bool needsTorsion =
        (topology.mixedCornersCount > 0 || topology.freeCornersCount > 0) &&
            topology.spanningType.index == 0; // Two-way only

    final double stripLenMm = (topology.shortSpanLxM * 1000.0) / 5.0;
    final double asMixed = (3.0 / 8.0) * shortMidAsGoverningMm2;
    final double asFree = (3.0 / 4.0) * shortMidAsGoverningMm2;

    final double maxCornerAs =
        topology.freeCornersCount > 0 ? asFree : asMixed;
    final spacingSel = ReinforcementTables.selectBarSpacing(
      requiredAreaMm2PerM: maxCornerAs,
      diameterMm: barDiameterMm,
      maxSpacingMm: 250.0,
    );

    return TorsionReinforcementDetail(
      isRequired: needsTorsion,
      mixedCornersCount: topology.mixedCornersCount,
      freeCornersCount: topology.freeCornersCount,
      stripLengthMm: stripLenMm,
      asMixedCornerMm2: asMixed,
      asFreeCornerMm2: asFree,
      recommendedTopMeshNotation:
          spacingSel?.standardNotation ?? 'Ø$barDiameterMm @ 250 mm',
    );
  }
}
