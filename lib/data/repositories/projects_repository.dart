import 'dart:convert';
import '../../domain/models/slab_geometry_models.dart';
import 'local_storage_service.dart';

/// سجل مشروع سقف محفوظ محلياً مع تاريخ آخر تعديل
class SavedFloorProjectRecord {
  final FloorGridPlan plan;
  final DateTime updatedAt;

  const SavedFloorProjectRecord({
    required this.plan,
    required this.updatedAt,
  });

  String get projectId => plan.projectId;
  String get projectName => plan.projectName;

  Map<String, dynamic> toJson() {
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'plan': plan.toJson(),
    };
  }

  factory SavedFloorProjectRecord.fromJson(Map<String, dynamic> json) {
    return SavedFloorProjectRecord(
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      plan: FloorGridPlan.fromJson(
        Map<String, dynamic>.from(json['plan'] as Map),
      ),
    );
  }
}

/// مستودع حفظ واسترجاع وتعديل مخططات الأسقف محلياً عبر Hive (بدون إنترنت)
class ProjectsRepository {
  ProjectsRepository._();

  /// استرجاع جميع المشاريع المحفوظة مرتبة من الأحدث إلى الأقدم
  static List<SavedFloorProjectRecord> loadAllProjects() {
    final rawMap = LocalStorageService.readAllRawProjects();
    final records = <SavedFloorProjectRecord>[];

    for (final rawJson in rawMap.values) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          records.add(
            SavedFloorProjectRecord.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // تجاهل أي سجل تالف دون تعطيل التطبيق
      }
    }

    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  /// حفظ أو تحديث مشروع سقف في التخزين المحلي
  static Future<SavedFloorProjectRecord> saveProject(FloorGridPlan plan) async {
    final record = SavedFloorProjectRecord(
      plan: plan,
      updatedAt: DateTime.now(),
    );
    final encoded = jsonEncode(record.toJson());
    await LocalStorageService.writeRawProject(plan.projectId, encoded);
    return record;
  }

  /// حذف مشروع بالمعرّف
  static Future<void> deleteProject(String projectId) async {
    await LocalStorageService.deleteRawProject(projectId);
  }

  /// إعادة تسمية مشروع محفوظ
  static Future<SavedFloorProjectRecord?> renameProject({
    required String projectId,
    required String newName,
  }) async {
    final all = loadAllProjects();
    for (final rec in all) {
      if (rec.projectId == projectId) {
        final updatedPlan = rec.plan.copyWith(projectName: newName.trim());
        return saveProject(updatedPlan);
      }
    }
    return null;
  }

  /// إنشاء نسخة جديدة (Duplicate) من مشروع محفوظ بمعرّف فريد
  static Future<SavedFloorProjectRecord?> duplicateProject(
    String projectId,
  ) async {
    final all = loadAllProjects();
    for (final rec in all) {
      if (rec.projectId == projectId) {
        final newId = 'proj_${DateTime.now().microsecondsSinceEpoch}';
        final copyPlan = rec.plan.copyWith(
          projectId: newId,
          projectName: '${rec.plan.projectName} (نسخة)',
        );
        return saveProject(copyPlan);
      }
    }
    return null;
  }
}
