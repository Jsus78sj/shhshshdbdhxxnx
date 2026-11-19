import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/design_mode.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/mode_switcher_banner.dart';
import '../../../data/bs8110/flexure_tables.dart';
import '../../../domain/engine/engineering_engine.dart';
import '../../providers/single_slab_provider.dart';
import 'widgets/interactive_slab_edge_diagram.dart';
import 'widgets/neighbor_edge_editor_card.dart';

class SingleSlabScreen extends ConsumerStatefulWidget {
  const SingleSlabScreen({super.key});

  @override
  ConsumerState<SingleSlabScreen> createState() => _SingleSlabScreenState();
}

class _SingleSlabScreenState extends ConsumerState<SingleSlabScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _slabIdCtrl;
  late TextEditingController _widthXCtrl;
  late TextEditingController _heightYCtrl;
  late TextEditingController _loadNCtrl;
  late TextEditingController _gkCtrl;
  late TextEditingController _qkCtrl;
  late TextEditingController _depthHCtrl;
  late TextEditingController _coverCCtrl;
  late TextEditingController _fillDepthCtrl;
  late TextEditingController _fillWeightCtrl;
  late TextEditingController _addSupportMomCtrl;

  int _syncedRevision = -1;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(singleSlabFormProvider);
    _slabIdCtrl = TextEditingController();
    _widthXCtrl = TextEditingController();
    _heightYCtrl = TextEditingController();
    _loadNCtrl = TextEditingController();
    _gkCtrl = TextEditingController();
    _qkCtrl = TextEditingController();
    _depthHCtrl = TextEditingController();
    _coverCCtrl = TextEditingController();
    _fillDepthCtrl = TextEditingController();
    _fillWeightCtrl = TextEditingController();
    _addSupportMomCtrl = TextEditingController();
    _syncControllersFromState(initial);
  }

  void _syncControllersFromState(SingleSlabFormState s) {
    _syncedRevision = s.presetRevision;
    _slabIdCtrl.text = s.slabId;
    _widthXCtrl.text = s.widthXM.toStringAsFixed(2);
    _heightYCtrl.text = s.heightYM.toStringAsFixed(2);
    _loadNCtrl.text = s.designLoadN.toStringAsFixed(2);
    _gkCtrl.text = s.characteristicDeadGk.toStringAsFixed(2);
    _qkCtrl.text = s.characteristicImposedQk.toStringAsFixed(2);
    _depthHCtrl.text = s.overallDepthH.toStringAsFixed(0);
    _coverCCtrl.text = s.clearCoverC.toStringAsFixed(0);
    _fillDepthCtrl.text = s.fillDepthM.toStringAsFixed(2);
    _fillWeightCtrl.text = s.fillUnitWeightKnM3.toStringAsFixed(1);
    _addSupportMomCtrl.text = s.additionalSupportMomentKnM.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _slabIdCtrl.dispose();
    _widthXCtrl.dispose();
    _heightYCtrl.dispose();
    _loadNCtrl.dispose();
    _gkCtrl.dispose();
    _qkCtrl.dispose();
    _depthHCtrl.dispose();
    _coverCCtrl.dispose();
    _fillDepthCtrl.dispose();
    _fillWeightCtrl.dispose();
    _addSupportMomCtrl.dispose();
    super.dispose();
  }

  void _onCalculatePressed() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final mode = ref.read(designModeProvider);
    final notifier = ref.read(singleSlabFormProvider.notifier);

    try {
      final report = notifier.runDesign(mode);
      ref.read(activeReportProvider.notifier).setReport(
            ActiveReportContext(
              report: report,
              sourceLabelAr: 'وضع الإدخال السريع (بلاطة + جيرانها)',
              recompute: (newMode, {bool autoAdjustDepth = false}) {
                return ref.read(singleSlabFormProvider.notifier).runDesign(
                      newMode,
                      overrideAutoAdjust: autoAdjustDepth,
                    );
              },
            ),
          );
      context.push(AppRoutes.slabReport);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر إتمام الحساب: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(singleSlabFormProvider);
    final notifier = ref.read(singleSlabFormProvider.notifier);
    final activeMode = ref.watch(designModeProvider);
    final theme = Theme.of(context);

    if (_syncedRevision != formState.presetRevision) {
      _syncControllersFromState(formState);
    }

    final previewTopology = formState.tryResolvePreviewTopology();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصميم بلاطة واحدة + جيرانها'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            // شريط القوالب السريعة للتجربة الفورية
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.quiz_rounded, size: 18),
                    label: const Text('مثال الاختبار S7'),
                    onPressed: notifier.loadExamPresetS7,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.balcony_rounded, size: 18),
                    label: const Text('مثال S6 (مع كابولي)'),
                    onPressed: notifier.loadExamPresetS6WithCantilever,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('بلاطة جديدة'),
                    onPressed: notifier.resetToSimplePanel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // مفتاح تبديل وضع الحساب
            const ModeSwitcherBanner(),
            const SizedBox(height: 16),

            // القسم 1: أبعاد البلاطة ونوعها
            _SectionHeader(
              number: '1',
              title: 'أبعاد البلاطة ونوعها',
              subtitle: 'أدخل البعد الأفقي (X) والبعد الرأسي (Y) بالمتر',
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _slabIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رمز البلاطة',
                            hintText: 'S7',
                          ),
                          onChanged: notifier.updateSlabId,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _widthXCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'البعد الأفقي X',
                            suffixText: 'm',
                          ),
                          validator: _positiveDoubleValidator,
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              notifier.updateWidthX(parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _heightYCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'البعد الرأسي Y',
                            suffixText: 'm',
                          ),
                          validator: _positiveDoubleValidator,
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              notifier.updateHeightY(parsed);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<SlabCellType>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<SlabCellType>(
                        value: SlabCellType.normalSolid,
                        label: Text('بلاطة مصمتة عادية'),
                        icon: Icon(Icons.crop_square_rounded, size: 18),
                      ),
                      ButtonSegment<SlabCellType>(
                        value: SlabCellType.droppedSolid,
                        label: Text('بلاطة مهبطة (Dropped)'),
                        icon: Icon(Icons.layers_rounded, size: 18),
                      ),
                    ],
                    selected: {formState.cellType},
                    onSelectionChanged: (sel) {
                      if (sel.isNotEmpty) {
                        notifier.updateCellType(sel.first);
                      }
                    },
                  ),
                  if (formState.cellType == SlabCellType.droppedSolid) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fillDepthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'سماكة الردم (m)',
                              hintText: '0.20',
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v);
                              if (p != null && p >= 0) {
                                notifier.updateFillDepth(p);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _fillWeightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'كثافة الردم (kN/m³)',
                              hintText: '18.5',
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v);
                              if (p != null && p > 0) {
                                notifier.updateFillUnitWeight(p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // القسم 2: الرسم التفاعلي لحالات الحواف الأربع
            _SectionHeader(
              number: '2',
              title: 'شروط استناد الحواف الأربع',
              subtitle:
                  'تُفتح حقول البلاطة المجاورة أو الكابولي تلقائياً للحواف المستمرة',
            ),
            const SizedBox(height: 10),

            InteractiveSlabEdgeDiagram(
              slabId: formState.slabId,
              widthXM: formState.widthXM,
              heightYM: formState.heightYM,
              cellType: formState.cellType,
              topEdge: formState.topEdge,
              bottomEdge: formState.bottomEdge,
              leftEdge: formState.leftEdge,
              rightEdge: formState.rightEdge,
              previewTopology: previewTopology,
              onEdgeChanged: notifier.updateEdgeCondition,
            ),
            const SizedBox(height: 14),

            // بطاقات الجيران والكوابيل الديناميكية
            ...EdgeSide.values.expand((side) {
              final cond = formState.edgeFor(side);
              if (cond == EdgeCondition.continuous &&
                  formState.neighborFor(side) != null) {
                return [
                  NeighborEditorCard(
                    key: ValueKey('neighbor_${side.name}'),
                    side: side,
                    neighbor: formState.neighborFor(side)!,
                    revision: formState.presetRevision,
                    onChanged: (n) => notifier.updateNeighbor(side, n),
                  ),
                ];
              }
              if (cond == EdgeCondition.cantilever &&
                  formState.cantileverFor(side) != null) {
                return [
                  CantileverEditorCard(
                    key: ValueKey('cant_${side.name}'),
                    side: side,
                    cantilever: formState.cantileverFor(side)!,
                    fallbackLoadN: formState.effectiveDesignLoadN,
                    revision: formState.presetRevision,
                    onChanged: (c) => notifier.updateCantilever(side, c),
                    momentSource: formState.cantileverMomentSource,
                    givenMomentKnM: formState.additionalSupportMomentKnM,
                    onMomentSourceChanged: notifier.updateCantileverMomentSource,
                  ),
                ];
              }
              return const <Widget>[];
            }),
            const SizedBox(height: 8),

            // القسم 3: المعطيات التصميمية والأحمال والمواد
            _SectionHeader(
              number: '3',
              title: 'الأحمال وخصائص القطاع والمواد',
              subtitle: 'معطيات الخرسانة والحديد والغطاء الخرساني وفق BS 8110',
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('إدخال n مباشرة'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('حساب 1.4 Gk + 1.6 Qk'),
                      ),
                    ],
                    selected: {formState.useDirectLoadN},
                    onSelectionChanged: (sel) {
                      if (sel.isNotEmpty) {
                        notifier.updateUseDirectLoad(sel.first);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  if (formState.useDirectLoadN)
                    TextFormField(
                      controller: _loadNCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'الحمل التصميمي الأقصى (n)',
                        suffixText: 'kN/m²',
                      ),
                      validator: _positiveDoubleValidator,
                      onChanged: (v) {
                        final p = double.tryParse(v);
                        if (p != null && p > 0) notifier.updateDesignLoadN(p);
                      },
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gkCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الحمل الميت Gk',
                                  suffixText: 'kN/m²',
                                ),
                                validator: _positiveDoubleValidator,
                                onChanged: (v) {
                                  final p = double.tryParse(v);
                                  if (p != null && p > 0) notifier.updateGk(p);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _qkCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الحمل الحي Qk',
                                  suffixText: 'kN/m²',
                                ),
                                validator: _nonNegativeDoubleValidator,
                                onChanged: (v) {
                                  final p = double.tryParse(v);
                                  if (p != null && p >= 0) notifier.updateQk(p);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الحمل المصعّد المحسوب: n = ${formState.effectiveDesignLoadN.toStringAsFixed(2)} kN/m²',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _depthHCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'السماكة الكلية h',
                            suffixText: 'mm',
                          ),
                          validator: _positiveDoubleValidator,
                          onChanged: (v) {
                            final p = double.tryParse(v);
                            if (p != null && p >= 60) {
                              notifier.updateOverallDepthH(p);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _coverCCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'الغطاء الصافي c',
                            suffixText: 'mm',
                          ),
                          validator: _positiveDoubleValidator,
                          onChanged: (v) {
                            final p = double.tryParse(v);
                            if (p != null && p >= 10) {
                              notifier.updateClearCoverC(p);
                            }
                          },
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
                          value: formState.barDiameterPhi,
                          decoration: const InputDecoration(
                            labelText: 'قطر الحديد Ø',
                          ),
                          items: const [8, 10, 12, 14, 16]
                              .map(
                                (d) => DropdownMenuItem<int>(
                                  value: d,
                                  child: Text('Ø$d mm'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) notifier.updateBarDiameter(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          // value يتحكم به الـ state؛ initialValue لا يتحدّث بعد أول بناء.
                          // ignore: deprecated_member_use
                          value: formState.fcu,
                          decoration: const InputDecoration(
                            labelText: 'fcu (N/mm²)',
                          ),
                          items: FlexureTables.supportedFcuGrades
                              .map(
                                (g) => DropdownMenuItem<int>(
                                  value: g,
                                  child: Text('$g'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) notifier.updateFcu(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          // value يتحكم به الـ state؛ initialValue لا يتحدّث بعد أول بناء.
                          // ignore: deprecated_member_use
                          value: formState.fy,
                          decoration: const InputDecoration(
                            labelText: 'fy (N/mm²)',
                          ),
                          items: const [250.0, 460.0]
                              .map(
                                (y) => DropdownMenuItem<double>(
                                  value: y,
                                  child: Text(y.toStringAsFixed(0)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) notifier.updateFy(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // خيارات متقدمة مطوية
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'خيارات متقدمة (عزم مسند إضافي / تعديل السماكة التلقائي)',
                      style: theme.textTheme.labelLarge,
                    ),
                    children: [
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addSupportMomCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'عزم مسند أدنى إضافي (مثل 1 kN.m/m)',
                          suffixText: 'kN.m/m',
                        ),
                        onChanged: (v) {
                          final p = double.tryParse(v);
                          if (p != null && p >= 0) {
                            notifier.updateAdditionalSupportMoment(p);
                          }
                        },
                      ),
                      if (activeMode == DesignCalculationMode.strictBs8110)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                              'زيادة السماكة تلقائياً إذا فشل فحص الهطول'),
                          subtitle: const Text(
                              'يُحدّث الوزن الذاتي ويعيد الحساب بالسماكة الآمنة في الوضع الصارم'),
                          value: formState.autoAdjustDepthInStrictMode,
                          onChanged: notifier.updateAutoAdjustDepth,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: ElevatedButton.icon(
            onPressed: _onCalculatePressed,
            icon: const Icon(Icons.calculate_rounded),
            label: Text(
              'احسب وصمّم البلاطة (${formState.slabId.trim().isEmpty ? "S1" : formState.slabId.trim()})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  String? _positiveDoubleValidator(String? val) {
    final parsed = double.tryParse(val?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'أدخل قيمة موجبة';
    }
    return null;
  }

  String? _nonNegativeDoubleValidator(String? val) {
    final parsed = double.tryParse(val?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'أدخل قيمة >= 0';
    }
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          child: Text(
            number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
