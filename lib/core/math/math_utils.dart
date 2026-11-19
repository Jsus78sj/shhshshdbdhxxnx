import 'dart:math' as math;

/// تفاصيل عملية التناسب الخطي (تُستخدم لعرض خطوة التناسب في الحل الأكاديمي)
class InterpolationTrace {
  final double targetX;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// النتيجة المعتمدة في الحسابات (مقرّبة إن كان [roundedDecimals] غير null)
  final double result;
  final bool wasExactMatch;

  /// النتيجة الخام قبل التقريب (تساوي [result] إذا لم يُطبَّق تقريب)
  final double rawResult;

  /// عدد الخانات العشرية التي قُرّبت إليها النتيجة (كما يفعل الشرح: 0.0369 ≈ 0.037)
  final int? roundedDecimals;

  const InterpolationTrace({
    required this.targetX,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.result,
    required this.wasExactMatch,
    double? rawResult,
    this.roundedDecimals,
  }) : rawResult = rawResult ?? result;

  /// هل غيّر التقريب قيمة النتيجة فعلاً؟
  bool get wasRounded =>
      roundedDecimals != null && (rawResult - result).abs() > 1e-12;

  /// نسخة مقرّبة إلى [decimals] خانات عشرية (للاستخدام في وضع شرح المحاضرة).
  /// القيم المأخوذة مباشرة من الجدول بلا تناسب (تطابق تام) تبقى كما هي.
  InterpolationTrace withRounding(int decimals) {
    if (wasExactMatch) return this;
    return InterpolationTrace(
      targetX: targetX,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      result: MathUtils.roundTo(rawResult, decimals),
      wasExactMatch: wasExactMatch,
      rawResult: rawResult,
      roundedDecimals: decimals,
    );
  }

  /// صياغة معادلة التناسب الخطي بصيغة LaTeX مطابقة لطريقة الشرح الجامعية
  String toLectureLatex({String unknownSymbol = 'x', int decimals = 4}) {
    final xStr = targetX.toStringAsFixed(decimals);
    final x1Str = x1.toStringAsFixed(2);
    final x2Str = x2.toStringAsFixed(2);
    final y1Str = y1.toStringAsFixed(3);
    final y2Str = y2.toStringAsFixed(3);
    final rawStr = rawResult.toStringAsFixed(4);
    final base =
        '\\frac{$x1Str - $xStr}{$x1Str - $x2Str} = \\frac{$y1Str - $unknownSymbol}{$y1Str - $y2Str} \\implies $unknownSymbol = $rawStr';
    if (wasRounded) {
      final resStr = result.toStringAsFixed(roundedDecimals!);
      return '$base \\approx $resStr';
    }
    return base;
  }
}

/// دوال رياضية مساعدة لمعاملات الكود البريطاني والتناسب الخطي
class MathUtils {
  MathUtils._();

  /// حساب التناسب الخطي (Linear Interpolation) بين نقطتين (x1, y1) و (x2, y2)
  /// عند القيمة المطلوبة [x].
  static double linearInterpolate({
    required double x,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) {
    if ((x2 - x1).abs() < 1e-12) {
      return y1;
    }
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
  }

  /// إيجاد القيمة بالتناسب الخطي من خريطة مرتبة من المفاتيح والقيم
  /// مع إرجاع كامل تفاصيل التناسب [InterpolationTrace].
  static InterpolationTrace interpolateWithTrace(
    double targetKey,
    Map<double, double> sortedTable,
  ) {
    if (sortedTable.isEmpty) {
      throw ArgumentError('لا يمكن إجراء التناسب الخطي على جدول فارغ.');
    }

    final keys = sortedTable.keys.toList()..sort();

    if (targetKey <= keys.first) {
      final k = keys.first;
      final v = sortedTable[k]!;
      return InterpolationTrace(
        targetX: targetKey,
        x1: k,
        y1: v,
        x2: k,
        y2: v,
        result: v,
        wasExactMatch: true,
      );
    }

    if (targetKey >= keys.last) {
      final k = keys.last;
      final v = sortedTable[k]!;
      return InterpolationTrace(
        targetX: targetKey,
        x1: k,
        y1: v,
        x2: k,
        y2: v,
        result: v,
        wasExactMatch: true,
      );
    }

    for (int i = 0; i < keys.length - 1; i++) {
      final k1 = keys[i];
      final k2 = keys[i + 1];
      if ((targetKey - k1).abs() < 1e-9) {
        final v1 = sortedTable[k1]!;
        return InterpolationTrace(
          targetX: targetKey,
          x1: k1,
          y1: v1,
          x2: k1,
          y2: v1,
          result: v1,
          wasExactMatch: true,
        );
      }
      if ((targetKey - k2).abs() < 1e-9) {
        final v2 = sortedTable[k2]!;
        return InterpolationTrace(
          targetX: targetKey,
          x1: k2,
          y1: v2,
          x2: k2,
          y2: v2,
          result: v2,
          wasExactMatch: true,
        );
      }
      if (targetKey > k1 && targetKey < k2) {
        final v1 = sortedTable[k1]!;
        final v2 = sortedTable[k2]!;
        final result = linearInterpolate(
          x: targetKey,
          x1: k1,
          y1: v1,
          x2: k2,
          y2: v2,
        );
        return InterpolationTrace(
          targetX: targetKey,
          x1: k1,
          y1: v1,
          x2: k2,
          y2: v2,
          result: result,
          wasExactMatch: false,
        );
      }
    }

    final lastK = keys.last;
    final lastV = sortedTable[lastK]!;
    return InterpolationTrace(
      targetX: targetKey,
      x1: lastK,
      y1: lastV,
      x2: lastK,
      y2: lastV,
      result: lastV,
      wasExactMatch: true,
    );
  }

  /// إيجاد القيمة بالتناسب الخطي من خريطة مرتبة من المفاتيح والقيم
  /// (تُستخدم لاستخراج معاملات βsx و βvx من Table 3.14 و Table 3.15).
  static double interpolateFromTable(
    double targetKey,
    Map<double, double> sortedTable,
  ) {
    return interpolateWithTrace(targetKey, sortedTable).result;
  }

  /// تقريب رقم عشري إلى عدد محدد من الخانات
  static double roundTo(double value, int decimals) {
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }
}
