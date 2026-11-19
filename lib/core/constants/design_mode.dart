/// أوضاع الحساب الهندسي المدعومة في التطبيق
enum DesignCalculationMode {
  /// وضع شرح المحاضرة والاختبارات الجامعية:
  /// - يستخدم B.R = 26 للبلاطة المستمرة في نظام السقف عند فحص الهطول
  /// - يقرّب β الناتج عن التناسب الخطي إلى 3 خانات عشرية (0.0369 ≈ 0.037) كورقة الحل
  /// - يستخدم fs = (2/3) * fy و جدول التسليح بصيغة (No Ø)
  lectureMode,

  /// وضع الكود البريطاني الصارم (BS 8110-1:1997):
  /// - يطبق حرفية Table 3.9 في الهطول مع اقتراح تعديل السماكة أو حديد الضغط
  /// - يتحقق من تسليح الالتواء عند الأركان وتحديث الوزن الذاتي عند زيادة السماكة
  strictBs8110,
}

extension DesignCalculationModeX on DesignCalculationMode {
  String get titleAr {
    switch (this) {
      case DesignCalculationMode.lectureMode:
        return 'وضع شرح المحاضرة والاختبارات';
      case DesignCalculationMode.strictBs8110:
        return 'وضع الكود البريطاني الصارم (BS 8110)';
    }
  }

  String get shortLabelAr {
    switch (this) {
      case DesignCalculationMode.lectureMode:
        return 'شرح المحاضرة';
      case DesignCalculationMode.strictBs8110:
        return 'الكود الصارم';
    }
  }

  String get descriptionAr {
    switch (this) {
      case DesignCalculationMode.lectureMode:
        return 'يلتزم بخطوات الشرح الجامعي: تقريب β إلى 3 خانات، موازنة العزوم، صيغة عدد الأسياخ (No Ø)، وفحص الهطول بنسبة أساسية B.R = 26 للبلاطة المستمرة في النظام.';
      case DesignCalculationMode.strictBs8110:
        return 'يطبق حرفية جداول BS 8110 في الهطول (Table 3.9) والالتواء عند الأركان مع اقتراح تعديل السماكة تلقائياً.';
    }
  }

  String get storageValue => name;

  static DesignCalculationMode fromStorage(String? value) {
    return DesignCalculationMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => DesignCalculationMode.lectureMode,
    );
  }
}
