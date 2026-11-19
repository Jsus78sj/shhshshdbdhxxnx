import 'package:bs8110_slab_designer/app.dart';
import 'package:bs8110_slab_designer/data/repositories/local_storage_service.dart';
import 'package:bs8110_slab_designer/data/repositories/projects_repository.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LocalStorageService.clearMemoryFallback();
  });

  group('المرحلة 5 — تسلسل JSON ومستودع المشاريع المحلية', () {
    test('حفظ واسترجاع مخطط اختبار جامعة عدن عبر JSON يحافظ على كافة التفاصيل ونتائج S7',
        () {
      final original = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan();
      final json = original.toJson();
      final restored = FloorGridPlan.fromJson(json);

      expect(restored.projectId, original.projectId);
      expect(restored.xSpansM, original.xSpansM);
      expect(restored.ySpansM, original.ySpansM);
      expect(restored.cells.length, 12);
      expect(restored.findById('S6')?.cantilevers.length, 1);
      expect(restored.findById('S9')?.overrideHeightYM, 4.00);
      expect(restored.findById('S3')?.overrideHeightYM, 4.20);

      final reportAfterRestore = SlabDesignPipeline.designFromFloorGrid(
        plan: restored,
        slabId: 'S7',
      );
      expect(reportAfterRestore.summaryRow.shortMidLecture, '5 No 10');
      expect(reportAfterRestore.summaryRow.longMidLecture, '6 No 10');
      expect(reportAfterRestore.summaryRow.longSupportLecture, '6 No 10');
    });

    test('عمليات CRUD في ProjectsRepository: حفظ، إعادة تسمية، نسخ، وحذف',
        () async {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan();

      // حفظ
      await ProjectsRepository.saveProject(plan);
      expect(ProjectsRepository.loadAllProjects().length, 1);

      // إعادة تسمية
      await ProjectsRepository.renameProject(
        projectId: plan.projectId,
        newName: 'مشروع سقف معدّل',
      );
      expect(
        ProjectsRepository.loadAllProjects().first.projectName,
        'مشروع سقف معدّل',
      );

      // إنشاء نسخة
      final dup = await ProjectsRepository.duplicateProject(plan.projectId);
      expect(dup, isNotNull);
      expect(ProjectsRepository.loadAllProjects().length, 2);

      // حذف
      await ProjectsRepository.deleteProject(plan.projectId);
      expect(ProjectsRepository.loadAllProjects().length, 1);
    });
  });

  group('المرحلة 5 — اختبارات واجهة محرر المخطط الكامل والمشاريع المحفوظة', () {
    testWidgets(
        'فتح محرر المخطط -> حفظ المشروع -> تصميم S7 من المخطط -> التحقق من المشاريع المحفوظة',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Bs8110SlabApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. الدخول إلى محرر المخطط الكامل
      await tester.tap(find.text('بناء مخطط سقف كامل (Grid Editor)'));
      await tester.pumpAndSettle();

      // التحقق من فتح قالب الاختبار واختيار S7 افتراضياً
      expect(find.text('صمّم البلاطة (S7) واعرض الحل الكامل'), findsOneWidget);

      // 2. حفظ المشروع محلياً
      await tester.tap(find.byTooltip('حفظ المشروع محلياً'));
      await tester.pumpAndSettle();
      expect(ProjectsRepository.loadAllProjects().length, 1);

      // 3. فتح تقرير تصميم البلاطة S7 من المخطط الكامل
      await tester.tap(find.text('صمّم البلاطة (S7) واعرض الحل الكامل'));
      await tester.pumpAndSettle();

      expect(find.text('تقرير تصميم البلاطة S7'), findsOneWidget);
      expect(find.text('5 No 10'), findsOneWidget);
      expect(find.text('6 No 10'), findsNWidgets(2));
    });
  });
}
