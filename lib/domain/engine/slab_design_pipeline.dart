import '../../core/constants/app_constants.dart';
import '../../core/constants/design_mode.dart';
import '../../data/bs8110/bs8110_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_geometry_models.dart';
import '../models/slab_project_settings.dart';
import 'cantilever_designer.dart';
import 'deflection_checker.dart';
import 'flexure_designer.dart';
import 'load_calculator.dart';
import 'moment_analyzer.dart';
import 'moment_balancer.dart';
import 'shear_checker.dart';
import 'topology_resolver.dart';

/// المنسق الهندسي الشامل (Pipeline): يجمع كافة الوحدات الحسابية ويولّد
/// التقرير النهائي [SlabDesignReport] متضمناً خطوات الحل الأكاديمية الكاملة.
class SlabDesignPipeline {
  SlabDesignPipeline._();

  /// تصميم بلاطة محددة بالمعرّف [slabId] من داخل مخطط سقف كامل [FloorGridPlan]
  static SlabDesignReport designFromFloorGrid({
    required FloorGridPlan plan,
    required String slabId,
    bool autoAdjustDepthIfUnsafeInStrictMode = false,
  }) {
    final cell = plan.findById(slabId);
    if (cell == null) {
      throw ArgumentError('لم يتم العثور على البلاطة ($slabId) داخل المخطط.');
    }
    if (!cell.cellType.isDesignableSlab) {
      throw ArgumentError(
        'الخانة ($slabId) من نوع (${cell.cellType.titleAr}) وليست بلاطة مصمتة قابلة للتصميم.',
      );
    }

    final topology = TopologyResolver.resolveFromFloorGrid(
      plan: plan,
      cell: cell,
    );

    final Map<EdgeSide, CantileverAttachment> cantMap = {
      for (final c in cell.cantilevers) c.side: c,
    };

    return _executePipeline(
      slabId: cell.id,
      settings: plan.settings,
      topology: topology,
      cellType: cell.cellType,
      customDesignLoadN: cell.customDesignLoadN,
      fillDepthM: cell.fillDepthM,
      fillUnitWeightKnM3: cell.fillUnitWeightKnM3,
      cantilevers: cantMap,
      cantileverMomentSource: plan.cantileverMomentSource,
      givenCantileverMomentKnM: plan.additionalSupportMomentKnM,
      balanceFn: (initialMoments, finalLoadN) =>
          MomentBalancer.balanceInFloorGrid(
        plan: plan,
        cell: cell,
        topology: topology,
        initialMoments: initialMoments,
        designLoadN: finalLoadN,
      ),
      autoAdjustDepthIfUnsafeInStrictMode: autoAdjustDepthIfUnsafeInStrictMode,
    );
  }

  /// تصميم بلاطة واحدة + جيرانها (الوضع السريع)
  static SlabDesignReport designSingleSlab({
    required SingleSlabInput input,
    required SlabProjectSettings settings,
    bool autoAdjustDepthIfUnsafeInStrictMode = false,
  }) {
    final topology = TopologyResolver.resolveFromSingleSlab(input);

    final Map<EdgeSide, CantileverAttachment> cantMap = {};
    for (final side in EdgeSide.values) {
      final cant = input.cantileverFor(side);
      if (cant != null) cantMap[side] = cant;
    }

    return _executePipeline(
      slabId: input.slabId,
      settings: settings,
      topology: topology,
      cellType: input.cellType,
      customDesignLoadN: input.customDesignLoadN,
      fillDepthM: input.fillDepthM,
      fillUnitWeightKnM3: input.fillUnitWeightKnM3,
      cantilevers: cantMap,
      cantileverMomentSource: input.cantileverMomentSource,
      givenCantileverMomentKnM: input.additionalSupportMomentKnM,
      balanceFn: (initialMoments, finalLoadN) =>
          MomentBalancer.balanceForSingleSlab(
        input: input,
        topology: topology,
        initialMoments: initialMoments,
        designLoadN: finalLoadN,
        // الجار يحتفظ بحمله الأساسي: لا ردم هذه البلاطة ولا وزنها الذاتي الإضافي
        neighborFallbackLoadN: input.customDesignLoadN ?? settings.designLoadN,
        betaRoundDecimals: settings.betaRoundDecimals,
      ),
      autoAdjustDepthIfUnsafeInStrictMode: autoAdjustDepthIfUnsafeInStrictMode,
    );
  }

  /// الحد الأقصى لمحاولات زيادة السماكة تلقائياً حتى ينجح فحص الهطول
  static const int _maxAutoDepthIterations = 12;

  static SlabDesignReport _executePipeline({
    required String slabId,
    required SlabProjectSettings settings,
    required ResolvedTopology topology,
    required SlabCellType cellType,
    required double? customDesignLoadN,
    required double fillDepthM,
    required double fillUnitWeightKnM3,
    required Map<EdgeSide, CantileverAttachment> cantilevers,
    required CantileverMomentSource cantileverMomentSource,
    required double givenCantileverMomentKnM,
    required BalancedMomentsResult Function(
      InitialMomentsResult initialMoments,
      double finalLoadN,
    ) balanceFn,
    required bool autoAdjustDepthIfUnsafeInStrictMode,
  }) {
    SlabDesignReport run({double? depthMm, int attempts = 0}) => _runOnce(
          slabId: slabId,
          settings: settings,
          topology: topology,
          cellType: cellType,
          customDesignLoadN: customDesignLoadN,
          fillDepthM: fillDepthM,
          fillUnitWeightKnM3: fillUnitWeightKnM3,
          cantilevers: cantilevers,
          cantileverMomentSource: cantileverMomentSource,
          givenCantileverMomentKnM: givenCantileverMomentKnM,
          balanceFn: balanceFn,
          overrideDepthHMm: depthMm,
          autoAdjustAttempts: attempts,
        );

    SlabDesignReport report = run();

    // زيادة السماكة تلقائياً في وضع الكود الصارم: نكرّر حتى ينجح فحص الهطول، لأن كل
    // زيادة في السماكة ترفع الوزن الذاتي والعزوم والتسليح المطلوب فتغيّر نتيجة الفحص.
    if (autoAdjustDepthIfUnsafeInStrictMode &&
        settings.calculationMode == DesignCalculationMode.strictBs8110) {
      double h = report.loadResult.overallDepthHMm;
      int attempts = 0;
      while (!report.deflectionCheck.isSafe &&
          attempts < _maxAutoDepthIterations) {
        final double? suggested = report.deflectionCheck.suggestedOverallDepthHMm;
        final double nextH =
            (suggested != null && suggested > h + 1e-9) ? suggested : h + 10.0;
        h = nextH;
        attempts++;
        report = run(depthMm: h, attempts: attempts);
      }
    }
    return report;
  }

  static SlabDesignReport _runOnce({
    required String slabId,
    required SlabProjectSettings settings,
    required ResolvedTopology topology,
    required SlabCellType cellType,
    required double? customDesignLoadN,
    required double fillDepthM,
    required double fillUnitWeightKnM3,
    required Map<EdgeSide, CantileverAttachment> cantilevers,
    required CantileverMomentSource cantileverMomentSource,
    required double givenCantileverMomentKnM,
    required BalancedMomentsResult Function(
      InitialMomentsResult initialMoments,
      double finalLoadN,
    ) balanceFn,
    double? overrideDepthHMm,
    int autoAdjustAttempts = 0,
  }) {
    // 1. الأحمال والأعماق الفعالة
    final loadRes = LoadCalculator.compute(
      settings: settings,
      cellType: cellType,
      customDesignLoadN: customDesignLoadN,
      fillDepthM: fillDepthM,
      fillUnitWeightKnM3: fillUnitWeightKnM3,
      overrideOverallDepthHMm: overrideDepthHMm,
    );

    // 2. العزوم الأولية
    final initMoments = MomentAnalyzer.analyze(
      topology: topology,
      designLoadN: loadRes.finalDesignLoadN,
      cantilevers: cantilevers,
      roundBetaDecimals: settings.betaRoundDecimals,
    );

    // 3. موازنة العزوم عند المساند المستمرة
    final balMoments = balanceFn(initMoments, loadRes.finalDesignLoadN);

    // 4. تصميم حديد التسليح للقطاعات الأربعة
    final shortMidSteel = FlexureDesigner.designSection(
      zoneId: 'short_mid',
      zoneTitleAr: 'منتصف البحر القصير (Short Span — Mid)',
      directionAr: topology.isShortSpanHorizontal ? 'الاتجاه X' : 'الاتجاه Y',
      isTopSteel: false,
      designMomentKnM: balMoments.shortMidMomentFinal,
      effectiveDepthMm: loadRes.dxMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      settings: settings,
    );

    final shortSupSteel = topology.isShortSpanContinuous
        ? FlexureDesigner.designSection(
            zoneId: 'short_support',
            zoneTitleAr: 'المساند المستمرة بالاتجاه القصير (Short — Support)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه X' : 'الاتجاه Y',
            isTopSteel: true,
            designMomentKnM: balMoments.shortSupportMomentFinal,
            effectiveDepthMm: loadRes.dxMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          )
        : FlexureDesigner.designDiscontinuousSupportSteel(
            zoneId: 'short_support',
            zoneTitleAr:
                'المساند غير المستمرة بالاتجاه القصير (50% As ≥ As,min)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه X' : 'الاتجاه Y',
            midSpanAsRequiredMm2: shortMidSteel.asRequiredMm2,
            effectiveDepthMm: loadRes.dxMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          );

    final longMidSteel = FlexureDesigner.designSection(
      zoneId: 'long_mid',
      zoneTitleAr: 'منتصف البحر الطويل (Long Span — Mid)',
      directionAr: topology.isShortSpanHorizontal ? 'الاتجاه Y' : 'الاتجاه X',
      isTopSteel: false,
      designMomentKnM: balMoments.longMidMomentFinal,
      effectiveDepthMm: loadRes.dyMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      settings: settings,
    );

    final longSupSteel = topology.isLongSpanContinuous
        ? FlexureDesigner.designSection(
            zoneId: 'long_support',
            zoneTitleAr: 'المساند المستمرة بالاتجاه الطويل (Long — Support)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه Y' : 'الاتجاه X',
            isTopSteel: true,
            designMomentKnM: balMoments.longSupportMomentFinal,
            effectiveDepthMm: loadRes.dyMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          )
        : FlexureDesigner.designDiscontinuousSupportSteel(
            zoneId: 'long_support',
            zoneTitleAr: 'المساند غير المستمرة بالاتجاه الطويل (50% As ≥ As,min)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه Y' : 'الاتجاه X',
            midSpanAsRequiredMm2: longMidSteel.asRequiredMm2,
            effectiveDepthMm: loadRes.dyMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          );

    // 4-ب. حديد الحافة غير المستمرة في الاتجاهات المختلطة (حافة مستمرة + حافة غير مستمرة):
    // تُصمَّم مجموعة Support للحافة المستمرة (أعلاه)، وتُصمَّم هنا مجموعة مستقلة للحافة غير
    // المستمرة بقاعدة 50% As,mid ≥ As,min بدل وسم الحافتين بحديد الحافة المستمرة.
    final List<EdgeSide> shortSupportSides = topology.isShortSpanHorizontal
        ? [EdgeSide.left, EdgeSide.right]
        : [EdgeSide.top, EdgeSide.bottom];
    final List<EdgeSide> longSupportSides = topology.isShortSpanHorizontal
        ? [EdgeSide.top, EdgeSide.bottom]
        : [EdgeSide.left, EdgeSide.right];

    final bool shortDirectionIsMixed = topology.isShortSpanContinuous &&
        shortSupportSides.any((e) => topology.edgeFor(e).isDiscontinuous);
    final bool longDirectionIsMixed = topology.isLongSpanContinuous &&
        longSupportSides.any((e) => topology.edgeFor(e).isDiscontinuous);

    final SectionReinforcementDesign? shortDiscEdgeSteel = shortDirectionIsMixed
        ? FlexureDesigner.designDiscontinuousSupportSteel(
            zoneId: 'short_support_disc',
            zoneTitleAr:
                'الحافة غير المستمرة بالاتجاه القصير (50% As ≥ As,min)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه X' : 'الاتجاه Y',
            midSpanAsRequiredMm2: shortMidSteel.asRequiredMm2,
            effectiveDepthMm: loadRes.dxMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          )
        : null;

    final SectionReinforcementDesign? longDiscEdgeSteel = longDirectionIsMixed
        ? FlexureDesigner.designDiscontinuousSupportSteel(
            zoneId: 'long_support_disc',
            zoneTitleAr:
                'الحافة غير المستمرة بالاتجاه الطويل (50% As ≥ As,min)',
            directionAr:
                topology.isShortSpanHorizontal ? 'الاتجاه Y' : 'الاتجاه X',
            midSpanAsRequiredMm2: longMidSteel.asRequiredMm2,
            effectiveDepthMm: loadRes.dyMm,
            overallDepthHMm: loadRes.overallDepthHMm,
            settings: settings,
          )
        : null;

    // 5. تسليح الالتواء عند الأركان
    final torsion = FlexureDesigner.designCornerTorsion(
      topology: topology,
      shortMidAsGoverningMm2: shortMidSteel.asGoverningMm2,
      barDiameterMm: settings.barDiameterPhi.round(),
    );

    // 6. فحص الهطول (Deflection Check)
    // حديد الضغط المقدَّم في منتصف البحر القصير (إن وُجد) يدخل في معامل M.Fc (Table 3.11)
    final deflection = DeflectionChecker.check(
      topology: topology,
      shortMidSteel: shortMidSteel,
      settings: settings,
      overallDepthHMm: loadRes.overallDepthHMm,
      compressionSteelPercent: shortMidSteel.compressionSteelProvidedPercent,
    );

    // 7. فحص القص (Shear Check)
    final shear = ShearChecker.check(
      topology: topology,
      designLoadN: loadRes.finalDesignLoadN,
      dxMm: loadRes.dxMm,
      dyMm: loadRes.dyMm,
      overallDepthHMm: loadRes.overallDepthHMm,
      shortSupportSteel: shortSupSteel,
      longSupportSteel: longSupSteel,
      settings: settings,
    );

    // 7-ب. تصميم الكوابيل المتصلة (عزم المسند، الحديد العلوي، الهطول B.R = 7، القص V = n·lc).
    // الكابولي صبّة واحدة مع البلاطة فيأخذ سماكتها المعتمدة (بعد أي زيادة تلقائية)، وحمله الأساسي
    // هو حمل البلاطة الأساسي مع وزنها الذاتي الإضافي دون ردم البلاطة المهبطة.
    final Map<EdgeSide, CantileverDesignReport> cantileverReports = {};
    if (cantilevers.isNotEmpty) {
      final SlabProjectSettings cantSettings =
          settings.copyWith(overallDepthH: loadRes.overallDepthHMm);
      final double cantParentLoadN =
          loadRes.baseDesignLoadN + loadRes.selfWeightDeltaN;
      for (final entry in cantilevers.entries) {
        cantileverReports[entry.key] = CantileverDesigner.design(
          cantilever: entry.value,
          settings: cantSettings,
          parentLoadN: cantParentLoadN,
          momentSource: cantileverMomentSource,
          givenSupportMomentKnM: givenCantileverMomentKnM,
        );
      }
    }

    // 8. جدول الملخص
    final summaryRow = SlabReinforcementSummaryRow(
      slabId: slabId,
      shortMidLecture: shortMidSteel.barCountSelection.lectureNotation,
      shortSupportLecture: shortSupSteel.barCountSelection.lectureNotation,
      longMidLecture: longMidSteel.barCountSelection.lectureNotation,
      longSupportLecture: longSupSteel.barCountSelection.lectureNotation,
      shortMidSpacing: shortMidSteel.barSpacingSelection?.standardNotation ??
          shortMidSteel.barCountSelection.lectureNotation,
      shortSupportSpacing:
          shortSupSteel.barSpacingSelection?.standardNotation ??
              shortSupSteel.barCountSelection.lectureNotation,
      longMidSpacing: longMidSteel.barSpacingSelection?.standardNotation ??
          longMidSteel.barCountSelection.lectureNotation,
      longSupportSpacing: longSupSteel.barSpacingSelection?.standardNotation ??
          longSupSteel.barCountSelection.lectureNotation,
      shortSupportDiscLecture:
          shortDiscEdgeSteel?.barCountSelection.lectureNotation,
      shortSupportDiscSpacing: shortDiscEdgeSteel == null
          ? null
          : (shortDiscEdgeSteel.barSpacingSelection?.standardNotation ??
              shortDiscEdgeSteel.barCountSelection.lectureNotation),
      longSupportDiscLecture:
          longDiscEdgeSteel?.barCountSelection.lectureNotation,
      longSupportDiscSpacing: longDiscEdgeSteel == null
          ? null
          : (longDiscEdgeSteel.barSpacingSelection?.standardNotation ??
              longDiscEdgeSteel.barCountSelection.lectureNotation),
    );

    // 9. جمع التحذيرات وبناء سجل الخطوات الأكاديمية
    final warnings = <String>[];
    if (!deflection.isSafe) {
      final StringBuffer defMsg = StringBuffer(
        'فحص الهطول غير آمن على السماكة ${loadRes.overallDepthHMm.toStringAsFixed(0)} mm؛ يُنصح بزيادة السماكة إلى ${deflection.suggestedOverallDepthHMm?.toStringAsFixed(0)} mm',
      );
      final double? compPct = deflection.suggestedCompressionSteelPercent;
      if (compPct != null) {
        // نحوّل النسبة المقترحة من Table 3.11 إلى مساحة وعدد أسياخ قابلين للتنفيذ
        final double asCompNeeded =
            (compPct / 100.0) * AppConstants.stripWidth * shortMidSteel.effectiveDepthMm;
        final compBars = ReinforcementTables.selectBarCount(
          requiredAreaMm2PerM: asCompNeeded,
          diameterMm: settings.barDiameterPhi.round(),
          maxSpacingMm: shortMidSteel.maxSpacingAllowedMm,
          minCount: 4,
        );
        defMsg.write(
          '، أو إضافة حديد ضغط علوي في البحر القصير لا يقل عن ${compPct.toStringAsFixed(2)}% (A\'s ≈ ${asCompNeeded.toStringAsFixed(0)} mm²/m ≈ ${compBars.lectureNotation}) وفق Table 3.11',
        );
      }
      defMsg.write('.');
      warnings.add(defMsg.toString());
    }
    if (deflection.comparativeModeNoteAr != null) {
      warnings.add(deflection.comparativeModeNoteAr!);
    }
    if (!shear.isSafe) {
      warnings.add(shear.table316Result.requirementAr);
    }
    for (final b in balMoments.supportBalances) {
      if (b.assumedNeighborCaseNumber != null) {
        warnings.add(
          'الجار ${b.neighborLabel} (${b.side.titleAr}): لم تُحدَّد حالته في Table 3.14 فافتُرضت Case ${b.assumedNeighborCaseNumber} (الحافتان الموازيتان للشريحة مستمرتان)؛ حدّدها يدوياً إن اختلفت.',
        );
      }
    }
    if (topology.squareOrientationNoteAr != null) {
      warnings.add(topology.squareOrientationNoteAr!);
    }
    if (loadRes.selfWeightDeltaN > 0) {
      warnings.add(
        'تم تعديل السماكة تلقائياً من ${settings.overallDepthH.toStringAsFixed(0)} mm إلى ${loadRes.overallDepthHMm.toStringAsFixed(0)} mm وتحديث الحمل التصميمي بمقدار +${loadRes.selfWeightDeltaN.toStringAsFixed(3)} kN/m².',
      );
    }
    if (autoAdjustAttempts > 1) {
      warnings.add(
        'استلزم تحقق الهطول $autoAdjustAttempts محاولات متتالية لزيادة السماكة، إذ ترفع كل زيادة الوزن الذاتي والعزوم والتسليح المطلوب.',
      );
    }

    final allDesigns = <SectionReinforcementDesign>[
      shortMidSteel,
      shortSupSteel,
      if (shortDiscEdgeSteel != null) shortDiscEdgeSteel,
      longMidSteel,
      longSupSteel,
      if (longDiscEdgeSteel != null) longDiscEdgeSteel,
    ];
    warnings.addAll(
      _collectFlexureWarnings(designs: allDesigns, settings: settings),
    );
    for (final entry in cantileverReports.entries) {
      for (final w in entry.value.warningsAr) {
        warnings.add('الكابولي ${entry.value.label} (${entry.key.titleAr}): $w');
      }
    }

    final steps = _buildAcademicSteps(
      settings: settings,
      topology: topology,
      loadRes: loadRes,
      initMoments: initMoments,
      balMoments: balMoments,
      shortMidSteel: shortMidSteel,
      shortSupSteel: shortSupSteel,
      longMidSteel: longMidSteel,
      longSupSteel: longSupSteel,
      shortDiscEdgeSteel: shortDiscEdgeSteel,
      longDiscEdgeSteel: longDiscEdgeSteel,
      torsion: torsion,
      deflection: deflection,
      shear: shear,
    );

    return SlabDesignReport(
      slabId: slabId,
      settingsUsed: settings.copyWith(overallDepthH: loadRes.overallDepthHMm),
      topology: topology,
      loadResult: loadRes,
      initialMoments: initMoments,
      balancedMoments: balMoments,
      shortMidSteel: shortMidSteel,
      shortSupportSteel: shortSupSteel,
      longMidSteel: longMidSteel,
      longSupportSteel: longSupSteel,
      shortDiscontinuousEdgeSteel: shortDiscEdgeSteel,
      longDiscontinuousEdgeSteel: longDiscEdgeSteel,
      cantilevers: Map<EdgeSide, CantileverAttachment>.unmodifiable(cantilevers),
      cantileverReports:
          Map<EdgeSide, CantileverDesignReport>.unmodifiable(cantileverReports),
      torsionDetail: torsion,
      deflectionCheck: deflection,
      shearCheck: shear,
      summaryRow: summaryRow,
      steps: steps,
      warningsAr: warnings,
    );
  }

  /// تحذيرات التسليح: حديد الضغط المطلوب، وعدم كفاية أقصى عدد أسياخ لتوفير المساحة
  static List<String> _collectFlexureWarnings({
    required List<SectionReinforcementDesign> designs,
    required SlabProjectSettings settings,
  }) {
    final out = <String>[];
    final int dia = settings.barDiameterPhi.round();
    final double maxMOverBd2 =
        FlexureTables.getTable4Row(settings.fcu).maxMOverBd2;

    for (final d in designs) {
      if (d.requiresDoublyReinforced) {
        final comp = d.compressionBarSelection;
        final String compText = comp == null
            ? '${d.compressionSteelMm2.toStringAsFixed(0)} mm²/m'
            : '${d.compressionSteelMm2.toStringAsFixed(0)} mm²/m (${comp.lectureNotation}، ${d.compressionSteelProvidedPercent.toStringAsFixed(2)}%)';
        out.add(
          '${d.zoneTitleAr}: M/bd² = ${d.mOverBd2.toStringAsFixed(3)} يتجاوز الحد الأقصى ${maxMOverBd2.toStringAsFixed(2)} لـ Table 4؛ يلزم تسليح مزدوج (Table 5 عند x/d = 0.5): حديد ضغط A\'sc = $compText في الوجه المقابل مع حديد شد ${d.asRequiredMm2.toStringAsFixed(0)} mm²/m، أو زيادة السماكة.',
        );
        if (d.compressionSteelMayNotYield) {
          out.add(
            '${d.zoneTitleAr}: النسبة d\'/d أكبر من الحد المسموح في Table 5 (x/d = 0.5)، فقد لا يصل حديد الضغط إلى الخضوع؛ زد السماكة أو قلّل الغطاء.',
          );
        }
      }
      if (!d.isAreaSufficient) {
        final double needed = d.requiresDoublyReinforced &&
                d.compressionBarSelection != null &&
                !d.compressionBarSelection!.isSufficient &&
                d.barCountSelection.isSufficient
            ? d.compressionSteelMm2
            : d.asGoverningMm2;
        final int? nextDia = ReinforcementTables.nextSufficientDiameter(
          requiredAreaMm2PerM: needed,
          currentDiameterMm: dia,
          maxSpacingMm: d.maxSpacingAllowedMm,
        );
        out.add(
          '${d.zoneTitleAr}: المساحة المطلوبة ${needed.toStringAsFixed(0)} mm²/m أكبر من أقصى ما توفره 15 Ø$dia؛ ${nextDia == null ? 'زد السماكة أو استخدم تسليحاً بطبقتين' : 'استخدم قطراً أكبر (Ø$nextDia) أو زد السماكة'}.',
        );
      }
    }
    return out;
  }

  /// توليد سجل الخطوات الأكاديمية المرقّمة (1 إلى 7) بصيغ LaTeX جاهزة للعرض والـ PDF
  static List<DesignStepRecord> _buildAcademicSteps({
    required SlabProjectSettings settings,
    required ResolvedTopology topology,
    required LoadCalculationResult loadRes,
    required InitialMomentsResult initMoments,
    required BalancedMomentsResult balMoments,
    required SectionReinforcementDesign shortMidSteel,
    required SectionReinforcementDesign shortSupSteel,
    required SectionReinforcementDesign longMidSteel,
    required SectionReinforcementDesign longSupSteel,
    SectionReinforcementDesign? shortDiscEdgeSteel,
    SectionReinforcementDesign? longDiscEdgeSteel,
    required TorsionReinforcementDetail torsion,
    required DeflectionCheckResult deflection,
    required ShearCheckResult shear,
  }) {
    final steps = <DesignStepRecord>[];

    // Step 1: المعطيات والأعماق الفعالة وتصنيف البلاطة
    steps.add(
      DesignStepRecord(
        stepNumber: 1,
        titleAr: 'المعطيات والأعماق الفعالة وتصنيف البلاطة',
        subtitleEn: 'Data, Effective Depths & Panel Classification',
        descriptionAr:
            'تحديد البحر القصير والطويل ونسبة الاستطالة وحالة استناد الحواف الأربع لاستخراج رقم الحالة من الكود.',
        tableReference: 'Table 3.14',
        latexFormulas: [
          'd_x = h - c - \\frac{\\varnothing}{2} = ${loadRes.overallDepthHMm.toStringAsFixed(0)} - ${settings.clearCoverC.toStringAsFixed(0)} - ${(settings.barDiameterPhi / 2).toStringAsFixed(0)} = ${loadRes.dxMm.toStringAsFixed(0)}\\text{ mm}',
          'd_y = h - c - \\varnothing - \\frac{\\varnothing}{2} = ${loadRes.dyMm.toStringAsFixed(0)}\\text{ mm}',
          '\\frac{l_y}{l_x} = \\frac{${topology.longSpanLyM.toStringAsFixed(2)}}{${topology.shortSpanLxM.toStringAsFixed(2)}} = ${topology.lyOverLx.toStringAsFixed(4)} ${topology.lyOverLx <= 2.0 ? "\\le 2.0" : "> 2.0"}',
        ],
        keyValues: {
          'الحمل التصميمي النهائي (n)':
              '${loadRes.finalDesignLoadN.toStringAsFixed(3)} kN/m²',
          'نوع البلاطة': topology.spanningType.titleAr,
          'تصنيف الحواف': topology.twoWayCase != null
              ? 'Case ${topology.twoWayCase!.caseNumber}: ${topology.twoWayCase!.titleAr}'
              : 'بلاطة اتجاه واحد',
          'العلوية / السفلية':
              '${topology.topEdge.titleAr} | ${topology.bottomEdge.titleAr}',
          'اليسرى / اليمنى':
              '${topology.leftEdge.titleAr} | ${topology.rightEdge.titleAr}',
        },
      ),
    );

    // Step 2: معاملات العزوم والتناسب الخطي والعزوم الأولية
    // عند تقريب β (وضع الشرح) نعرضه بثلاث خانات كما في ورقة الحل: 0.037 وليس 0.0369
    final int betaPosDecimals =
        (initMoments.betaSxPosTrace?.wasRounded ?? false) ? 3 : 4;
    final int betaNegDecimals =
        (initMoments.betaSxNegTrace?.wasRounded ?? false) ? 3 : 4;
    final bool betaWasRounded =
        (initMoments.betaSxPosTrace?.wasRounded ?? false) ||
            (initMoments.betaSxNegTrace?.wasRounded ?? false);
    final step2Formulas = <String>[
      if (initMoments.betaSxPosTrace != null &&
          !initMoments.betaSxPosTrace!.wasExactMatch)
        initMoments.betaSxPosTrace!.toLectureLatex(unknownSymbol: r'\beta_{sx}^+'),
      if (initMoments.betaSxNegTrace != null &&
          !initMoments.betaSxNegTrace!.wasExactMatch)
        initMoments.betaSxNegTrace!.toLectureLatex(unknownSymbol: r'\beta_{sx}^-'),
      'n l_x^2 = ${loadRes.finalDesignLoadN.toStringAsFixed(3)} \\times (${topology.shortSpanLxM.toStringAsFixed(2)})^2 = ${initMoments.nLx2.toStringAsFixed(2)}\\text{ kN.m/m}',
      'M_{sx}^+ = ${initMoments.betaSxPos.toStringAsFixed(betaPosDecimals)} \\times ${initMoments.nLx2.toStringAsFixed(2)} = ${initMoments.msxPos.toStringAsFixed(2)}\\text{ kN.m/m}',
      'M_{sy}^+ = ${initMoments.betaSyPos.toStringAsFixed(3)} \\times ${initMoments.nLx2.toStringAsFixed(2)} = ${initMoments.msyPos.toStringAsFixed(2)}\\text{ kN.m/m}',
      if (initMoments.msyNeg > 0)
        'M_{sy}^- = ${initMoments.betaSyNeg!.toStringAsFixed(3)} \\times ${initMoments.nLx2.toStringAsFixed(2)} = ${initMoments.msyNeg.toStringAsFixed(2)}\\text{ kN.m/m}',
      if (initMoments.msxNeg > 0)
        'M_{sx}^- = ${initMoments.betaSxNeg!.toStringAsFixed(betaNegDecimals)} \\times ${initMoments.nLx2.toStringAsFixed(2)} = ${initMoments.msxNeg.toStringAsFixed(2)}\\text{ kN.m/m}',
    ];

    steps.add(
      DesignStepRecord(
        stepNumber: 2,
        titleAr: 'حساب معاملات العزوم (β) والعزوم الأولية',
        subtitleEn: 'Moment Coefficients & Initial Bending Moments',
        descriptionAr:
            'استخراج معاملات العزوم من Table 3.14 مع إجراء التناسب الخطي عند الحاجة وحساب العزوم الأولية.'
            '${betaWasRounded ? ' وفق طريقة الشرح يُقرَّب β الناتج عن التناسب الخطي إلى 3 خانات عشرية قبل ضربه في n·lx² (كما في ورقة الحل).' : ''}',
        tableReference: 'Table 3.14',
        latexFormulas: step2Formulas,
        keyValues: {
          'βsx+': initMoments.betaSxPos.toStringAsFixed(betaPosDecimals),
          'βsx-': initMoments.betaSxNeg?.toStringAsFixed(betaNegDecimals) ?? '—',
          'βsy+': initMoments.betaSyPos.toStringAsFixed(3),
          'βsy-': initMoments.betaSyNeg?.toStringAsFixed(3) ?? '—',
        },
      ),
    );

    // Step 3: موازنة وتوزيع العزوم عند المساند المستمرة
    final step3Formulas = <String>[];
    for (final b in balMoments.supportBalances) {
      if (b.isCantileverSupport) {
        step3Formulas.add(
          'M_{\\text{cant (${b.side.titleEn})}} = ${b.mNeighborInitial.toStringAsFixed(2)}\\text{ kN.m/m} \\implies M_S = ${b.mBalancedSupport.toStringAsFixed(2)}\\text{ kN.m/m}',
        );
      } else {
        step3Formulas.add(
          '\\text{${b.side.titleEn} (${b.neighborLabel}): } M_{UB} = |${b.mSlabInitial.toStringAsFixed(2)} - ${b.mNeighborInitial.toStringAsFixed(2)}| = ${b.mUnbalanced.toStringAsFixed(2)} \\implies M_S = ${b.mBalancedSupport.toStringAsFixed(2)}\\text{ kN.m/m}',
        );
      }
    }
    if (balMoments.longMidMomentFinal > initMoments.msyPos + 1e-4) {
      step3Formulas.add(
        'M_{\\text{mid},y} = ${initMoments.msyPos.toStringAsFixed(2)} + \\Delta M_{\\text{mid}} = ${balMoments.longMidMomentFinal.toStringAsFixed(2)}\\text{ kN.m/m}',
      );
    }
    if (balMoments.shortMidMomentFinal > initMoments.msxPos + 1e-4) {
      step3Formulas.add(
        'M_{\\text{mid},x} = ${initMoments.msxPos.toStringAsFixed(2)} + \\Delta M_{\\text{mid}} = ${balMoments.shortMidMomentFinal.toStringAsFixed(2)}\\text{ kN.m/m}',
      );
    }

    steps.add(
      DesignStepRecord(
        stepNumber: 3,
        titleAr: 'موازنة وتوزيع العزوم عند المساند المستمرة',
        subtitleEn: 'Support Moment Balancing & Mid-Span Adjustment',
        descriptionAr: balMoments.supportBalances.isEmpty
            ? 'لا توجد مساند مستمرة مزوّدة بجيران للموازنة؛ تُعتمد العزوم الأولية مباشرة.'
            : 'توزيع العزم غير المتوازن M_UB بنسبة الجساءات النسبية (k) وتعديل العزم الموجب بمنتصف البحر بإضافة نصف الانخفاض.',
        latexFormulas: step3Formulas,
        keyValues: {
          'عزم منتصف البحر القصير النهائي':
              '${balMoments.shortMidMomentFinal.toStringAsFixed(2)} kN.m/m',
          'عزم منتصف البحر الطويل النهائي':
              '${balMoments.longMidMomentFinal.toStringAsFixed(2)} kN.m/m',
          'أكبر عزم مسند بالاتجاه القصير':
              '${balMoments.shortSupportMomentFinal.toStringAsFixed(2)} kN.m/m',
          'أكبر عزم مسند بالاتجاه الطويل':
              '${balMoments.longSupportMomentFinal.toStringAsFixed(2)} kN.m/m',
        },
      ),
    );

    // Step 4: تصميم حديد التسليح للانحناء
    steps.add(
      DesignStepRecord(
        stepNumber: 4,
        titleAr: 'تصميم حديد التسليح للانحناء والالتواء',
        subtitleEn: 'Flexural Reinforcement Design (ULS)',
        descriptionAr:
            'حساب مساحة حديد التسليح المطلوبة لكل منطقة ومقارنتها بالحد الأدنى من Table 3.25 واختيار الأسياخ من Table 1 و Table 2.',
        tableReference: 'Table 4, Table 3.25, Table 1 & 2',
        latexFormulas: [
          'A_{s,\\min} = ${shortMidSteel.asMinMm2.toStringAsFixed(1)}\\text{ mm}^2/\\text{m}',
          '\\text{Short Mid: } \\frac{M}{bd_x^2} = ${shortMidSteel.mOverBd2.toStringAsFixed(3)} \\implies A_s = ${shortMidSteel.asGoverningMm2.toStringAsFixed(1)}\\text{ mm}^2/\\text{m} \\;(${shortMidSteel.barCountSelection.lectureNotation})',
          '\\text{Long Mid: } \\frac{M}{bd_y^2} = ${longMidSteel.mOverBd2.toStringAsFixed(3)} \\implies A_s = ${longMidSteel.asGoverningMm2.toStringAsFixed(1)}\\text{ mm}^2/\\text{m} \\;(${longMidSteel.barCountSelection.lectureNotation})',
          if (!longSupSteel.isDiscontinuousSupportRule)
            '\\text{Long Sup: } \\frac{M}{bd_y^2} = ${longSupSteel.mOverBd2.toStringAsFixed(3)} \\implies A_s = ${longSupSteel.asGoverningMm2.toStringAsFixed(1)}\\text{ mm}^2/\\text{m} \\;(${longSupSteel.barCountSelection.lectureNotation})',
        ],
        keyValues: {
          'Short Mid':
              '${shortMidSteel.barCountSelection.lectureNotation} (${shortMidSteel.barSpacingSelection?.standardNotation ?? "-"})',
          'Short Support':
              '${shortSupSteel.barCountSelection.lectureNotation} (${shortSupSteel.barSpacingSelection?.standardNotation ?? "-"})',
          if (shortDiscEdgeSteel != null)
            'Short Support — الحافة غير المستمرة':
                '${shortDiscEdgeSteel.barCountSelection.lectureNotation} (${shortDiscEdgeSteel.barSpacingSelection?.standardNotation ?? "-"})',
          'Long Mid':
              '${longMidSteel.barCountSelection.lectureNotation} (${longMidSteel.barSpacingSelection?.standardNotation ?? "-"})',
          'Long Support':
              '${longSupSteel.barCountSelection.lectureNotation} (${longSupSteel.barSpacingSelection?.standardNotation ?? "-"})',
          if (longDiscEdgeSteel != null)
            'Long Support — الحافة غير المستمرة':
                '${longDiscEdgeSteel.barCountSelection.lectureNotation} (${longDiscEdgeSteel.barSpacingSelection?.standardNotation ?? "-"})',
          for (final d in [
            shortMidSteel,
            shortSupSteel,
            longMidSteel,
            longSupSteel,
          ])
            if (d.requiresDoublyReinforced)
              'حديد الضغط — ${d.zoneId}':
                  '${d.compressionSteelMm2.toStringAsFixed(0)} mm²/m (${d.compressionBarSelection?.lectureNotation ?? "-"})',
          'تسليح الالتواء (Torsion)': torsion.isRequired
              ? 'شبكة علوية ${torsion.recommendedTopMeshNotation} بمسافة ${torsion.stripLengthMm.toStringAsFixed(0)} mm عند الأركان'
              : 'غير مطلوب',
        },
      ),
    );

    // Step 5: التحقق من الهطول (Deflection)
    steps.add(
      DesignStepRecord(
        stepNumber: 5,
        titleAr: 'التحقق من الهطول والتشققات (حد التشغيل)',
        subtitleEn: 'Serviceability Limit State — Deflection & Cracking',
        descriptionAr:
            'فحص كفاية العمق الفعال في الاتجاه القصير وفق وضع الحساب النشط (${settings.calculationMode.shortLabelAr}) والتحقق من المسافة القصوى بين الأسياخ (s ≤ 3d).',
        tableReference: 'Table 3.9, Table 3.10 & Table 3.11',
        latexFormulas: [
          'f_s = ${deflection.serviceStressFs.toStringAsFixed(2)}\\text{ N/mm}^2 \\quad,\\quad M.F_t = ${deflection.rawModificationFactor.toStringAsFixed(3)} \\to ${deflection.tensionModificationFactor.toStringAsFixed(2)}',
          'd_{\\min} = \\frac{${deflection.spanMm.toStringAsFixed(0)}}{${deflection.basicRatioBR.toStringAsFixed(0)} \\times ${deflection.tensionModificationFactor.toStringAsFixed(2)}${deflection.compressionModificationFactor > 1.0 ? " \\times ${deflection.compressionModificationFactor.toStringAsFixed(3)}" : ""}} = ${deflection.dMinRequiredMm.toStringAsFixed(2)}\\text{ mm} ${deflection.isSafe ? "\\le" : ">"} d_x = ${deflection.effectiveDepthMm.toStringAsFixed(0)}\\text{ mm}',
        ],
        keyValues: {
          'النسبة الأساسية (B.R)': deflection.basicRatioBR.toStringAsFixed(1),
          'النسبة الفعلية (lx / dx)':
              deflection.actualSpanDepthRatio.toStringAsFixed(2),
          'النسبة المسموحة':
              deflection.allowableSpanDepthRatio.toStringAsFixed(2),
          'حالة الهطول': deflection.isSafe ? 'آمن (Safe — OK)' : 'غير آمن (Unsafe)',
          if (deflection.compressionModificationFactor > 1.0)
            'معامل حديد الضغط (M.Fc)':
                deflection.compressionModificationFactor.toStringAsFixed(3),
        },
        warningNoteAr: deflection.comparativeModeNoteAr,
      ),
    );

    // Step 6: التحقق من القص (Shear)
    steps.add(
      DesignStepRecord(
        stepNumber: 6,
        titleAr: 'التحقق من إجهاد القص (Shear Check)',
        subtitleEn: 'Ultimate Limit State — Shear Capacity',
        descriptionAr:
            'حساب أقصى قوة قص وإجهاد القص التصميمي v ومقارنته بمقاومة الخرسانة للقص vc من Table 3.8 و Table 3.16.',
        tableReference: 'Table 3.15, Table 3.8 & Table 3.16',
        latexFormulas: [
          'V_{\\max} = ${shear.governingBetaV.toStringAsFixed(3)} \\times ${loadRes.finalDesignLoadN.toStringAsFixed(3)} \\times ${topology.shortSpanLxM.toStringAsFixed(2)} = ${shear.vMaxKnPerM.toStringAsFixed(2)}\\text{ kN/m}',
          'v = \\frac{${shear.vMaxKnPerM.toStringAsFixed(2)} \\times 10^3}{1000 \\times ${shear.governingDepthMm.toStringAsFixed(0)}} = ${shear.designShearStressV.toStringAsFixed(3)}\\text{ N/mm}^2',
          'v_c = ${shear.concreteShearStressVc.toStringAsFixed(3)}\\text{ N/mm}^2 \\implies v ${shear.isSafe ? "<" : ">"} v_c',
        ],
        keyValues: {
          'الحافة الحاكمة': shear.governingEdgeAr,
          'نسبة حديد المسند (100As/bd)':
              '${shear.tensionSteelPercent.toStringAsFixed(3)}%',
          'حالة القص': shear.table316Result.requirementAr,
        },
        warningNoteAr: shear.table316Result.depthWarningNoteAr,
      ),
    );

    return steps;
  }
}
