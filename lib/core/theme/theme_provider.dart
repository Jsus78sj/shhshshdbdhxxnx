import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/local_storage_service.dart';
import '../constants/app_constants.dart';
import '../constants/design_mode.dart';

/// مزوّد إدارة الثيم (فاتح / داكن / حسب النظام) مع حفظ الإعداد محلياً
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = LocalStorageService.readSetting(AppConstants.themeModeKey);
    switch (saved) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await LocalStorageService.writeSetting(
      AppConstants.themeModeKey,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await LocalStorageService.writeSetting(
      AppConstants.themeModeKey,
      mode.name,
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// مزوّد إدارة وضع الحساب الهندسي (شرح المحاضرة / الكود البريطاني الصارم)
class DesignModeNotifier extends Notifier<DesignCalculationMode> {
  @override
  DesignCalculationMode build() {
    final saved = LocalStorageService.readSetting(AppConstants.designModeKey);
    return DesignCalculationModeX.fromStorage(saved);
  }

  Future<void> setMode(DesignCalculationMode mode) async {
    state = mode;
    await LocalStorageService.writeSetting(
      AppConstants.designModeKey,
      mode.storageValue,
    );
  }

  Future<void> toggleMode() async {
    final next = state == DesignCalculationMode.lectureMode
        ? DesignCalculationMode.strictBs8110
        : DesignCalculationMode.lectureMode;
    await setMode(next);
  }
}

final designModeProvider =
    NotifierProvider<DesignModeNotifier, DesignCalculationMode>(
  DesignModeNotifier.new,
);
