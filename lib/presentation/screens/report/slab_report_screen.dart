import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/design_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/ltr_formula_box.dart';
import '../../../domain/engine/engineering_engine.dart';
import '../../painters/moment_diagram_painter.dart';
import '../../painters/rebar_plan_painter.dart';
import '../../painters/slab_section_painter.dart';
import '../../pdf/slab_report_pdf_generator.dart';
import '../../providers/single_slab_provider.dart';

/// شاشة عرض نتائج وتقرير التصميم الكامل للبلاطة (3 تبويبات + تصدير PDF عربي)
class SlabReportScreen extends ConsumerStatefulWidget {
  const SlabReportScreen({super.key});

  @override
  ConsumerState<SlabReportScreen> createState() => _SlabReportScreenState();
}

class _SlabReportScreenState extends ConsumerState<SlabReportScreen> {
  /// التبديل بين صيغة عدد الأسياخ (5 No 10) وصيغة المسافات (Ø10 @ 200 mm)
  bool _useLectureBarCountNotation = true;
  bool _isExportingPdf = false;

  Future<void> _exportPdf(ActiveReportContext ctx, {required bool share}) async {
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await SlabReportPdfGenerator.generatePdfBytes(
        report: ctx.report,
        sourceLabelAr: ctx.sourceLabelAr,
      );
      if (!mounted) return;
      final filename = 'BS8110_Slab_${ctx.report.slabId}_Report.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => bytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر إنشاء ملف PDF: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportCtx = ref.watch(activeReportProvider);
    final theme = Theme.of(context);

    if (reportCtx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تقرير التصميم')),
        body: const Center(
          child: Text('لا يوجد تقرير نشط حالياً. ابدأ بإدخال بيانات بلاطة.'),
        ),
      );
    }

    final report = reportCtx.report;
    final mode = report.settingsUsed.calculationMode;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تقرير تصميم البلاطة ${report.slabId}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${mode.shortLabelAr} • h=${report.loadResult.overallDepthHMm.toStringAsFixed(0)}mm • n=${report.loadResult.finalDesignLoadN.toStringAsFixed(2)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'طباعة / معاينة PDF',
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _isExportingPdf
                  ? null
                  : () => _exportPdf(reportCtx, share: false),
            ),
            IconButton(
              tooltip: 'مشاركة PDF',
              icon: const Icon(Icons.share_rounded),
              onPressed: _isExportingPdf
                  ? null
                  : () => _exportPdf(reportCtx, share: true),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                mode == DesignCalculationMode.lectureMode
                    ? 'الكود الصارم'
                    : 'شرح المحاضرة',
                style: const TextStyle(fontSize: 11.5),
              ),
              onPressed: () {
                final nextMode = mode == DesignCalculationMode.lectureMode
                    ? DesignCalculationMode.strictBs8110
                    : DesignCalculationMode.lectureMode;
                ref.read(designModeProvider.notifier).setMode(nextMode);
                ref
                    .read(activeReportProvider.notifier)
                    .recomputeWithMode(nextMode);
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.summarize_rounded),
                text: 'الملخص',
              ),
              Tab(
                icon: Icon(Icons.format_list_numbered_rtl_rounded),
                text: 'الحل بالخطوات',
              ),
              Tab(
                icon: Icon(Icons.architecture_rounded),
                text: 'الرسومات والقطاعات',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(
              report: report,
              sourceLabelAr: reportCtx.sourceLabelAr,
              useLectureNotation: _useLectureBarCountNotation,
              onNotationChanged: (val) {
                setState(() => _useLectureBarCountNotation = val);
              },
              onApplySuggestedDepth: () {
                ref.read(activeReportProvider.notifier).recomputeWithMode(
                      DesignCalculationMode.strictBs8110,
                      autoAdjustDepth: true,
                    );
              },
            ),
            _StepsTab(report: report),
            _DrawingsTab(
              report: report,
              useLectureNotation: _useLectureBarCountNotation,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('طباعة / حفظ PDF'),
                    onPressed: _isExportingPdf
                        ? null
                        : () => _exportPdf(reportCtx, share: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('مشاركة التقرير'),
                    onPressed: _isExportingPdf
                        ? null
                        : () => _exportPdf(reportCtx, share: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// التبويب الثالث: الرسومات الهندسية التفاعلية (مخطط العزوم + مسقط التسليح + القطاعات العرضية)
class _DrawingsTab extends StatefulWidget {
  final SlabDesignReport report;
  final bool useLectureNotation;

  const _DrawingsTab({
    required this.report,
    required this.useLectureNotation,
  });

  @override
  State<_DrawingsTab> createState() => _DrawingsTabState();
}

class _DrawingsTabState extends State<_DrawingsTab> {
  late SlabAxisDirection _momentAxis;
  MomentDiagramDisplayMode _momentMode = MomentDiagramDisplayMode.comparison;
  RebarLayerVisibility _layers = const RebarLayerVisibility();

  @override
  void initState() {
    super.initState();
    // نختار تلقائياً المحور الذي يحتوي على موازنة عزوم (مثل المحور Y للبلاطة S7)
    final hasYBalance = widget.report.balancedMoments.supportBalances
        .any((b) => b.axisDirection == SlabAxisDirection.verticalY);
    _momentAxis = hasYBalance
        ? SlabAxisDirection.verticalY
        : SlabAxisDirection.horizontalX;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final report = widget.report;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. مخطط عزوم الانحناء التفاعلي (قبل / بعد الموازنة / مقارنة)
        _DrawingCard(
          title: '1. مخطط عزوم الانحناء للشريحة (Bending Moment Diagram)',
          subtitle: 'بدّل بين قبل الموازنة، بعد الموازنة، أو المقارنة معاً',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<MomentDiagramDisplayMode>(
                      showSelectedIcon: false,
                      segments: MomentDiagramDisplayMode.values
                          .map(
                            (m) => ButtonSegment<MomentDiagramDisplayMode>(
                              value: m,
                              label: Text(
                                m.labelAr,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          )
                          .toList(),
                      selected: {_momentMode},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) {
                          setState(() => _momentMode = sel.first);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('شريحة Y–Y'),
                    selected: _momentAxis == SlabAxisDirection.verticalY,
                    onSelected: (_) =>
                        setState(() => _momentAxis = SlabAxisDirection.verticalY),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('شريحة X–X'),
                    selected: _momentAxis == SlabAxisDirection.horizontalX,
                    onSelected: (_) => setState(
                        () => _momentAxis = SlabAxisDirection.horizontalX),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: MomentDiagramPainter(
                      report: report,
                      axis: _momentAxis,
                      displayMode: _momentMode,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. مسقط التسليح الأفقي التفاعلي مع أزرار عزل الطبقات
        _DrawingCard(
          title: '2. مسقط توزيع حديد التسليح (Reinforcement Plan)',
          subtitle: 'انقر على أزرار الطبقات لعزل أو إظهار كل شبكة حديد',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('الفرش السفلي (B1)',
                        style: TextStyle(fontSize: 11)),
                    selected: _layers.showBottomShort,
                    selectedColor: AppColors.rebarBottomX.withAlpha(40),
                    onSelected: (v) => setState(
                      () => _layers = _layers.copyWith(showBottomShort: v),
                    ),
                  ),
                  FilterChip(
                    label: const Text('الغطاء السفلي (B2)',
                        style: TextStyle(fontSize: 11)),
                    selected: _layers.showBottomLong,
                    selectedColor: AppColors.rebarBottomY.withAlpha(40),
                    onSelected: (v) => setState(
                      () => _layers = _layers.copyWith(showBottomLong: v),
                    ),
                  ),
                  FilterChip(
                    label: const Text('علوي مستمر (0.3L)',
                        style: TextStyle(fontSize: 11)),
                    selected: _layers.showTopContinuous,
                    selectedColor: AppColors.rebarTopContinuous.withAlpha(40),
                    onSelected: (v) => setState(
                      () => _layers = _layers.copyWith(showTopContinuous: v),
                    ),
                  ),
                  FilterChip(
                    label: const Text('علوي طرفي (0.15L)',
                        style: TextStyle(fontSize: 11)),
                    selected: _layers.showTopDiscontinuous,
                    selectedColor:
                        AppColors.rebarTopDiscontinuous.withAlpha(40),
                    onSelected: (v) => setState(
                      () => _layers = _layers.copyWith(showTopDiscontinuous: v),
                    ),
                  ),
                  if (report.torsionDetail.isRequired)
                    FilterChip(
                      label: const Text('التواء الأركان (T)',
                          style: TextStyle(fontSize: 11)),
                      selected: _layers.showCornerTorsion,
                      selectedColor: const Color(0xFF7C3AED).withAlpha(40),
                      onSelected: (v) => setState(
                        () => _layers = _layers.copyWith(showCornerTorsion: v),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 2.5,
                    child: CustomPaint(
                      painter: RebarPlanPainter(
                        report: report,
                        layers: _layers,
                        useLectureNotation: widget.useLectureNotation,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. القطاع العرضي X-X
        _DrawingCard(
          title: '3. القطاع العرضي الأفقي (Section X–X)',
          subtitle:
              'يُظهر الغطاء الخرساني، الحديد السفلي والعلوي، وحالة المسندين الأيسر والأيمن (بما في ذلك البلاطة المهبطة أو الكابولي)',
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 185,
              width: double.infinity,
              child: CustomPaint(
                painter: SlabSectionPainter(
                  report: report,
                  axis: SlabAxisDirection.horizontalX,
                  useLectureNotation: widget.useLectureNotation,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. القطاع العرضي Y-Y
        _DrawingCard(
          title: '4. القطاع العرضي الرأسي (Section Y–Y)',
          subtitle: 'يُظهر الاستمرارية فوق المسندين العلوي والسفلي وأطوال التوقف',
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 185,
              width: double.infinity,
              child: CustomPaint(
                painter: SlabSectionPainter(
                  report: report,
                  axis: SlabAxisDirection.verticalY,
                  useLectureNotation: widget.useLectureNotation,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DrawingCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// التبويب الأول: الملخص السريع، بطاقات الأمان، جدول التسليح، والعزوم النهائية
class _SummaryTab extends StatelessWidget {
  final SlabDesignReport report;
  final String sourceLabelAr;
  final bool useLectureNotation;
  final ValueChanged<bool> onNotationChanged;
  final VoidCallback onApplySuggestedDepth;

  const _SummaryTab({
    required this.report,
    required this.sourceLabelAr,
    required this.useLectureNotation,
    required this.onNotationChanged,
    required this.onApplySuggestedDepth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeColor =
        report.overallIsSafe ? AppColors.safeGreen : AppColors.dangerRed;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: safeColor.withAlpha(22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: safeColor.withAlpha(110), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    report.overallIsSafe
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: safeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.overallIsSafe
                              ? 'التصميم آمن ومستوفٍ لمتطلبات الحد الأقصى والتشغيل'
                              : 'التصميم يحتاج تعديلاً (راجع فحص الهطول/القص)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: safeColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${report.topology.spanningType.titleAr}${report.topology.twoWayCase != null ? " — Case ${report.topology.twoWayCase!.caseNumber}" : ""} ($sourceLabelAr)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!report.deflectionCheck.isSafe &&
                  report.deflectionCheck.suggestedOverallDepthHMm != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentAmber,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(
                      'إعادة التصميم بالسماكة الآمنة المقترحة (h = ${report.deflectionCheck.suggestedOverallDepthHMm!.toStringAsFixed(0)} mm)',
                    ),
                    onPressed: onApplySuggestedDepth,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _StatusMetricCard(
                title: 'الهطول',
                isSafe: report.deflectionCheck.isSafe,
                primaryMetric:
                    'd_min = ${report.deflectionCheck.dMinRequiredMm.toStringAsFixed(1)}',
                secondaryMetric:
                    'd_x = ${report.deflectionCheck.effectiveDepthMm.toStringAsFixed(0)} mm (B.R=${report.deflectionCheck.basicRatioBR.toStringAsFixed(0)})',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusMetricCard(
                title: 'القص',
                isSafe: report.shearCheck.isSafe,
                primaryMetric:
                    'v = ${report.shearCheck.designShearStressV.toStringAsFixed(3)}',
                secondaryMetric:
                    'vc = ${report.shearCheck.concreteShearStressVc.toStringAsFixed(3)} N/mm²',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusMetricCard(
                title: 'التباعد',
                isSafe: report.isFlexureSpacingSafe,
                primaryMetric: report.isFlexureSpacingSafe ? 's ≤ 3d' : 's > 3d',
                secondaryMetric:
                    'h = ${report.loadResult.overallDepthHMm.toStringAsFixed(0)} mm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: Text(
                'جدول التسليح النهائي للبلاطة ${report.slabId}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ChoiceChip(
              label: Text(useLectureNotation ? 'No Ø' : '@ mm'),
              selected: true,
              onSelected: (_) => onNotationChanged(!useLectureNotation),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.primary.withAlpha(22),
              ),
              columns: [
                const DataColumn(label: Text('Slab')),
                const DataColumn(label: Text('Short — Mid')),
                DataColumn(
                  label: Text(
                    report.summaryRow.shortSupportDiscLecture != null
                        ? 'Short — Sup (Cont.)'
                        : 'Short — Sup',
                  ),
                ),
                if (report.summaryRow.shortSupportDiscLecture != null)
                  const DataColumn(label: Text('Short — Sup (Disc.)')),
                const DataColumn(label: Text('Long — Mid')),
                DataColumn(
                  label: Text(
                    report.summaryRow.longSupportDiscLecture != null
                        ? 'Long — Sup (Cont.)'
                        : 'Long — Sup',
                  ),
                ),
                if (report.summaryRow.longSupportDiscLecture != null)
                  const DataColumn(label: Text('Long — Sup (Disc.)')),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        report.summaryRow.slabId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                        useLectureNotation
                            ? report.summaryRow.shortMidLecture
                            : report.summaryRow.shortMidSpacing,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.rebarBottomX,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        useLectureNotation
                            ? report.summaryRow.shortSupportLecture
                            : report.summaryRow.shortSupportSpacing,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.rebarTopDiscontinuous,
                        ),
                      ),
                    ),
                    if (report.summaryRow.shortSupportDiscLecture != null)
                      DataCell(
                        Text(
                          (useLectureNotation
                                  ? report.summaryRow.shortSupportDiscLecture
                                  : report.summaryRow.shortSupportDiscSpacing) ??
                              '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.rebarTopDiscontinuous,
                          ),
                        ),
                      ),
                    DataCell(
                      Text(
                        useLectureNotation
                            ? report.summaryRow.longMidLecture
                            : report.summaryRow.longMidSpacing,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.rebarBottomY,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        useLectureNotation
                            ? report.summaryRow.longSupportLecture
                            : report.summaryRow.longSupportSpacing,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.rebarTopContinuous,
                        ),
                      ),
                    ),
                    if (report.summaryRow.longSupportDiscLecture != null)
                      DataCell(
                        Text(
                          (useLectureNotation
                                  ? report.summaryRow.longSupportDiscLecture
                                  : report.summaryRow.longSupportDiscSpacing) ??
                              '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.rebarTopDiscontinuous,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص العزوم التصميمية النهائية (kN.m/m)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _KeyValueRow(
                label: 'عزم منتصف البحر القصير (Short Mid)',
                value:
                    '${report.balancedMoments.shortMidMomentFinal.toStringAsFixed(2)} kN.m/m',
              ),
              _KeyValueRow(
                label: 'أكبر عزم مسند بالاتجاه القصير (Short Sup)',
                value:
                    '${report.balancedMoments.shortSupportMomentFinal.toStringAsFixed(2)} kN.m/m',
              ),
              _KeyValueRow(
                label: 'عزم منتصف البحر الطويل (Long Mid)',
                value:
                    '${report.balancedMoments.longMidMomentFinal.toStringAsFixed(2)} kN.m/m',
              ),
              _KeyValueRow(
                label: 'أكبر عزم مسند بالاتجاه الطويل (Long Sup)',
                value:
                    '${report.balancedMoments.longSupportMomentFinal.toStringAsFixed(2)} kN.m/m',
              ),
              if (report.torsionDetail.isRequired) ...[
                const Divider(height: 18),
                _KeyValueRow(
                  label: 'تسليح الالتواء عند الأركان (Torsion Mesh)',
                  value:
                      '${report.torsionDetail.recommendedTopMeshNotation} (${report.torsionDetail.stripLengthMm.toStringAsFixed(0)} mm)',
                ),
              ],
            ],
          ),
        ),

        for (final entry in report.cantileverReports.entries) ...[
          const SizedBox(height: 16),
          _CantileverDesignCard(
            side: entry.key,
            report: entry.value,
            useLectureNotation: useLectureNotation,
          ),
        ],

        if (report.warningsAr.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentAmber.withAlpha(110)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.warningAmber,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'تنبيهات وملاحظات هندسية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warningAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...report.warningsAr.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $w',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// التبويب الثاني: الحل الأكاديمي المفصّل خطوة بخطوة بالمعادلات الرياضية LaTeX
class _StepsTab extends StatefulWidget {
  final SlabDesignReport report;

  const _StepsTab({required this.report});

  @override
  State<_StepsTab> createState() => _StepsTabState();
}

class _StepsTabState extends State<_StepsTab> {
  final Set<int> _expandedSteps = {1, 2, 3, 4, 5, 6};

  void _toggleAll() {
    setState(() {
      if (_expandedSteps.length == widget.report.steps.length) {
        _expandedSteps.clear();
      } else {
        _expandedSteps.addAll(widget.report.steps.map((s) => s.stepNumber));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allExpanded = _expandedSteps.length == widget.report.steps.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'خطوات الحل الأكاديمي (${widget.report.steps.length} خطوات)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _toggleAll,
              icon: Icon(
                allExpanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 18,
              ),
              label: Text(allExpanded ? 'طي الكل' : 'توسيع الكل'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ...widget.report.steps.map((step) {
          final isOpen = _expandedSteps.contains(step.stepNumber);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      if (isOpen) {
                        _expandedSteps.remove(step.stepNumber);
                      } else {
                        _expandedSteps.add(step.stepNumber);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            '${step.stepNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.titleAr,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                step.subtitleEn,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(160),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (step.tableReference != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              step.tableReference!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                          isOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          step.descriptionAr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.55,
                          ),
                        ),
                        if (step.latexFormulas.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...step.latexFormulas.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: LtrFormulaBox(tex: f, fontSize: 13.5),
                            ),
                          ),
                        ],
                        if (step.keyValues.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...step.keyValues.entries.map(
                            (e) => _KeyValueRow(label: e.key, value: e.value),
                          ),
                        ],
                        if (step.stepNumber == 4) ...[
                          const SizedBox(height: 10),
                          _FlexureBreakdownTable(
                            designs: widget.report.allSteelDesigns,
                          ),
                        ],
                        if (step.warningNoteAr != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accentAmber.withAlpha(110),
                              ),
                            ),
                            child: Text(
                              step.warningNoteAr!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.45,
                                color: AppColors.warningAmber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _FlexureBreakdownTable extends StatelessWidget {
  final List<SectionReinforcementDesign> designs;

  const _FlexureBreakdownTable({required this.designs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('الموقع')),
            DataColumn(label: Text('M (kN.m)')),
            DataColumn(label: Text('d (mm)')),
            DataColumn(label: Text('M/bd²')),
            DataColumn(label: Text('As,req')),
            DataColumn(label: Text('As,gov')),
            DataColumn(label: Text('العدد (Table 1)')),
            DataColumn(label: Text('المسافة (Table 2)')),
            DataColumn(label: Text("A'sc (ضغط)")),
          ],
          rows: designs
              .map(
                (d) => DataRow(
                  cells: [
                    DataCell(Text(d.zoneId)),
                    DataCell(Text(d.designMomentKnM.toStringAsFixed(2))),
                    DataCell(Text(d.effectiveDepthMm.toStringAsFixed(0))),
                    DataCell(Text(d.mOverBd2.toStringAsFixed(3))),
                    DataCell(Text(d.asRequiredMm2.toStringAsFixed(1))),
                    DataCell(Text(d.asGoverningMm2.toStringAsFixed(1))),
                    DataCell(
                      Text(
                        '${d.barCountSelection.lectureNotation} (${d.barCountSelection.areaProvidedMm2.toStringAsFixed(0)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(d.barSpacingSelection?.standardNotation ?? '—'),
                    ),
                    DataCell(
                      Text(
                        d.requiresDoublyReinforced
                            ? '${d.compressionSteelMm2.toStringAsFixed(0)} (${d.compressionBarSelection?.lectureNotation ?? "-"})'
                            : '—',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: d.requiresDoublyReinforced
                              ? AppColors.dangerRed
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  final String title;
  final bool isSafe;
  final String primaryMetric;
  final String secondaryMetric;

  const _StatusMetricCard({
    required this.title,
    required this.isSafe,
    required this.primaryMetric,
    required this.secondaryMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSafe ? AppColors.safeGreen : AppColors.dangerRed;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSafe ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            primaryMetric,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondaryMetric,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(165),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة نتائج تصميم الكابولي المتصل بحافة البلاطة (عزم، حديد علوي، هطول B.R = 7، قص V = n·lc)
class _CantileverDesignCard extends StatelessWidget {
  final EdgeSide side;
  final CantileverDesignReport report;
  final bool useLectureNotation;

  const _CantileverDesignCard({
    required this.side,
    required this.report,
    required this.useLectureNotation,
  });

  String _barLabel(SectionReinforcementDesign d) {
    if (useLectureNotation) return d.barCountSelection.lectureNotation;
    return d.barSpacingSelection?.standardNotation ??
        d.barCountSelection.lectureNotation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool safe = report.overallIsSafe;
    final Color color = safe ? AppColors.safeGreen : AppColors.dangerRed;
    final defl = report.deflectionCheck;
    final shear = report.shearCheck;
    final bool momentDiffers =
        (report.supportMomentKnM - report.staticMomentKnM).abs() > 1e-9;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                safe ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'تصميم الكابولي عند ${side.titleAr} (${report.label})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KeyValueRow(
            label: 'الطول lc / السماكة h / العمق الفعال d',
            value:
                '${report.cantilever.lengthM.toStringAsFixed(2)} m / ${report.loadResult.overallDepthHMm.toStringAsFixed(0)} mm / ${report.loadResult.dxMm.toStringAsFixed(0)} mm',
          ),
          _KeyValueRow(
            label: 'الحمل التصميمي n',
            value: '${report.loadResult.finalDesignLoadN.toStringAsFixed(3)} kN/m²',
          ),
          _KeyValueRow(
            label: 'عزم المسند (${report.momentSource.titleAr})',
            value: '${report.supportMomentKnM.toStringAsFixed(2)} kN.m/m',
          ),
          if (momentDiffers)
            _KeyValueRow(
              label: 'العزم الستاتيكي n·lc²/2 (للمقارنة)',
              value: '${report.staticMomentKnM.toStringAsFixed(2)} kN.m/m',
            ),
          const Divider(height: 16),
          _KeyValueRow(
            label: 'الحديد العلوي عند المسند',
            value:
                '${_barLabel(report.topSteel)} (As,req = ${report.topSteel.asRequiredMm2.toStringAsFixed(0)} / As,min = ${report.topSteel.asMinMm2.toStringAsFixed(0)} mm²/m)',
          ),
          _KeyValueRow(
            label: 'حديد التوزيع (As,min)',
            value: _barLabel(report.distributionSteel),
          ),
          _KeyValueRow(
            label: 'امتداد الحديد العلوي داخل البلاطة (1.5 lc)',
            value: '${report.anchorageInsideSlabM.toStringAsFixed(2)} m',
          ),
          const Divider(height: 16),
          _KeyValueRow(
            label: 'الهطول (B.R = ${defl.basicRatioBR.toStringAsFixed(0)})',
            value:
                '${defl.isSafe ? "آمن" : "غير آمن"} — d_min = ${defl.dMinRequiredMm.toStringAsFixed(1)} مقابل d = ${defl.effectiveDepthMm.toStringAsFixed(0)} mm',
          ),
          if (!defl.isSafe && defl.suggestedOverallDepthHMm != null)
            _KeyValueRow(
              label: 'السماكة المقترحة للكابولي',
              value: 'h = ${defl.suggestedOverallDepthHMm!.toStringAsFixed(0)} mm',
            ),
          _KeyValueRow(
            label: 'القص (V = n·lc)',
            value:
                '${shear.isSafe ? "آمن" : "غير آمن"} — V = ${shear.vMaxKnPerM.toStringAsFixed(2)} kN/m ، v = ${shear.designShearStressV.toStringAsFixed(3)} مقابل vc = ${shear.concreteShearStressVc.toStringAsFixed(3)} N/mm²',
          ),
        ],
      ),
    );
  }
}
