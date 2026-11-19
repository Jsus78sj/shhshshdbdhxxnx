import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// عنصر مخصص لعرض المعادلات الرياضية (LaTeX) باتجاه من اليسار إلى اليمين (LTR)
/// بشكل سليم وسط واجهة عربية (RTL)، مع قابلية التمرير الأفقي للمعادلات الطويلة.
class LtrFormulaBox extends StatelessWidget {
  final String tex;
  final String? captionAr;
  final double fontSize;

  const LtrFormulaBox({
    super.key,
    required this.tex,
    this.captionAr,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B29)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (captionAr != null) ...[
            Text(
              captionAr!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Center(
                child: Math.tex(
                  tex,
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
