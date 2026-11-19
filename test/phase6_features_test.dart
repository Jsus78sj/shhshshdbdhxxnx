import 'dart:convert';
import 'package:bs8110_slab_designer/app.dart';
import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:bs8110_slab_designer/presentation/pdf/slab_report_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('المرحلة 6 — مولد تقارير PDF العربية', () {
    test('يولّد ملف PDF صالح (%PDF-) للبلاطة S7 في وضعي الشرح والكود الصارم',
        () async {
      final lecturePlan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.lectureMode,
      );
      final reportLecture = SlabDesignPipeline.designFromFloorGrid(
        plan: lecturePlan,
        slabId: 'S7',
      );

      final bytesLecture = await SlabReportPdfGenerator.generatePdfBytes(
        report: reportLecture,
        sourceLabelAr: 'اختبار جامعة عدن',
      );
      expect(bytesLecture.length, greaterThan(1000));
      expect(utf8.decode(bytesLecture.sublist(0, 5)), '%PDF-');
      // الخطوط مُضمَّنة فعلاً: Helvetica الاحتياطي لا يتجاوز بضع عشرات الكيلوبايت.
      expect(bytesLecture.length, greaterThan(80000),
          reason: 'لم تُضمَّن خطوط NotoSansArabic/DejaVu في ملف PDF');

      final strictPlan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.strictBs8110,
      );
      final reportStrict = SlabDesignPipeline.designFromFloorGrid(
        plan: strictPlan,
        slabId: 'S7',
        autoAdjustDepthIfUnsafeInStrictMode: true,
      );
      final bytesStrict = await SlabReportPdfGenerator.generatePdfBytes(
        report: reportStrict,
        sourceLabelAr: 'وضع الكود الصارم',
      );
      expect(bytesStrict.length, greaterThan(1000));
      expect(utf8.decode(bytesStrict.sublist(0, 5)), '%PDF-');
      expect(bytesStrict.length, greaterThan(80000),
          reason: 'لم تُضمَّن خطوط NotoSansArabic/DejaVu في ملف PDF');
    });
  });

  group('المرحلة 6 — واجهة الرسومات التفاعلية وكتيّب الكود التفاعلي', () {
    testWidgets('يعرض تبويب الرسومات والقطاعات للبلاطة S7 ويتفاعل مع التبديلات',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Bs8110SlabApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('تصميم بلاطة واحدة + جيرانها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('احسب وصمّم البلاطة (S7)'));
      await tester.pumpAndSettle();

      // فتح التبويب الثالث: الرسومات والقطاعات
      await tester.tap(find.text('الرسومات والقطاعات'));
      await tester.pumpAndSettle();

      expect(
        find.text('1. مخطط عزوم الانحناء للشريحة (Bending Moment Diagram)'),
        findsOneWidget,
      );
      expect(
        find.text('2. مسقط توزيع حديد التسليح (Reinforcement Plan)'),
        findsOneWidget,
      );

      // التبديل بين أوضاع مخطط العزوم
      await tester.tap(find.text('قبل الموازنة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بعد الموازنة'));
      await tester.pumpAndSettle();
    });

    testWidgets('كتيّب الكود: البحث عن Table 3.14 وفتح الجدول وحاسبة التناسب الخطي',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Bs8110SlabApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('كتيّب الكود BS 8110'));
      await tester.pumpAndSettle();

      // البحث الفوري عن Table 3.14
      await tester.enterText(find.byType(TextField), '3.14');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Table 3.14'),
        findsWidgets,
      );

      // فتح تفاصيل Table 3.14
      await tester.tap(find.textContaining('Table 3.14').first);
      await tester.pumpAndSettle();
      expect(find.text('C6 — موجب (+)'), findsOneWidget);

      // فتح حاسبة التناسب الخطي والتحقق من النتيجة الافتراضية لـ S7 (0.0369)
      await tester.tap(find.byTooltip('حاسبة التناسب الخطي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0.0369'), findsOneWidget);
    });
  });
}
