import 'package:bs8110_slab_designer/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('تشغيل التطبيق بواجهة عربية RTL والتبديل بين الشاشات ووضع الحساب',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Bs8110SlabApp(),
      ),
    );
    await tester.pumpAndSettle();

    // التحقق من اتجاه الواجهة العربية RTL
    final directionality = Directionality.of(
      tester.element(find.text('ابدأ التصميم الإنشائي')),
    );
    expect(directionality, TextDirection.rtl);

    // التحقق من وجود البطاقات الرئيسية
    final singleSlabCard = find.text('تصميم بلاطة واحدة + جيرانها');
    expect(singleSlabCard, findsOneWidget);
    expect(find.text('بناء مخطط سقف كامل (Grid Editor)'), findsOneWidget);
    expect(find.text('كتيّب الكود BS 8110'), findsOneWidget);

    // اختبار التبديل إلى وضع الكود الصارم
    await tester.tap(find.text('الكود الصارم BS 8110'));
    await tester.pumpAndSettle();
    expect(find.text('الكود الصارم'), findsOneWidget);

    // اختبار التنقل إلى شاشة البلاطة الواحدة (المرحلة 4)
    await tester.ensureVisible(singleSlabCard);
    await tester.tap(singleSlabCard);
    await tester.pumpAndSettle();
    expect(find.text('انقر على أي حافة لتغيير شرط استنادها'), findsOneWidget);
    expect(find.text('مثال الاختبار S7'), findsOneWidget);
  });
}
