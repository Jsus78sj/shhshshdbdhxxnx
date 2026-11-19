import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/bs8110/bs8110_tables.dart';
import 'code_table_detail_screen.dart';
import 'widgets/interpolation_calculator_sheet.dart';

/// شاشة كتيّب الكود البريطاني المدمج (Offline Code Browser — المرحلة 6)
/// تدعم تصفح كافة الجداول الـ 18 مع بحث فوري وتصفية بالفئة وحاسبة تناسب خطي مستقلة.
class CodeBrowserScreen extends StatefulWidget {
  const CodeBrowserScreen({super.key});

  @override
  State<CodeBrowserScreen> createState() => _CodeBrowserScreenState();
}

class _CodeBrowserScreenState extends State<CodeBrowserScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  List<String> get _categories {
    final cats = Bs8110CodeCatalog.sections
        .map((s) => s.categoryAr)
        .toSet()
        .toList();
    return ['الكل', ...cats];
  }

  List<CodeSectionMeta> get _filteredSections {
    final q = _searchQuery.trim().toLowerCase();
    return Bs8110CodeCatalog.sections.where((s) {
      final matchesCat =
          _selectedCategory == 'الكل' || s.categoryAr == _selectedCategory;
      if (!matchesCat) return false;
      if (q.isEmpty) return true;
      return s.codeId.toLowerCase().contains(q) ||
          s.titleAr.toLowerCase().contains(q) ||
          s.titleEn.toLowerCase().contains(q) ||
          s.categoryAr.toLowerCase().contains(q);
    }).toList();
  }

  void _openInterpolationCalc() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const InterpolationCalculatorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filteredSections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتيّب الكود البريطاني BS 8110'),
        actions: [
          IconButton(
            tooltip: 'حاسبة التناسب الخطي',
            icon: const Icon(Icons.calculate_rounded),
            onPressed: _openInterpolationCalc,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث الفوري وتصفية الفئات
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الجدول (مثل: 3.14، هطول، قص، تسليح)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories
                        .map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(
                                cat,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _selectedCategory == cat,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // قائمة الجداول الـ 18
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('لا توجد جداول مطابقة لعبارة البحث.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final section = results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primary.withAlpha(24),
                            child: Text(
                              section.pageNumber,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            '${section.codeId} — ${section.titleAr}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            section.titleEn,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CodeTableDetailScreen(section: section),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        onPressed: _openInterpolationCalc,
        icon: const Icon(Icons.calculate_rounded),
        label: const Text('حاسبة التناسب الخطي'),
      ),
    );
  }
}
