import 'dart:io';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../core/constants/app_constants.dart';

/// خدمة التخزين المحلي (Offline-First) باستخدام Hive
/// مع ذاكرة احتياطية داخلية عند تشغيل اختبارات الوحدة/الواجهة بدون تهيئة Hive.
class LocalStorageService {
  LocalStorageService._();

  static Box<dynamic>? _settingsBox;
  static Box<dynamic>? _projectsBox;

  // ذاكرة احتياطية تُستخدم تلقائياً فقط عندما لا يكون Hive مهيأً (مثل بيئة flutter test)
  static final Map<String, String> _memorySettings = {};
  static final Map<String, String> _memoryProjects = {};

  /// تهيئة قواعد البيانات المحلية عند بدء تشغيل التطبيق
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      // على بعض إصدارات path_provider_android (المبنية على JNI) قد يفشل جلب مجلد التطبيق
      // (ClassNotFoundException). نستعمل مساراً بديلاً داخل مجلد بيانات التطبيق الخاص
      // حتى تبقى المشاريع محفوظة دائماً بدل الاكتفاء بالذاكرة المؤقتة.
      Hive.init(_fallbackStorageDir().path);
    }
    _settingsBox = await Hive.openBox<dynamic>(AppConstants.settingsBoxName);
    _projectsBox = await Hive.openBox<dynamic>(AppConstants.projectsBoxName);
  }

  /// Android: Directory.systemTemp = <app data>/cache  →  نستخدم <app data>/files/bs8110_hive
  static Directory _fallbackStorageDir() {
    final tmp = Directory.systemTemp;
    try {
      final dir = Directory('${tmp.parent.path}/files/bs8110_hive');
      dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      final dir = Directory('${tmp.path}/bs8110_hive');
      dir.createSync(recursive: true);
      return dir;
    }
  }

  static bool get isInitialized => _settingsBox != null && _projectsBox != null;

  static String? readSetting(String key) {
    if (_settingsBox != null) {
      return _settingsBox!.get(key) as String?;
    }
    return _memorySettings[key];
  }

  static Future<void> writeSetting(String key, String value) async {
    if (_settingsBox != null) {
      await _settingsBox!.put(key, value);
    } else {
      _memorySettings[key] = value;
    }
  }

  static int get savedProjectsCount =>
      _projectsBox?.length ?? _memoryProjects.length;

  static Map<String, String> readAllRawProjects() {
    if (_projectsBox != null) {
      final result = <String, String>{};
      for (final key in _projectsBox!.keys) {
        final val = _projectsBox!.get(key);
        if (val is String) {
          result[key.toString()] = val;
        }
      }
      return result;
    }
    return Map<String, String>.from(_memoryProjects);
  }

  static Future<void> writeRawProject(String id, String encodedJson) async {
    if (_projectsBox != null) {
      await _projectsBox!.put(id, encodedJson);
    } else {
      _memoryProjects[id] = encodedJson;
    }
  }

  static Future<void> deleteRawProject(String id) async {
    if (_projectsBox != null) {
      await _projectsBox!.delete(id);
    } else {
      _memoryProjects.remove(id);
    }
  }

  /// تنظيف الذاكرة الاحتياطية بين الاختبارات
  static void clearMemoryFallback() {
    _memorySettings.clear();
    _memoryProjects.clear();
  }
}
