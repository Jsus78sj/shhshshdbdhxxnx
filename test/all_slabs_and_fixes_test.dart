import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/bs8110/bs8110_tables.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:bs8110_slab_designer/presentation/providers/floor_grid_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات تغطية كل بلاطات مخطط الاختبار (S0–S9 + المهبطة) وإصلاحات «الملاحظات الصغيرة»:
/// vc، معرّفات الأعمدة، البلاطة المربعة، حالة الجار المفترضة، اتجاه واحد.
void main() {
  // حالات Table 3.14 المتوقعة محسوبة يدوياً من هندسة المخطط (أبعاد الخانات + استمرارية الحواف)
  const expectedCase = <String, int>{
    'S0': 4,
    'S1': 3,
    'S2': 1,
    'S3': 8,
    'S4': 5,
    'S5': 5,
    'S6': 2,
    'S7': 6,
    'S8': 3,
    'S9': 7,
    'Dropped': 9,
  };

  FloorGridPlan plan(DesignCalculationMode mode) =>
      ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(mode: mode);

  group('كل بلاطات المخطط S0–S9 + المهبطة', () {
    for (final mode in DesignCalculationMode.values) {
      for (final entry in expectedCase.entries) {
        test('${entry.key} (${mode.name}): الحالة ${entry.value} ونتائج منطقية', () {
          final r = SlabDesignPipeline.designFromFloorGrid(
            plan: plan(mode),
            slabId: entry.key,
          );

          expect(r.topology.spanningType, SlabSpanningType.twoWay);
          expect(r.topology.twoWayCase?.caseNumber, entry.value);

          // عزوم نهائية موجبة ومنتهية
          final m = r.balancedMoments;
          for (final v in [m.shortMidMomentFinal, m.longMidMomentFinal]) {
            expect(v.isFinite, isTrue);
            expect(v, greaterThan(0));
          }
          expect(m.shortSupportMomentFinal.isFinite, isTrue);
          expect(m.longSupportMomentFinal.isFinite, isTrue);

          // كل منطقة تسليح: مساحة منتهية، حاكمة ≥ الحد الأدنى، والمختار يغطي المطلوب
          for (final d in r.allSteelDesigns) {
            expect(d.barCountSelection.areaProvidedMm2.isFinite, isTrue,
                reason: d.zoneId);
            expect(d.barCountSelection.areaProvidedMm2, greaterThan(0),
                reason: d.zoneId);
            expect(d.asGoverningMm2, greaterThanOrEqualTo(d.asMinMm2 - 1e-6),
                reason: d.zoneId);
            if (d.isAreaSufficient && !d.requiresDoublyReinforced) {
              expect(d.barCountSelection.areaProvidedMm2,
                  greaterThanOrEqualTo(d.asGoverningMm2 - 1e-6),
                  reason: d.zoneId);
            }
          }

          // القص: إجهادات منتهية وموجبة
          expect(r.shearCheck.designShearStressV.isFinite, isTrue);
          expect(r.shearCheck.designShearStressV, greaterThan(0));
          expect(r.shearCheck.concreteShearStressVc, greaterThan(0));
        });
      }
    }

    test('المهبطة: أربع حواف غير مستمرة ولا ردم افتراضي', () {
      final r = SlabDesignPipeline.designFromFloorGrid(
        plan: plan(DesignCalculationMode.lectureMode),
        slabId: 'Dropped',
      );
      expect(r.topology.cellType, SlabCellType.droppedSolid);
      for (final side in EdgeSide.values) {
        expect(r.topology.edgeFor(side).isDiscontinuous, isTrue,
            reason: side.name);
      }
      expect(r.loadResult.fillLoadAddedN, 0.0);
    });
  });

  group('بلاطة اتجاه واحد (ly/lx > 2)', () {
    const settings = SlabProjectSettings(
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10.0,
      fcu: 25.0,
      fy: 250.0,
    );

    SlabDesignReport oneWay(EdgeCondition left, EdgeCondition right) {
      return SlabDesignPipeline.designSingleSlab(
        input: SingleSlabInput(
          slabId: 'OW',
          widthXM: 2.0,
          heightYM: 5.0,
          topEdge: EdgeCondition.discontinuousFree,
          bottomEdge: EdgeCondition.discontinuousFree,
          leftEdge: left,
          rightEdge: right,
        ),
        settings: settings,
      );
    }

    test('مستمرة على أحد الطرفين: 0.60 F وتصميم منتهٍ', () {
      final r = oneWay(EdgeCondition.continuous, EdgeCondition.discontinuousFree);
      expect(r.topology.spanningType, SlabSpanningType.oneWay);
      expect(r.topology.twoWayCase, isNull);
      expect(r.shearCheck.governingBetaV, 0.60);
      expect(r.shearCheck.designShearStressV.isFinite, isTrue);
    });

    test('بسيطة الاستناد: 0.50 F', () {
      final r = oneWay(
        EdgeCondition.discontinuousFree,
        EdgeCondition.discontinuousFree,
      );
      expect(r.shearCheck.governingBetaV, 0.50);
    });
  });

  group('البلاطة المربعة — تسمية الحواف القصيرة/الطويلة', () {
    ResolvedTopology square(EdgeCondition top, EdgeCondition left) {
      return TopologyResolver.resolveFromEdges(
        slabId: 'SQ',
        cellType: SlabCellType.normalSolid,
        widthXM: 4.0,
        heightYM: 4.0,
        topEdge: top,
        bottomEdge: EdgeCondition.continuous,
        leftEdge: left,
        rightEdge: EdgeCondition.continuous,
      );
    }

    test('حافة واحدة غير مستمرة: النتيجة نفسها أياً كان الضلع (Case الأكثر تحفظاً)', () {
      final a = square(EdgeCondition.discontinuousFree, EdgeCondition.continuous);
      final b = square(EdgeCondition.continuous, EdgeCondition.discontinuousFree);
      expect(a.twoWayCase, b.twoWayCase);
      expect(a.twoWayCase, TwoWayPanelCase.oneLongEdgeDiscontinuous);
      expect(a.squareOrientationNoteAr, isNotNull);
      expect(b.squareOrientationNoteAr, isNotNull);
    });

    test('أربع حواف مستمرة: لا ملاحظة', () {
      final t = square(EdgeCondition.continuous, EdgeCondition.continuous);
      expect(t.twoWayCase, TwoWayPanelCase.interiorPanels);
      expect(t.squareOrientationNoteAr, isNull);
    });

    test('البلاطة غير المربعة لا تتأثر', () {
      final r = SlabDesignPipeline.designFromFloorGrid(
        plan: plan(DesignCalculationMode.lectureMode),
        slabId: 'S7',
      );
      expect(r.topology.squareOrientationNoteAr, isNull);
      expect(r.topology.twoWayCase, TwoWayPanelCase.twoLongEdgesDiscontinuous);
    });
  });

  group('حالة الجار في الوضع السريع', () {
    test('تُستنتج من الهندسة عند غياب الحالة اليدوية', () {
      const farCont = NeighborSlabInput(
        label: 'A',
        spanAlongStripM: 4.2,
        perpendicularSpanM: 4.1,
        isFarEndContinuous: true,
      );
      const farFreeShort = NeighborSlabInput(
        label: 'B',
        spanAlongStripM: 4.2,
        perpendicularSpanM: 4.1,
      );
      const farFreeLong = NeighborSlabInput(
        label: 'C',
        spanAlongStripM: 4.0,
        perpendicularSpanM: 4.4,
      );
      expect(farCont.effectivePanelCase, TwoWayPanelCase.interiorPanels);
      expect(farFreeShort.effectivePanelCase,
          TwoWayPanelCase.oneShortEdgeDiscontinuous);
      expect(farFreeLong.effectivePanelCase,
          TwoWayPanelCase.oneLongEdgeDiscontinuous);
      expect(farCont.isPanelCaseAssumed, isTrue);
    });

    test('الحالة اليدوية تُحترم ولا تُعدّ مفترضة', () {
      const n = NeighborSlabInput(
        label: 'D',
        spanAlongStripM: 4.2,
        perpendicularSpanM: 4.1,
        panelCase: TwoWayPanelCase.twoAdjacentEdgesDiscontinuous,
      );
      expect(n.effectivePanelCase, TwoWayPanelCase.twoAdjacentEdgesDiscontinuous);
      expect(n.isPanelCaseAssumed, isFalse);
    });

    test('تحذير في التقرير عند افتراض الحالة، وبلا تحذير عند تحديدها', () {
      SlabDesignReport run(TwoWayPanelCase? c) {
        return SlabDesignPipeline.designSingleSlab(
          input: SingleSlabInput(
            slabId: 'Q',
            widthXM: 4.1,
            heightYM: 4.2,
            topEdge: EdgeCondition.continuous,
            bottomEdge: EdgeCondition.discontinuousFree,
            leftEdge: EdgeCondition.discontinuousFree,
            rightEdge: EdgeCondition.discontinuousFree,
            topNeighbor: NeighborSlabInput(
              label: 'N1',
              spanAlongStripM: 4.2,
              perpendicularSpanM: 4.1,
              panelCase: c,
            ),
          ),
          settings: const SlabProjectSettings(
            designLoadN: 11.50,
            overallDepthH: 120.0,
            clearCoverC: 25.0,
            barDiameterPhi: 10.0,
            fcu: 25.0,
            fy: 250.0,
          ),
        );
      }

      final assumed = run(null);
      final explicit = run(TwoWayPanelCase.oneShortEdgeDiscontinuous);
      expect(assumed.warningsAr.any((w) => w.contains('افتُرضت Case')), isTrue);
      expect(explicit.warningsAr.any((w) => w.contains('افتُرضت Case')), isFalse);
    });
  });

  group('معرّفات البلاطات عند إضافة/حذف الأعمدة والصفوف', () {
    test('حذف عمود ثم إضافة عمود لا يكرّر أي معرّف', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(floorGridEditorProvider.notifier);

      n.removeLastColumn();
      n.addColumn();
      n.removeLastRow();
      n.addRow();

      final ids = container
          .read(floorGridEditorProvider)
          .plan
          .cells
          .map((c) => c.id)
          .toList();
      expect(ids.toSet().length, ids.length, reason: ids.join(','));
    });
  });

  group('Table 3.8 — vc عند نسب تسليح أقل من 0.15%', () {
    test('لا يُرفع إلى قيمة 0.15% (تحفظ)', () {
      double vcFor(double asMm2) => ShearTables.calculateConcreteShearStressVc(
            asProvidedMm2: asMm2,
            bvMm: 1000,
            dMm: 100,
            fcu: 25,
          );
      final low = vcFor(100); // 0.10%
      final atLimit = vcFor(150); // 0.15%
      expect(low, closeTo(0.4149, 0.002));
      expect(low, lessThan(atLimit));
    });

    test('الحد الأعلى 3% ما زال مطبقاً', () {
      double vcFor(double asMm2) => ShearTables.calculateConcreteShearStressVc(
            asProvidedMm2: asMm2,
            bvMm: 1000,
            dMm: 100,
            fcu: 25,
          );
      expect(vcFor(5000), closeTo(vcFor(3000), 1e-9));
    });
  });
}
