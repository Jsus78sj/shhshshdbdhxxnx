export 'column_tables.dart';
export 'deflection_tables.dart';
export 'flexure_tables.dart';
export 'loads_weights_table.dart';
export 'reinforcement_tables.dart';
export 'shear_tables.dart';
export 'slab_moment_shear_tables.dart';

/// تعريف وصفي لكل جدول أو قسم في الكود المرفق (يُستخدم في كتيّب الكود والبحث)
class CodeSectionMeta {
  final String codeId;
  final String pageNumber;
  final String titleAr;
  final String titleEn;
  final String categoryAr;

  const CodeSectionMeta({
    required this.codeId,
    required this.pageNumber,
    required this.titleAr,
    required this.titleEn,
    required this.categoryAr,
  });
}

/// الفهرس الرسمي لجميع الجداول والأقسام الـ 18 المرقمنة في قاعدة بيانات BS 8110
class Bs8110CodeCatalog {
  Bs8110CodeCatalog._();

  static const List<CodeSectionMeta> sections = [
    CodeSectionMeta(
      codeId: 'Table 1',
      pageNumber: '٢',
      titleAr: 'مساحات ومحيط عدد محدد من أسياخ التسليح',
      titleEn: 'Bar Reinforcement: Cross Sectional Areas & Perimeters',
      categoryAr: 'حديد التسليح',
    ),
    CodeSectionMeta(
      codeId: 'Table 2',
      pageNumber: '٢',
      titleAr: 'مساحات أسياخ التسليح لكل متر عرض حسب المسافات',
      titleEn: 'Bar Reinforcement: Cross Sectional Areas per Meter Width',
      categoryAr: 'حديد التسليح',
    ),
    CodeSectionMeta(
      codeId: 'Table 3',
      pageNumber: '٣',
      titleAr: 'الأحمال الحية والأوزان السطحية والنوعية للمواد',
      titleEn: 'Typical Imposed Loads And Weights Of Materials',
      categoryAr: 'الأحمال والمواد',
    ),
    CodeSectionMeta(
      codeId: 'Table 4',
      pageNumber: '٤',
      titleAr: 'تصميم القطاعات أحادية التسليح',
      titleEn: 'Design Table For Singly Reinforced Sections',
      categoryAr: 'تصميم الانحناء',
    ),
    CodeSectionMeta(
      codeId: 'Table 5',
      pageNumber: '٤',
      titleAr: 'تصميم القطاعات مزدوجة التسليح',
      titleEn: 'Design Table For Doubly Reinforced Sections',
      categoryAr: 'تصميم الانحناء',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.25',
      pageNumber: '٥',
      titleAr: 'النسب المئوية الدنيا لحديد التسليح',
      titleEn: 'Minimum Percentages Of Reinforcement',
      categoryAr: 'تصميم الانحناء',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.9',
      pageNumber: '٦',
      titleAr: 'النسب الأساسية للبحر إلى العمق الفعال',
      titleEn: 'Basic Span/Effective Depth Ratio',
      categoryAr: 'فحص الهطول',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.10',
      pageNumber: '٦',
      titleAr: 'معامل التعديل لتسليح الشد (Equation 7 & 8)',
      titleEn: 'Modification Factor For Tension Reinforcement',
      categoryAr: 'فحص الهطول',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.11',
      pageNumber: '٧',
      titleAr: 'معامل التعديل لتسليح الضغط',
      titleEn: 'Modification Factor For Compression Reinforcement',
      categoryAr: 'فحص الهطول',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.7',
      pageNumber: '٧',
      titleAr: 'شكل ومساحة تسليح القص في الكمرات',
      titleEn: 'Form And Area Of Shear Reinforcement In Beams',
      categoryAr: 'فحص القص والكمرات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.16',
      pageNumber: '٧',
      titleAr: 'شكل ومساحة تسليح القص في البلاطات المصمتة',
      titleEn: 'Form And Area Of Shear Reinforcement In Solid Slabs',
      categoryAr: 'فحص القص للبلاطات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.8',
      pageNumber: '٨',
      titleAr: 'إجهاد القص التصميمي للخرسانة vc',
      titleEn: 'Values Of vc Design Concrete Shear Stress',
      categoryAr: 'فحص القص للبلاطات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.5',
      pageNumber: '٨',
      titleAr: 'عزوم الانحناء وقوى القص للكمرات المستمرة',
      titleEn: 'Design Ultimate Bending Moments And Shear Forces (Beams)',
      categoryAr: 'فحص القص والكمرات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.12',
      pageNumber: '٨',
      titleAr: 'العزوم وقوى القص للبلاطات العاملة في اتجاه واحد',
      titleEn: 'Ultimate Bending Moment And Shear Forces In One-Way Slabs',
      categoryAr: 'تصميم البلاطات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.14',
      pageNumber: '٩',
      titleAr: 'معاملات عزوم الانحناء للبلاطات العاملة في اتجاهين',
      titleEn: 'Bending Moment Coefficients For Two-Way Rectangular Panels',
      categoryAr: 'تصميم البلاطات',
    ),
    CodeSectionMeta(
      codeId: 'Table 3.15',
      pageNumber: '١٠',
      titleAr: 'معاملات قوى القص للبلاطات العاملة في اتجاهين',
      titleEn: 'Shear Force Coefficients For Two-Way Rectangular Panels',
      categoryAr: 'تصميم البلاطات',
    ),
    CodeSectionMeta(
      codeId: 'Columns (le)',
      pageNumber: 'ملحق',
      titleAr: 'طريقة الجساءة لحساب الطول الفعال للأعمدة',
      titleEn: 'Stiffness Method For Effective Height Of Columns',
      categoryAr: 'ملحق الأعمدة',
    ),
    CodeSectionMeta(
      codeId: 'Table 2 (Col)',
      pageNumber: 'ملحق',
      titleAr: 'معامل β لتحويل العزوم ثنائية المحور في الأعمدة',
      titleEn: 'Coefficient β For Biaxial Bending In Columns',
      categoryAr: 'ملحق الأعمدة',
    ),
  ];
}
