import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/bs8110/bs8110_tables.dart';

/// نافذة «حول التطبيق» تعرض تفاصيل الإصدار والعمل دون إنترنت والمرجع الهندسي
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.architecture_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appNameAr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'الإصدار ${AppConstants.appVersion} (Release)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أداة هندسية متكاملة لتصميم البلاطات الخرسانية المصمتة وفق الكود البريطاني BS 8110-1 وطريقة الشرح الجامعية، مع دعم البلاطة المفردة مع جيرانها ومحرر المخطط الشبكي الكامل.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 12),
            const _InfoLine(
              icon: Icons.wifi_off_rounded,
              color: AppColors.safeGreen,
              text: 'يعمل 100% دون إنترنت (Offline-First — بدون صلاحية إنترنت).',
            ),
            _InfoLine(
              icon: Icons.table_chart_rounded,
              color: AppColors.secondary,
              text:
                  'قاعدة بيانات مدمجة تضم ${Bs8110CodeCatalog.sections.length} جدولاً وقسماً من الكود البريطاني.',
            ),
            const _InfoLine(
              icon: Icons.font_download_rounded,
              color: AppColors.primaryLight,
              text: 'خطوط عربية ورموز هندسية مدمجة محلياً للواجهة وتقارير PDF.',
            ),
            const _InfoLine(
              icon: Icons.verified_user_outlined,
              color: AppColors.accentAmber,
              text:
                  'تنويه هندسي: التطبيق أداة مساعدة للدراسة والتحقق، وتبقى مسؤولية المراجعة النهائية للمخططات التنفيذية على المهندس الإنشائي المختص.',
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
