import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// جدول مرجعي تفاعلي يدعم التظليل المتقاطع (Crosshair Highlight) عند النقر على أي خلية
/// ليسهّل على الطالب قراءة القيمة المقابلة للصف والعمود دون خطأ.
class HighlightableCodeTable extends StatefulWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final String? footnoteAr;

  const HighlightableCodeTable({
    super.key,
    required this.headers,
    required this.rows,
    this.footnoteAr,
  });

  @override
  State<HighlightableCodeTable> createState() => _HighlightableCodeTableState();
}

class _HighlightableCodeTableState extends State<HighlightableCodeTable> {
  int? _selectedRow;
  int? _selectedCol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedRow != null && _selectedCol != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary.withAlpha(90)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 16,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الخلية المحددة: [${widget.rows[_selectedRow!][0]} × ${widget.headers[_selectedCol!]}] = ${widget.rows[_selectedRow!][_selectedCol!]}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _selectedRow = null;
                    _selectedCol = null;
                  }),
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(
                  color: theme.dividerColor,
                  width: 0.7,
                ),
                children: [
                  // صف العناوين
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(
                        isDark ? 65 : 24,
                      ),
                    ),
                    children: List.generate(widget.headers.length, (c) {
                      final isColSelected = _selectedCol == c;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        color: isColSelected
                            ? AppColors.accentAmber.withAlpha(55)
                            : null,
                        child: Text(
                          widget.headers[c],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }),
                  ),
                  // صفوف البيانات
                  ...List.generate(widget.rows.length, (r) {
                    final row = widget.rows[r];
                    final isRowSel = _selectedRow == r;
                    return TableRow(
                      children: List.generate(row.length, (c) {
                        final isColSel = _selectedCol == c;
                        final isExact = isRowSel && isColSel;
                        Color? cellBg;
                        if (isExact) {
                          cellBg = AppColors.secondary.withAlpha(80);
                        } else if (isRowSel || isColSel) {
                          cellBg = AppColors.accentAmber.withAlpha(
                            isDark ? 35 : 28,
                          );
                        } else if (r.isOdd) {
                          cellBg = theme.colorScheme.onSurface.withAlpha(8);
                        }

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRow = r;
                              _selectedCol = c;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            color: cellBg,
                            child: Text(
                              row[c],
                              textAlign:
                                  c == 0 ? TextAlign.left : TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: (c == 0 || isExact)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        if (widget.footnoteAr != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.footnoteAr!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(185),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
