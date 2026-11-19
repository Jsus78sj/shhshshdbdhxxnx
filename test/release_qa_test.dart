import 'package:bs8110_slab_designer/app.dart';
import 'package:bs8110_slab_designer/data/repositories/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LocalStorageService.clearMemoryFallback();
  });

  group('المرحلة 7 (QA) — اختبارات الاستجابة وعدم التداخل عبر مقاسات الشاشات', () {
    final screenSizes = <String, Size>{
      'هاتف صغير (360x640)': const Size(360, 640),
      'هاتف قياسي (390x844)': const Size(390, 844),
      'جهاز لوحي (800x1280)': const Size(800, 1280),
    };

    for (final entry in screenSizes.entries) {
      testWidgets('فحص خلو الواجهة من Overflow على ${entry.key}',
          (WidgetTester tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: Bs8110SlabApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. الشاشة الرئيسية + نافذة حول التطبيق + التبديل للوضع الداكن
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('حول التطبيق'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Offline-First'), findsOneWidget);
        await tester.tap(find.text('إغلاق'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('التبديل إلى الوضع الداكن'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. شاشة الإدخال السريع -> التقرير (بكل تبويباته الـ 3)
        final singleBtn = find.text('تصميم بلاطة واحدة + جيرانها');
        await tester.ensureVisible(singleBtn);
        await tester.tap(singleBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('احسب وصمّم البلاطة (S7)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('الحل بالخطوات'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('الرسومات والقطاعات'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
