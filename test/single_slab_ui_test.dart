import 'package:bs8110_slab_designer/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'مسار الإدخال السريع والتقرير: تصميم S7 -> الجدول والخطوات -> التبديل للوضع الصارم وإعادة التصميم بـ 140 mm',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Bs8110SlabApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. فتح شاشة الإدخال السريع
    await tester.tap(find.text('تصميم بلاطة واحدة + جيرانها'));
    await tester.pumpAndSettle();

    expect(find.text('Case 6'), findsOneWidget);

    // 2. الضغط على زر الحساب والتصميم
    await tester.tap(find.text('احسب وصمّم البلاطة (S7)'));
    await tester.pumpAndSettle();

    // 3. التحقق من شاشة التقرير وجدول التسليح المطابق للسبورة (وضع شرح المحاضرة)
    expect(find.text('تقرير تصميم البلاطة S7'), findsOneWidget);
    expect(find.text('5 No 10'), findsOneWidget);
    expect(find.text('4 No 10'), findsOneWidget);
    expect(find.text('6 No 10'), findsNWidgets(2));

    // 4. الانتقال لتبويب الحل خطوة بخطوة
    await tester.tap(find.text('الحل بالخطوات'));
    await tester.pumpAndSettle();
    expect(find.text('خطوات الحل الأكاديمي (6 خطوات)'), findsOneWidget);
    expect(find.text('المعطيات والأعماق الفعالة وتصنيف البلاطة'), findsOneWidget);

    // 5. العودة لتبويب الملخص والتبديل السريع إلى وضع الكود الصارم من شريط التقرير
    await tester.tap(find.text('الملخص'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكود الصارم'));
    await tester.pumpAndSettle();

    // التحقق من اكتشاف فشل الهطول وظهور زر السماكة المقترحة 140 mm
    final applyBtn = find.widgetWithText(
      ElevatedButton,
      'إعادة التصميم بالسماكة الآمنة المقترحة (h = 140 mm)',
    );
    expect(applyBtn, findsOneWidget);

    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    expect(
      find.text('التصميم آمن ومستوفٍ لمتطلبات الحد الأقصى والتشغيل'),
      findsOneWidget,
    );
  });
}
