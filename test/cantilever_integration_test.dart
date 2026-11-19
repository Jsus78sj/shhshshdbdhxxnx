import 'dart:convert';
import 'dart:ui' as ui;
import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/bs8110/slab_moment_shear_tables.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:bs8110_slab_designer/presentation/painters/rebar_plan_painter.dart';
import 'package:bs8110_slab_designer/presentation/pdf/slab_report_pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// ربط الكوابيل بالمحرك والواجهات (المشكلة 2): تصميم الكابولي نفسه (عزم، حديد علوي،
/// هطول B.R = 7، قص V = n·lc)، ومصدر العزم (المعطى = 1 kN.m/m أو الستاتيكي n·l²/2)،
/// والرسم والـ PDF.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FloorGridPlan examPlan({
    CantileverMomentSource source = CantileverMomentSource.givenSupportMoment,
    double givenM = 1.0,
    DesignCalculationMode mode = DesignCalculationMode.lectureMode,
  }) =>
      ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(
        mode: mode,
        additionalSupportMomentKnM: givenM,
        cantileverMomentSource: source,
      );

  group('قالب الاختبار — عزم الكابولي المعطى', () {
    test('القالب يعتمد افتراضياً عزم الكابولي المعطى = 1 kN.m/m', () {
      final plan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan();
      expect(plan.additionalSupportMomentKnM, 1.0);
      expect(plan.cantileverMomentSource,
          CantileverMomentSource.givenSupportMoment);
    });

    test('مصدر العزم يُحفظ ويُستعاد من JSON', () {
      final restored = FloorGridPlan.fromJson(examPlan().toJson());
      expect(restored.cantileverMomentSource,
          CantileverMomentSource.givenSupportMoment);
      expect(restored.additionalSupportMomentKnM, 1.0);
    });
  });

  group('تصميم الكابولي داخل تقرير البلاطة', () {
    test('S6 (عزم معطى = 1): تقرير كابولي بطوبولوجية كابولية وB.R = 7 وV = n·lc', () {
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(),
        slabId: 'S6',
      );
      expect(report.cantilevers.keys, [EdgeSide.left]);
      expect(report.cantileverReports.keys, [EdgeSide.left]);

      final cr = report.cantileverReports[EdgeSide.left]!;
      expect(cr.topology.spanningType, SlabSpanningType.cantilever);
      expect(cr.cantilever.lengthM, 1.60);
      expect(cr.momentSource, CantileverMomentSource.givenSupportMoment);
      expect(cr.supportMomentKnM, closeTo(1.0, 1e-9));
      expect(cr.staticMomentKnM, closeTo(14.72, 1e-6));

      // الحديد العلوي = الحد الأدنى 0.24% × 1000 × 120 = 288 mm²/m
      expect(cr.topSteel.asRequiredMm2, lessThan(cr.topSteel.asMinMm2));
      expect(cr.topSteel.asGoverningMm2, closeTo(288.0, 0.5));
      expect(cr.topSteel.barCountSelection.areaProvidedMm2,
          greaterThanOrEqualTo(cr.topSteel.asGoverningMm2));

      // الهطول: B.R = 7، و d_min ≥ lc/(7×2) = 114.3 mm أكبر من d = 90 mm
      expect(cr.deflectionCheck.basicRatioBR, 7.0);
      expect(cr.deflectionCheck.dMinRequiredMm, greaterThanOrEqualTo(114.0));
      expect(cr.deflectionCheck.isSafe, isFalse);
      expect(cr.deflectionCheck.suggestedOverallDepthHMm, isNotNull);
      expect(cr.deflectionCheck.suggestedOverallDepthHMm!, greaterThan(120.0));

      // القص: V = n · lc = 11.5 × 1.6 = 18.4 kN/m
      expect(cr.shearCheck.vMaxKnPerM, closeTo(18.4, 1e-6));
      expect(cr.shearCheck.isSafe, isTrue);

      // فشل هطول الكابولي لا يُغيّر حالة البلاطة نفسها، لكنه يظهر في التحذيرات
      expect(cr.overallIsSafe, isFalse);
      expect(report.cantileversAreSafe, isFalse);
      expect(report.warningsAr.any((w) => w.contains('الكابولي')), isTrue);
    });

    test('S6 (ستاتيكي): عزم الكابولي 14.72 وحديده العلوي أكبر بكثير من الحد الأدنى', () {
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(
          source: CantileverMomentSource.statics,
          givenM: 0.0,
        ),
        slabId: 'S6',
      );
      final cr = report.cantileverReports[EdgeSide.left]!;
      expect(cr.supportMomentKnM, closeTo(14.72, 1e-6));
      expect(cr.topSteel.mOverBd2, closeTo(14.72e6 / (1000 * 90 * 90), 1e-6));
      expect(cr.topSteel.asRequiredMm2, greaterThan(600));
      expect(cr.topSteel.asRequiredMm2, lessThan(900));
      expect(cr.topSteel.barCountSelection.areaProvidedMm2,
          greaterThanOrEqualTo(cr.topSteel.asGoverningMm2));
      expect(cr.deflectionCheck.basicRatioBR, 7.0);
      expect(cr.shearCheck.vMaxKnPerM, closeTo(18.4, 1e-6));
    });

    test('S1 وS2 عند الكابولي اليميني، وS7 بلا كوابيل', () {
      for (final id in ['S1', 'S2']) {
        final r = SlabDesignPipeline.designFromFloorGrid(
          plan: examPlan(),
          slabId: id,
        );
        expect(r.cantileverReports.keys, [EdgeSide.right], reason: id);
        expect(r.cantileverReports[EdgeSide.right]!.topology.spanningType,
            SlabSpanningType.cantilever);
      }
      final s7 = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(),
        slabId: 'S7',
      );
      expect(s7.cantileverReports, isEmpty);
      expect(s7.cantileversAreSafe, isTrue);
    });

    test('الكابولي يتبع سماكة البلاطة المعتمدة وحمله الأساسي (وضع الكود الصارم + زيادة تلقائية)', () {
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(
          source: CantileverMomentSource.statics,
          givenM: 0.0,
          mode: DesignCalculationMode.strictBs8110,
        ),
        slabId: 'S6',
        autoAdjustDepthIfUnsafeInStrictMode: true,
      );
      final cr = report.cantileverReports[EdgeSide.left]!;
      expect(cr.loadResult.overallDepthHMm,
          closeTo(report.loadResult.overallDepthHMm, 1e-9));
      expect(cr.loadResult.finalDesignLoadN,
          closeTo(report.loadResult.finalDesignLoadN, 1e-9));
    });
  });

  group('أثر مصدر العزم على حديد حافة الكابولي في البلاطة', () {
    test('S1: العزم المعطى يخفض عزم المسند وحديده عن العزم الستاتيكي 14.72', () {
      final statics = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(source: CantileverMomentSource.statics, givenM: 0.0),
        slabId: 'S1',
      );
      final given = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(),
        slabId: 'S1',
      );

      expect(
        statics.balancedMoments.supportMomentBySide[EdgeSide.right],
        closeTo(14.72, 0.01),
      );
      final double mGiven =
          given.balancedMoments.supportMomentBySide[EdgeSide.right]!;
      expect(mGiven, greaterThan(1.0));
      expect(mGiven, lessThan(14.72));

      expect(
        given.topSteelForEdge(EdgeSide.right).barCountSelection.areaProvidedMm2,
        lessThan(
          statics
              .topSteelForEdge(EdgeSide.right)
              .barCountSelection
              .areaProvidedMm2,
        ),
      );
    });
  });

  group('الوضع السريع (بلاطة واحدة) مع كابولي', () {
    SingleSlabInput s6Quick(CantileverMomentSource source, double givenM) {
      return SingleSlabInput(
        slabId: 'S6',
        widthXM: 4.10,
        heightYM: 4.20,
        topEdge: EdgeCondition.discontinuousFree,
        bottomEdge: EdgeCondition.continuous,
        leftEdge: EdgeCondition.cantilever,
        rightEdge: EdgeCondition.continuous,
        bottomNeighbor: const NeighborSlabInput(
          label: 'S7',
          spanAlongStripM: 4.20,
          perpendicularSpanM: 4.10,
          isFarEndContinuous: true,
          panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        ),
        rightNeighbor: const NeighborSlabInput(
          label: 'S4',
          spanAlongStripM: 3.70,
          perpendicularSpanM: 4.20,
          isFarEndContinuous: true,
          panelCase: TwoWayPanelCase.twoShortEdgesDiscontinuous,
        ),
        leftCantilever: const CantileverAttachment(
          side: EdgeSide.left,
          lengthM: 1.60,
          label: 'كابولي يسار S6',
        ),
        customDesignLoadN: 11.50,
        additionalSupportMomentKnM: givenM,
        cantileverMomentSource: source,
      );
    }

    const settings = SlabProjectSettings(
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10.0,
      fcu: 25.0,
      fy: 250.0,
    );

    test('يُنتج تقرير كابولي ويحترم مصدر العزم', () {
      final given = SlabDesignPipeline.designSingleSlab(
        input: s6Quick(CantileverMomentSource.givenSupportMoment, 1.0),
        settings: settings,
      );
      final statics = SlabDesignPipeline.designSingleSlab(
        input: s6Quick(CantileverMomentSource.statics, 0.0),
        settings: settings,
      );
      expect(given.cantileverReports[EdgeSide.left]!.supportMomentKnM,
          closeTo(1.0, 1e-9));
      expect(statics.cantileverReports[EdgeSide.left]!.supportMomentKnM,
          closeTo(14.72, 1e-6));
      expect(
        statics.balancedMoments.supportMomentBySide[EdgeSide.left],
        closeTo(14.72, 0.01),
      );
    });
  });

  group('الرسم وتقرير PDF', () {
    test('رسام مسقط التسليح يرسم S6 بكابولي دون أخطاء', () {
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(),
        slabId: 'S6',
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      RebarPlanPainter(
        report: report,
        layers: const RebarLayerVisibility(),
        useLectureNotation: true,
        isDark: false,
      ).paint(canvas, const ui.Size(360, 280));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('تقرير PDF لبلاطة بكابولي يُولَّد بخطوط مضمّنة', () async {
      final report = SlabDesignPipeline.designFromFloorGrid(
        plan: examPlan(),
        slabId: 'S6',
      );
      final bytes = await SlabReportPdfGenerator.generatePdfBytes(
        report: report,
        sourceLabelAr: 'اختبار جامعة عدن',
      );
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(80000));
    });
  });
}
