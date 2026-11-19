import '../../core/math/math_utils.dart';

/// الحالات التسع للبلاطات المصمتة العاملة في اتجاهين (Table 3.14 و Table 3.15)
enum TwoWayPanelCase {
  interiorPanels(
    caseNumber: 1,
    titleEn: 'Interior panels (Four edges continuous)',
    titleAr: 'بلاطة داخلية (أربع حواف مستمرة)',
  ),
  oneShortEdgeDiscontinuous(
    caseNumber: 2,
    titleEn: 'One short edge discontinuous',
    titleAr: 'حافة قصيرة واحدة غير مستمرة',
  ),
  oneLongEdgeDiscontinuous(
    caseNumber: 3,
    titleEn: 'One long edge discontinuous',
    titleAr: 'حافة طويلة واحدة غير مستمرة',
  ),
  twoAdjacentEdgesDiscontinuous(
    caseNumber: 4,
    titleEn: 'Two adjacent edges discontinuous',
    titleAr: 'حافتان متجاورتان غير مستمرتين',
  ),
  twoShortEdgesDiscontinuous(
    caseNumber: 5,
    titleEn: 'Two short edges discontinuous',
    titleAr: 'حافتان قصيرتان غير مستمرتين',
  ),
  twoLongEdgesDiscontinuous(
    caseNumber: 6,
    titleEn: 'Two long edges discontinuous',
    titleAr: 'حافتان طويلتان غير مستمرتين',
  ),
  threeEdgesDiscontinuousOneLongContinuous(
    caseNumber: 7,
    titleEn: 'Three edges discontinuous (one long edge continuous)',
    titleAr: 'ثلاث حواف غير مستمرة (حافة طويلة واحدة مستمرة)',
  ),
  threeEdgesDiscontinuousOneShortContinuous(
    caseNumber: 8,
    titleEn: 'Three edges discontinuous (one short edge continuous)',
    titleAr: 'ثلاث حواف غير مستمرة (حافة قصيرة واحدة مستمرة)',
  ),
  fourEdgesDiscontinuous(
    caseNumber: 9,
    titleEn: 'Four edges discontinuous',
    titleAr: 'أربع حواف غير مستمرة',
  );

  final int caseNumber;
  final String titleEn;
  final String titleAr;

  const TwoWayPanelCase({
    required this.caseNumber,
    required this.titleEn,
    required this.titleAr,
  });
}

/// صف بيانات Table 3.14 لحالة واحدة
class Table314Row {
  final TwoWayPanelCase panelCase;
  final Map<double, double>? betaSxNegative;
  final Map<double, double> betaSxPositive;
  final double? betaSyNegative;
  final double betaSyPositive;

  const Table314Row({
    required this.panelCase,
    required this.betaSxNegative,
    required this.betaSxPositive,
    required this.betaSyNegative,
    required this.betaSyPositive,
  });
}

/// نتيجة استخراج معاملات العزوم من Table 3.14 مع سجل التناسب الخطي
class MomentCoefficientsResult {
  final TwoWayPanelCase panelCase;
  final double lyOverLx;
  final InterpolationTrace? betaSxNegTrace;
  final InterpolationTrace betaSxPosTrace;
  final double? betaSyNeg;
  final double betaSyPos;

  const MomentCoefficientsResult({
    required this.panelCase,
    required this.lyOverLx,
    required this.betaSxNegTrace,
    required this.betaSxPosTrace,
    required this.betaSyNeg,
    required this.betaSyPos,
  });

  double? get betaSxNeg => betaSxNegTrace?.result;
  double get betaSxPos => betaSxPosTrace.result;
}

/// صف بيانات Table 3.15 لحالة واحدة
class Table315Row {
  final TwoWayPanelCase panelCase;
  final Map<double, double>? betaVxContinuous;
  final Map<double, double>? betaVxDiscontinuous;
  final double? betaVyContinuous;
  final double? betaVyDiscontinuous;

  const Table315Row({
    required this.panelCase,
    required this.betaVxContinuous,
    required this.betaVxDiscontinuous,
    required this.betaVyContinuous,
    required this.betaVyDiscontinuous,
  });
}

/// نتيجة استخراج معاملات القص من Table 3.15 مع سجل التناسب الخطي
class ShearCoefficientsResult {
  final TwoWayPanelCase panelCase;
  final double lyOverLx;
  final InterpolationTrace? betaVxContTrace;
  final InterpolationTrace? betaVxDiscTrace;
  final double? betaVyCont;
  final double? betaVyDisc;

  const ShearCoefficientsResult({
    required this.panelCase,
    required this.lyOverLx,
    required this.betaVxContTrace,
    required this.betaVxDiscTrace,
    required this.betaVyCont,
    required this.betaVyDisc,
  });

  double? get betaVxCont => betaVxContTrace?.result;
  double? get betaVxDisc => betaVxDiscTrace?.result;

  /// أكبر معامل قص حاكم على محيط البلاطة
  double get maxCoefficient {
    final values = <double>[
      if (betaVxCont != null) betaVxCont!,
      if (betaVxDisc != null) betaVxDisc!,
      if (betaVyCont != null) betaVyCont!,
      if (betaVyDisc != null) betaVyDisc!,
    ];
    values.sort();
    return values.last;
  }
}

/// جداول معاملات البلاطات (الصفحات 8 و 9 و 10 من الكود المرفق):
/// - Table 3.14: معاملات عزوم الانحناء للبلاطات العاملة في اتجاهين
/// - Table 3.15: معاملات قوى القص للبلاطات العاملة في اتجاهين
/// - Table 3.12: معاملات العزوم والقص للبلاطات المستمرة العاملة في اتجاه واحد
class SlabMomentShearTables {
  SlabMomentShearTables._();

  static const List<double> aspectRatioColumns = [
    1.0,
    1.1,
    1.2,
    1.3,
    1.4,
    1.5,
    1.75,
    2.0,
  ];

  /// Table 3.14 — Bending moment coefficients for rectangular panels
  /// supported on four sides with provision for torsion at corners
  static final Map<TwoWayPanelCase, Table314Row> table314 = {
    TwoWayPanelCase.interiorPanels: Table314Row(
      panelCase: TwoWayPanelCase.interiorPanels,
      betaSxNegative: {
        1.0: 0.031,
        1.1: 0.037,
        1.2: 0.042,
        1.3: 0.046,
        1.4: 0.050,
        1.5: 0.053,
        1.75: 0.059,
        2.0: 0.063,
      },
      betaSxPositive: {
        1.0: 0.024,
        1.1: 0.028,
        1.2: 0.032,
        1.3: 0.035,
        1.4: 0.037,
        1.5: 0.040,
        1.75: 0.044,
        2.0: 0.048,
      },
      betaSyNegative: 0.032,
      betaSyPositive: 0.024,
    ),
    TwoWayPanelCase.oneShortEdgeDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.oneShortEdgeDiscontinuous,
      betaSxNegative: {
        1.0: 0.039,
        1.1: 0.044,
        1.2: 0.048,
        1.3: 0.052,
        1.4: 0.055,
        1.5: 0.058,
        1.75: 0.063,
        2.0: 0.067,
      },
      betaSxPositive: {
        1.0: 0.029,
        1.1: 0.033,
        1.2: 0.036,
        1.3: 0.039,
        1.4: 0.041,
        1.5: 0.043,
        1.75: 0.047,
        2.0: 0.050,
      },
      betaSyNegative: 0.037,
      betaSyPositive: 0.028,
    ),
    TwoWayPanelCase.oneLongEdgeDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.oneLongEdgeDiscontinuous,
      betaSxNegative: {
        1.0: 0.039,
        1.1: 0.049,
        1.2: 0.056,
        1.3: 0.062,
        1.4: 0.068,
        1.5: 0.073,
        1.75: 0.082,
        2.0: 0.089,
      },
      betaSxPositive: {
        1.0: 0.030,
        1.1: 0.036,
        1.2: 0.042,
        1.3: 0.047,
        1.4: 0.051,
        1.5: 0.055,
        1.75: 0.062,
        2.0: 0.067,
      },
      betaSyNegative: 0.037,
      betaSyPositive: 0.028,
    ),
    TwoWayPanelCase.twoAdjacentEdgesDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.twoAdjacentEdgesDiscontinuous,
      betaSxNegative: {
        1.0: 0.047,
        1.1: 0.056,
        1.2: 0.063,
        1.3: 0.069,
        1.4: 0.074,
        1.5: 0.078,
        1.75: 0.087,
        2.0: 0.093,
      },
      betaSxPositive: {
        1.0: 0.036,
        1.1: 0.042,
        1.2: 0.047,
        1.3: 0.051,
        1.4: 0.055,
        1.5: 0.059,
        1.75: 0.065,
        2.0: 0.070,
      },
      betaSyNegative: 0.045,
      betaSyPositive: 0.034,
    ),
    TwoWayPanelCase.twoShortEdgesDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.twoShortEdgesDiscontinuous,
      betaSxNegative: {
        1.0: 0.046,
        1.1: 0.050,
        1.2: 0.054,
        1.3: 0.057,
        1.4: 0.060,
        1.5: 0.062,
        1.75: 0.067,
        2.0: 0.070,
      },
      betaSxPositive: {
        1.0: 0.034,
        1.1: 0.038,
        1.2: 0.040,
        1.3: 0.043,
        1.4: 0.045,
        1.5: 0.047,
        1.75: 0.050,
        2.0: 0.053,
      },
      betaSyNegative: null,
      betaSyPositive: 0.034,
    ),
    TwoWayPanelCase.twoLongEdgesDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
      betaSxNegative: null,
      betaSxPositive: {
        1.0: 0.034,
        1.1: 0.046,
        1.2: 0.056,
        1.3: 0.065,
        1.4: 0.072,
        1.5: 0.078,
        1.75: 0.091,
        2.0: 0.100,
      },
      betaSyNegative: 0.045,
      betaSyPositive: 0.034,
    ),
    TwoWayPanelCase.threeEdgesDiscontinuousOneLongContinuous: Table314Row(
      panelCase: TwoWayPanelCase.threeEdgesDiscontinuousOneLongContinuous,
      betaSxNegative: {
        1.0: 0.057,
        1.1: 0.065,
        1.2: 0.071,
        1.3: 0.076,
        1.4: 0.081,
        1.5: 0.084,
        1.75: 0.092,
        2.0: 0.098,
      },
      betaSxPositive: {
        1.0: 0.043,
        1.1: 0.048,
        1.2: 0.053,
        1.3: 0.057,
        1.4: 0.060,
        1.5: 0.063,
        1.75: 0.069,
        2.0: 0.074,
      },
      betaSyNegative: null,
      betaSyPositive: 0.044,
    ),
    TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous: Table314Row(
      panelCase: TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous,
      betaSxNegative: null,
      betaSxPositive: {
        1.0: 0.042,
        1.1: 0.054,
        1.2: 0.063,
        1.3: 0.071,
        1.4: 0.078,
        1.5: 0.084,
        1.75: 0.096,
        2.0: 0.105,
      },
      betaSyNegative: 0.058,
      betaSyPositive: 0.044,
    ),
    TwoWayPanelCase.fourEdgesDiscontinuous: Table314Row(
      panelCase: TwoWayPanelCase.fourEdgesDiscontinuous,
      betaSxNegative: null,
      betaSxPositive: {
        1.0: 0.055,
        1.1: 0.065,
        1.2: 0.074,
        1.3: 0.081,
        1.4: 0.087,
        1.5: 0.092,
        1.75: 0.103,
        2.0: 0.111,
      },
      betaSyNegative: null,
      betaSyPositive: 0.056,
    ),
  };

  /// استخراج معاملات العزوم من Table 3.14 مع التناسب الخطي التلقائي.
  ///
  /// إذا مُرّر [roundBetaDecimals] (وضع شرح المحاضرة: 3) تُقرَّب نتيجة التناسب الخطي
  /// إلى هذا العدد من الخانات قبل استعمالها، كما يفعل الشرح (0.0369 ≈ 0.037)،
  /// فتطابق العزوم أرقام ورقة الحل (7.15 بدل 7.14). القيم المأخوذة من الجدول مباشرة
  /// بلا تناسب لا يمسّها التقريب.
  static MomentCoefficientsResult getMomentCoefficients({
    required TwoWayPanelCase panelCase,
    required double lyOverLx,
    int? roundBetaDecimals,
  }) {
    final row = table314[panelCase]!;
    InterpolationTrace? negTrace = row.betaSxNegative == null
        ? null
        : MathUtils.interpolateWithTrace(lyOverLx, row.betaSxNegative!);
    InterpolationTrace posTrace =
        MathUtils.interpolateWithTrace(lyOverLx, row.betaSxPositive);
    if (roundBetaDecimals != null) {
      negTrace = negTrace?.withRounding(roundBetaDecimals);
      posTrace = posTrace.withRounding(roundBetaDecimals);
    }

    return MomentCoefficientsResult(
      panelCase: panelCase,
      lyOverLx: lyOverLx,
      betaSxNegTrace: negTrace,
      betaSxPosTrace: posTrace,
      betaSyNeg: row.betaSyNegative,
      betaSyPos: row.betaSyPositive,
    );
  }

  /// Table 3.15 — Shear force coefficient for uniformly loaded rectangular panels
  /// supported on four sides with provision for torsion at corners
  static final Map<TwoWayPanelCase, Table315Row> table315 = {
    TwoWayPanelCase.interiorPanels: Table315Row(
      panelCase: TwoWayPanelCase.interiorPanels,
      betaVxContinuous: {
        1.0: 0.33,
        1.1: 0.36,
        1.2: 0.39,
        1.3: 0.41,
        1.4: 0.43,
        1.5: 0.45,
        1.75: 0.48,
        2.0: 0.50,
      },
      betaVxDiscontinuous: null,
      betaVyContinuous: 0.33,
      betaVyDiscontinuous: null,
    ),
    TwoWayPanelCase.oneShortEdgeDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.oneShortEdgeDiscontinuous,
      betaVxContinuous: {
        1.0: 0.36,
        1.1: 0.39,
        1.2: 0.42,
        1.3: 0.44,
        1.4: 0.45,
        1.5: 0.47,
        1.75: 0.50,
        2.0: 0.52,
      },
      betaVxDiscontinuous: null,
      betaVyContinuous: 0.36,
      betaVyDiscontinuous: 0.24,
    ),
    TwoWayPanelCase.oneLongEdgeDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.oneLongEdgeDiscontinuous,
      betaVxContinuous: {
        1.0: 0.36,
        1.1: 0.40,
        1.2: 0.44,
        1.3: 0.47,
        1.4: 0.49,
        1.5: 0.51,
        1.75: 0.55,
        2.0: 0.59,
      },
      betaVxDiscontinuous: {
        1.0: 0.24,
        1.1: 0.27,
        1.2: 0.29,
        1.3: 0.31,
        1.4: 0.32,
        1.5: 0.34,
        1.75: 0.36,
        2.0: 0.38,
      },
      betaVyContinuous: 0.36,
      betaVyDiscontinuous: null,
    ),
    TwoWayPanelCase.twoAdjacentEdgesDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.twoAdjacentEdgesDiscontinuous,
      betaVxContinuous: {
        1.0: 0.40,
        1.1: 0.44,
        1.2: 0.47,
        1.3: 0.50,
        1.4: 0.52,
        1.5: 0.54,
        1.75: 0.57,
        2.0: 0.60,
      },
      betaVxDiscontinuous: {
        1.0: 0.26,
        1.1: 0.29,
        1.2: 0.31,
        1.3: 0.33,
        1.4: 0.34,
        1.5: 0.35,
        1.75: 0.38,
        2.0: 0.40,
      },
      betaVyContinuous: 0.40,
      betaVyDiscontinuous: 0.26,
    ),
    TwoWayPanelCase.twoShortEdgesDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.twoShortEdgesDiscontinuous,
      betaVxContinuous: {
        1.0: 0.40,
        1.1: 0.43,
        1.2: 0.45,
        1.3: 0.47,
        1.4: 0.48,
        1.5: 0.49,
        1.75: 0.52,
        2.0: 0.54,
      },
      betaVxDiscontinuous: null,
      betaVyContinuous: null,
      betaVyDiscontinuous: 0.26,
    ),
    TwoWayPanelCase.twoLongEdgesDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
      betaVxContinuous: null,
      betaVxDiscontinuous: {
        1.0: 0.26,
        1.1: 0.30,
        1.2: 0.33,
        1.3: 0.36,
        1.4: 0.38,
        1.5: 0.40,
        1.75: 0.44,
        2.0: 0.47,
      },
      betaVyContinuous: 0.40,
      betaVyDiscontinuous: null,
    ),
    TwoWayPanelCase.threeEdgesDiscontinuousOneLongContinuous: Table315Row(
      panelCase: TwoWayPanelCase.threeEdgesDiscontinuousOneLongContinuous,
      betaVxContinuous: {
        1.0: 0.45,
        1.1: 0.48,
        1.2: 0.51,
        1.3: 0.53,
        1.4: 0.55,
        1.5: 0.57,
        1.75: 0.60,
        2.0: 0.63,
      },
      betaVxDiscontinuous: {
        1.0: 0.30,
        1.1: 0.32,
        1.2: 0.34,
        1.3: 0.35,
        1.4: 0.36,
        1.5: 0.37,
        1.75: 0.39,
        2.0: 0.41,
      },
      betaVyContinuous: null,
      betaVyDiscontinuous: 0.29,
    ),
    TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous: Table315Row(
      panelCase: TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous,
      betaVxContinuous: null,
      betaVxDiscontinuous: {
        1.0: 0.29,
        1.1: 0.33,
        1.2: 0.36,
        1.3: 0.38,
        1.4: 0.40,
        1.5: 0.42,
        1.75: 0.45,
        2.0: 0.48,
      },
      betaVyContinuous: 0.45,
      betaVyDiscontinuous: 0.30,
    ),
    TwoWayPanelCase.fourEdgesDiscontinuous: Table315Row(
      panelCase: TwoWayPanelCase.fourEdgesDiscontinuous,
      betaVxContinuous: null,
      betaVxDiscontinuous: {
        1.0: 0.33,
        1.1: 0.36,
        1.2: 0.39,
        1.3: 0.41,
        1.4: 0.43,
        1.5: 0.45,
        1.75: 0.48,
        2.0: 0.50,
      },
      betaVyContinuous: null,
      betaVyDiscontinuous: 0.33,
    ),
  };

  /// استخراج معاملات القص من Table 3.15 مع التناسب الخطي التلقائي
  static ShearCoefficientsResult getShearCoefficients({
    required TwoWayPanelCase panelCase,
    required double lyOverLx,
  }) {
    final row = table315[panelCase]!;
    final contTrace = row.betaVxContinuous == null
        ? null
        : MathUtils.interpolateWithTrace(lyOverLx, row.betaVxContinuous!);
    final discTrace = row.betaVxDiscontinuous == null
        ? null
        : MathUtils.interpolateWithTrace(lyOverLx, row.betaVxDiscontinuous!);

    return ShearCoefficientsResult(
      panelCase: panelCase,
      lyOverLx: lyOverLx,
      betaVxContTrace: contTrace,
      betaVxDiscTrace: discTrace,
      betaVyCont: row.betaVyContinuous,
      betaVyDisc: row.betaVyDiscontinuous,
    );
  }

  /// Table 3.12 — Ultimate bending moment and shear forces in one-way spanning slabs
  /// (approximately equal spans, variation <= 15% of longest)
  /// Moment = coeff * F * l , Shear = coeff * F  where F = (1.4 Gk + 1.6 Qk) * l
  static const Map<String, ({double momentCoeff, double? shearCoeff})>
      table312OneWaySlab = {
    'simpleOuterSupport': (momentCoeff: 0.0, shearCoeff: 0.40),
    'simpleEndSpanMid': (momentCoeff: 0.086, shearCoeff: null),
    'continuousOuterSupport': (momentCoeff: -0.040, shearCoeff: 0.46),
    'continuousEndSpanMid': (momentCoeff: 0.075, shearCoeff: null),
    'firstInteriorSupport': (momentCoeff: -0.086, shearCoeff: 0.60),
    'middleInteriorSpans': (momentCoeff: 0.063, shearCoeff: null),
    'interiorSupports': (momentCoeff: -0.063, shearCoeff: 0.50),
  };
}
