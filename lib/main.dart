import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/repositories/local_storage_service.dart';

/// رسالة تشخيص تظهر في أسفل الشاشة إذا فشلت تهيئة التخزين المحلي عند الإقلاع.
String? _startupDiagnostic;

void main() {
  // أي استثناء غير ملتقط لا يترك التطبيق معلّقاً على شاشة البداية بصمت.
  runZonedGuarded<void>(
    _bootstrap,
    (Object error, StackTrace stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // في وضع release الافتراضي يظهر مستطيل رمادي فارغ عند خطأ في بناء واجهة؛
  // نعرض نص الخطأ بدلاً منه ليسهل تشخيصه.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFFF7ED),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            'UI error: ${details.exceptionAsString()}',
            style: const TextStyle(color: Color(0xFF7C2D12), fontSize: 12),
          ),
        ),
      ),
    );
  };

  // تهيئة التخزين المحلي Hive للعمل بدون إنترنت.
  // فشلها (أو تعلّقها) لا يجب أن يمنع فتح التطبيق: نكمل بذاكرة مؤقتة داخلية.
  try {
    await LocalStorageService.initialize().timeout(const Duration(seconds: 10));
  } catch (e, st) {
    debugPrint('Local storage init failed: $e\n$st');
    _startupDiagnostic =
        'تعذّرت تهيئة التخزين المحلي، سيعمل التطبيق دون حفظ دائم للمشاريع.\n$e';
  }

  runApp(
    ProviderScope(
      child: _StartupDiagnosticOverlay(
        message: _startupDiagnostic,
        child: const Bs8110SlabApp(),
      ),
    ),
  );
}

/// يعرض شريطاً أحمر صغيراً بالخطأ (إن وُجد) فوق التطبيق؛ يُغلق بالنقر عليه.
class _StartupDiagnosticOverlay extends StatefulWidget {
  final String? message;
  final Widget child;

  const _StartupDiagnosticOverlay({required this.message, required this.child});

  @override
  State<_StartupDiagnosticOverlay> createState() =>
      _StartupDiagnosticOverlayState();
}

class _StartupDiagnosticOverlayState extends State<_StartupDiagnosticOverlay> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (msg != null && !_dismissed)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(
                color: const Color(0xFFB91C1C),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _dismissed = true),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      msg,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
