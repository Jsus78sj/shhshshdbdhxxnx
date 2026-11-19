import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/design_mode.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/bs8110/flexure_tables.dart';
import '../../../domain/engine/engineering_engine.dart';
import '../../painters/floor_plan_painter.dart';
import '../../providers/floor_grid_provider.dart';
import '../../providers/single_slab_provider.dart';

/// شاشة محرر المخطط الشبكي الكامل للسقف (Full Floor Grid Editor — المرحلة 5)
class FloorGridScreen extends ConsumerWidget {
  const FloorGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(floorGridEditorProvider);
    final notifier = ref.read(floorGridEditorProvider.notifier);
    final activeMode = ref.watch(designModeProvider);
    final theme = Theme.of(context);

    final plan = editorState.plan;
    final selectedCell = editorState.selectedCell;
    final selectedTopo = editorState.selectedTopology;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _showRenameDialog(context, plan.projectName, notifier),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      plan.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (editorState.hasUnsavedChanges) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${plan.colsCount}×${plan.rowsCount} محاور • ${plan.designableSlabsCount} بلاطة • ${activeMode.shortLabelAr}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'حاسبة الرقم السحري (S_No.)',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => _showMagicNumberDialog(context, notifier),
          ),
          IconButton(
            tooltip: 'جدول تسليح السقف كاملاً',
            icon: const Icon(Icons.table_rows_rounded),
            onPressed: () =>
                _showFullBuildingScheduleSheet(context, ref, activeMode),
          ),
          IconButton(
            tooltip: 'إعدادات المشروع (n, h, c, Ø, fcu, fy)',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showProjectSettingsSheet(context, plan, notifier),
          ),
          IconButton(
            tooltip: 'حفظ المشروع محلياً',
            icon: const Icon(Icons.save_rounded),
            onPressed: () async {
              await notifier.saveCurrentPlan();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ المشروع "${plan.projectName}" محلياً.'),
                    backgroundColor: AppColors.safeGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. شريط أدوات الشبكة والمحاور السريع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.straighten_rounded, size: 17),
                    label: const Text('تعديل المحاور'),
                    onPressed: () =>
                        _showAxesEditorDialog(context, plan, notifier),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.add_box_outlined, size: 17),
                    label: const Text('+ عمود X'),
                    onPressed: () => notifier.addColumn(),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.add_box_outlined, size: 17),
                    label: const Text('+ صف Y'),
                    onPressed: () => notifier.addRow(),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.format_list_numbered_rounded,
                        size: 17),
                    label: const Text('ترقيم تلقائي'),
                    onPressed: notifier.autoRenumberNormalSlabs,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.quiz_rounded, size: 17),
                    label: const Text('قالب الاختبار'),
                    onPressed: notifier.loadUniversityExamTemplate,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.note_add_outlined, size: 17),
                    label: const Text('مخطط جديد'),
                    onPressed: () => notifier.createNewBlankPlan(),
                  ),
                ],
              ),
            ),
          ),

          // 2. لوحة رسم المخطط التفاعلية (Pinch, Zoom & Tap)
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FloorPlanCanvasWidget(
                    plan: plan,
                    selectedRow: editorState.selectedRow,
                    selectedCol: editorState.selectedCol,
                    highlightedSlabId: editorState.highlightedSlabId,
                    onCellTapped: notifier.selectCell,
                  ),
                ),
                // تلميح علوي صغير للتحكم
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withAlpha(225),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      'انقر على أي بلاطة لتحديدها • اسحب أو كبّر بإصبعين',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
                if (editorState.highlightedSlabId != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: InputChip(
                      avatar: const Icon(
                        Icons.star_rounded,
                        color: AppColors.accentAmber,
                        size: 18,
                      ),
                      label: Text(
                        'الرقم السحري: ${editorState.highlightedSlabId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onDeleted: notifier.clearHighlight,
                    ),
                  ),
              ],
            ),
          ),

          // 3. لوحة خصائص الخانة المحددة وزر التصميم الفوري
          if (selectedCell != null)
            _SelectedCellInspectorPanel(
              plan: plan,
              cell: selectedCell,
              topology: selectedTopo,
              onChangeType: (t) => notifier.updateCellType(
                selectedCell.row,
                selectedCell.col,
                t,
              ),
              onEditDetails: () =>
                  _showCellDetailsDialog(context, plan, selectedCell, notifier),
              onToggleCantilever: (side) => notifier.toggleCantilever(
                row: selectedCell.row,
                col: selectedCell.col,
                side: side,
              ),
              onDesignPressed: selectedCell.cellType.isDesignableSlab
                  ? () => _openSlabDesignReport(
                        context,
                        ref,
                        selectedCell.id,
                        activeMode,
                      )
                  : null,
            ),
        ],
      ),
    );
  }

  void _openSlabDesignReport(
    BuildContext context,
    WidgetRef ref,
    String slabId,
    DesignCalculationMode mode,
  ) {
    final notifier = ref.read(floorGridEditorProvider.notifier);
    try {
      final report = notifier.designSlab(slabId, mode);
      ref.read(activeReportProvider.notifier).setReport(
            ActiveReportContext(
              report: report,
              sourceLabelAr:
                  'محرر المخطط الكامل (${ref.read(floorGridEditorProvider).plan.projectName})',
              recompute: (newMode, {bool autoAdjustDepth = false}) {
                return ref.read(floorGridEditorProvider.notifier).designSlab(
                      slabId,
                      newMode,
                      autoAdjustDepthInStrictMode: autoAdjustDepth,
                    );
              },
            ),
          );
      context.push(AppRoutes.slabReport);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر تصميم البلاطة $slabId: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String currentName,
    FloorGridEditorNotifier notifier,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم المشروع'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم المخطط'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      notifier.updateProjectName(ctrl.text.trim());
    }
    ctrl.dispose();
  }

  Future<void> _showMagicNumberDialog(
    BuildContext context,
    FloorGridEditorNotifier notifier,
  ) async {
    final d1Ctrl = TextEditingController(text: '4');
    final d2Ctrl = TextEditingController(text: '2');
    String preview = 'S7';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void recalc() {
            final d1 = int.tryParse(d1Ctrl.text.trim());
            final d2 = int.tryParse(d2Ctrl.text.trim());
            if (d1 != null &&
                d2 != null &&
                d1 >= 0 &&
                d1 <= 9 &&
                d2 >= 0 &&
                d2 <= 9) {
              setState(() => preview = FloorGridPlan.magicSlabId(d1, d2));
            } else {
              setState(() => preview = '—');
            }
          }

          return AlertDialog(
            title: const Text('حاسبة الرقم السحري (S_No.)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'أدخل آخر رقمين من رقم القيد الجامعي لحساب بلاطة الاختبار وتظليلها تلقائياً:\nS_No. = 9 − |d₁ − d₂|',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: d1Ctrl,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'الرقم الأول d1',
                          counterText: '',
                        ),
                        onChanged: (_) => recalc(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: d2Ctrl,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'الرقم الثاني d2',
                          counterText: '',
                        ),
                        onChanged: (_) => recalc(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'البلاطة المطلوبة: $preview',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warningAmber,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final d1 = int.tryParse(d1Ctrl.text.trim());
                  final d2 = int.tryParse(d2Ctrl.text.trim());
                  if (d1 != null &&
                      d2 != null &&
                      d1 >= 0 &&
                      d1 <= 9 &&
                      d2 >= 0 &&
                      d2 <= 9) {
                    notifier.applyMagicRegistrationDigits(d1, d2);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('تحديد على المخطط'),
              ),
            ],
          );
        },
      ),
    );
    d1Ctrl.dispose();
    d2Ctrl.dispose();
  }

  Future<void> _showAxesEditorDialog(
    BuildContext context,
    FloorGridPlan plan,
    FloorGridEditorNotifier notifier,
  ) async {
    final xCtrls = plan.xSpansM
        .map((v) => TextEditingController(text: v.toStringAsFixed(2)))
        .toList();
    final yCtrls = plan.ySpansM
        .map((v) => TextEditingController(text: v.toStringAsFixed(2)))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تعديل أطوال المحاور الأفقية (X) والرأسية (Y)',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'المحاور الأفقية X (الأعمدة)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (plan.colsCount > 1)
                    TextButton.icon(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('حذف آخر عمود'),
                      onPressed: () {
                        notifier.removeLastColumn();
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  xCtrls.length,
                  (i) => SizedBox(
                    width: 105,
                    child: TextField(
                      controller: xCtrls[i],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'X${i + 1} (m)',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'المحاور الرأسية Y (الصفوف)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (plan.rowsCount > 1)
                    TextButton.icon(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('حذف آخر صف'),
                      onPressed: () {
                        notifier.removeLastRow();
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  yCtrls.length,
                  (i) => SizedBox(
                    width: 105,
                    child: TextField(
                      controller: yCtrls[i],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Y${i + 1} (m)',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  for (int i = 0; i < xCtrls.length; i++) {
                    final v = double.tryParse(xCtrls[i].text.trim());
                    if (v != null && v > 0) notifier.updateColumnSpan(i, v);
                  }
                  for (int i = 0; i < yCtrls.length; i++) {
                    final v = double.tryParse(yCtrls[i].text.trim());
                    if (v != null && v > 0) notifier.updateRowSpan(i, v);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('تطبيق الأبعاد'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final c in xCtrls) {
      c.dispose();
    }
    for (final c in yCtrls) {
      c.dispose();
    }
  }

  Future<void> _showProjectSettingsSheet(
    BuildContext context,
    FloorGridPlan plan,
    FloorGridEditorNotifier notifier,
  ) async {
    final s = plan.settings;
    final loadCtrl = TextEditingController(text: s.designLoadN.toStringAsFixed(2));
    final hCtrl = TextEditingController(text: s.overallDepthH.toStringAsFixed(0));
    final cCtrl = TextEditingController(text: s.clearCoverC.toStringAsFixed(0));
    final addMomCtrl = TextEditingController(
      text: plan.additionalSupportMomentKnM.toStringAsFixed(2),
    );

    int dia = s.barDiameterPhi.round();
    int fcu = s.fcu.round();
    double fy = s.fy;
    CantileverMomentSource cantSource = plan.cantileverMomentSource;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'معطيات التصميم العامة للمخطط',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: loadCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'الحمل n (kN/m²)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'السماكة h (mm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'الغطاء c (mm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // value يتحكم به الـ state؛ initialValue لا يتحدّث بعد أول بناء.
                        // ignore: deprecated_member_use
                        value: dia,
                        decoration: const InputDecoration(labelText: 'القطر Ø'),
                        items: const [8, 10, 12, 14, 16]
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('Ø$d')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => dia = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // value يتحكم به الـ state؛ initialValue لا يتحدّث بعد أول بناء.
                        // ignore: deprecated_member_use
                        value: fcu,
                        decoration: const InputDecoration(labelText: 'fcu'),
                        items: FlexureTables.supportedFcuGrades
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text('$g')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => fcu = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        // value يتحكم به الـ state؛ initialValue لا يتحدّث بعد أول بناء.
                        // ignore: deprecated_member_use
                        value: fy,
                        decoration: const InputDecoration(labelText: 'fy'),
                        items: const [250.0, 460.0]
                            .map((y) => DropdownMenuItem(
                                value: y, child: Text(y.toStringAsFixed(0))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => fy = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addMomCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'عزم مسند أدنى إضافي لجميع البلاطات (kN.m/m)',
                    hintText: '0.00 أو 1.00 حسب ملاحظة الاختبار',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'عزم مسند الكابولي',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SegmentedButton<CantileverMomentSource>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CantileverMomentSource.givenSupportMoment,
                      label: Text('المعطى في السؤال'),
                    ),
                    ButtonSegment(
                      value: CantileverMomentSource.statics,
                      label: Text('ستاتيكي n·l²/2'),
                    ),
                  ],
                  selected: {cantSource},
                  onSelectionChanged: (v) =>
                      setState(() => cantSource = v.first),
                ),
                const SizedBox(height: 4),
                Text(
                  cantSource == CantileverMomentSource.givenSupportMoment
                      ? 'يُعتمد عزم المسند أعلاه كعزم الكابولي (ملاحظة المخطط: 1 kN.m/m). إن كان صفراً يُستخدم العزم الستاتيكي.'
                      : 'يُحسب عزم الكابولي من الحمل والطول: M = n·lc²/2.',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final nVal = double.tryParse(loadCtrl.text.trim()) ??
                        s.designLoadN;
                    final hVal =
                        double.tryParse(hCtrl.text.trim()) ?? s.overallDepthH;
                    final cVal =
                        double.tryParse(cCtrl.text.trim()) ?? s.clearCoverC;
                    final addM =
                        double.tryParse(addMomCtrl.text.trim()) ?? 0.0;

                    notifier.updateSettings(
                      s.copyWith(
                        designLoadN: nVal > 0 ? nVal : s.designLoadN,
                        overallDepthH: hVal >= 60 ? hVal : s.overallDepthH,
                        clearCoverC: cVal >= 10 ? cVal : s.clearCoverC,
                        barDiameterPhi: dia.toDouble(),
                        fcu: fcu.toDouble(),
                        fy: fy,
                      ),
                      additionalSupportMomentKnM: addM >= 0 ? addM : 0.0,
                      cantileverMomentSource: cantSource,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('حفظ المعطيات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    loadCtrl.dispose();
    hCtrl.dispose();
    cCtrl.dispose();
    addMomCtrl.dispose();
  }

  Future<void> _showCellDetailsDialog(
    BuildContext context,
    FloorGridPlan plan,
    FloorSlabCell cell,
    FloorGridEditorNotifier notifier,
  ) async {
    final idCtrl = TextEditingController(text: cell.id);
    final labelCtrl = TextEditingController(text: cell.label);
    final owCtrl = TextEditingController(
      text: cell.overrideWidthXM?.toStringAsFixed(2) ?? '',
    );
    final ohCtrl = TextEditingController(
      text: cell.overrideHeightYM?.toStringAsFixed(2) ?? '',
    );
    final loadCtrl = TextEditingController(
      text: cell.customDesignLoadN?.toStringAsFixed(2) ?? '',
    );
    final fillCtrl =
        TextEditingController(text: cell.fillDepthM.toStringAsFixed(2));
    final fillWeightCtrl = TextEditingController(
        text: cell.fillUnitWeightKnM3.toStringAsFixed(1));

    final cantCtrls = <EdgeSide, TextEditingController>{
      for (final c in cell.cantilevers)
        c.side: TextEditingController(text: c.lengthM.toStringAsFixed(2)),
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'خصائص الخانة (${cell.id})',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: idCtrl,
                      decoration: const InputDecoration(labelText: 'رمز البلاطة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'التسمية'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: owCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'تجاوز العرض X (m)',
                        hintText: plan.xSpansM[cell.col].toStringAsFixed(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ohCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'تجاوز الطول Y (m)',
                        hintText: plan.ySpansM[cell.row].toStringAsFixed(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: loadCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'حمل تصميمي مخصص لهذه البلاطة (اختياري — kN/m²)',
                  hintText:
                      'افتراضي المشروع: ${plan.settings.designLoadN.toStringAsFixed(2)}',
                ),
              ),
              if (cell.cellType == SlabCellType.droppedSolid) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fillCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'سماكة الردم (m)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fillWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'كثافة الردم (kN/m³)'),
                      ),
                    ),
                  ],
                ),
              ],
              if (cantCtrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'أطوال الكوابيل المتصلة بهذه البلاطة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...cantCtrls.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: e.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'طول الكابولي (${e.key.titleAr}) — m',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  final ow = double.tryParse(owCtrl.text.trim());
                  final oh = double.tryParse(ohCtrl.text.trim());
                  final cl = double.tryParse(loadCtrl.text.trim());
                  final fd = double.tryParse(fillCtrl.text.trim());
                  final fw = double.tryParse(fillWeightCtrl.text.trim());

                  notifier.updateCellProperties(
                    row: cell.row,
                    col: cell.col,
                    id: idCtrl.text,
                    label: labelCtrl.text,
                    overrideWidthXM: (ow != null && ow > 0) ? ow : null,
                    clearOverrideWidthX: owCtrl.text.trim().isEmpty,
                    overrideHeightYM: (oh != null && oh > 0) ? oh : null,
                    clearOverrideHeightY: ohCtrl.text.trim().isEmpty,
                    customDesignLoadN: (cl != null && cl > 0) ? cl : null,
                    clearCustomDesignLoad: loadCtrl.text.trim().isEmpty,
                    fillDepthM: (fd != null && fd >= 0) ? fd : null,
                    fillUnitWeightKnM3: (fw != null && fw > 0) ? fw : null,
                  );

                  for (final entry in cantCtrls.entries) {
                    final len = double.tryParse(entry.value.text.trim());
                    if (len != null && len > 0) {
                      notifier.updateCantileverLength(
                        row: cell.row,
                        col: cell.col,
                        side: entry.key,
                        lengthM: len,
                      );
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );

    idCtrl.dispose();
    labelCtrl.dispose();
    owCtrl.dispose();
    ohCtrl.dispose();
    loadCtrl.dispose();
    fillCtrl.dispose();
    fillWeightCtrl.dispose();
    for (final c in cantCtrls.values) {
      c.dispose();
    }
  }

  Future<void> _showFullBuildingScheduleSheet(
    BuildContext context,
    WidgetRef ref,
    DesignCalculationMode mode,
  ) async {
    final reports =
        ref.read(floorGridEditorProvider.notifier).designAllSlabs(mode);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'جدول تسليح جميع بلاطات السقف (${reports.length})',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'انقر على أي صف لفتح التقرير الكامل للبلاطة • ${mode.shortLabelAr}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Slab')),
                      DataColumn(label: Text('Case')),
                      DataColumn(label: Text('Short Mid')),
                      DataColumn(label: Text('Short Sup')),
                      DataColumn(label: Text('Long Mid')),
                      DataColumn(label: Text('Long Sup')),
                      DataColumn(label: Text('الحالة')),
                    ],
                    rows: reports
                        .map(
                          (r) => DataRow(
                            onSelectChanged: (_) {
                              Navigator.pop(ctx);
                              _openSlabDesignReport(
                                  context, ref, r.slabId, mode);
                            },
                            cells: [
                              DataCell(
                                Text(
                                  r.slabId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.topology.twoWayCase != null
                                      ? 'C${r.topology.twoWayCase!.caseNumber}'
                                      : '1-Way',
                                ),
                              ),
                              DataCell(Text(r.summaryRow.shortMidLecture)),
                              DataCell(Text(r.summaryRow.shortSupportAllLecture())),
                              DataCell(Text(r.summaryRow.longMidLecture)),
                              DataCell(Text(r.summaryRow.longSupportAllLecture())),
                              DataCell(
                                Icon(
                                  r.overallIsSafe
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 18,
                                  color: r.overallIsSafe
                                      ? AppColors.safeGreen
                                      : AppColors.dangerRed,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// لوحة المفتش السفلية للخانة المحددة على المخطط
class _SelectedCellInspectorPanel extends StatelessWidget {
  final FloorGridPlan plan;
  final FloorSlabCell cell;
  final ResolvedTopology? topology;
  final ValueChanged<SlabCellType> onChangeType;
  final VoidCallback onEditDetails;
  final ValueChanged<EdgeSide> onToggleCantilever;
  final VoidCallback? onDesignPressed;

  const _SelectedCellInspectorPanel({
    required this.plan,
    required this.cell,
    required this.topology,
    required this.onChangeType,
    required this.onEditDetails,
    required this.onToggleCantilever,
    required this.onDesignPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wM = plan.widthOf(cell);
    final hM = plan.heightOf(cell);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصف الأول: عنوان الخانة + التصنيف + زر الخصائص
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withAlpha(25),
                  child: Text(
                    cell.id.length <= 3 ? cell.id : cell.id.substring(0, 2),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cell.id} (${wM.toStringAsFixed(2)} × ${hM.toStringAsFixed(2)} m)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        topology != null
                            ? (topology!.twoWayCase != null
                                ? 'Case ${topology!.twoWayCase!.caseNumber}: ${topology!.twoWayCase!.titleAr}'
                                : topology!.spanningType.titleAr)
                            : cell.cellType.titleAr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل خصائص الخانة',
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: onEditDetails,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // الصف الثاني: تبديل سريع لنوع الخانة
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...SlabCellType.values.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          _shortTypeLabel(t),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        selected: cell.cellType == t,
                        onSelected: (_) => onChangeType(t),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  if (cell.cellType.isDesignableSlab) ...[
                    const SizedBox(width: 4),
                    ...EdgeSide.values.map((side) {
                      final hasCant = cell.cantileverOn(side) != null;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text(
                            'كابولي ${_shortSideLabel(side)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: hasCant,
                          selectedColor: AppColors.safeGreen.withAlpha(40),
                          onSelected: (_) => onToggleCantilever(side),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            if (onDesignPressed != null) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: onDesignPressed,
                icon: const Icon(Icons.calculate_rounded),
                label: Text(
                  'صمّم البلاطة (${cell.id}) واعرض الحل الكامل',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortTypeLabel(SlabCellType t) {
    switch (t) {
      case SlabCellType.normalSolid:
        return 'بلاطة عادية';
      case SlabCellType.droppedSolid:
        return 'مهبطة (Dropped)';
      case SlabCellType.stairwellOrVoid:
        return 'درج / فتحة';
      case SlabCellType.exteriorEmpty:
        return 'فراغ';
    }
  }

  static String _shortSideLabel(EdgeSide s) {
    switch (s) {
      case EdgeSide.top:
        return 'أعلى';
      case EdgeSide.bottom:
        return 'أسفل';
      case EdgeSide.left:
        return 'يسار';
      case EdgeSide.right:
        return 'يمين';
    }
  }
}
