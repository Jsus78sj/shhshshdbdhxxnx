import 'dart:ui' as ui;
import 'package:bs8110_slab_designer/core/constants/design_mode.dart';
import 'package:bs8110_slab_designer/data/bs8110/bs8110_tables.dart';
import 'package:bs8110_slab_designer/data/templates/exam_floor_plan_template.dart';
import 'package:bs8110_slab_designer/domain/engine/engineering_engine.dart';
import 'package:bs8110_slab_designer/presentation/painters/rebar_plan_painter.dart';
import 'package:bs8110_slab_designer/presentation/painters/slab_section_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات الأخطاء المؤثرة على النتائج:
/// 1) حديد الحافة غير المستمرة في الاتجاهات المختلطة، 3) حديد الضغط،
/// 4) selectBarCount عند تجاوز أقصى عدد أسياخ، 5) الهطول في الوضع الصارم،
/// 7) ردم البلاطة المهبطة في قالب الاختبار.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const designableIds = [
    'S0', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'Dropped',
  ];

  FloorGridPlan plan(DesignCalculationMode mode) =>
      ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan(mode: mode);

  group('البند 1 — حديد الحافة غير المستمرة في الاتجاه المختلط', () {
    for (final mode in DesignCalculationMode.values) {
      test('كل البلاطات (${mode.name}): الحافة غير المستمرة تأخذ قاعدة 50% As,mid', () {
        final p = plan(mode);
        for (final id in designableIds) {
          final r = SlabDesignPipeline.designFromFloorGrid(plan: p, slabId: id);
          final topo = r.topology;

          for (final side in EdgeSide.values) {
            final steel = r.topSteelForEdge(side);
            final cond = topo.edgeFor(side);
            if (cond.isContinuous) {
              // الحافة المستمرة/الكابولي: تصميم المسند المستمر للاتجاه
              expect(steel.isDiscontinuousSupportRule, isFalse,
                  reason: '$id ${side.name}');
            } else {
              // الحافة غير المستمرة: دائماً قاعدة 50% As,mid ≥ As,min
              expect(steel.isDiscontinuousSupportRule, isTrue,
                  reason: '$id ${side.name}');
              expect(steel.asGoverningMm2,
                  greaterThanOrEqualTo(steel.asMinMm2 - 1e-6));
            }
          }
        }
      });
    }

    test('S1: يسار مهبطة (غير مستمرة) ≠ يمين كابولي (مستمرة) في الاتجاه القصير', () {
      final r = SlabDesignPipeline.designFromFloorGrid(
        plan: plan(DesignCalculationMode.lectureMode),
        slabId: 'S1',
      );
      expect(r.topology.leftEdge, EdgeCondition.discontinuousDropped);
      expect(r.topology.rightEdge, EdgeCondition.cantilever);

      final left = r.topSteelForEdge(EdgeSide.left);
      final right = r.topSteelForEdge(EdgeSide.right);
      expect(left.isDiscontinuousSupportRule, isTrue);
      expect(right.isDiscontinuousSupportRule, isFalse);

      // الاتجاه مختلط: يجب وجود تصميم مستقل للحافة غير المستمرة وصف ملخص يحمله
      expect(r.shortDiscontinuousEdgeSteel, isNotNull);
      expect(r.summaryRow.shortSupportDiscLecture, isNotNull);
      expect(
        r.topLabelForEdge(EdgeSide.left, lecture: true),
        r.summaryRow.shortSupportDiscLecture,
      );
      expect(
        r.topLabelForEdge(EdgeSide.right, lecture: true),
        r.summaryRow.shortSupportLecture,
      );
      // مساحة الحافة غير المستمرة لا تتجاوز مساحة المستمرة
      expect(
        left.barCountSelection.areaProvidedMm2,
        lessThanOrEqualTo(right.barCountSelection.areaProvidedMm2),
      );
    });

    test('S7 (Case 6): لا اتجاه مختلط ولا تصميم حافة إضافي', () {
      final r = SlabDesignPipeline.designFromFloorGrid(
        plan: plan(DesignCalculationMode.lectureMode),
        slabId: 'S7',
      );
      expect(r.shortDiscontinuousEdgeSteel, isNull);
      expect(r.longDiscontinuousEdgeSteel, isNull);
      expect(r.allSteelDesigns.length, 4);
    });

    test('الرسامان يرسمان كل البلاطات في الوضعين بلا استثناء', () {
      for (final mode in DesignCalculationMode.values) {
        final p = plan(mode);
        for (final id in designableIds) {
          final r = SlabDesignPipeline.designFromFloorGrid(plan: p, slabId: id);
          for (final lecture in [true, false]) {
            final rec = ui.PictureRecorder();
            RebarPlanPainter(
              report: r,
              layers: const RebarLayerVisibility(),
              useLectureNotation: lecture,
              isDark: false,
            ).paint(ui.Canvas(rec), const ui.Size(360, 280));
            rec.endRecording().dispose();

            for (final axis in SlabAxisDirection.values) {
              final rec2 = ui.PictureRecorder();
              SlabSectionPainter(
                report: r,
                axis: axis,
                useLectureNotation: lecture,
                isDark: false,
              ).paint(ui.Canvas(rec2), const ui.Size(360, 220));
              rec2.endRecording().dispose();
            }
          }
        }
      }
    });
  });

  group('البند 3 — حديد الضغط', () {
    const settings = SlabProjectSettings(
      designLoadN: 11.5,
      overallDepthH: 120,
      clearCoverC: 25,
      barDiameterPhi: 10,
      fcu: 25,
      fy: 250,
    );

    test('عزم كبير: يُحسب حديد الضغط ويُختار له أسياخ ويدخل في M.Fc', () {
      final d = FlexureDesigner.designSection(
        zoneId: 'test',
        zoneTitleAr: 'اختبار',
        directionAr: 'X',
        isTopSteel: false,
        designMomentKnM: 40.0,
        effectiveDepthMm: 90.0,
        overallDepthHMm: 120.0,
        settings: settings,
      );
      expect(d.requiresDoublyReinforced, isTrue);
      expect(d.compressionSteelMm2, greaterThan(0));
      expect(d.compressionBarSelection, isNotNull);
      expect(d.compressionSteelProvidedPercent, greaterThan(0));

      // تمرير نسبة حديد الضغط يرفع معامل M.Fc فوق 1 (Table 3.11)
      final mfc = DeflectionTables.calculateCompressionModificationFactor(
        compressionSteelPercent: d.compressionSteelProvidedPercent,
      );
      expect(mfc, greaterThan(1.0));
    });

    test('عزم صغير: لا حديد ضغط', () {
      final d = FlexureDesigner.designSection(
        zoneId: 'test',
        zoneTitleAr: 'اختبار',
        directionAr: 'X',
        isTopSteel: false,
        designMomentKnM: 5.0,
        effectiveDepthMm: 90.0,
        overallDepthHMm: 120.0,
        settings: settings,
      );
      expect(d.requiresDoublyReinforced, isFalse);
      expect(d.compressionBarSelection, isNull);
      expect(d.compressionSteelProvidedPercent, 0.0);
    });
  });

  group('البند 4 — selectBarCount عند تجاوز أقصى عدد أسياخ', () {
    test('مساحة تفوق 15 سيخاً تُعلَّم غير كافية ولا تُعرض كأنها كافية', () {
      final sel = ReinforcementTables.selectBarCount(
        requiredAreaMm2PerM: 5000.0,
        diameterMm: 10,
        maxSpacingMm: 270,
      );
      expect(sel.isSufficient, isFalse);
      expect(sel.areaProvidedMm2, lessThan(5000.0));
    });

    test('مساحة عادية تُعلَّم كافية', () {
      final sel = ReinforcementTables.selectBarCount(
        requiredAreaMm2PerM: 400.0,
        diameterMm: 10,
        maxSpacingMm: 270,
      );
      expect(sel.isSufficient, isTrue);
      expect(sel.areaProvidedMm2, greaterThanOrEqualTo(400.0));
    });

    test('قطر أكبر يوفّر المساحة نفسها', () {
      final d = ReinforcementTables.nextSufficientDiameter(
        requiredAreaMm2PerM: 5000.0,
        currentDiameterMm: 10,
        maxSpacingMm: 270,
      );
      expect(d, isNotNull);
      expect(d!, greaterThan(10));
    });
  });

  group('البند 5 — الوضع الصارم يستخدم مساحة الأسياخ المعروضة في الهطول', () {
    test('fs = 2·fy·As,req / (3·As,prov) بمساحة عدد الأسياخ (Table 1)', () {
      final r = SlabDesignPipeline.designFromFloorGrid(
        plan: plan(DesignCalculationMode.strictBs8110),
        slabId: 'S7',
      );
      final s = r.shortMidSteel;
      final expected = (2.0 * r.settingsUsed.fy * s.asRequiredMm2) /
          (3.0 * s.barCountSelection.areaProvidedMm2);
      expect(r.deflectionCheck.serviceStressFs, closeTo(expected, 1e-6));
    });
  });

  group('البند 6 — زيادة السماكة التلقائية تتكرر حتى ينجح الهطول', () {
    test('الوضع الصارم: بعد الزيادة التلقائية يكون الهطول آمناً', () {
      final p = plan(DesignCalculationMode.strictBs8110);
      for (final id in designableIds) {
        final r = SlabDesignPipeline.designFromFloorGrid(
          plan: p,
          slabId: id,
          autoAdjustDepthIfUnsafeInStrictMode: true,
        );
        expect(r.deflectionCheck.isSafe, isTrue, reason: id);
      }
    });

    test('حمل الجار لا يتأثر بالوزن الذاتي الإضافي للبلاطة المدروسة', () {
      final p = plan(DesignCalculationMode.strictBs8110);
      final base = SlabDesignPipeline.designFromFloorGrid(plan: p, slabId: 'S4');
      final adj = SlabDesignPipeline.designFromFloorGrid(
        plan: p,
        slabId: 'S4',
        autoAdjustDepthIfUnsafeInStrictMode: true,
      );
      // عزم الجار عند الحافة المشتركة مبني على حمل الجار الأصلي في الحالتين
      for (final b in adj.balancedMoments.supportBalances) {
        final match = base.balancedMoments.supportBalances
            .where((x) => x.side == b.side)
            .toList();
        if (match.isNotEmpty) {
          expect(b.mNeighborInitial, closeTo(match.first.mNeighborInitial, 1e-9));
        }
      }
    });
  });

  group('البند 7 — ردم البلاطة المهبطة', () {
    test('قالب الاختبار لا يضع ردماً افتراضياً (النص لا يذكره)', () {
      final p = plan(DesignCalculationMode.lectureMode);
      final dropped = p.findById('Dropped')!;
      expect(dropped.cellType, SlabCellType.droppedSolid);
      expect(dropped.fillDepthM, 0.0);
    });

    test('حمل البلاطة المهبطة = حمل المشروع بلا ردم', () {
      final p = plan(DesignCalculationMode.lectureMode);
      final r = SlabDesignPipeline.designFromFloorGrid(plan: p, slabId: 'Dropped');
      expect(r.loadResult.fillLoadAddedN, 0.0);
      expect(r.loadResult.finalDesignLoadN, closeTo(p.settings.designLoadN, 1e-9));
    });

    test('إدخال ردم يدوياً يضيف 1.4·(0.20×18.5) = 5.18 kN/m²', () {
      final p = plan(DesignCalculationMode.lectureMode);
      final dropped = p.findById('Dropped')!;
      final withFill = p.copyWith(
        cells: [
          for (final c in p.cells)
            if (c.id == 'Dropped')
              c.copyWith(fillDepthM: 0.20, fillUnitWeightKnM3: 18.5)
            else
              c,
        ],
      );
      expect(dropped.fillDepthM, 0.0);
      final r =
          SlabDesignPipeline.designFromFloorGrid(plan: withFill, slabId: 'Dropped');
      expect(r.loadResult.fillLoadAddedN, closeTo(5.18, 1e-9));
    });
  });
}
