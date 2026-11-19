import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ltr_formula_box.dart';
import '../../../data/bs8110/bs8110_tables.dart';
import 'widgets/highlightable_code_table.dart';
import 'widgets/interpolation_calculator_sheet.dart';

/// شاشة عرض جدول أو قسم واحد من الكود BS 8110 بكامل قيمه ومعادلاته وملاحظاته
class CodeTableDetailScreen extends StatelessWidget {
  final CodeSectionMeta section;

  const CodeTableDetailScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.codeId,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              section.titleAr,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'حاسبة التناسب الخطي',
            icon: const Icon(Icons.calculate_rounded),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const InterpolationCalculatorSheet(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                Row(
                  children: [
                    Chip(
                      label: Text('صفحة ${section.pageNumber}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(section.categoryAr),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  section.titleEn,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'انقر على أي خلية داخل الجدول لتظليل صفّها وعمودها معاً بدقة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._buildBodyForCodeId(context, section.codeId),
        ],
      ),
    );
  }

  List<Widget> _buildBodyForCodeId(BuildContext context, String codeId) {
    switch (codeId) {
      case 'Table 1':
        return [
          HighlightableCodeTable(
            headers: const [
              'Ø (mm)',
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
              '10',
              'Perimeter',
            ],
            rows: ReinforcementTables.standardDiameters.map((d) {
              final areas = ReinforcementTables.table1AreasByCount[d]!;
              final p = ReinforcementTables.table1PerimetersMm[d]!;
              return [
                'Ø$d',
                ...areas.map((a) => a.toStringAsFixed(0)),
                p.toStringAsFixed(1),
              ];
            }).toList(),
            footnoteAr: 'المساحات بـ mm² والمحيط لسيخ واحد بـ mm.',
          ),
        ];

      case 'Table 2':
        return [
          HighlightableCodeTable(
            headers: [
              'Ø (mm)',
              ...ReinforcementTables.standardSpacingsMm.map((s) => '$s'),
            ],
            rows: ReinforcementTables.standardDiameters.map((d) {
              final areas = ReinforcementTables.table2AreasBySpacing[d]!;
              return ['Ø$d', ...areas.map((a) => a.toStringAsFixed(0))];
            }).toList(),
            footnoteAr: 'المساحات بـ mm² لكل متر عرض عند المسافات (75 إلى 300 mm).',
          ),
        ];

      case 'Table 3':
        return [
          _subHeading(context, 'الأحمال الحية للأسقف والمباني (kN/m²)'),
          HighlightableCodeTable(
            headers: const ['الوصف', 'القيمة', 'الوحدة'],
            rows: LoadsWeightsTable.imposedLoads
                .map((e) => ['${e.nameAr}\n(${e.nameEn})', e.value.toStringAsFixed(2), e.unit])
                .toList(),
          ),
          const SizedBox(height: 14),
          _subHeading(context, 'الأوزان السطحية للمواد والبلوك (kN/m²)'),
          HighlightableCodeTable(
            headers: const ['المادة', 'القيمة', 'الوحدة'],
            rows: LoadsWeightsTable.surfaceWeights
                .map((e) => ['${e.nameAr}\n(${e.nameEn})', e.value.toStringAsFixed(2), e.unit])
                .toList(),
          ),
          const SizedBox(height: 14),
          _subHeading(context, 'الكثافات الوزنية للمواد (kN/m³)'),
          HighlightableCodeTable(
            headers: const ['المادة', 'القيمة', 'الوحدة'],
            rows: LoadsWeightsTable.unitWeights
                .map((e) => ['${e.nameAr}\n(${e.nameEn})', e.value.toStringAsFixed(2), e.unit])
                .toList(),
          ),
        ];

      case 'Table 4':
        return [
          HighlightableCodeTable(
            headers: [
              'المعامل',
              ...FlexureTables.supportedFcuGrades.map((g) => 'fcu=$g'),
            ],
            rows: [
              [
                'Ky',
                ...FlexureTables.supportedFcuGrades.map(
                  (g) => FlexureTables.table4Singly[g]!.ky.toStringAsFixed(3),
                ),
              ],
              [
                'Kz',
                ...FlexureTables.supportedFcuGrades.map(
                  (g) => FlexureTables.table4Singly[g]!.kz.toStringAsFixed(3),
                ),
              ],
              [
                'Max M/bd²',
                ...FlexureTables.supportedFcuGrades.map(
                  (g) => FlexureTables.table4Singly[g]!
                      .maxMOverBd2
                      .toStringAsFixed(2),
                ),
              ],
              [
                'Limiting M/bd² (z=0.95d)',
                ...FlexureTables.supportedFcuGrades.map(
                  (g) => FlexureTables.table4Singly[g]!
                      .limitingMOverBd2
                      .toStringAsFixed(3),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'إذا كانت M/bd² أقل من أو تساوي القيمة الحدية:',
            tex: r'\frac{f_y A_s}{b d} = 1.108\,\frac{M}{b d^2}',
          ),
          const SizedBox(height: 10),
          const LtrFormulaBox(
            captionAr: 'إذا كانت M/bd² بين القيمة الحدية والقصوى:',
            tex: r'\frac{f_y A_s}{b d} = K_y - \sqrt{K_y^2 - K_z \frac{M}{b d^2}}',
          ),
        ];

      case 'Table 5':
        final rows = <List<String>>[];
        for (final xOverD in [0.3, 0.4, 0.5]) {
          final map = FlexureTables.table5Doubly[xOverD]!;
          rows.add([
            'x/d=$xOverD (Ko)',
            ...FlexureTables.supportedFcuGrades
                .map((g) => map[g]!.ko.toStringAsFixed(3)),
          ]);
          rows.add([
            'x/d=$xOverD (Kp)',
            ...FlexureTables.supportedFcuGrades
                .map((g) => map[g]!.kp.toStringAsFixed(3)),
          ]);
        }
        return [
          HighlightableCodeTable(
            headers: [
              'x/d & Coeff',
              ...FlexureTables.supportedFcuGrades.map((g) => 'fcu=$g'),
            ],
            rows: rows,
            footnoteAr:
                'حدود d\'/d القصوى: 0.3-(fy/2456) عند x/d=0.3 | 0.4-(fy/1842) عند x/d=0.4 | 0.5-(fy/1473) عند x/d=0.5.',
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'معادلات تسليح الضغط والشد في القطاعات مزدوجة التسليح:',
            tex:
                r'\frac{f_y A_{sc}}{bd} = \left(\frac{M}{bd^2} - K_o\right)\frac{1.05}{1 - d^\prime/d} \quad,\quad \frac{f_y A_{st}}{bd} = \frac{f_y A_{sc}}{bd} + K_p',
            fontSize: 13,
          ),
        ];

      case 'Table 3.25':
        return [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentAmber.withAlpha(110)),
            ),
            child: const Text(
              FlexureTables.table325TypoNoteAr,
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          HighlightableCodeTable(
            headers: const [
              'الحالة (Situation)',
              'التعريف',
              'fy = 250 (%)',
              'fy = 460 (%)',
            ],
            rows: FlexureTables.table325MinimumPercentages
                .map(
                  (e) => [
                    e.situationAr,
                    e.definitionFormula,
                    e.minPercentFy250.toStringAsFixed(2),
                    e.minPercentFy460.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
        ];

      case 'Table 3.9':
        return [
          HighlightableCodeTable(
            headers: const [
              'شرط الاستناد',
              'قطاع مستطيل (bw/b = 1)',
              'قطاع ذو شفة (bw/b ≤ 0.3)',
            ],
            rows: DeflectionTables.table39BasicRatios.entries
                .map(
                  (e) => [
                    e.key.labelAr,
                    e.value.rectangular.toStringAsFixed(1),
                    e.value.flanged.toStringAsFixed(1),
                  ],
                )
                .toList(),
            footnoteAr:
                'مبنية على تقييد الهطول الكلي بـ Span/250 وللقيم بين 0.3 و 1.0 يُستخدم التناسب الخطي.',
          ),
        ];

      case 'Table 3.10':
        return [
          HighlightableCodeTable(
            headers: [
              'fs (N/mm²)',
              ...DeflectionTables.table310MOverBd2Cols
                  .map((m) => m.toStringAsFixed(2)),
            ],
            rows: DeflectionTables.table310TensionFactors.entries
                .map(
                  (e) => [
                    e.key.toStringAsFixed(0),
                    ...e.value.map((v) => v.toStringAsFixed(2)),
                  ],
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'Equation 7 & Equation 8 (Table 3.10):',
            tex:
                r'M.F_t = 0.55 + \frac{477 - f_s}{120\left(0.9 + \frac{M}{bd^2}\right)} \le 2.0 \quad,\quad f_s = \frac{2 f_y A_{s,\mathrm{req}}}{3 A_{s,\mathrm{prov}}} \times \frac{1}{\beta_b}',
            fontSize: 13,
          ),
        ];

      case 'Table 3.11':
        return [
          HighlightableCodeTable(
            headers: const ['100 A\'s,prov / bd (%)', 'Factor'],
            rows: DeflectionTables.table311CompressionFactors.entries
                .map(
                  (e) => [
                    e.key.toStringAsFixed(2),
                    e.value.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'Note 1 — معادلة معامل التعديل لتسليح الضغط:',
            tex:
                r'M.F_c = 1 + \frac{100 A^\prime_{s,\mathrm{prov}} / bd}{3 + 100 A^\prime_{s,\mathrm{prov}} / bd} \le 1.5',
            fontSize: 13.5,
          ),
        ];

      case 'Table 3.7':
        return [
          HighlightableCodeTable(
            headers: const ['قيمة v (N/mm²)', 'شكل تسليح القص', 'المساحة المطلوبة'],
            rows: ShearTables.table37BeamShearRules
                .map((r) => [r.rangeEn, r.formEn, r.areaFormulaEn])
                .toList(),
          ),
        ];

      case 'Table 3.16':
        return [
          const HighlightableCodeTable(
            headers: ['قيمة v (N/mm²)', 'شكل تسليح القص', 'المساحة المطلوبة'],
            rows: [
              ['v < vc', 'None required', 'None'],
              [
                'vc < v < (vc + 0.4)',
                'Minimum links in areas where v > vc',
                'Asv ≥ 0.4 b sv / (0.95 fyv)',
              ],
              [
                '(vc + 0.4) < v < min(0.8√fcu, 5)',
                'Links and/or bent-up bars',
                'Asv ≥ b sv (v - vc) / (0.95 fyv)',
              ],
            ],
            footnoteAr:
                'Note 1: لا يُنصح باستخدام تسليح قص في البلاطات التي تقل سماكتها الكلية عن 200 mm.',
          ),
        ];

      case 'Table 3.8':
        return [
          HighlightableCodeTable(
            headers: [
              '100As / bvd',
              ...ShearTables.table38DepthColsMm.map((d) => 'd=$d'),
            ],
            rows: ShearTables.table38VcValues.entries
                .map(
                  (e) => [
                    e.key.toStringAsFixed(2),
                    ...e.value.map((v) => v.toStringAsFixed(2)),
                  ],
                )
                .toList(),
            footnoteAr:
                'لـ fcu > 25 N/mm² تُضرب القيم في (fcu/25)^(1/3) بحد أقصى fcu = 40 N/mm².',
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'Note 2 — المعادلة التحليلية لـ vc (مع γm = 1.25):',
            tex:
                r'v_c = \frac{0.79 \left(\frac{100 A_s}{b_v d}\right)^{1/3} \left(\frac{400}{d}\right)^{1/4}}{\gamma_m}',
          ),
        ];

      case 'Table 3.5':
        return [
          HighlightableCodeTable(
            headers: const ['الموقع', 'العزم (× Fl)', 'القص (× F)'],
            rows: ShearTables.table35ContinuousBeams.entries
                .map(
                  (e) => [
                    e.key,
                    e.value.momentCoeff.toStringAsFixed(2),
                    e.value.shearCoeff?.toStringAsFixed(2) ?? '—',
                  ],
                )
                .toList(),
            footnoteAr: 'F = 1.4 Gk + 1.6 Qk. صالحة لثلاثة بحور فأكثر (تفاوت ≤ 15% و Qk ≤ Gk).',
          ),
        ];

      case 'Table 3.12':
        return [
          HighlightableCodeTable(
            headers: const ['الموقع في البلاطة ذات الاتجاه الواحد', 'العزم (× Fl)', 'القص (× F)'],
            rows: SlabMomentShearTables.table312OneWaySlab.entries
                .map(
                  (e) => [
                    e.key,
                    e.value.momentCoeff.toStringAsFixed(3),
                    e.value.shearCoeff?.toStringAsFixed(2) ?? '—',
                  ],
                )
                .toList(),
          ),
        ];

      case 'Table 3.14':
        final rows = <List<String>>[];
        for (final entry in SlabMomentShearTables.table314.entries) {
          final r = entry.value;
          final cNum = entry.key.caseNumber;
          if (r.betaSxNegative != null || r.betaSyNegative != null) {
            rows.add([
              'C$cNum — سالب (-)',
              ...SlabMomentShearTables.aspectRatioColumns.map(
                (col) => r.betaSxNegative?[col]?.toStringAsFixed(3) ?? '—',
              ),
              r.betaSyNegative?.toStringAsFixed(3) ?? '—',
            ]);
          }
          rows.add([
            'C$cNum — موجب (+)',
            ...SlabMomentShearTables.aspectRatioColumns.map(
              (col) => r.betaSxPositive[col]!.toStringAsFixed(3),
            ),
            r.betaSyPositive.toStringAsFixed(3),
          ]);
        }
        return [
          HighlightableCodeTable(
            headers: [
              'الحالة (Case)',
              ...SlabMomentShearTables.aspectRatioColumns
                  .map((v) => v.toString()),
              'βsy',
            ],
            rows: rows,
            footnoteAr: 'جميع المعاملات تُضرب في n · lx² لحساب عزوم الاتجاهين.',
          ),
        ];

      case 'Table 3.15':
        final rows = <List<String>>[];
        for (final entry in SlabMomentShearTables.table315.entries) {
          final r = entry.value;
          final cNum = entry.key.caseNumber;
          if (r.betaVxContinuous != null || r.betaVyContinuous != null) {
            rows.add([
              'C$cNum — مستمرة',
              ...SlabMomentShearTables.aspectRatioColumns.map(
                (col) => r.betaVxContinuous?[col]?.toStringAsFixed(2) ?? '—',
              ),
              r.betaVyContinuous?.toStringAsFixed(2) ?? '—',
            ]);
          }
          if (r.betaVxDiscontinuous != null || r.betaVyDiscontinuous != null) {
            rows.add([
              'C$cNum — غير مستمرة',
              ...SlabMomentShearTables.aspectRatioColumns.map(
                (col) => r.betaVxDiscontinuous?[col]?.toStringAsFixed(2) ?? '—',
              ),
              r.betaVyDiscontinuous?.toStringAsFixed(2) ?? '—',
            ]);
          }
        }
        return [
          HighlightableCodeTable(
            headers: [
              'الحالة والحافة',
              ...SlabMomentShearTables.aspectRatioColumns
                  .map((v) => v.toString()),
              'βvy',
            ],
            rows: rows,
            footnoteAr: 'قوة القص التصميمية: V = βv · n · lx.',
          ),
        ];

      case 'Columns (le)':
        return const [
          LtrFormulaBox(
            captionAr: '1) الأعمدة المقيدة (Braced Columns) — الأصغر من:',
            tex:
                r'l_e = l_o \{0.7 + 0.05(\alpha_{c,1} + \alpha_{c,2})\} \le l_o \quad,\quad l_e = l_o \{0.85 + 0.05\,\alpha_{c,\min}\} \le l_o',
            fontSize: 13,
          ),
          SizedBox(height: 10),
          LtrFormulaBox(
            captionAr: '2) الأعمدة غير المقيدة (Unbraced Columns) — الأصغر من:',
            tex:
                r'l_e = l_o \{1.0 + 0.15(\alpha_{c,1} + \alpha_{c,2})\} \quad,\quad l_e = l_o \{2.0 + 0.3\,\alpha_{c,\min}\}',
            fontSize: 13,
          ),
        ];

      case 'Table 2 (Col)':
        return [
          HighlightableCodeTable(
            headers: [
              'N / (b h fcu)',
              ...ColumnTables.table2BiaxialBeta.keys
                  .map((k) => k == 0.6 ? '≥ 0.6' : k.toStringAsFixed(1)),
            ],
            rows: [
              [
                'β',
                ...ColumnTables.table2BiaxialBeta.values
                    .map((v) => v.toStringAsFixed(2)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const LtrFormulaBox(
            captionAr: 'معادلة β وتحويل العزوم ثنائية المحور:',
            tex:
                r'\beta = 1 - \frac{7N}{6 b h f_{cu}} \ge 0.30 \quad,\quad M_x^\prime = M_x + \beta\frac{h^\prime}{b^\prime}M_y',
            fontSize: 13.5,
          ),
        ];

      default:
        return [const Text('لا توجد بيانات إضافية لهذا القسم.')];
    }
  }

  Widget _subHeading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
