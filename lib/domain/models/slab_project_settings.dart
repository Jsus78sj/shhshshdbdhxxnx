import '../../core/constants/app_constants.dart';
import '../../core/constants/design_mode.dart';

/// الإعدادات الهندسية العامة لمشروع تصميم البلاطات المصمتة
class SlabProjectSettings {
  final double designLoadN; // الحمل التصميمي الأقصى n (kN/m²)
  final double overallDepthH; // السماكة الكلية h (mm)
  final double clearCoverC; // الغطاء الخرساني الصافي c (mm)
  final double barDiameterPhi; // قطر حديد التسليح Ø (mm)
  final double fcu; // المقاومة المميزة للخرسانة (N/mm²)
  final double fy; // المقاومة المميزة لحديد التسليح (N/mm²)
  final DesignCalculationMode calculationMode;

  /// وضع شرح المحاضرة فقط: تقريب معامل العزم β الناتج عن التناسب الخطي إلى 3 خانات
  /// عشرية كما في ورقة الدكتور (0.0369 ≈ 0.037 فيصبح Msx+ = 7.15 وليس 7.14).
  /// لا أثر له في وضع الكود الصارم.
  final bool lectureRoundBetaTo3Decimals;

  const SlabProjectSettings({
    this.designLoadN = AppConstants.defaultDesignLoad,
    this.overallDepthH = AppConstants.defaultOverallDepth,
    this.clearCoverC = AppConstants.defaultClearCover,
    this.barDiameterPhi = AppConstants.defaultBarDiameter,
    this.fcu = AppConstants.defaultFcu,
    this.fy = AppConstants.defaultFy,
    this.calculationMode = DesignCalculationMode.lectureMode,
    this.lectureRoundBetaTo3Decimals = true,
  });

  /// عدد الخانات العشرية لتقريب β في التناسب الخطي (null = بلا تقريب)
  int? get betaRoundDecimals =>
      (calculationMode == DesignCalculationMode.lectureMode &&
              lectureRoundBetaTo3Decimals)
          ? 3
          : null;

  /// العمق الفعال في الاتجاه القصير (الطبقة السفلية الخارجية)
  double get effectiveDepthDx =>
      overallDepthH - clearCoverC - (barDiameterPhi / 2.0);

  /// العمق الفعال في الاتجاه الطويل (الطبقة السفلية الداخلية)
  double get effectiveDepthDy =>
      overallDepthH - clearCoverC - barDiameterPhi - (barDiameterPhi / 2.0);

  SlabProjectSettings copyWith({
    double? designLoadN,
    double? overallDepthH,
    double? clearCoverC,
    double? barDiameterPhi,
    double? fcu,
    double? fy,
    DesignCalculationMode? calculationMode,
    bool? lectureRoundBetaTo3Decimals,
  }) {
    return SlabProjectSettings(
      designLoadN: designLoadN ?? this.designLoadN,
      overallDepthH: overallDepthH ?? this.overallDepthH,
      clearCoverC: clearCoverC ?? this.clearCoverC,
      barDiameterPhi: barDiameterPhi ?? this.barDiameterPhi,
      fcu: fcu ?? this.fcu,
      fy: fy ?? this.fy,
      calculationMode: calculationMode ?? this.calculationMode,
      lectureRoundBetaTo3Decimals:
          lectureRoundBetaTo3Decimals ?? this.lectureRoundBetaTo3Decimals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'designLoadN': designLoadN,
      'overallDepthH': overallDepthH,
      'clearCoverC': clearCoverC,
      'barDiameterPhi': barDiameterPhi,
      'fcu': fcu,
      'fy': fy,
      'calculationMode': calculationMode.name,
      'lectureRoundBetaTo3Decimals': lectureRoundBetaTo3Decimals,
    };
  }

  factory SlabProjectSettings.fromJson(Map<String, dynamic> json) {
    return SlabProjectSettings(
      designLoadN:
          (json['designLoadN'] as num?)?.toDouble() ??
          AppConstants.defaultDesignLoad,
      overallDepthH:
          (json['overallDepthH'] as num?)?.toDouble() ??
          AppConstants.defaultOverallDepth,
      clearCoverC:
          (json['clearCoverC'] as num?)?.toDouble() ??
          AppConstants.defaultClearCover,
      barDiameterPhi:
          (json['barDiameterPhi'] as num?)?.toDouble() ??
          AppConstants.defaultBarDiameter,
      fcu: (json['fcu'] as num?)?.toDouble() ?? AppConstants.defaultFcu,
      fy: (json['fy'] as num?)?.toDouble() ?? AppConstants.defaultFy,
      calculationMode: DesignCalculationModeX.fromStorage(
        json['calculationMode'] as String?,
      ),
      lectureRoundBetaTo3Decimals:
          (json['lectureRoundBetaTo3Decimals'] as bool?) ?? true,
    );
  }
}
