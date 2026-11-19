import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/engine/engineering_engine.dart';

/// رسم تفاعلي مصغر للبلاطة مع 4 أزرار على الحواف لتبديل حالة كل حافة مباشرة
class InteractiveSlabEdgeDiagram extends StatelessWidget {
  final String slabId;
  final double widthXM;
  final double heightYM;
  final SlabCellType cellType;
  final EdgeCondition topEdge;
  final EdgeCondition bottomEdge;
  final EdgeCondition leftEdge;
  final EdgeCondition rightEdge;
  final ResolvedTopology? previewTopology;
  final void Function(EdgeSide side, EdgeCondition newCondition) onEdgeChanged;

  const InteractiveSlabEdgeDiagram({
    super.key,
    required this.slabId,
    required this.widthXM,
    required this.heightYM,
    required this.cellType,
    required this.topEdge,
    required this.bottomEdge,
    required this.leftEdge,
    required this.rightEdge,
    required this.previewTopology,
    required this.onEdgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDropped = cellType == SlabCellType.droppedSolid;

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
          Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'انقر على أي حافة لتغيير شرط استنادها',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (previewTopology?.twoWayCase != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Case ${previewTopology!.twoWayCase!.caseNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // اتجاه LTR للرسم الهندسي بحيث يكون اليسار واليمين مطابقين للمسقط الأفقي
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                // الحافة العلوية (Top)
                _EdgeSelectorPill(
                  side: EdgeSide.top,
                  condition: topEdge,
                  onTap: () => _pickEdgeCondition(context, EdgeSide.top, topEdge),
                ),
                const SizedBox(height: 8),

                // الصف الأوسط: الحافة اليسرى + جسم البلاطة + الحافة اليمنى
                Row(
                  children: [
                    _EdgeSelectorPill(
                      side: EdgeSide.left,
                      condition: leftEdge,
                      isVertical: true,
                      onTap: () =>
                          _pickEdgeCondition(context, EdgeSide.left, leftEdge),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 136,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDropped
                              ? (isDark
                                  ? const Color(0xFF3B2E12)
                                  : AppColors.droppedSlabHatch)
                              : (isDark
                                  ? const Color(0xFF102A43)
                                  : AppColors.slabFill),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            top: _borderSideFor(topEdge),
                            bottom: _borderSideFor(bottomEdge),
                            left: _borderSideFor(leftEdge),
                            right: _borderSideFor(rightEdge),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slabId.trim().isEmpty ? 'S?' : slabId.trim(),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widthXM.toStringAsFixed(2)} m × ${heightYM.toStringAsFixed(2)} m',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (previewTopology != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ly / lx = ${previewTopology!.lyOverLx.toStringAsFixed(3)} (${previewTopology!.spanningType == SlabSpanningType.twoWay ? "Two-Way" : "One-Way"})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (isDropped) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Dropped Solid Slab',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.warningAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _EdgeSelectorPill(
                      side: EdgeSide.right,
                      condition: rightEdge,
                      isVertical: true,
                      onTap: () => _pickEdgeCondition(
                          context, EdgeSide.right, rightEdge),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                // الحافة السفلية (Bottom)
                _EdgeSelectorPill(
                  side: EdgeSide.bottom,
                  condition: bottomEdge,
                  onTap: () =>
                      _pickEdgeCondition(context, EdgeSide.bottom, bottomEdge),
                ),
              ],
            ),
          ),

          if (previewTopology?.twoWayCase != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'التصنيف التلقائي: Case ${previewTopology!.twoWayCase!.caseNumber} — ${previewTopology!.twoWayCase!.titleAr}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  BorderSide _borderSideFor(EdgeCondition condition) {
    switch (condition) {
      case EdgeCondition.continuous:
        return const BorderSide(color: AppColors.rebarBottomX, width: 4.0);
      case EdgeCondition.cantilever:
        return const BorderSide(color: AppColors.safeGreen, width: 4.0);
      case EdgeCondition.discontinuousDropped:
        return const BorderSide(color: AppColors.accentAmber, width: 2.5);
      case EdgeCondition.discontinuousStairwell:
        return const BorderSide(color: AppColors.dangerRed, width: 2.5);
      case EdgeCondition.discontinuousFree:
        return const BorderSide(color: Color(0xFF94A3B8), width: 1.8);
    }
  }

  Future<void> _pickEdgeCondition(
    BuildContext context,
    EdgeSide side,
    EdgeCondition current,
  ) async {
    final chosen = await showModalBottomSheet<EdgeCondition>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اختر حالة ${side.titleAr}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                ...EdgeCondition.values.map(
                  (cond) => ListTile(
                    leading: Icon(
                      _iconForCondition(cond),
                      color: _colorForCondition(cond),
                    ),
                    title: Text(cond.titleAr),
                    subtitle: Text(cond.titleEn),
                    trailing: cond == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.of(ctx).pop(cond),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      onEdgeChanged(side, chosen);
    }
  }

  static Color _colorForCondition(EdgeCondition c) {
    switch (c) {
      case EdgeCondition.continuous:
        return AppColors.rebarBottomX;
      case EdgeCondition.cantilever:
        return AppColors.safeGreen;
      case EdgeCondition.discontinuousDropped:
        return AppColors.accentAmber;
      case EdgeCondition.discontinuousStairwell:
        return AppColors.dangerRed;
      case EdgeCondition.discontinuousFree:
        return const Color(0xFF64748B);
    }
  }

  static IconData _iconForCondition(EdgeCondition c) {
    switch (c) {
      case EdgeCondition.continuous:
        return Icons.link_rounded;
      case EdgeCondition.cantilever:
        return Icons.balcony_rounded;
      case EdgeCondition.discontinuousDropped:
        return Icons.layers_rounded;
      case EdgeCondition.discontinuousStairwell:
        return Icons.stairs_rounded;
      case EdgeCondition.discontinuousFree:
        return Icons.border_style_rounded;
    }
  }

  static String _shortLabelFor(EdgeCondition c) {
    switch (c) {
      case EdgeCondition.continuous:
        return 'مستمرة';
      case EdgeCondition.cantilever:
        return 'كابولي';
      case EdgeCondition.discontinuousDropped:
        return 'مهبطة';
      case EdgeCondition.discontinuousStairwell:
        return 'درج';
      case EdgeCondition.discontinuousFree:
        return 'حرة';
    }
  }
}

class _EdgeSelectorPill extends StatelessWidget {
  final EdgeSide side;
  final EdgeCondition condition;
  final bool isVertical;
  final VoidCallback onTap;

  const _EdgeSelectorPill({
    required this.side,
    required this.condition,
    this.isVertical = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = InteractiveSlabEdgeDiagram._colorForCondition(condition);
    final label = InteractiveSlabEdgeDiagram._shortLabelFor(condition);
    final icon = InteractiveSlabEdgeDiagram._iconForCondition(condition);

    return Material(
      color: color.withAlpha(24),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: isVertical ? 76 : null,
          height: isVertical ? 96 : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(140)),
          ),
          child: isVertical
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(height: 4),
                    Text(
                      side == EdgeSide.left ? 'اليسار' : 'اليمين',
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      '${side.titleAr}: $label',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
                  ],
                ),
        ),
      ),
    );
  }
}
