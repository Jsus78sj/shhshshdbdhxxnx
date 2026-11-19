import 'dart:math' as math;

/// ملحق تصميم الأعمدة (الصفحة الأخيرة من الكود المرفق):
/// - طريقة الجساءة لحساب الطول الفعال للأعمدة المقيدة وغير المقيدة
/// - Table 2: معامل β لتحويل العزم ثنائي المحور إلى عزم أحادي المحور
class ColumnTables {
  ColumnTables._();

  /// Table 2 — القيم الجدولية للمعامل β بدلالة N / (b * h * fcu)
  static final Map<double, double> table2BiaxialBeta = {
    0.0: 1.00,
    0.1: 0.88,
    0.2: 0.77,
    0.3: 0.65,
    0.4: 0.53,
    0.5: 0.42,
    0.6: 0.30,
  };

  /// حساب المعامل β بالمعادلة التحليلية المرفقة في الكود:
  /// β = 1 - (7 * N) / (6 * b * h * fcu) >= 0.30
  static double calculateBiaxialBeta({
    required double axialLoadN,
    required double bMm,
    required double hMm,
    required double fcu,
  }) {
    final ratio = axialLoadN / (bMm * hMm * fcu);
    final beta = 1.0 - ((7.0 / 6.0) * ratio);
    return math.max(beta, 0.30);
  }

  /// تحويل العزوم ثنائية المحور (Mx, My) إلى عزم تصميمي مكافئ أحادي المحور
  static ({String governingAxis, double equivalentMoment, double beta})
      convertBiaxialToUniaxial({
    required double mx,
    required double my,
    required double hPrime,
    required double bPrime,
    required double axialLoadN,
    required double bMm,
    required double hMm,
    required double fcu,
  }) {
    final beta = calculateBiaxialBeta(
      axialLoadN: axialLoadN,
      bMm: bMm,
      hMm: hMm,
      fcu: fcu,
    );

    if ((mx / hPrime) >= (my / bPrime)) {
      final mxPrime = mx + beta * (hPrime / bPrime) * my;
      return (governingAxis: 'X', equivalentMoment: mxPrime, beta: beta);
    } else {
      final myPrime = my + beta * (bPrime / hPrime) * mx;
      return (governingAxis: 'Y', equivalentMoment: myPrime, beta: beta);
    }
  }

  /// الطول الفعال للعمود المقيد (Braced Column) بطريقة الجساءة
  static double bracedEffectiveHeight({
    required double clearHeightLo,
    required double alphaC1,
    required double alphaC2,
  }) {
    final alphaMin = math.min(alphaC1, alphaC2);
    final le1 = clearHeightLo * (0.7 + 0.05 * (alphaC1 + alphaC2));
    final le2 = clearHeightLo * (0.85 + 0.05 * alphaMin);
    return math.min(clearHeightLo, math.min(le1, le2));
  }

  /// الطول الفعال للعمود غير المقيد (Unbraced Column) بطريقة الجساءة
  static double unbracedEffectiveHeight({
    required double clearHeightLo,
    required double alphaC1,
    required double alphaC2,
  }) {
    final alphaMin = math.min(alphaC1, alphaC2);
    final le1 = clearHeightLo * (1.0 + 0.15 * (alphaC1 + alphaC2));
    final le2 = clearHeightLo * (2.0 + 0.3 * alphaMin);
    return math.min(le1, le2);
  }
}
