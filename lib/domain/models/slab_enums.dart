/// نوع الخانة في المخطط الإنشائي للسقف
enum SlabCellType {
  normalSolid('بلاطة مصمتة عادية', 'Solid Slab'),
  droppedSolid('بلاطة مهبطة (حمام/منسوب منخفض)', 'Dropped Solid Slab'),
  stairwellOrVoid('بيت درج / فتحة', 'Stairwell / Opening'),
  exteriorEmpty('فراغ خارجي', 'Exterior / Void');

  final String titleAr;
  final String titleEn;
  const SlabCellType(this.titleAr, this.titleEn);

  bool get isDesignableSlab =>
      this == SlabCellType.normalSolid || this == SlabCellType.droppedSolid;
}

/// حالة الاستناد على حافة واحدة من حواف البلاطة
enum EdgeCondition {
  continuous('مستمرة مع بلاطة مجاورة', 'Continuous'),
  discontinuousFree('غير مستمرة (حافة خارجية حرة)', 'Discontinuous (Outer)'),
  discontinuousDropped(
      'غير مستمرة (مجاورة لبلاطة مهبطة)', 'Discontinuous (Dropped Slab)'),
  discontinuousStairwell(
      'غير مستمرة (مجاورة لدرج/فتحة)', 'Discontinuous (Stairwell)'),
  cantilever('مستمرة مع كابولي جانبي', 'Continuous (Cantilever)');

  final String titleAr;
  final String titleEn;
  const EdgeCondition(this.titleAr, this.titleEn);

  /// هل الحافة توفر استمرارية لعزم سالب وتقييد للحديد العلوي؟
  bool get isContinuous =>
      this == EdgeCondition.continuous || this == EdgeCondition.cantilever;

  bool get isDiscontinuous => !isContinuous;
}

/// نوع العمل الإنشائي للبلاطة
enum SlabSpanningType {
  twoWay('بلاطة عاملة في اتجاهين', 'Two-Way Spanning Solid Slab'),
  oneWay('بلاطة عاملة في اتجاه واحد', 'One-Way Spanning Solid Slab'),
  cantilever('بلاطة كابولية', 'Cantilever Solid Slab');

  final String titleAr;
  final String titleEn;
  const SlabSpanningType(this.titleAr, this.titleEn);
}

/// مصدر عزم الكابولي عند مسنده
enum CantileverMomentSource {
  /// العزم الستاتيكي المحسوب: M = n · lc² / 2 (الافتراضي، الأكثر أماناً)
  statics('العزم الستاتيكي n·l²/2', 'Statics: n·l²/2'),

  /// عزم المسند المعطى في نص السؤال (مثل: support B.M. = 1 kN.m/m) يحل محل العزم الستاتيكي
  givenSupportMoment('عزم المسند المعطى في السؤال', 'Given support B.M.');

  final String titleAr;
  final String titleEn;
  const CantileverMomentSource(this.titleAr, this.titleEn);

  static CantileverMomentSource fromStorage(String? value) {
    return CantileverMomentSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CantileverMomentSource.statics,
    );
  }
}

/// اتجاهات الحواف الأربع للبلاطة على المسقط الأفقي
enum EdgeSide {
  top('الحافة العلوية', 'Top'),
  bottom('الحافة السفلية', 'Bottom'),
  left('الحافة اليسرى', 'Left'),
  right('الحافة اليمنى', 'Right');

  final String titleAr;
  final String titleEn;
  const EdgeSide(this.titleAr, this.titleEn);

  EdgeSide get opposite {
    switch (this) {
      case EdgeSide.top:
        return EdgeSide.bottom;
      case EdgeSide.bottom:
        return EdgeSide.top;
      case EdgeSide.left:
        return EdgeSide.right;
      case EdgeSide.right:
        return EdgeSide.left;
    }
  }
}

/// محور الشريحة الإنشائية
enum SlabAxisDirection {
  horizontalX('الاتجاه الأفقي (X)', 'X'),
  verticalY('الاتجاه الرأسي (Y)', 'Y');

  final String titleAr;
  final String symbol;
  const SlabAxisDirection(this.titleAr, this.symbol);
}
