# دليل بناء وتوقيع ملف الـ APK النهائي — الإصدار 1.0.0

يوضح هذا الدليل الخطوات العملية لإخراج ملف تثبيت أندرويد الإنتاجي (**Release APK**) جاهزاً للتثبيت على الهواتف الحقيقية والعمل بالكامل دون إنترنت.

---

## المتطلبات المسبقة على جهازك
- **Flutter SDK** (إصدار **3.24 أو أحدث**) و **Dart SDK >= 3.5** (يتحقق السكربت من ذلك تلقائياً).
- **Android Studio** أو **Android SDK Command-line Tools** مع **JDK 17**.
- تأكد من سلامة البيئة عبر الأمر:
  ```bash
  flutter doctor
  ```

---

## الطريقة السريعة (بأمر واحد عبر السكربت الجاهز)

### على نظام Windows (PowerShell):
افتح PowerShell داخل مجلد المشروع `bs8110_slab_designer` ونفّذ:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_release_apk.ps1
```

### على نظام macOS أو Linux:
افتح الطرفية (Terminal) داخل مجلد المشروع `bs8110_slab_designer` ونفّذ:
```bash
chmod +x scripts/build_release_apk.sh
./scripts/build_release_apk.sh
```

سيقوم السكربت تلقائياً بما يلي:
0. التحقق من أن إصدار Flutter ≥ 3.24 (يتوقف برسالة واضحة إن كان أقدم).
1. توليد مجلد `android/` المتوافق تماماً مع إصدار Flutter المثبّت على جهازك.
2. تطبيق ملف `AndroidManifest.xml` النظيف (بالاسم العربي `مصمم البلاطات BS 8110` ودعم `RTL` وبدون أي صلاحية إنترنت) ونسخ `proguard-rules.pro`.
3. تنزيل الحزم (`flutter pub get`).
4. **تعديل `android/app/build.gradle(.kts)` تلقائياً** (`tool/patch_android_gradle.dart`): ربط `proguard-rules.pro` بنسخة release، وتوقيع النسخة بمفتاحك إن وُجد `android/key.properties` وإلا بمفتاح debug. الأداة آمنة للتكرار وتحفظ نسخة `build.gradle*.bs8110.bak`.
5. توليد أيقونة التطبيق التكيفية (`flutter_launcher_icons`) وشاشة البداية (`flutter_native_splash`).
6. تشغيل الفحص الساكن (`flutter analyze`) وكافة الاختبارات (`flutter test`). **الأخطاء فقط توقف البناء**؛ تحذيرات الـ deprecation والأسلوب (info/warning) تُطبع ولا توقفه. للتخطي الطارئ للاختبارات: `SKIP_TESTS=1 ./scripts/build_release_apk.sh` (أو `-SkipTests` في PowerShell).
7. بناء ملفات الـ APK المقسّمة حسب معمارية المعالج (`--split-per-abi`) مع `--obfuscate`. احتفظ بمجلد `build/debug-info/` إن أردت فك تعتيم تتبّع الأعطال لاحقاً.

---

## أين تجد ملف الـ APK بعد انتهاء البناء؟
ستجد الملفات داخل المسار:
```text
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk     <-- الأنسب والأصغر لمعظم هواتف أندرويد الحديثة
├── app-armeabi-v7a-release.apk   <-- للهواتف الأقدم (32-bit)
└── app-x86_64-release.apk        <-- للمحاكيات
```

ولبناء ملف APK واحد شامل يعمل على جميع الهواتف (Universal APK):
```bash
flutter build apk --release
```

---

## توقيع النسخة الإنتاجية للنشر (اختياري لمتجر Google Play)
> دون `android/key.properties` يُوقَّع الـ APK بمفتاح **debug**: يصلح للتثبيت الشخصي فقط ولا يُقبل في Google Play، ويُظهر السكربت تنبيهاً بذلك في نهاية البناء.

1. أنشئ مفتاح التوقيع الخاص بك مرة واحدة (احتفظ به وبكلمات مروره في مكان آمن؛ فقدانه يمنع تحديث التطبيق لاحقاً):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bs8110key
   ```
2. انسخ `android_release_config/key.properties.example` إلى `android/key.properties` وأدخل كلمات المرور الخاصة بك (`storeFile` مسار نسبي إلى `android/app/`).
3. شغّل سكربت البناء كالمعتاد: الخطوة [4/7] تفعّل قراءة `key.properties` تلقائياً. ولبناء حزمة متجر Play: `flutter build appbundle --release`.

> لا ترفع `android/key.properties` ولا ملف `.jks` إلى Git (مضافان إلى `.gitignore` في هذا المشروع).

### إعداد gradle يدوياً (احتياطي إذا طبعت الأداة تحذير "could not patch")
في `android/app/build.gradle.kts` أضف قبل `android {`:
```kotlin
val bs8110KeyPropsFile = rootProject.file("key.properties")
val bs8110KeyProps = java.util.Properties()
if (bs8110KeyPropsFile.exists()) {
    java.io.FileInputStream(bs8110KeyPropsFile).use { bs8110KeyProps.load(it) }
}
```
وداخل `android {` أضف `signingConfigs { create("bs8110Release") { keyAlias = bs8110KeyProps.getProperty("keyAlias"); keyPassword = bs8110KeyProps.getProperty("keyPassword"); storeFile = file(bs8110KeyProps.getProperty("storeFile")); storePassword = bs8110KeyProps.getProperty("storePassword") } }`، وداخل `buildTypes { release { ... } }`:
```kotlin
signingConfig = signingConfigs.getByName("bs8110Release")
proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
```

---

## قائمة التحقق قبل التوزيع (Offline QA Checklist)
- [ ] تثبيت `app-arm64-v8a-release.apk` على هاتف أندرويد حقيقي وتفعيل **وضع الطيران (Airplane Mode)**.
- [ ] التحقق من ظهور أيقونة `BS 8110` وشاشة البداية والخطوط العربية بسلاسة.
- [ ] تجربة تصميم البلاطة `S7` من «بلاطة واحدة + جيرانها» ومن «محرر المخطط الكامل» في الوضعين (شرح المحاضرة والكود الصارم).
- [ ] حفظ مخطط سقف وإغلاق التطبيق وإعادة فتحه للتأكد من بقاء المشروع محفوظاً محلياً.
- [ ] فتح تقرير `S7` والضغط على **طباعة / حفظ PDF** للتأكد من سلامة اللغة العربية والرسم المتجهي داخل ملف الـ PDF دون إنترنت. إذا فشل تحميل الخطوط يظهر الآن شريط خطأ صريح («تعذّر تحميل خطوط PDF…») بدل الرجوع الصامت إلى خط بلا عربية؛ والاختبارات تتحقق من تضمين الخطوط في الملف، لكن شكل الحروف العربية المتصلة يُراجَع بالعين على جهاز حقيقي.
