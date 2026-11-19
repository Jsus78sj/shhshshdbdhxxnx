import 'dart:math' as math;
import '../../core/math/math_utils.dart';

/// شروط الاستناد للتحقق من نسبة البحر إلى العمق الفعال (Table 3.9)
enum SpanSupportCondition {
  cantilever('كابولي (Cantilever)'),
  simplySupported('بسيط الارتكاز (Simply Supported)'),
  continuous('مستمر (Continuous)');

  final String labelAr;
  const SpanSupportCondition(this.labelAr);
}

/// جداول فحص الهطول (الصفحتان 6 و 7 من الكود المرفق):
/// - Table 3.9: النسب الأساسية للبحر إلى العمق الفعال
/// - Table 3.10: معامل التعديل لتسليح الشد (Equation 7 & Equation 8)
/// - Table 3.11: معامل التعديل لتسليح الضغط (Note 1)
class DeflectionTables {
  DeflectionTables._();

  /// Table 3.9 — Basic span/effective depth ratios
  static const Map<SpanSupportCondition, ({double rectangular, double flanged})>
      table39BasicRatios = {
    SpanSupportCondition.cantilever: (rectangular: 7.0, flanged: 5.6),
    SpanSupportCondition.simplySupported: (rectangular: 20.0, flanged: 16.0),
    SpanSupportCondition.continuous: (rectangular: 26.0, flanged: 20.8),
  };

  /// استخراج النسبة الأساسية من Table 3.9 (يدعم القطاعات المستطيلة وذات الشفة)
  static double basicSpanDepthRatio({
    required SpanSupportCondition supportCondition,
    double bwOverB = 1.0,
  }) {
    final pair = table39BasicRatios[supportCondition]!;
    if (bwOverB >= 1.0) return pair.rectangular;
    if (bwOverB <= 0.3) return pair.flanged;
    return MathUtils.linearInterpolate(
      x: bwOverB,
      x1: 0.3,
      y1: pair.flanged,
      x2: 1.0,
      y2: pair.rectangular,
    );
  }

  /// Table 3.10 — Columns of M / (b d²)
  static const List<double> table310MOverBd2Cols = [
    0.50,
    0.75,
    1.00,
    1.50,
    2.00,
    3.00,
    4.00,
    5.00,
    6.00,
  ];

  /// Table 3.10 — Modification factor for tension reinforcement (tabular values)
  static final Map<double, List<double>> table310TensionFactors = {
    100: [2.00, 2.00, 2.00, 1.86, 1.63, 1.36, 1.19, 1.08, 1.01],
    150: [2.00, 2.00, 1.98, 1.69, 1.49, 1.25, 1.11, 1.01, 0.94],
    167: [2.00, 2.00, 1.91, 1.63, 1.44, 1.21, 1.08, 0.99, 0.92],
    200: [2.00, 1.95, 1.76, 1.51, 1.35, 1.14, 1.02, 0.94, 0.88],
    250: [1.90, 1.70, 1.55, 1.34, 1.20, 1.04, 0.94, 0.87, 0.82],
    300: [1.60, 1.44, 1.33, 1.16, 1.06, 0.93, 0.85, 0.80, 0.76],
    307: [1.56, 1.41, 1.30, 1.14, 1.04, 0.91, 0.84, 0.79, 0.76],
  };

  /// Table 3.10 — Equation 8: إجهاد التشغيل لحديد الشد fs (N/mm²)
  static double calculateServiceStressFs({
    required double fy,
    double? asRequired,
    double? asProvided,
    double betaB = 1.0,
  }) {
    if (asRequired == null || asProvided == null || asProvided <= 0) {
      // Note 3 / طريقة الشرح الجامعي: fs = (2/3) * fy
      return (2.0 / 3.0) * fy * (1.0 / betaB);
    }
    return ((2.0 * fy * asRequired) / (3.0 * asProvided)) * (1.0 / betaB);
  }

  /// Table 3.10 — Equation 7: معامل التعديل لتسليح الشد (بحد أقصى 2.0)
  static double calculateTensionModificationFactor({
    required double fs,
    required double mOverBd2,
  }) {
    final raw = 0.55 + ((477.0 - fs) / (120.0 * (0.9 + mOverBd2)));
    return math.min(raw, 2.0);
  }

  /// القيمة الخام قبل التقييد بـ 2.0 (مفيدة لعرضها في خطوات الحل مثل: 2.03 > 2.0)
  static double calculateRawTensionModificationFactor({
    required double fs,
    required double mOverBd2,
  }) {
    return 0.55 + ((477.0 - fs) / (120.0 * (0.9 + mOverBd2)));
  }

  /// Table 3.11 — Modification factor for compression reinforcement (tabular values)
  /// Key: 100 * A's,prov / (b * d)
  static final Map<double, double> table311CompressionFactors = {
    0.00: 1.00,
    0.15: 1.05,
    0.25: 1.08,
    0.35: 1.10,
    0.50: 1.14,
    0.75: 1.20,
    1.00: 1.25,
    1.50: 1.33,
    2.00: 1.40,
    2.50: 1.45,
    3.00: 1.50,
  };

  /// Table 3.11 — Note 1 equation: معامل التعديل لتسليح الضغط (بحد أقصى 1.5)
  static double calculateCompressionModificationFactor({
    required double compressionSteelPercent, // 100 * A's,prov / (b * d)
  }) {
    if (compressionSteelPercent <= 0) return 1.0;
    final raw =
        1.0 + (compressionSteelPercent / (3.0 + compressionSteelPercent));
    return math.min(raw, 1.5);
  }
}
