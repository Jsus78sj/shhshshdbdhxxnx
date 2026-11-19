import '../../core/constants/design_mode.dart';
import '../../domain/models/slab_enums.dart';
import '../../domain/models/slab_geometry_models.dart';
import '../../domain/models/slab_project_settings.dart';

/// قالب المخطط الإنشائي الكامل لسؤال اختبار جامعة عدن (S0 إلى S9 + البلاطة المهبطة + الدرج + الكوابيل)
class ExamFloorPlanTemplate {
  ExamFloorPlanTemplate._();

  /// [additionalSupportMomentKnM] و [cantileverMomentSource]: ملاحظة المخطط في ورقة الاختبار
  /// «The support B.M. of all Solid Slabs (Cantilevers) = 1 kN.m/m» تعطي عزم مسند الكوابيل،
  /// والسؤال ينص على أخذ هذه القيمة عند موازنة العزوم مع الكابولي؛ لذلك القالب يعتمدها افتراضياً
  /// (عزم الكابولي = 1 kN.m/m). للعودة إلى العزم الستاتيكي n·l²/2 مرّر
  /// `cantileverMomentSource: CantileverMomentSource.statics`.
  static FloorGridPlan buildUniversityOfAdenExamPlan({
    DesignCalculationMode mode = DesignCalculationMode.lectureMode,
    double additionalSupportMomentKnM = 1.0,
    CantileverMomentSource cantileverMomentSource =
        CantileverMomentSource.givenSupportMoment,
  }) {
    final settings = SlabProjectSettings(
      designLoadN: 11.50,
      overallDepthH: 120.0,
      clearCoverC: 25.0,
      barDiameterPhi: 10.0,
      fcu: 25.0,
      fy: 250.0,
      calculationMode: mode,
    );

    return FloorGridPlan(
      projectId: 'aden_exam_2026_2027',
      projectName: 'مخطط اختبار الخرسانة المسلحة II — جامعة عدن',
      xSpansM: const [4.10, 3.70, 4.10],
      ySpansM: const [4.20, 4.20, 4.40, 4.00],
      settings: settings,
      additionalSupportMomentKnM: additionalSupportMomentKnM,
      cantileverMomentSource: cantileverMomentSource,
      cells: const [
        // الصف 0 (العلوي): S6 | S4 | S0
        FloorSlabCell(
          row: 0,
          col: 0,
          id: 'S6',
          label: 'S6',
          cellType: SlabCellType.normalSolid,
          cantilevers: [
            CantileverAttachment(
              side: EdgeSide.left,
              lengthM: 1.60,
              label: 'Left Cantilever (S6)',
            ),
          ],
        ),
        FloorSlabCell(
          row: 0,
          col: 1,
          id: 'S4',
          label: 'S4',
          cellType: SlabCellType.normalSolid,
        ),
        FloorSlabCell(
          row: 0,
          col: 2,
          id: 'S0',
          label: 'S0',
          cellType: SlabCellType.normalSolid,
        ),

        // الصف 1: S7 | Dropped Solid Slab | S1 (+ Right Cantilever 1.60m)
        FloorSlabCell(
          row: 1,
          col: 0,
          id: 'S7',
          label: 'S7',
          cellType: SlabCellType.normalSolid,
        ),
        FloorSlabCell(
          row: 1,
          col: 1,
          id: 'Dropped',
          label: 'Dropped Solid Slab',
          cellType: SlabCellType.droppedSolid,
          // نص الاختبار لا يذكر ردماً للبلاطة المهبطة (0.20 م × 18.5 كانت من مثال السبورة)،
          // لذلك يبدأ الردم صفراً ويُدخله المستخدم يدوياً إن أراده.
        ),
        FloorSlabCell(
          row: 1,
          col: 2,
          id: 'S1',
          label: 'S1',
          cellType: SlabCellType.normalSolid,
          cantilevers: [
            CantileverAttachment(
              side: EdgeSide.right,
              lengthM: 1.60,
              label: 'Right Cantilever (S1)',
            ),
          ],
        ),

        // الصف 2: S8 | S5 | S2 (+ Right Cantilever 1.60m)
        FloorSlabCell(
          row: 2,
          col: 0,
          id: 'S8',
          label: 'S8',
          cellType: SlabCellType.normalSolid,
        ),
        FloorSlabCell(
          row: 2,
          col: 1,
          id: 'S5',
          label: 'S5',
          cellType: SlabCellType.normalSolid,
        ),
        FloorSlabCell(
          row: 2,
          col: 2,
          id: 'S2',
          label: 'S2',
          cellType: SlabCellType.normalSolid,
          cantilevers: [
            CantileverAttachment(
              side: EdgeSide.right,
              lengthM: 1.60,
              label: 'Right Cantilever (S2)',
            ),
          ],
        ),

        // الصف 3 (السفلي): S9 (4.00m) | Stairwell | S3 (4.20m)
        FloorSlabCell(
          row: 3,
          col: 0,
          id: 'S9',
          label: 'S9',
          cellType: SlabCellType.normalSolid,
          overrideHeightYM: 4.00,
        ),
        FloorSlabCell(
          row: 3,
          col: 1,
          id: 'Stairwell',
          label: 'Staircase',
          cellType: SlabCellType.stairwellOrVoid,
        ),
        FloorSlabCell(
          row: 3,
          col: 2,
          id: 'S3',
          label: 'S3',
          cellType: SlabCellType.normalSolid,
          overrideHeightYM: 4.20,
        ),
      ],
    );
  }
}
