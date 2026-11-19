import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/repositories/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة التخزين المحلي Hive للعمل بدون إنترنت
  await LocalStorageService.initialize();

  runApp(
    const ProviderScope(
      child: Bs8110SlabApp(),
    ),
  );
}
