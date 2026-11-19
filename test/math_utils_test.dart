import 'package:bs8110_slab_designer/core/math/math_utils.dart';
import 'package:bs8110_slab_designer/domain/models/slab_project_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathUtils — اختبارات التناسب الخطي والتقريب', () {
    test('يحسب معامل βsx+ للبلاطة S7 عند ly/lx = 1.0244 بدقة مطابقة للحل المرجعي', () {
      final betaTable = <double, double>{
        1.0: 0.034,
        1.1: 0.046,
        1.2: 0.056,
      };

      final result = MathUtils.interpolateFromTable(1.0244, betaTable);
      expect(result, closeTo(0.036928, 1e-6));
      expect(MathUtils.roundTo(result, 3), 0.037);
    });

    test('يحافظ على الحدود عند القيم الأصغر أو الأكبر من نطاق الجدول', () {
      final table = <double, double>{1.0: 0.26, 1.1: 0.30};
      expect(MathUtils.interpolateFromTable(0.9, table), 0.26);
      expect(MathUtils.interpolateFromTable(2.5, table), 0.30);
    });
  });

  group('SlabProjectSettings — الأعماق الفعالة الافتراضية', () {
    test('يحسب dx = 90 mm و dy = 80 mm للمعطيات الافتراضية (h=120, c=25, Ø=10)', () {
      const settings = SlabProjectSettings();
      expect(settings.effectiveDepthDx, 90.0);
      expect(settings.effectiveDepthDy, 80.0);
    });
  });
}
