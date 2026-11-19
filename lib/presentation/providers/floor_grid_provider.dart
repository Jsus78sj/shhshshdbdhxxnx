import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/design_mode.dart';
import '../../data/repositories/projects_repository.dart';
import '../../data/templates/exam_floor_plan_template.dart';
import '../../domain/engine/engineering_engine.dart';

/// مزوّد قائمة المشاريع المحفوظة محلياً (مرتبط بـ Hive ويتحدّث فورياً في كل الشاشات)
class SavedProjectsNotifier extends Notifier<List<SavedFloorProjectRecord>> {
  @override
  List<SavedFloorProjectRecord> build() {
    return ProjectsRepository.loadAllProjects();
  }

  void refresh() {
    state = ProjectsRepository.loadAllProjects();
  }

  Future<SavedFloorProjectRecord> save(FloorGridPlan plan) async {
    final saved = await ProjectsRepository.saveProject(plan);
    refresh();
    return saved;
  }

  Future<void> delete(String projectId) async {
    await ProjectsRepository.deleteProject(projectId);
    refresh();
  }

  Future<void> rename(String projectId, String newName) async {
    if (newName.trim().isEmpty) return;
    await ProjectsRepository.renameProject(
      projectId: projectId,
      newName: newName.trim(),
    );
    refresh();
  }

  Future<SavedFloorProjectRecord?> duplicate(String projectId) async {
    final copy = await ProjectsRepository.duplicateProject(projectId);
    refresh();
    return copy;
  }
}

final savedProjectsProvider =
    NotifierProvider<SavedProjectsNotifier, List<SavedFloorProjectRecord>>(
  SavedProjectsNotifier.new,
);

/// حالة محرر المخطط الشبكي الكامل للسقف
class FloorGridEditorState {
  final FloorGridPlan plan;
  final int selectedRow;
  final int selectedCol;
  final String? highlightedSlabId;
  final bool hasUnsavedChanges;

  const FloorGridEditorState({
    required this.plan,
    this.selectedRow = 1,
    this.selectedCol = 0,
    this.highlightedSlabId,
    this.hasUnsavedChanges = false,
  });

  FloorSlabCell? get selectedCell => plan.cellAt(selectedRow, selectedCol);

  ResolvedTopology? get selectedTopology {
    final cell = selectedCell;
    if (cell == null || !cell.cellType.isDesignableSlab) return null;
    return TopologyResolver.resolveFromFloorGrid(plan: plan, cell: cell);
  }

  FloorGridEditorState copyWith({
    FloorGridPlan? plan,
    int? selectedRow,
    int? selectedCol,
    String? highlightedSlabId,
    bool clearHighlight = false,
    bool? hasUnsavedChanges,
  }) {
    return FloorGridEditorState(
      plan: plan ?? this.plan,
      selectedRow: selectedRow ?? this.selectedRow,
      selectedCol: selectedCol ?? this.selectedCol,
      highlightedSlabId: clearHighlight
          ? null
          : (highlightedSlabId ?? this.highlightedSlabId),
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

/// متحكم محرر المخطط الشبكي الكامل للسقف
class FloorGridEditorNotifier extends Notifier<FloorGridEditorState> {
  @override
  FloorGridEditorState build() {
    // يفتح افتراضياً على مخطط اختبار جامعة عدن (S0 إلى S9) مع تحديد البلاطة S7
    final examPlan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan();
    return FloorGridEditorState(
      plan: examPlan,
      selectedRow: 1,
      selectedCol: 0,
      hasUnsavedChanges: false,
    );
  }

  void loadPlan(FloorGridPlan plan, {bool markUnsaved = false}) {
    // اختيار أول بلاطة قابلة للتصميم أو (0,0)
    int selR = 0;
    int selC = 0;
    for (final c in plan.cells) {
      if (c.cellType.isDesignableSlab) {
        selR = c.row;
        selC = c.col;
        break;
      }
    }
    state = FloorGridEditorState(
      plan: plan,
      selectedRow: selR,
      selectedCol: selC,
      highlightedSlabId: null,
      hasUnsavedChanges: markUnsaved,
    );
  }

  void loadUniversityExamTemplate() {
    final examPlan = ExamFloorPlanTemplate.buildUniversityOfAdenExamPlan();
    state = FloorGridEditorState(
      plan: examPlan,
      selectedRow: 1,
      selectedCol: 0,
      highlightedSlabId: null,
      hasUnsavedChanges: false,
    );
  }

  void createNewBlankPlan({
    int rows = 3,
    int cols = 3,
    double defaultSpanX = 4.00,
    double defaultSpanY = 4.20,
    String projectName = 'مخطط سقف جديد',
  }) {
    final xSpans = List<double>.filled(cols, defaultSpanX);
    final ySpans = List<double>.filled(rows, defaultSpanY);
    final cells = <FloorSlabCell>[];
    int idx = 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final id = 'S$idx';
        cells.add(
          FloorSlabCell(
            row: r,
            col: c,
            id: id,
            label: id,
            cellType: SlabCellType.normalSolid,
          ),
        );
        idx++;
      }
    }

    final newPlan = FloorGridPlan(
      projectId: 'proj_${DateTime.now().microsecondsSinceEpoch}',
      projectName: projectName,
      xSpansM: xSpans,
      ySpansM: ySpans,
      cells: cells,
      settings: state.plan.settings,
    );

    state = FloorGridEditorState(
      plan: newPlan,
      selectedRow: 0,
      selectedCol: 0,
      highlightedSlabId: null,
      hasUnsavedChanges: true,
    );
  }

  void selectCell(int row, int col) {
    if (row < 0 ||
        row >= state.plan.rowsCount ||
        col < 0 ||
        col >= state.plan.colsCount) {
      return;
    }
    state = state.copyWith(selectedRow: row, selectedCol: col);
  }

  void updateProjectName(String name) {
    if (name.trim().isEmpty) return;
    state = state.copyWith(
      plan: state.plan.copyWith(projectName: name.trim()),
      hasUnsavedChanges: true,
    );
  }

  void updateSettings(
    SlabProjectSettings newSettings, {
    double? additionalSupportMomentKnM,
    CantileverMomentSource? cantileverMomentSource,
  }) {
    state = state.copyWith(
      plan: state.plan.copyWith(
        settings: newSettings,
        additionalSupportMomentKnM: additionalSupportMomentKnM ??
            state.plan.additionalSupportMomentKnM,
        cantileverMomentSource:
            cantileverMomentSource ?? state.plan.cantileverMomentSource,
      ),
      hasUnsavedChanges: true,
    );
  }

  void updateColumnSpan(int col, double spanM) {
    if (col < 0 || col >= state.plan.colsCount || spanM <= 0) return;
    final nextX = List<double>.from(state.plan.xSpansM);
    nextX[col] = spanM;
    state = state.copyWith(
      plan: state.plan.copyWith(xSpansM: nextX),
      hasUnsavedChanges: true,
    );
  }

  void updateRowSpan(int row, double spanM) {
    if (row < 0 || row >= state.plan.rowsCount || spanM <= 0) return;
    final nextY = List<double>.from(state.plan.ySpansM);
    nextY[row] = spanM;
    state = state.copyWith(
      plan: state.plan.copyWith(ySpansM: nextY),
      hasUnsavedChanges: true,
    );
  }

  /// معرّف 'S<n>' غير مستعمل في أي خانة أخرى (يتفادى التكرار بعد حذف/إضافة صفوف وأعمدة).
  static String _uniqueSlabId(Iterable<FloorSlabCell> cells, int preferred) {
    final used = cells.map((c) => c.id).toSet();
    int n = preferred < 1 ? 1 : preferred;
    while (used.contains('S$n')) {
      n++;
    }
    return 'S$n';
  }

  void addColumn({double spanM = 4.00}) {
    if (state.plan.colsCount >= 8) return;
    final newCol = state.plan.colsCount;
    final nextX = [...state.plan.xSpansM, spanM];
    final nextCells = List<FloorSlabCell>.from(state.plan.cells);

    for (int r = 0; r < state.plan.rowsCount; r++) {
      final id = _uniqueSlabId(nextCells, nextCells.length + 1);
      nextCells.add(
        FloorSlabCell(
          row: r,
          col: newCol,
          id: id,
          label: id,
          cellType: SlabCellType.normalSolid,
        ),
      );
    }

    state = state.copyWith(
      plan: state.plan.copyWith(xSpansM: nextX, cells: nextCells),
      hasUnsavedChanges: true,
    );
  }

  void removeLastColumn() {
    if (state.plan.colsCount <= 1) return;
    final removeCol = state.plan.colsCount - 1;
    final nextX = state.plan.xSpansM.sublist(0, removeCol);
    final nextCells =
        state.plan.cells.where((c) => c.col != removeCol).toList();
    final safeCol = state.selectedCol >= nextX.length
        ? nextX.length - 1
        : state.selectedCol;

    state = state.copyWith(
      plan: state.plan.copyWith(xSpansM: nextX, cells: nextCells),
      selectedCol: safeCol,
      hasUnsavedChanges: true,
    );
  }

  void addRow({double spanM = 4.20}) {
    if (state.plan.rowsCount >= 8) return;
    final newRow = state.plan.rowsCount;
    final nextY = [...state.plan.ySpansM, spanM];
    final nextCells = List<FloorSlabCell>.from(state.plan.cells);

    for (int c = 0; c < state.plan.colsCount; c++) {
      final id = _uniqueSlabId(nextCells, nextCells.length + 1);
      nextCells.add(
        FloorSlabCell(
          row: newRow,
          col: c,
          id: id,
          label: id,
          cellType: SlabCellType.normalSolid,
        ),
      );
    }

    state = state.copyWith(
      plan: state.plan.copyWith(ySpansM: nextY, cells: nextCells),
      hasUnsavedChanges: true,
    );
  }

  void removeLastRow() {
    if (state.plan.rowsCount <= 1) return;
    final removeRow = state.plan.rowsCount - 1;
    final nextY = state.plan.ySpansM.sublist(0, removeRow);
    final nextCells =
        state.plan.cells.where((c) => c.row != removeRow).toList();
    final safeRow = state.selectedRow >= nextY.length
        ? nextY.length - 1
        : state.selectedRow;

    state = state.copyWith(
      plan: state.plan.copyWith(ySpansM: nextY, cells: nextCells),
      selectedRow: safeRow,
      hasUnsavedChanges: true,
    );
  }

  void updateCellType(int row, int col, SlabCellType newType) {
    final target = state.plan.cellAt(row, col);
    if (target == null) return;

    String newId = target.id;
    String newLabel = target.label;
    double fillDepth = target.fillDepthM;

    if (newType == SlabCellType.droppedSolid) {
      if (target.cellType != SlabCellType.droppedSolid) {
        newLabel = 'Dropped Solid Slab';
        // لا نفترض ردماً: الردم يُدخله المستخدم من خصائص الخانة إن كان في السؤال
        fillDepth = target.fillDepthM;
      }
    } else if (newType == SlabCellType.stairwellOrVoid) {
      newId = 'Stair_${row}_$col';
      newLabel = 'Staircase';
    } else if (newType == SlabCellType.exteriorEmpty) {
      newId = 'Void_${row}_$col';
      newLabel = 'فراغ';
    } else if (newType == SlabCellType.normalSolid &&
        !target.cellType.isDesignableSlab) {
      newId = _uniqueSlabId(
        state.plan.cells.where((c) => !(c.row == row && c.col == col)),
        row * state.plan.colsCount + col + 1,
      );
      newLabel = newId;
    }

    final updated = target.copyWith(
      id: newId,
      label: newLabel,
      cellType: newType,
      fillDepthM: fillDepth,
      cantilevers:
          newType.isDesignableSlab ? target.cantilevers : const [],
    );

    _replaceCell(updated);
  }

  void updateCellProperties({
    required int row,
    required int col,
    required String id,
    required String label,
    double? overrideWidthXM,
    bool clearOverrideWidthX = false,
    double? overrideHeightYM,
    bool clearOverrideHeightY = false,
    double? customDesignLoadN,
    bool clearCustomDesignLoad = false,
    double? fillDepthM,
    double? fillUnitWeightKnM3,
  }) {
    final target = state.plan.cellAt(row, col);
    if (target == null) return;

    final updated = target.copyWith(
      id: id.trim().isEmpty ? target.id : id.trim(),
      label: label.trim().isEmpty ? target.label : label.trim(),
      overrideWidthXM: overrideWidthXM,
      clearOverrideWidthX: clearOverrideWidthX,
      overrideHeightYM: overrideHeightYM,
      clearOverrideHeightY: clearOverrideHeightY,
      customDesignLoadN: customDesignLoadN,
      clearCustomDesignLoad: clearCustomDesignLoad,
      fillDepthM: fillDepthM,
      fillUnitWeightKnM3: fillUnitWeightKnM3,
    );
    _replaceCell(updated);
  }

  void toggleCantilever({
    required int row,
    required int col,
    required EdgeSide side,
    double defaultLengthM = 1.60,
  }) {
    final target = state.plan.cellAt(row, col);
    if (target == null || !target.cellType.isDesignableSlab) return;

    final existing = target.cantileverOn(side);
    final nextCantilevers = List<CantileverAttachment>.from(target.cantilevers);
    if (existing != null) {
      nextCantilevers.removeWhere((c) => c.side == side);
    } else {
      nextCantilevers.add(
        CantileverAttachment(
          side: side,
          lengthM: defaultLengthM,
          label: 'Solid Slab (${side.titleEn})',
        ),
      );
    }
    _replaceCell(target.copyWith(cantilevers: nextCantilevers));
  }

  void updateCantileverLength({
    required int row,
    required int col,
    required EdgeSide side,
    required double lengthM,
  }) {
    final target = state.plan.cellAt(row, col);
    if (target == null || lengthM <= 0) return;

    final nextCantilevers = target.cantilevers.map((c) {
      if (c.side == side) {
        return CantileverAttachment(
          side: c.side,
          lengthM: lengthM,
          customDesignLoadN: c.customDesignLoadN,
          label: c.label,
        );
      }
      return c;
    }).toList();

    _replaceCell(target.copyWith(cantilevers: nextCantilevers));
  }

  /// ترقيم تلقائي للبلاطات المصمتة العادية (S0, S1, S2...)
  void autoRenumberNormalSlabs({bool startFromZero = true}) {
    int counter = startFromZero ? 0 : 1;
    final sorted = List<FloorSlabCell>.from(state.plan.cells)
      ..sort((a, b) =>
          a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));

    final updatedCells = sorted.map((c) {
      if (c.cellType == SlabCellType.normalSolid) {
        final newId = 'S$counter';
        counter++;
        return c.copyWith(id: newId, label: newId);
      }
      return c;
    }).toList();

    state = state.copyWith(
      plan: state.plan.copyWith(cells: updatedCells),
      hasUnsavedChanges: true,
    );
  }

  /// تطبيق معادلة الرقم السحري لرقم القيد: S_No. = 9 - |d1 - d2|
  /// يرجع معرّف البلاطة المطلوبة ويحددها على المخطط تلقائياً إن وُجدت.
  String applyMagicRegistrationDigits(int digit1, int digit2) {
    final targetId = FloorGridPlan.magicSlabId(digit1, digit2);
    final found = state.plan.findById(targetId);

    if (found != null) {
      state = state.copyWith(
        selectedRow: found.row,
        selectedCol: found.col,
        highlightedSlabId: found.id,
      );
    } else {
      state = state.copyWith(highlightedSlabId: targetId);
    }
    return targetId;
  }

  void clearHighlight() {
    state = state.copyWith(clearHighlight: true);
  }

  /// حفظ المخطط الحالي في التخزين المحلي (Hive)
  Future<SavedFloorProjectRecord> saveCurrentPlan() async {
    final saved =
        await ref.read(savedProjectsProvider.notifier).save(state.plan);
    state = state.copyWith(hasUnsavedChanges: false);
    return saved;
  }

  /// تشغيل المحرك الهندسي لتصميم البلاطة المحددة (أو أي بلاطة بالمعرّف) من داخل المخطط
  SlabDesignReport designSlab(
    String slabId,
    DesignCalculationMode mode, {
    bool autoAdjustDepthInStrictMode = false,
  }) {
    final planWithMode = state.plan.copyWith(
      settings: state.plan.settings.copyWith(calculationMode: mode),
    );
    return SlabDesignPipeline.designFromFloorGrid(
      plan: planWithMode,
      slabId: slabId,
      autoAdjustDepthIfUnsafeInStrictMode: autoAdjustDepthInStrictMode,
    );
  }

  /// تصميم جميع البلاطات القابلة للتصميم في السقف لإنتاج جدول التسليح الكامل للمبنى
  List<SlabDesignReport> designAllSlabs(DesignCalculationMode mode) {
    final planWithMode = state.plan.copyWith(
      settings: state.plan.settings.copyWith(calculationMode: mode),
    );
    final reports = <SlabDesignReport>[];
    final sorted = List<FloorSlabCell>.from(planWithMode.cells)
      ..sort((a, b) => a.id.compareTo(b.id));

    for (final c in sorted) {
      if (c.cellType.isDesignableSlab) {
        reports.add(
          SlabDesignPipeline.designFromFloorGrid(
            plan: planWithMode,
            slabId: c.id,
          ),
        );
      }
    }
    return reports;
  }

  void _replaceCell(FloorSlabCell updated) {
    final nextCells = state.plan.cells
        .map((c) => (c.row == updated.row && c.col == updated.col) ? updated : c)
        .toList();
    state = state.copyWith(
      plan: state.plan.copyWith(cells: nextCells),
      hasUnsavedChanges: true,
    );
  }
}

final floorGridEditorProvider =
    NotifierProvider<FloorGridEditorNotifier, FloorGridEditorState>(
  FloorGridEditorNotifier.new,
);
