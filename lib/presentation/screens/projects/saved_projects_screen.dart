import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/projects_repository.dart';
import '../../providers/floor_grid_provider.dart';

/// شاشة إدارة المشاريع والمخططات المحفوظة محلياً عبر Hive (بدون إنترنت)
class SavedProjectsScreen extends ConsumerWidget {
  const SavedProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(savedProjectsProvider);
    final projectsNotifier = ref.read(savedProjectsProvider.notifier);
    final gridNotifier = ref.read(floorGridEditorProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('المشاريع المحفوظة (${projects.length})'),
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: projectsNotifier.refresh,
          ),
        ],
      ),
      body: projects.isEmpty
          ? _EmptyProjectsView(
              onOpenExamTemplate: () {
                gridNotifier.loadUniversityExamTemplate();
                context.push(AppRoutes.floorGrid);
              },
              onCreateNewPlan: () {
                gridNotifier.createNewBlankPlan();
                context.push(AppRoutes.floorGrid);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final record = projects[index];
                final plan = record.plan;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      gridNotifier.loadPlan(plan);
                      context.push(AppRoutes.floorGrid);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.projectName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'شبكة ${plan.colsCount}×${plan.rowsCount} • ${plan.designableSlabsCount} بلاطة • h=${plan.settings.overallDepthH.toStringAsFixed(0)}mm • n=${plan.settings.designLoadN.toStringAsFixed(2)} kN/m²',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(180),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'آخر حفظ: ${_formatDateTime(record.updatedAt)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(
                              context,
                              action,
                              record,
                              projectsNotifier,
                              gridNotifier,
                            ),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'open',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.open_in_new_rounded),
                                  title: Text('فتح في المحرر'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_rounded),
                                  title: Text('إعادة تسمية'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.copy_rounded),
                                  title: Text('إنشاء نسخة'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.dangerRed,
                                  ),
                                  title: Text(
                                    'حذف',
                                    style:
                                        TextStyle(color: AppColors.dangerRed),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          gridNotifier.createNewBlankPlan();
          context.push(AppRoutes.floorGrid);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('مخطط سقف جديد'),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    SavedFloorProjectRecord record,
    SavedProjectsNotifier projectsNotifier,
    FloorGridEditorNotifier gridNotifier,
  ) async {
    switch (action) {
      case 'open':
        gridNotifier.loadPlan(record.plan);
        context.push(AppRoutes.floorGrid);
      case 'duplicate':
        await projectsNotifier.duplicate(record.projectId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء نسخة من المشروع.')),
          );
        }
      case 'rename':
        final ctrl = TextEditingController(text: record.projectName);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('إعادة تسمية المشروع'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم الجديد'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
        if (ok == true && ctrl.text.trim().isNotEmpty) {
          await projectsNotifier.rename(record.projectId, ctrl.text.trim());
        }
        ctrl.dispose();
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف المشروع "${record.projectName}" نهائياً؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await projectsNotifier.delete(record.projectId);
        }
    }
  }

  static String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }
}

class _EmptyProjectsView extends StatelessWidget {
  final VoidCallback onOpenExamTemplate;
  final VoidCallback onCreateNewPlan;

  const _EmptyProjectsView({
    required this.onOpenExamTemplate,
    required this.onCreateNewPlan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primary.withAlpha(24),
              child: Icon(
                Icons.folder_open_rounded,
                size: 38,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد مشاريع محفوظة بعد',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك البدء بفتح قالب مخطط اختبار جامعة عدن الجاهز (S0 إلى S9) أو بناء مخطط سقف جديد وحفظه للعمل دون إنترنت.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onOpenExamTemplate,
              icon: const Icon(Icons.quiz_rounded),
              label: const Text('فتح مخطط الاختبار الجاهز (S0 – S9)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCreateNewPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('بناء مخطط سقف جديد'),
            ),
          ],
        ),
      ),
    );
  }
}
