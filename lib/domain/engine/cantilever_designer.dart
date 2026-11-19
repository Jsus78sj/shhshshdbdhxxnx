import '../../core/constants/app_constants.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_geometry_models.dart';
import '../models/slab_project_settings.dart';
import 'deflection_checker.dart';
import 'flexure_designer.dart';
import 'load_calculator.dart';
import 'shear_checker.dart';

/// مصمم الكابولي (شريحة بعرض 1 m): العزم عند المسند، الحديد العلوي، الهطول (B.R = 7)،
/// والقص (V = n · lc). يستخدم نفس فاحصي الهطول والقص المستعملين في البلاطات.
class CantileverDesigner {
  CantileverDesigner._();

  /// الحد الأقصى لمحاولات زيادة السماكة تلقائياً حتى ينجح فحص الهطول
  static const int _maxAutoDepthIterations = 12;

  /// تصميم كابولي واحد.
  ///
  /// - [parentLoadN]: الحمل التصميمي الذي يُفترض للكابولي إن لم يكن له حمل مخصص
  ///   (الافتراضي = حمل المشروع الأساسي).
  /// - [momentSource] و [givenSupportMomentKnM]: اختيار العزم الستاتيكي n·l²/2 أو
  ///   عزم المسند المعطى في السؤال.
  /// - [autoAdjustDepth]: زيادة سماكة الكابولي تدريجياً حتى ينجح الهطول.
  static CantileverDesignReport design({
    required CantileverAttachment cantilever,
    required SlabProjectSettings settings,
    double? parentLoadN,
    CantileverMomentSource momentSource = CantileverMomentSource.statics,
    double givenSupportMomentKnM = 0.0,
    bool autoAdjustDepth = false,
  }) {
    if (cantilever.lengthM <= 0) {
      throw ArgumentError('طول الكابولي يجب أن يكون أكبر من الصفر.');
    }

    CantileverDesignReport report = _runOnce(
      cantilever: cantilever,
      settings: settings,
      parentLoadN: parentLoadN,
      momentSource: momentSource,
      givenSupportMomentKnM: givenSupportMomentKnM,
      overrideDepthHMm: null,
      attempts: 0,
    );

    if (autoAdjustDepth) {
      double h = report.loadResult.overallDepthHMm;
      int attempts = 0;
      while (!report.deflectionCheck.isSafe &&
          attempts < _maxAutoDepthIterations) {
        final double? suggested = report.deflectionCheck.suggestedOverallDepthHMm;
        h = (suggested != null && suggested > h + 1e-9) ? suggested : h + 10.0;
        attempts++;
        report = _runOnce(
          cantilever: cantilever,
          settings: settings,
          parentLoadN: parentLoadN,
          momentSource: momentSource,
          givenSupportMomentKnM: givenSupportMomentKnM,
          overrideDepthHMm: h,
          attempts: attempts,
        );
      }
    }
    return report;
  }

  static CantileverDesignReport _runOnce({
    required CantileverAttachment cantilever,
    required SlabProjectSettings settings,
    required double? parentLoadN,
    required CantileverMomentSource momentSource,
    required double givenSupportMomentKnM,
    required double? overrideDepthHMm,
    required int attempts,
  }) {
    final double lc = cantilever.lengthM;

    // 1. الحمل والأعماق الفعالة (للكابولي حمله الخاص إن وُجد، وإلا حمل المشروع)
    final loadRes = LoadCalculator.compute(
      settings: settings,
      cellType: SlabCellType.normalSolid,
      customDesignLoadN:
          cantilever.customDesignLoadN ?? parentLoadN ?? settings.designLoadN,
      overrideOverallDepthHMm: overrideDepthHMm,
    );
    final double n = loadRes.finalDesignLoadN;

    // 2. العزم عند المسند
    final double staticM = (n * lc * lc) / 2.0;
    final double designM = cantilever.supportMomentKnPerM(
      n,
      source: momentSource,
      givenMomentKnM: givenSupportMomentKnM,
    );
    // العزم الستاتيكي المحسوب ببيانات الكابولي (قد يختلف عن n النهائي عند زيادة السماكة)
    final double mDesign = momentSource == CantileverMomentSource.statics
        ? staticM
        : designM;

    // 3. طوبولوجية الكابولي: المسند (يسار) مستمر، والطرف الحر وحوافه الجانبية غير مستمرة
    final topology = ResolvedTopology(
      slabId: cantilever.label,
      cellType: SlabCellType.normalSolid,
      widthXM: lc,
      heightYM: 1.0,
      shortSpanLxM: lc,
      longSpanLyM: lc,
      lyOverLx: 1.0,
      isShortSpanHorizontal: true,
      spanningType: SlabSpanningType.cantilever,
      twoWayCase: null,
      topEdge: EdgeCondition.discontinuousFree,
      bottomEdge: EdgeCondition.discontinuousFree,
      leftEdge: EdgeCondition.continuous,
      rightEdge: EdgeCondition.discontinuousFree,
      mixedCornersCount: 0,
      freeCornersCount: 0,
    );

    // 4. الحديد العلوي عند المسند (العمق الفعال dx للطبقة العليا الخارجية)
    final topSteel = FlexureDesigner.designSection(
      zoneId: 'cantilever_support',
      zoneTitleAr: 'الحديد العلوي عند مسند الكابولي (${cantilever.label})',
      directionAr: 'عمودي على المسند',
      isTopSteel: true,
      designMomentKnM: mDesign,
      effectiveDepthMm: loadRes.dxMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      settings: settings,
    );

    // 5. حديد التوزيع (As,min) في الاتجاه الموازي للمسند
    final distributionSteel = FlexureDesigner.designSection(
      zoneId: 'cantilever_distribution',
      zoneTitleAr: 'حديد التوزيع للكابولي (As,min)',
      directionAr: 'موازٍ للمسند',
      isTopSteel: false,
      designMomentKnM: 0.0,
      effectiveDepthMm: loadRes.dyMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      settings: settings,
    );

    // 6. الهطول (B.R = 7 للكابولي) — الحديد المشدود هو الحديد العلوي
    final deflection = DeflectionChecker.check(
      topology: topology,
      shortMidSteel: topSteel,
      settings: settings,
      overallDepthHMm: loadRes.overallDepthHMm,
      compressionSteelPercent: topSteel.compressionSteelProvidedPercent,
    );

    // 7. القص عند المسند: V = n · lc
    final shear = ShearChecker.check(
      topology: topology,
      designLoadN: n,
      dxMm: loadRes.dxMm,
      dyMm: loadRes.dyMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      shortSupportSteel: topSteel,
      longSupportSteel: topSteel,
      settings: settings,
    );

    // 8. التحذيرات
    final warnings = <String>[];
    if (momentSource == CantileverMomentSource.givenSupportMoment &&
        givenSupportMomentKnM > 0) {
      if (givenSupportMomentKnM + 1e-9 < staticM) {
        warnings.add(
          'عزم المسند المعطى (${givenSupportMomentKnM.toStringAsFixed(2)} kN.m/m) أقل من العزم الستاتيكي n·l²/2 = ${staticM.toStringAsFixed(2)} kN.m/m؛ التصميم يعتمد المعطى كما طُلب في السؤال، وهو غير آمن لكابولي حقيقي بهذا الحمل والطول.',
        );
      }
    }
    if (!deflection.isSafe) {
      warnings.add(
        'فحص هطول الكابولي غير آمن على السماكة ${loadRes.overallDepthHMm.toStringAsFixed(0)} mm (B.R = ${deflection.basicRatioBR.toStringAsFixed(0)})؛ d_min = ${deflection.dMinRequiredMm.toStringAsFixed(1)} mm، والمقترح h = ${deflection.suggestedOverallDepthHMm?.toStringAsFixed(0)} mm.',
      );
    }
    if (!shear.isSafe) {
      warnings.add(shear.table316Result.requirementAr);
    }
    if (loadRes.selfWeightDeltaN > 0) {
      warnings.add(
        'تم تعديل سماكة الكابولي تلقائياً من ${settings.overallDepthH.toStringAsFixed(0)} mm إلى ${loadRes.overallDepthHMm.toStringAsFixed(0)} mm وتحديث الحمل بمقدار +${loadRes.selfWeightDeltaN.toStringAsFixed(3)} kN/m².',
      );
    }
    if (attempts > 1) {
      warnings.add(
        'استلزم تحقق الهطول $attempts محاولات متتالية لزيادة السماكة.',
      );
    }
    for (final d in [topSteel, distributionSteel]) {
      if (d.requiresDoublyReinforced) {
        warnings.add(
          '${d.zoneTitleAr}: M/bd² = ${d.mOverBd2.toStringAsFixed(3)} يتجاوز الحد الأقصى لـ Table 4؛ يلزم حديد ضغط A\'sc = ${d.compressionSteelMm2.toStringAsFixed(0)} mm²/m (${d.compressionBarSelection?.lectureNotation ?? "-"}) أو زيادة السماكة.',
        );
      }
      if (!d.isAreaSufficient) {
        warnings.add(
          '${d.zoneTitleAr}: أقصى عدد أسياخ لا يوفر المساحة المطلوبة ${d.asGoverningMm2.toStringAsFixed(0)} mm²/m؛ استخدم قطراً أكبر أو زد السماكة.',
        );
      }
    }

    return CantileverDesignReport(
      label: cantilever.label,
      cantilever: cantilever,
      settingsUsed: settings.copyWith(overallDepthH: loadRes.overallDepthHMm),
      topology: topology,
      loadResult: loadRes,
      momentSource: momentSource,
      supportMomentKnM: mDesign,
      staticMomentKnM: staticM,
      topSteel: topSteel,
      distributionSteel: distributionSteel,
      deflectionCheck: deflection,
      shearCheck: shear,
      anchorageInsideSlabM: cantilever.anchorExtensionInsideSlabM,
      warningsAr: warnings,
    );
  }

  /// أقصى سماكة لا تحتاج هطولاً لحظياً (مرجع سريع للواجهة): d ≥ lc·1000 / (7 · M.Ft)
  static double minEffectiveDepthForBasicRatioMm(double lengthM) {
    return (lengthM * 1000.0) / (7.0 * 2.0);
  }

  /// عرض الشريحة المعتمد في التصميم (mm)
  static const double stripWidthMm = AppConstants.stripWidth;
}
