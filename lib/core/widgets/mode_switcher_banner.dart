import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/design_mode.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

/// بطاقة تفاعلية لتبديل وضع الحساب الهندسي بين "شرح المحاضرة" و"الكود الصارم"
class ModeSwitcherBanner extends ConsumerWidget {
  const ModeSwitcherBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(designModeProvider);
    final theme = Theme.of(context);
    final isLecture = currentMode == DesignCalculationMode.lectureMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isLecture ? AppColors.secondary : AppColors.accentAmber)
              .withAlpha(90),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isLecture ? Icons.school_rounded : Icons.gavel_rounded,
                color: isLecture ? AppColors.secondary : AppColors.accentAmber,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'وضع الحساب الهندسي النشط',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isLecture
                          ? AppColors.secondary
                          : AppColors.accentAmber)
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentMode.shortLabelAr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        isLecture ? AppColors.secondary : AppColors.accentAmber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<DesignCalculationMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<DesignCalculationMode>(
                value: DesignCalculationMode.lectureMode,
                label: Text(
                  'شرح المحاضرة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
                icon: Icon(Icons.menu_book_rounded, size: 17),
              ),
              ButtonSegment<DesignCalculationMode>(
                value: DesignCalculationMode.strictBs8110,
                label: Text(
                  'الكود الصارم BS 8110',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
                icon: Icon(Icons.verified_outlined, size: 17),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                ref.read(designModeProvider.notifier).setMode(selection.first);
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            currentMode.descriptionAr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(185),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
