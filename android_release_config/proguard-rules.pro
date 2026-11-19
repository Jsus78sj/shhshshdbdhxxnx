# قواعد ProGuard / R8 لحماية ملفات التطبيق عند التعتيم وتقليص الحجم (Release APK)
# تُربط بالبناء تلقائياً عبر tool/patch_android_gradle.dart (خطوة [4/7] في سكربت البناء).
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# الحفاظ على حزمة الطباعة ومشاركة ملفات PDF
-keep class net.nfet.flutter.printing.** { *; }

# منع تحذيرات المكتبات الداخلية
-dontwarn io.flutter.embedding.**
-dontwarn javax.annotation.**
# إصدارات Flutter القديمة تشير إلى Play Core (المكونات المؤجلة) ولا نستخدمها: يمنع فشل R8 بـ "Missing class"
-dontwarn com.google.android.play.core.**
