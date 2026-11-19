import '../../core/constants/app_constants.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_project_settings.dart';

/// حاسب الأحمال التصميمية والأعماق الفعالة (يدعم البلاطات العادية والمهبطة وتعديل السماكة)
class LoadCalculator {
  LoadCalculator._();

  /// حساب الحمل التصميمي الأقصى وفق BS 8110: n = 1.4 Gk + 1.6 Qk
  static double calculateFactoredUltimateLoad({
    required double characteristicDeadLoadGk,
    required double characteristicImposedLoadQk,
  }) {
    return (1.4 * characteristicDeadLoadGk) +
        (1.6 * characteristicImposedLoadQk);
  }

  /// حساب حمل الردم المضاف للبلاطة المهبطة (مثال السبورة: 0.2 * 18.5 = 3.7 -> 1.4 * 3.7 = 5.18)
  static double calculateDroppedSlabFillFactoredLoad({
    required double fillDepthM,
    double fillUnitWeightKnM3 = 18.5,
  }) {
    if (fillDepthM <= 0) return 0.0;
    return 1.4 * (fillDepthM * fillUnitWeightKnM3);
  }

  /// حساب الزيادة في الوزن الذاتي المصعّد عند تعديل سماكة البلاطة من hOld إلى hNew
  static double calculateSelfWeightDeltaFactored({
    required double originalDepthHMm,
    required double newDepthHMm,
    double concreteUnitWeightKnM3 = AppConstants.concreteUnitWeight,
  }) {
    final deltaHM = (newDepthHMm - originalDepthHMm) / 1000.0;
    if (deltaHM.abs() < 1e-9) return 0.0;
    return 1.4 * (deltaHM * concreteUnitWeightKnM3);
  }

  /// حساب الأحمال النهائية والأعماق الفعالة dx و dy للبلاطة
  static LoadCalculationResult compute({
    required SlabProjectSettings settings,
    required SlabCellType cellType,
    double? customDesignLoadN,
    double fillDepthM = 0.0,
    double fillUnitWeightKnM3 = 18.5,
    double? overrideOverallDepthHMm,
  }) {
    final baseLoad = customDesignLoadN ?? settings.designLoadN;
    final double hOriginal = settings.overallDepthH;
    final double hUsed = overrideOverallDepthHMm ?? hOriginal;

    final double fillDelta = cellType == SlabCellType.droppedSolid
        ? calculateDroppedSlabFillFactoredLoad(
            fillDepthM: fillDepthM,
            fillUnitWeightKnM3: fillUnitWeightKnM3,
          )
        : 0.0;

    final double selfWeightDelta = calculateSelfWeightDeltaFactored(
      originalDepthHMm: hOriginal,
      newDepthHMm: hUsed,
    );

    final double finalLoad = baseLoad + fillDelta + selfWeightDelta;

    final double dx =
        hUsed - settings.clearCoverC - (settings.barDiameterPhi / 2.0);
    final double dy = hUsed -
        settings.clearCoverC -
        settings.barDiameterPhi -
        (settings.barDiameterPhi / 2.0);

    return LoadCalculationResult(
      baseDesignLoadN: baseLoad,
      fillLoadAddedN: fillDelta,
      selfWeightDeltaN: selfWeightDelta,
      finalDesignLoadN: finalLoad,
      overallDepthHMm: hUsed,
      dxMm: dx,
      dyMm: dy,
    );
  }
}
