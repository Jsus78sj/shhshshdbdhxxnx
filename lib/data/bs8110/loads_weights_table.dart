/// عنصر حمل أو وزن مادة في Table 3
class MaterialLoadEntry {
  final String id;
  final String categoryEn;
  final String nameEn;
  final String nameAr;
  final double value;
  final String unit;

  const MaterialLoadEntry({
    required this.id,
    required this.categoryEn,
    required this.nameEn,
    required this.nameAr,
    required this.value,
    required this.unit,
  });
}

/// Table 3 — Typical Imposed Loads And Weights Of Materials (الصفحة 3 من الكود المرفق)
class LoadsWeightsTable {
  LoadsWeightsTable._();

  /// الأحمال الحية للأسقف والمباني (kN/m²)
  static const List<MaterialLoadEntry> imposedLoads = [
    MaterialLoadEntry(
      id: 'flat_roof_no_access',
      categoryEn: 'Roof And Floor Imposed Loads',
      nameEn: 'Flat roof, no access',
      nameAr: 'سطح مستوٍ غير مستخدم (بدون وصول)',
      value: 0.75,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'flat_roof_with_access',
      categoryEn: 'Roof And Floor Imposed Loads',
      nameEn: 'Flat roof, with access',
      nameAr: 'سطح مستوٍ مستخدم (مع وصول)',
      value: 1.50,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'houses_normal_furniture',
      categoryEn: 'Residential premises',
      nameEn: 'Houses with normal furniture',
      nameAr: 'منازل سكنية بأثاث عادي',
      value: 1.50,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'hotels_motels_hospitals',
      categoryEn: 'Residential premises',
      nameEn: 'Hotels, motels and hospitals',
      nameAr: 'فنادق وموتيلات ومستشفيات',
      value: 2.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'hostels_schools_colleges',
      categoryEn: 'Residential premises',
      nameEn: 'Hostels in schools and colleges',
      nameAr: 'سكن طلاب المدارس والكليات',
      value: 1.50,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'classrooms_labs',
      categoryEn: 'Place of public assembly',
      nameEn: 'Class-room and laboratories',
      nameAr: 'فصول دراسية ومختبرات',
      value: 3.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'public_halls_theatres',
      categoryEn: 'Place of public assembly',
      nameEn: 'Public halls, theatres and cinemas',
      nameAr: 'صالات عامة ومسارح ودور سينما',
      value: 4.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'library_reading_rooms',
      categoryEn: 'Place of public assembly',
      nameEn: 'Library reading rooms with book storage',
      nameAr: 'قاعات مطالعة ومكتبات مع تخزين كتب',
      value: 4.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'shops_display_sale',
      categoryEn: 'Place of public assembly',
      nameEn: 'Shops (display and sale)',
      nameAr: 'محلات تجارية (عرض وبيع)',
      value: 4.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'stores_libraries',
      categoryEn: 'Storage',
      nameEn: 'Stores and libraries',
      nameAr: 'مخازن ومستودعات كتب',
      value: 6.00,
      unit: 'kN/m²',
    ),
  ];

  /// الأوزان السطحية للمواد والجدران (kN/m²)
  static const List<MaterialLoadEntry> surfaceWeights = [
    MaterialLoadEntry(
      id: 'floor_tiles_2_5cm',
      categoryEn: 'Weights',
      nameEn: 'Floor tiles 2.5 cm thick',
      nameAr: 'بلاط أرضيات بسماكة 2.5 سم',
      value: 0.65,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'hollow_block_10cm',
      categoryEn: 'Weights',
      nameEn: 'Hollow concrete block, 10 cm thick',
      nameAr: 'بلوك خرساني مفرغ سماكة 10 سم',
      value: 1.30,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'hollow_block_15cm',
      categoryEn: 'Weights',
      nameEn: 'Hollow concrete block, 15 cm thick',
      nameAr: 'بلوك خرساني مفرغ سماكة 15 سم',
      value: 2.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'hollow_block_20cm',
      categoryEn: 'Weights',
      nameEn: 'Hollow concrete block, 20 cm thick',
      nameAr: 'بلوك خرساني مفرغ سماكة 20 سم',
      value: 2.60,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'plain_block_10cm',
      categoryEn: 'Weights',
      nameEn: 'Plain concrete block, 10 cm thick',
      nameAr: 'بلوك خرساني مصمت سماكة 10 سم',
      value: 2.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'plain_block_15cm',
      categoryEn: 'Weights',
      nameEn: 'Plain concrete block, 15 cm thick',
      nameAr: 'بلوك خرساني مصمت سماكة 15 سم',
      value: 3.00,
      unit: 'kN/m²',
    ),
    MaterialLoadEntry(
      id: 'plain_block_20cm',
      categoryEn: 'Weights',
      nameEn: 'Plain concrete block, 20 cm thick',
      nameAr: 'بلوك خرساني مصمت سماكة 20 سم',
      value: 4.00,
      unit: 'kN/m²',
    ),
  ];

  /// الأوزان النوعية (الكثافات الوزنية) للمواد (kN/m³)
  static const List<MaterialLoadEntry> unitWeights = [
    MaterialLoadEntry(
      id: 'cement',
      categoryEn: 'Unit Weights',
      nameEn: 'Cement',
      nameAr: 'أسمنت',
      value: 13.00,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'cement_mortar',
      categoryEn: 'Unit Weights',
      nameEn: 'Cement mortar',
      nameAr: 'مونة أسمنتية',
      value: 16.50,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'cement_plaster',
      categoryEn: 'Unit Weights',
      nameEn: 'Cement plaster',
      nameAr: 'لياسة (قصارة) أسمنتية',
      value: 16.50,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'tiles',
      categoryEn: 'Unit Weights',
      nameEn: 'Tiles',
      nameAr: 'بلاط',
      value: 24.00,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'stone_wall',
      categoryEn: 'Unit Weights',
      nameEn: 'Stone wall',
      nameAr: 'جدار حجري',
      value: 23.00,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'plain_concrete',
      categoryEn: 'Unit Weights',
      nameEn: 'Plain concrete',
      nameAr: 'خرسانة عادية',
      value: 23.00,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'reinforced_concrete',
      categoryEn: 'Unit Weights',
      nameEn: 'Reinforced concrete',
      nameAr: 'خرسانة مسلحة',
      value: 24.00,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'marbles',
      categoryEn: 'Unit Weights',
      nameEn: 'Marbles',
      nameAr: 'رخام',
      value: 27.50,
      unit: 'kN/m³',
    ),
    MaterialLoadEntry(
      id: 'sand_layer',
      categoryEn: 'Unit Weights',
      nameEn: 'Sand layer',
      nameAr: 'طبقة رمل (ردم)',
      value: 17.50,
      unit: 'kN/m³',
    ),
  ];

  static double get reinforcedConcreteUnitWeight => 24.00;
  static double get sandLayerUnitWeight => 17.50;
}
