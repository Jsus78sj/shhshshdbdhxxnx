import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/bs8110/slab_moment_shear_tables.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('وضع الشرح — تقريب β الناتج عن التناسب الخطي إلى 3 خانات', () {
    test('Table 3.14 Case 6 عند ly/lx = 1.0244: 0.0369 ≈ 0.037 (كما في ورقة الدكتور)',
        () {
      final rounded = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: 4.20 / 4.10,
        roundBetaDecimals: 3,
      );
      expect(rounded.betaSxPos, closeTo(0.037, 1e-12));
      expect(rounded.betaSxPosTrace.rawResult, closeTo(0.03693, 1e-4));
      expect(rounded.betaSxPosTrace.wasRounded, isTrue);

      final raw = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: 4.20 / 4.10,
      );
      expect(raw.betaSxPos, closeTo(0.03693, 1e-4));
      expect(raw.betaSxPosTrace.wasRounded, isFalse);
    });

    test('القيم المأخوذة من الجدول مباشرة (بلا تناسب) لا يمسّها التقريب', () {
      final exact = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: 1.0,
        roundBetaDecimals: 3,
      );
      expect(exact.betaSxPos, 0.034);
      expect(exact.betaSxPosTrace.wasExactMatch, isTrue);
      expect(exact.betaSxPosTrace.wasRounded, isFalse);
    });

    test('صيغة LaTeX تعرض 0.0369 ثم ≈ 0.037 عند التقريب', () {
      final rounded = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: 4.20 / 4.10,
        roundBetaDecimals: 3,
      );
      final tex = rounded.betaSxPosTrace.toLectureLatex(unknownSymbol: 'x');
      expect(tex, contains('0.0369'));
      expect(tex, contains(r'\approx'));
      expect(tex, contains('0.037'));

      final raw = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: 4.20 / 4.10,
      );
      expect(
        raw.betaSxPosTrace.toLectureLatex(unknownSymbol: 'x'),
        isNot(contains(r'\approx')),
      );
    });

    test('S7 في وضع الشرح: Msx+ = 7.15 كما في ورقة الحل ويبقى التسليح 5 No 10', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.lectureMode,
      );
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
      );
      expect(report.initialMoments.betaSxPos, closeTo(0.037, 1e-12));
      expect(report.initialMoments.msxPos, closeTo(7.15, 0.005));
      expect(report.summaryRow.shortMidLecture, '5 No 10');
    });

    test('S7 في الوضع الصارم: لا تقريب (β = 0.0369 و Msx+ = 7.14)', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.strictBs8110,
      );
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
      );
      expect(report.initialMoments.betaSxPos, closeTo(0.03693, 1e-4));
      expect(report.initialMoments.betaSxPosTrace!.wasRounded, isFalse);
      expect(report.initialMoments.msxPos, closeTo(7.14, 0.005));
    });

    test('إيقاف الخيار يعيد القيمة غير المقرّبة داخل وضع الشرح', () {
      final basePlan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.lectureMode,
      );
      final plan = basePlan.copyWith(
        settings: basePlan.settings.copyWith(
          lectureRoundBetaTo3Decimals: false,
        ),
      );
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
      );
      expect(report.initialMoments.betaSxPos, closeTo(0.03693, 1e-4));
      expect(report.initialMoments.msxPos, closeTo(7.14, 0.005));
    });

    test('الإعداد يُحفظ ويُقرأ من JSON، والقيمة الافتراضية للملفات القديمة true', () {
      const off = SlabProjectSettings(lectureRoundBetaTo3Decimals: false);
      final restored = SlabProjectSettings.fromJson(off.toJson());
      expect(restored.lectureRoundBetaTo3Decimals, isFalse);

      final legacy = SlabProjectSettings.fromJson({'fcu': 25.0});
      expect(legacy.lectureRoundBetaTo3Decimals, isTrue);

      expect(const SlabProjectSettings().betaRoundDecimals, 3);
      expect(off.betaRoundDecimals, isNull);
      expect(
        const SlabProjectSettings(
          calculationMode: DesignCalculationMode.strictBs8110,
        ).betaRoundDecimals,
        isNull,
      );
    });
  });

  group('وضع الشرح — قاعدة B.R في فحص الهطول', () {
    test('S7 (اتجاهان، حافتا lx غير مستمرتين، حافتان مستمرتان): B.R = 26 مع ملاحظة توضح القاعدة',
        () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.lectureMode,
      );
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
      );
      expect(report.deflectionCheck.basicRatioBR, 26.0);
      final note = report.deflectionCheck.comparativeModeNoteAr!;
      // الملاحظة تذكر القاعدة المطبّقة صراحةً ثم المقارنة مع Table 3.9 الحرفي (h = 140 mm)
      expect(note, contains('مستمرة في نظام السقف'));
      expect(note, contains('B.R = 26'));
      expect(note, contains('140'));
    });

    test('اتجاه واحد مستمر عند الحافتين القصيرتين فقط: B.R = 20 (لا يعدّ بحراً مستمراً)',
        () {
      // lx = 1.8 m بين الحافتين الطويلتين (يسار/يمين) غير المستمرتين،
      // والاستمرارية على الحافتين القصيرتين (أعلى/أسفل) لا تؤثر على بحر الاتجاه الواحد.
      const input = SingleSlabInput(
        slabId: 'ONE_WAY_A',
        widthXM: 1.8,
        heightYM: 4.5,
        topEdge: EdgeCondition.continuous,
        bottomEdge: EdgeCondition.continuous,
        leftEdge: EdgeCondition.discontinuousFree,
        rightEdge: EdgeCondition.discontinuousFree,
      );
      final report = SlabDesignPipeline.designSingleSlab(
        input: input,
        settings: const SlabProjectSettings(
          calculationMode: DesignCalculationMode.lectureMode,
        ),
      );
      expect(report.topology.spanningType, SlabSpanningType.oneWay);
      expect(report.deflectionCheck.basicRatioBR, 20.0);
    });

    test('اتجاه واحد مستمر عند إحدى حافتي البحر القصير: B.R = 26', () {
      const input = SingleSlabInput(
        slabId: 'ONE_WAY_B',
        widthXM: 1.8,
        heightYM: 4.5,
        topEdge: EdgeCondition.discontinuousFree,
        bottomEdge: EdgeCondition.discontinuousFree,
        leftEdge: EdgeCondition.continuous,
        rightEdge: EdgeCondition.discontinuousFree,
      );
      final report = SlabDesignPipeline.designSingleSlab(
        input: input,
        settings: const SlabProjectSettings(
          calculationMode: DesignCalculationMode.lectureMode,
        ),
      );
      expect(report.topology.spanningType, SlabSpanningType.oneWay);
      expect(report.deflectionCheck.basicRatioBR, 26.0);
    });
  });
}
