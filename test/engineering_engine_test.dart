import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/bs8110/slab_moment_shear_tables.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('الاختبار الذهبي 1 — البلاطة S7 في وضع شرح المحاضرة (h = 120 mm)', () {
    test('تحقق كامل من مخطط الاختبار الكامل (FloorGridPlan -> S7)', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.lectureMode,
      );

      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
      );

      // 1. الطوبولوجية والحالة
      expect(report.topology.shortSpanLxM, 4.10);
      expect(report.topology.longSpanLyM, 4.20);
      expect(report.topology.lyOverLx, closeTo(1.0244, 1e-4));
      expect(report.topology.spanningType, SlabSpanningType.twoWay);
      expect(
        report.topology.twoWayCase,
        TwoWayPanelCase.twoLongEdgesDiscontinuous,
      );
      expect(report.topology.topEdge, EdgeCondition.continuous);
      expect(report.topology.bottomEdge, EdgeCondition.continuous);
      expect(report.topology.leftEdge, EdgeCondition.discontinuousFree);
      expect(report.topology.rightEdge, EdgeCondition.discontinuousDropped);

      // 2. الأعماق الفعالة والأحمال
      expect(report.loadResult.finalDesignLoadN, closeTo(11.50, 1e-6));
      expect(report.loadResult.dxMm, 90.0);
      expect(report.loadResult.dyMm, 80.0);

      // 3. العزوم الأولية
      // وضع الشرح يقرّب β الناتج عن التناسب الخطي إلى 3 خانات كما في ورقة الدكتور
      expect(report.initialMoments.betaSxPos, closeTo(0.037, 1e-9));
      expect(report.initialMoments.betaSxPosTrace!.rawResult,
          closeTo(0.03693, 1e-4));
      expect(report.initialMoments.betaSxPosTrace!.wasRounded, isTrue);
      expect(report.initialMoments.betaSxNeg, isNull);
      expect(report.initialMoments.betaSyNeg, 0.045);
      expect(report.initialMoments.betaSyPos, 0.034);
      expect(report.initialMoments.msxPos, closeTo(7.15, 0.005));
      expect(report.initialMoments.msyPos, closeTo(6.57, 0.02));
      expect(report.initialMoments.msyNeg, closeTo(8.70, 0.02));

      // 4. موازنة العزوم عند المسندين المستمرين (مع S6 و S8)
      expect(report.balancedMoments.supportBalances.length, 2);
      expect(
        report.balancedMoments.supportMomentBySide[EdgeSide.top],
        closeTo(7.82, 0.02),
      );
      expect(
        report.balancedMoments.supportMomentBySide[EdgeSide.bottom],
        closeTo(7.91, 0.02),
      );
      expect(report.balancedMoments.longMidMomentFinal, closeTo(7.41, 0.02));

      // 5. جدول التسليح النهائي المطابق للسبورة (No 10)
      expect(report.summaryRow.shortMidLecture, '5 No 10');
      expect(report.summaryRow.shortSupportLecture, '4 No 10');
      expect(report.summaryRow.longMidLecture, '6 No 10');
      expect(report.summaryRow.longSupportLecture, '6 No 10');

      // 6. فحص الهطول في وضع الشرح (B.R = 26 -> d_min = 78.85 <= 90)
      expect(report.deflectionCheck.basicRatioBR, 26.0);
      expect(report.deflectionCheck.serviceStressFs, closeTo(166.67, 0.05));
      expect(report.deflectionCheck.tensionModificationFactor, 2.0);
      expect(report.deflectionCheck.dMinRequiredMm, closeTo(78.85, 0.1));
      expect(report.deflectionCheck.isSafe, isTrue);
      // وجود التنبيه المقارن مع وضع الكود الصارم
      expect(report.deflectionCheck.comparativeModeNoteAr, isNotNull);

      // 7. فحص القص (Table 3.15 & Table 3.8 & Table 3.16)
      expect(report.shearCheck.governingBetaV, 0.40);
      expect(report.shearCheck.vMaxKnPerM, closeTo(18.86, 0.05));
      expect(report.shearCheck.designShearStressV, closeTo(0.236, 0.005));
      expect(report.shearCheck.concreteShearStressVc, closeTo(0.792, 0.005));
      expect(report.shearCheck.isSafe, isTrue);

      // 8. سجل الخطوات الأكاديمية
      expect(report.steps.length, 6);
      expect(report.overallIsSafe, isTrue);
    });

    test('تطابق وضع الإدخال السريع (SingleSlabInput) مع نتيجة المخطط الكامل لـ S7',
        () {
      const input = SingleSlabInput(
        slabId: 'S7',
        widthXM: 4.10,
        heightYM: 4.20,
        topEdge: EdgeCondition.continuous,
        bottomEdge: EdgeCondition.continuous,
        leftEdge: EdgeCondition.discontinuousFree,
        rightEdge: EdgeCondition.discontinuousDropped,
        topNeighbor: NeighborSlabInput(
          label: 'S6',
          spanAlongStripM: 4.20,
          perpendicularSpanM: 4.10,
          isFarEndContinuous: false,
          panelCase: TwoWayPanelCase.oneShortEdgeDiscontinuous,
        ),
        bottomNeighbor: NeighborSlabInput(
          label: 'S8',
          spanAlongStripM: 4.40,
          perpendicularSpanM: 4.10,
          isFarEndContinuous: true,
          panelCase: TwoWayPanelCase.oneLongEdgeDiscontinuous,
        ),
      );

      final report = SlabDesignPipeline.designSingleSlab(
        input: input,
        settings: const SlabProjectSettings(
          calculationMode: DesignCalculationMode.lectureMode,
        ),
      );

      expect(report.balancedMoments.longMidMomentFinal, closeTo(7.41, 0.02));
      expect(report.summaryRow.shortMidLecture, '5 No 10');
      expect(report.summaryRow.longMidLecture, '6 No 10');
      expect(report.summaryRow.longSupportLecture, '6 No 10');
      expect(report.overallIsSafe, isTrue);
    });
  });

  group('الاختبار الذهبي 2 — البلاطة S7 في وضع الكود البريطاني الصارم BS 8110',
      () {
    test('يكتشف فشل الهطول عند h=120 mm ويقترح h=140 mm', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.strictBs8110,
      );

      final report120 = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
        autoAdjustDepthIfUnsafeInStrictMode: false,
      );

      expect(report120.deflectionCheck.basicRatioBR, 20.0);
      expect(report120.deflectionCheck.actualSpanDepthRatio, closeTo(45.56, 0.05));
      expect(report120.deflectionCheck.allowableSpanDepthRatio, closeTo(40.0, 0.05));
      expect(report120.deflectionCheck.isSafe, isFalse);
      expect(report120.deflectionCheck.suggestedOverallDepthHMm, 140.0);
      expect(report120.deflectionCheck.suggestedCompressionSteelPercent, isNotNull);
    });

    test('يعيد التصميم تلقائياً بـ h=140 mm ويحدّث الحمل إلى 12.172 kN/m² وينجح', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: DesignCalculationMode.strictBs8110,
      );

      final report140 = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S7',
        autoAdjustDepthIfUnsafeInStrictMode: true,
      );

      expect(report140.loadResult.overallDepthHMm, 140.0);
      expect(report140.loadResult.dxMm, 110.0);
      expect(report140.loadResult.dyMm, 100.0);
      expect(report140.loadResult.selfWeightDeltaN, closeTo(0.672, 1e-4));
      expect(report140.loadResult.finalDesignLoadN, closeTo(12.172, 1e-4));
      expect(report140.deflectionCheck.actualSpanDepthRatio, closeTo(37.27, 0.05));
      expect(report140.deflectionCheck.isSafe, isTrue);
      expect(report140.shearCheck.isSafe, isTrue);
      expect(report140.overallIsSafe, isTrue);
    });
  });

  group('الاختبار الذهبي 3 — أمثلة السبورة (Section A-A, Section B-B, المهبطة, الكابولي)',
      () {
    test('موازنة Section B-B: M_UB = 7.14, M_L = 8.94, M_mid = 12.15', () {
      final kLeft = MomentBalancer.relativeStiffness(
        spanLengthM: 4.0,
        isBothEndsContinuous: false,
      );
      final kRight = MomentBalancer.relativeStiffness(
        spanLengthM: 6.5,
        isBothEndsContinuous: false,
      );

      final res = MomentBalancer.balanceTwoSpanSupport(
        mSlabInitial: 13.36,
        mNeighborInitial: 6.22,
        kSlab: kLeft,
        kNeighbor: kRight,
      );

      expect(res.mUnbalanced, closeTo(7.14, 1e-4));
      expect(res.mBalanced, closeTo(8.94, 0.01));
      expect(9.94 + res.midSpanIncrease, closeTo(12.15, 0.01));
    });

    test('موازنة Section A-A عند المسند B والمسند C', () {
      final kAB = MomentBalancer.relativeStiffness(
        spanLengthM: 4.1,
        isBothEndsContinuous: false,
      );
      final kBC = MomentBalancer.relativeStiffness(
        spanLengthM: 5.0,
        isBothEndsContinuous: true,
      );
      final kCD = MomentBalancer.relativeStiffness(
        spanLengthM: 4.5,
        isBothEndsContinuous: false,
      );

      // عند المسند B
      final atB = MomentBalancer.balanceTwoSpanSupport(
        mSlabInitial: 9.74,
        mNeighborInitial: 6.22,
        kSlab: kAB,
        kNeighbor: kBC,
      );
      expect(atB.mUnbalanced, closeTo(3.52, 1e-4));
      expect(atB.mBalanced, closeTo(8.06, 0.05));
      expect(7.39 + atB.midSpanIncrease, closeTo(8.23, 0.05));

      // عند المسند C
      final atC = MomentBalancer.balanceTwoSpanSupport(
        mSlabInitial: 7.56,
        mNeighborInitial: 6.22,
        kSlab: kCD,
        kNeighbor: kBC,
      );
      expect(atC.mUnbalanced, closeTo(1.34, 1e-4));
      expect(atC.mBalanced, closeTo(6.95, 0.01));
      expect(5.71 + atC.midSpanIncrease, closeTo(6.02, 0.01));
    });

    test('حمل البلاطة المهبطة (الردم 20 سم × 18.5 = 3.7 => W = 15.68 kN/m²)', () {
      final fillFactored = LoadCalculator.calculateDroppedSlabFillFactoredLoad(
        fillDepthM: 0.20,
        fillUnitWeightKnM3: 18.5,
      );
      expect(fillFactored, closeTo(5.18, 1e-4));
      expect(10.5 + fillFactored, closeTo(15.68, 1e-4));
    });

    test('البلاطة S6 المتصلة بكابولي 1.60 m تحسب عزم الكابولي وامتداده 1.5L', () {
      // العزم الستاتيكي صراحةً (قالب الاختبار يعتمد افتراضياً عزم الكابولي المعطى = 1)
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        additionalSupportMomentKnM: 0.0,
        cantileverMomentSource: CantileverMomentSource.statics,
      );
      final reportS6 = SlabDesignPipeline.designFromFloorGrid(
        plan: plan,
        slabId: 'S6',
      );
      // الكابولي يسار S6: M = 11.5 * 1.6^2 / 2 = 14.72 kN.m/m
      expect(
        reportS6.initialMoments.cantileverMomentsBySide[EdgeSide.left],
        closeTo(14.72, 0.01),
      );
      expect(
        reportS6.balancedMoments.supportMomentBySide[EdgeSide.left],
        closeTo(14.72, 0.01),
      );
    });

    test('معادلة الرقم السحري لرقم القيد S_No. = 9 - |d1 - d2|', () {
      expect(FloorGridPlan.magicSlabId(4, 2), 'S7');
      expect(FloorGridPlan.magicSlabId(5, 5), 'S9');
      expect(FloorGridPlan.magicSlabId(0, 9), 'S0');
    });
  });
}
