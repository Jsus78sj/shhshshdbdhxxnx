import 'dart:math' as math;
import '../../core/constants/design_mode.dart';
import '../../data/bs8110/deflection_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_project_settings.dart';

/// فاحص الهطول (Serviceability Limit State — Deflection)
/// يدعم كلاً من:
/// 1. وضع شرح المحاضرة (B.R = 26 للبلاطة المستمرة في السقف، fs = 2/3 fy)
/// 2. وضع الكود البريطاني الصارم BS 8110 (Table 3.9 حرفياً + Equation 8 + اقتراح h أو Table 3.11)
class DeflectionChecker {
  DeflectionChecker._();

  static DeflectionCheckResult check({
    required ResolvedTopology topology,
    required SectionReinforcementDesign shortMidSteel,
    required SlabProjectSettings settings,
    required double overallDepthHMm,
    double compressionSteelPercent = 0.0,
  }) {
    final mode = settings.calculationMode;
    final double spanMm = topology.shortSpanLxM * 1000.0;
    final double dMm = shortMidSteel.effectiveDepthMm;
    final double mOverBd2 = shortMidSteel.mOverBd2;

    // 1. حساب إجهاد التشغيل fs
    // في الوضع الصارم تُستخدم مساحة الأسياخ المعروضة فعلياً (عدد الأسياخ من Table 1)
    // وهي نفس التسليح الظاهر في الجدول والرسم، لا مساحة Table 2 المنفصلة بالمسافات.
    final double fs = mode == DesignCalculationMode.lectureMode
        ? DeflectionTables.calculateServiceStressFs(fy: settings.fy)
        : DeflectionTables.calculateServiceStressFs(
            fy: settings.fy,
            asRequired: shortMidSteel.asRequiredMm2,
            asProvided: shortMidSteel.barCountSelection.areaProvidedMm2,
          );

    // 2. معامل التعديل لتسليح الشد (Table 3.10 — Equation 7)
    final double rawMft = DeflectionTables.calculateRawTensionModificationFactor(
      fs: fs,
      mOverBd2: mOverBd2,
    );
    final double mft = math.min(rawMft, 2.0);

    // 3. معامل التعديل لتسليح الضغط (Table 3.11)
    final double mfc = DeflectionTables.calculateCompressionModificationFactor(
      compressionSteelPercent: compressionSteelPercent,
    );

    // 4. تحديد النسبة الأساسية B.R من Table 3.9 حسب الوضع النشط
    final double strictBR = _strictBasicRatio(topology);
    final double lectureBR = _lectureBasicRatio(topology);
    final double usedBR =
        mode == DesignCalculationMode.lectureMode ? lectureBR : strictBR;

    final double allowableRatio = usedBR * mft * mfc;
    final double actualRatio = spanMm / dMm;
    final double dMinRequired = spanMm / allowableRatio;
    final bool isSafe = actualRatio <= allowableRatio + 1e-6;

    // 5. في حال عدم الأمان: اقتراح السماكة الآمنة (مقربة لأعلى 10 mm) ونسبة حديد الضغط البديلة
    double? suggestedH;
    double? suggestedCompPct;
    if (!isSafe) {
      final double minH =
          dMinRequired + settings.clearCoverC + (settings.barDiameterPhi / 2.0);
      suggestedH = (minH / 10.0).ceil() * 10.0;

      // حساب معامل الضغط المطلوب من Table 3.11: M.Fc = actualRatio / (usedBR * mft)
      final double neededMfc = actualRatio / (usedBR * mft);
      if (neededMfc <= 1.5) {
        // حل عكسي لمعادلة Table 3.11: neededMfc = 1 + p / (3 + p) => p = 3*(mfc-1)/(2-mfc)
        final double requiredP =
            (3.0 * (neededMfc - 1.0)) / (2.0 - neededMfc);
        suggestedCompPct = (requiredP * 100).ceil() / 100.0;
      }
    }

    // 6. ملاحظة مقارنة هندسية عند اختلاف B.R بين الوضعين، تذكر القاعدة المطبّقة صراحةً
    String? comparativeNote;
    if ((lectureBR - strictBR).abs() > 1e-6) {
      final double strictDMin = spanMm / (strictBR * mft);
      final bool strictWouldPass = dMm >= strictDMin - 1e-6;
      if (mode == DesignCalculationMode.lectureMode) {
        final String ruleAr = _lectureRuleDescriptionAr(topology, lectureBR);
        if (strictWouldPass) {
          comparativeNote =
              '$ruleAr وبتطبيق Table 3.9 حرفياً (B.R = ${strictBR.toStringAsFixed(0)}) يبقى الفحص آمناً أيضاً (d_min = ${strictDMin.toStringAsFixed(1)} mm ≤ ${dMm.toStringAsFixed(0)} mm).';
        } else {
          final double strictMinH =
              strictDMin + settings.clearCoverC + (settings.barDiameterPhi / 2.0);
          final double strictSuggestedH = (strictMinH / 10.0).ceil() * 10.0;
          comparativeNote =
              '$ruleAr تنبيه هندسي (مقارنة مع الكود الصارم Table 3.9): البحر القصير غير مستمر على طرفيه فيأخذ الكود الصارم B.R = ${strictBR.toStringAsFixed(0)} مما يعطي d_min = ${strictDMin.toStringAsFixed(1)} mm (> ${dMm.toStringAsFixed(0)} mm)، ويتطلب زيادة السماكة إلى ${strictSuggestedH.toStringAsFixed(0)} mm أو إضافة حديد ضغط علوي من Table 3.11.';
        }
      } else if (!isSafe) {
        final double lectureDMin = spanMm / (lectureBR * mft);
        comparativeNote =
            'ملاحظة (مقارنة مع شرح المحاضرة): في وضع شرح المحاضرة تُؤخذ B.R = ${lectureBR.toStringAsFixed(0)} للبلاطة المستمرة في نظام السقف، مما يعطي d_min = ${lectureDMin.toStringAsFixed(1)} mm (${dMm >= lectureDMin - 1e-6 ? 'آمن' : 'غير آمن'} على السماكة ${overallDepthHMm.toStringAsFixed(0)} mm).';
      }
    }

    return DeflectionCheckResult(
      modeUsed: mode,
      spanMm: spanMm,
      effectiveDepthMm: dMm,
      mOverBd2: mOverBd2,
      serviceStressFs: fs,
      rawModificationFactor: rawMft,
      tensionModificationFactor: mft,
      compressionModificationFactor: mfc,
      basicRatioBR: usedBR,
      allowableSpanDepthRatio: allowableRatio,
      actualSpanDepthRatio: actualRatio,
      dMinRequiredMm: dMinRequired,
      isSafe: isSafe,
      suggestedOverallDepthHMm: suggestedH,
      suggestedCompressionSteelPercent: suggestedCompPct,
      comparativeModeNoteAr: comparativeNote,
    );
  }

  /// النسبة الأساسية وفق حرفية Table 3.9 للبحر القصير lx
  static double _strictBasicRatio(ResolvedTopology topology) {
    if (topology.spanningType == SlabSpanningType.cantilever) {
      return DeflectionTables.basicSpanDepthRatio(
        supportCondition: SpanSupportCondition.cantilever,
      );
    }
    return DeflectionTables.basicSpanDepthRatio(
      supportCondition: topology.isShortSpanContinuous
          ? SpanSupportCondition.continuous
          : SpanSupportCondition.simplySupported,
    );
  }

  /// النسبة الأساسية وفق طريقة الشرح الجامعي.
  ///
  /// المصدر الوحيد المتاح لهذه القاعدة هو حل الدكتور للبلاطة S7 (اتجاهان، Case 6):
  /// الحافتان الطويلتان (اللتان تحملان البحر القصير lx) غير مستمرتين، ومع ذلك أخذ الدكتور
  /// B.R = 26 لأن البلاطة مستمرة في نظام السقف عبر الحافتين الأخريين، وذكر صراحةً أن Table 3.9
  /// حرفياً تعطي 20.
  ///
  /// - الكابولي: 7.
  /// - اتجاهان: 26 إذا وُجدت حافة مستمرة واحدة على الأقل (قاعدة S7)، وإلا 20.
  /// - اتجاه واحد: تُحدَّد الاستمرارية من طرفي البحر القصير فقط (استمرارية الحافتين
  ///   الموازيتين لاتجاه الحمل لا تجعل البحر مستمراً)، فتطابق قاعدة Table 3.9.
  ///
  /// تنبيه: القاعدة الخاصة باتجاهين غير مؤكَّدة إلا من مثال S7؛ يجب مراجعتها مع أمثلة
  /// الدكتور الأخرى (انظر [_lectureRuleDescriptionAr] الذي يُظهرها في ملاحظة التقرير).
  static double _lectureBasicRatio(ResolvedTopology topology) {
    if (topology.spanningType == SlabSpanningType.cantilever) {
      return 7.0;
    }
    if (topology.spanningType == SlabSpanningType.twoWay) {
      return topology.continuousEdgesCount > 0 ? 26.0 : 20.0;
    }
    return topology.isShortSpanContinuous ? 26.0 : 20.0;
  }

  /// نص يوضح للمستخدم أي قاعدة طُبّقت في وضع الشرح (يظهر في ملاحظة المقارنة بالتقرير)
  static String _lectureRuleDescriptionAr(
    ResolvedTopology topology,
    double lectureBR,
  ) {
    if (topology.spanningType == SlabSpanningType.twoWay &&
        !topology.isShortSpanContinuous &&
        topology.continuousEdgesCount > 0) {
      return 'وفق طريقة الشرح (كما في حل S7) تُؤخذ B.R = ${lectureBR.toStringAsFixed(0)} لأن البلاطة مستمرة في نظام السقف عبر ${topology.continuousEdgesCount} حافة/حواف رغم أن طرفي البحر القصير غير مستمرين.';
    }
    return 'وفق طريقة الشرح تُؤخذ B.R = ${lectureBR.toStringAsFixed(0)}.';
  }
}
