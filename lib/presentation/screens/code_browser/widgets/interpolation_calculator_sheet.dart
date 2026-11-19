import 'package:flutter/material.dart';
import '../../../../core/math/math_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ltr_formula_box.dart';

/// حاسبة التناسب الخطي المستقلة المدمجة في كتيّب الكود
class InterpolationCalculatorSheet extends StatefulWidget {
  const InterpolationCalculatorSheet({super.key});

  @override
  State<InterpolationCalculatorSheet> createState() =>
      _InterpolationCalculatorSheetState();
}

class _InterpolationCalculatorSheetState
    extends State<InterpolationCalculatorSheet> {
  final _x1Ctrl = TextEditingController(text: '1.00');
  final _y1Ctrl = TextEditingController(text: '0.034');
  final _x2Ctrl = TextEditingController(text: '1.10');
  final _y2Ctrl = TextEditingController(text: '0.046');
  final _targetXCtrl = TextEditingController(text: '1.0244');

  InterpolationTrace? _trace;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _x1Ctrl.dispose();
    _y1Ctrl.dispose();
    _x2Ctrl.dispose();
    _y2Ctrl.dispose();
    _targetXCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final x1 = double.tryParse(_x1Ctrl.text.trim());
    final y1 = double.tryParse(_y1Ctrl.text.trim());
    final x2 = double.tryParse(_x2Ctrl.text.trim());
    final y2 = double.tryParse(_y2Ctrl.text.trim());
    final x = double.tryParse(_targetXCtrl.text.trim());

    if (x1 == null || y1 == null || x2 == null || y2 == null || x == null) {
      setState(() => _trace = null);
      return;
    }

    final result = MathUtils.linearInterpolate(
      x: x,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
    );
    setState(() {
      _trace = InterpolationTrace(
        targetX: x,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        result: result,
        wasExactMatch: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'حاسبة التناسب الخطي (Linear Interpolation)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _x1Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'x1'),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _y1Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'y1'),
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _x2Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'x2'),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _y2Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'y2'),
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetXCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'القيمة المطلوبة (x — مثل ly/lx)',
              ),
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 14),
            if (_trace != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.safeGreen.withAlpha(90)),
                ),
                child: Text(
                  'النتيجة: y = ${_trace!.result.toStringAsFixed(4)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.safeGreen,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LtrFormulaBox(
                captionAr: 'خطوة التناسب بصيغة الشرح الجامعي:',
                tex: _trace!.toLectureLatex(unknownSymbol: 'y'),
                fontSize: 13.5,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
