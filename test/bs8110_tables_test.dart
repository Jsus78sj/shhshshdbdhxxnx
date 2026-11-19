import 'package:bs8110_slab_designer/core/math/math_utils.dart';
import 'package:bs8110_slab_designer/data/bs8110/bs8110_tables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Table 1 & Table 2 — جداول حديد التسليح', () {
    test('يسترجع مساحات ومحيط قطر 10 mm بدقة مطابقة للجدول', () {
      expect(ReinforcementTables.areaForBarCount(diameterMm: 10, count: 4), 314);
      expect(ReinforcementTables.areaForBarCount(diameterMm: 10, count: 5), 393);
      expect(ReinforcementTables.areaForBarCount(diameterMm: 10, count: 6), 471);
      expect(ReinforcementTables.perimeterForDiameter(10), 31.4);

      expect(ReinforcementTables.areaForSpacing(diameterMm: 10, spacingMm: 175), 449);
      expect(ReinforcementTables.areaForSpacing(diameterMm: 10, spacingMm: 200), 393);
      expect(ReinforcementTables.areaForSpacing(diameterMm: 10, spacingMm: 225), 349);
    });

    test('يختار 5 No 10 لـ 352.1 mm² و 6 No 10 لـ 442.3 mm² (مطابق للبلاطة S7)', () {
      final midX = ReinforcementTables.selectBarCount(
        requiredAreaMm2PerM: 352.1,
        diameterMm: 10,
        maxSpacingMm: 270,
      );
      expect(midX.lectureNotation, '5 No 10');
      expect(midX.areaProvidedMm2, 393);

      final supY = ReinforcementTables.selectBarCount(
        requiredAreaMm2PerM: 442.3,
        diameterMm: 10,
        maxSpacingMm: 240,
      );
      expect(supY.lectureNotation, '6 No 10');
      expect(supY.areaProvidedMm2, 471);
    });

    test('يختار Ø10 @ 225 mm لـ 336 mm² و Ø10 @ 175 mm لـ 408.2 mm² من Table 2', () {
      final sel1 = ReinforcementTables.selectBarSpacing(
        requiredAreaMm2PerM: 336.0,
        diameterMm: 10,
        maxSpacingMm: 300,
      );
      expect(sel1?.standardNotation, 'Ø10 @ 225 mm');
      expect(sel1?.areaProvidedMm2PerM, 349);

      final sel2 = ReinforcementTables.selectBarSpacing(
        requiredAreaMm2PerM: 408.2,
        diameterMm: 10,
        maxSpacingMm: 300,
      );
      expect(sel2?.standardNotation, 'Ø10 @ 175 mm');
      expect(sel2?.areaProvidedMm2PerM, 449);
    });
  });

  group('Table 3 — الأحمال الحية وأوزان المواد', () {
    test('يتحقق من قيم الكثافات الوزنية والأحمال الحية الأساسية', () {
      expect(LoadsWeightsTable.imposedLoads.length, 10);
      expect(LoadsWeightsTable.surfaceWeights.length, 7);
      expect(LoadsWeightsTable.unitWeights.length, 9);
      expect(LoadsWeightsTable.reinforcedConcreteUnitWeight, 24.0);
      expect(LoadsWeightsTable.sandLayerUnitWeight, 17.5);
    });
  });

  group('Table 4, Table 5, Table 3.25 — تصميم الانحناء والحد الأدنى', () {
    test('يحسب fy*As/bd عند fcu=25 للحالتين (<= 1.06 و > 1.06) مطابقة للبلاطة S7', () {
      // منتصف البحر القصير: M/bd² = 0.883 <= 1.06
      final f1 = FlexureTables.calculateSinglyFyAsOverBd(
        fcu: 25,
        mOverBd2: 0.883,
      );
      expect(f1, closeTo(0.978364, 1e-4));

      // المسند السفلي الطويل: M/bd² = 1.236 (> 1.06 و <= 3.90)
      final f2 = FlexureTables.calculateSinglyFyAsOverBd(
        fcu: 25,
        mOverBd2: 1.236,
      );
      expect(f2, closeTo(1.3822, 1e-3));

      // تجاوز الحد الأقصى 3.90 يرجع null
      expect(
        FlexureTables.calculateSinglyFyAsOverBd(fcu: 25, mOverBd2: 4.10),
        isNull,
      );
    });

    test('يحسب Table 5 للقطاعات مزدوجة التسليح و max d\'/d بدقة', () {
      expect(
        FlexureTables.maxDPrimeOverD(xOverD: 0.5, fy: 250),
        closeTo(0.33028, 1e-4),
      );
      final res = FlexureTables.calculateDoublyReinforced(
        xOverD: 0.5,
        fcu: 25,
        fy: 250,
        mOverBd2: 4.5,
        bMm: 1000,
        dMm: 100,
        dPrimeMm: 20,
      );
      expect(res.ascMm2, greaterThan(0));
      expect(res.astMm2, greaterThan(res.ascMm2));
    });

    test('Table 5: kp = 0.4235·fcu·(x/d) لكل الأعمدة (تصحيح fcu=20 عند x/d=0.3)', () {
      expect(FlexureTables.table5Doubly[0.3]![20]!.kp, closeTo(2.541, 1e-9));
      expect(FlexureTables.table5Doubly[0.3]![25]!.kp, closeTo(3.176, 1e-9));
      FlexureTables.table5Doubly.forEach((xd, byFcu) {
        byFcu.forEach((fcu, row) {
          expect(row.kp, closeTo(0.4235 * fcu * xd, 0.02),
              reason: 'kp عند x/d=$xd و fcu=$fcu');
        });
      });
    });

    test('يحسب الحد الأدنى للتسليح من Table 3.25 بعد تصحيح عمود fy=460', () {
      expect(
        FlexureTables.minSolidSlabSteelArea(bMm: 1000, hMm: 120, fy: 250),
        closeTo(288.0, 1e-6),
      );
      expect(
        FlexureTables.minSolidSlabSteelArea(bMm: 1000, hMm: 140, fy: 250),
        closeTo(336.0, 1e-6),
      );
      expect(
        FlexureTables.minSolidSlabSteelArea(bMm: 1000, hMm: 120, fy: 460),
        closeTo(156.0, 1e-6),
      );
    });
  });

  group('Table 3.14 & Table 3.15 & Table 3.12 — البلاطات', () {
    test('يتحقق من وجود الحالات التسع الكاملة في Table 3.14 و Table 3.15', () {
      expect(SlabMomentShearTables.table314.length, 9);
      expect(SlabMomentShearTables.table315.length, 9);
    });

    test('يستخرج معاملات البلاطة S7 (Case 6 عند ly/lx = 4.20/4.10 = 1.0244)', () {
      const ratio = 4.20 / 4.10;
      final mom = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: ratio,
      );
      expect(mom.betaSxNeg, isNull);
      expect(MathUtils.roundTo(mom.betaSxPos, 4), closeTo(0.0369, 1e-4));
      expect(mom.betaSyNeg, 0.045);
      expect(mom.betaSyPos, 0.034);
      expect(mom.betaSxPosTrace.wasExactMatch, isFalse);

      final sh = SlabMomentShearTables.getShearCoefficients(
        panelCase: TwoWayPanelCase.twoLongEdgesDiscontinuous,
        lyOverLx: ratio,
      );
      expect(sh.betaVxCont, isNull);
      expect(sh.betaVxDisc, closeTo(0.2698, 1e-3));
      expect(sh.betaVyCont, 0.40);
      expect(sh.maxCoefficient, 0.40);
    });

    test('يستخرج مثال السبورة Case 8 عند ly/lx = 4.10 / 4.00 = 1.025', () {
      final mom = SlabMomentShearTables.getMomentCoefficients(
        panelCase: TwoWayPanelCase.threeEdgesDiscontinuousOneShortContinuous,
        lyOverLx: 1.025,
      );
      expect(mom.betaSxPos, closeTo(0.045, 1e-6));
      expect(mom.betaSyNeg, 0.058);
      expect(mom.betaSyPos, 0.044);
    });
  });

  group('Table 3.9, 3.10, 3.11 — جداول الهطول', () {
    test('يتحقق من النسب الأساسية ومعاملات التعديل للشد والضغط', () {
      expect(
        DeflectionTables.basicSpanDepthRatio(
          supportCondition: SpanSupportCondition.simplySupported,
        ),
        20.0,
      );
      expect(
        DeflectionTables.basicSpanDepthRatio(
          supportCondition: SpanSupportCondition.continuous,
        ),
        26.0,
      );

      final fs = DeflectionTables.calculateServiceStressFs(fy: 250);
      expect(fs, closeTo(166.67, 0.01));

      final mf = DeflectionTables.calculateTensionModificationFactor(
        fs: fs,
        mOverBd2: 0.883,
      );
      expect(mf, 2.0);

      final mfc = DeflectionTables.calculateCompressionModificationFactor(
        compressionSteelPercent: 0.50,
      );
      expect(mfc, closeTo(1.1429, 1e-3));
    });
  });

  group('Table 3.8 & Table 3.16 — فحص القص للبلاطات', () {
    test('يحسب vc للبلاطة S7 (6 No 10 = 471 mm², d=80 mm) ويجتاز Table 3.16', () {
      final vc = ShearTables.calculateConcreteShearStressVc(
        asProvidedMm2: 471,
        bvMm: 1000,
        dMm: 80,
        fcu: 25,
      );
      expect(vc, closeTo(0.792, 0.005));

      final check = ShearTables.checkSolidSlabShear(
        designShearStressV: 0.236,
        concreteShearStressVc: vc,
        fcu: 25,
        overallDepthHMm: 120,
      );
      expect(check.isSafeWithoutShearSteel, isTrue);
    });
  });

  group('Column Tables — ملحق الأعمدة وفهرس الكود', () {
    test('يتحقق من معادلة β وطول العمود الفعال وعدد أقسام الفهرس (18)', () {
      expect(
        ColumnTables.calculateBiaxialBeta(
          axialLoadN: 0,
          bMm: 300,
          hMm: 300,
          fcu: 25,
        ),
        1.0,
      );
      expect(
        ColumnTables.bracedEffectiveHeight(
          clearHeightLo: 3000,
          alphaC1: 1.0,
          alphaC2: 1.0,
        ),
        2400.0,
      );
      expect(Bs8110CodeCatalog.sections.length, 18);
    });
  });
  group('Table 2 — مطابقة رياضية π·d²/4 × 1000 / s', () {
    test('كل القيم ضمن 0.7% من القيمة الهندسية (تقريب الكتيّب)', () {
      ReinforcementTables.table2AreasBySpacing.forEach((d, areas) {
        for (var i = 0; i < areas.length; i++) {
          final s = ReinforcementTables.standardSpacingsMm[i];
          final exact = 3.141592653589793 * d * d / 4 * 1000 / s;
          expect((areas[i] - exact).abs() / exact, lessThan(0.007),
              reason: 'Ø$d @ $s: ${areas[i]} مقابل ${exact.toStringAsFixed(1)}');
        }
      });
    });

    test('القيم الأربع المصحَّحة', () {
      double a(int d, int s) => ReinforcementTables.table2AreasBySpacing[d]![
          ReinforcementTables.standardSpacingsMm.indexOf(s)];
      expect(a(12, 120), 942);
      expect(a(12, 250), 452);
      expect(a(20, 150), 2094);
      expect(a(25, 100), 4909);
    });
  });
}
