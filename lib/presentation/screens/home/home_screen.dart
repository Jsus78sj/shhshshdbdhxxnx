import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/ltr_formula_box.dart';
import '../../../core/widgets/mode_switcher_banner.dart';
import '../../../data/bs8110/bs8110_tables.dart';
import '../../providers/floor_grid_provider.dart';
import 'widgets/about_app_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final savedCount = ref.watch(savedProjectsProvider).length;
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appNameAr,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'تصميم البلاطات الخرسانية المصمتة — يعمل دون إنترنت',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                isDark ? 'التبديل إلى الوضع الفاتح' : 'التبديل إلى الوضع الداكن',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            tooltip: 'حول التطبيق',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const AboutAppDialog(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // شريط تبديل وضع الحساب (شرح المحاضرة / الكود الصارم)
          const ModeSwitcherBanner(),
          const SizedBox(height: 18),

          // قسم أوضاع التصميم الرئيسية
          Text(
            'ابدأ التصميم الإنشائي',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          _PrimaryActionCard(
            title: 'تصميم بلاطة واحدة + جيرانها',
            subtitle:
                'إدخال سريع لأبعاد البلاطة وحالة حوافها الأربع مع موازنة العزوم عند المساند المستمرة.',
            badgeText: 'الوضع السريع',
            icon: Icons.crop_square_rounded,
            accentColor: AppColors.primary,
            onTap: () => context.push(AppRoutes.singleSlab),
          ),
          const SizedBox(height: 12),

          _PrimaryActionCard(
            title: 'بناء مخطط سقف كامل (Grid Editor)',
            subtitle:
                'ارسم شبكة المحاور كاملة مع البلاطات المهبطة (Dropped) والدرج والكوابيل واستنتج حل أي بلاطة تلقائياً.',
            badgeText: 'مخطط كامل',
            icon: Icons.grid_view_rounded,
            accentColor: AppColors.secondary,
            onTap: () => context.push(AppRoutes.floorGrid),
          ),
          const SizedBox(height: 18),

          // أدوات مساعدة (كتيّب الكود والمشاريع المحفوظة)
          Text(
            'المراجع والمشاريع',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _SecondaryTile(
                  icon: Icons.table_chart_rounded,
                  title: 'كتيّب الكود BS 8110',
                  subtitle:
                      '${Bs8110CodeCatalog.sections.length} جدولاً وقسماً مدمجاً',
                  color: AppColors.accentAmber,
                  onTap: () => context.push(AppRoutes.codeBrowser),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryTile(
                  icon: Icons.folder_copy_rounded,
                  title: 'المشاريع المحفوظة',
                  subtitle: '$savedCount مشروع محفوظ محلياً',
                  color: AppColors.primaryLight,
                  onTap: () => context.push(AppRoutes.savedProjects),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // بطاقة مرجعية سريعة لأهم معادلات التصميم
          const LtrFormulaBox(
            captionAr: 'مرجع سريع — معادلتا موازنة العزوم وفحص الهطول (BS 8110):',
            tex:
                r'M_S = M_L - \left[ M_{UB} \times \frac{k_L}{k_L + k_{\mathrm{adj}}} \right] \quad,\quad d_{\min} = \frac{\mathrm{Span}}{B.R \times M.F_t}',
            fontSize: 13.5,
          ),
          const SizedBox(height: 16),

          // شريط جاهزية الإصدار والعمل دون إنترنت
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.safeGreen.withAlpha(75),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.safeGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الإصدار ${AppConstants.appVersion} • يعمل بالكامل دون إنترنت مع رسومات هندسية وتصدير PDF عربي.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withAlpha(70)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(185),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(175),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
