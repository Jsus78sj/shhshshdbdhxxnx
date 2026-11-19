import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/design_mode.dart';
import '../../domain/engine/engineering_engine.dart';

/// يُرمى عند تعذّر تحميل خطوط PDF العربية المدمجة (بدلاً من الرجوع الصامت إلى Helvetica
/// الذي يُظهر الحروف العربية فارغة/مربعات دون أي تنبيه).
class PdfFontLoadException implements Exception {
  final String message;
  const PdfFontLoadException(this.message);

  @override
  String toString() => message;
}

/// مولد تقارير التصميم الهندسية بصيغة PDF باللغة العربية السليمة (RTL)
/// يعمل بالكامل دون إنترنت باستخدام الخطوط المدمجة في assets/fonts/.
class SlabReportPdfGenerator {
  SlabReportPdfGenerator._();

  static const String _arabicRegularAsset =
      'assets/fonts/NotoSansArabic-Regular.ttf';
  static const String _arabicBoldAsset =
      'assets/fonts/NotoSansArabic-Bold.ttf';
  static const String _latinRegularAsset = 'assets/fonts/DejaVuSans.ttf';
  static const String _latinBoldAsset = 'assets/fonts/DejaVuSans-Bold.ttf';

  /// توليد بايتات ملف PDF كامل للتقرير الهندسي [report]
  ///
  /// إذا تعذّر تحميل الخطوط يُرمى [PdfFontLoadException] (يظهر للمستخدم كرسالة خطأ).
  /// [allowFontFallback] = true يسمح بخط Helvetica الاحتياطي (بلا عربية) — للاختبارات فقط.
  static Future<Uint8List> generatePdfBytes({
    required SlabDesignReport report,
    required String sourceLabelAr,
    bool allowFontFallback = false,
  }) async {
    final themeData = await _loadPdfTheme(allowFallback: allowFontFallback);

    final pdf = pw.Document(
      title: 'تقرير تصميم البلاطة ${report.slabId} — BS 8110',
      author: 'BS 8110 Solid Slab Designer',
      theme: themeData,
    );

    final primaryColor = PdfColor.fromHex('#0F3D5E');
    final secondaryColor = PdfColor.fromHex('#0E7C7B');
    final safeColor = PdfColor.fromHex('#15803D');
    final dangerColor = PdfColor.fromHex('#B91C1C');
    final amberColor = PdfColor.fromHex('#B45309');
    final lightBg = PdfColor.fromHex('#F4F7FA');
    final borderColor = PdfColor.fromHex('#CBD5E1');

    final topo = report.topology;
    final load = report.loadResult;
    final mode = report.settingsUsed.calculationMode;
    final verdictColor = report.overallIsSafe ? safeColor : dangerColor;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        textDirection: pw.TextDirection.rtl,
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'تقرير تصميم البلاطة المصمتة (${report.slabId}) — BS 8110',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.Text(
                mode.shortLabelAr,
                style: pw.TextStyle(fontSize: 9, color: secondaryColor),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderColor, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'تطبيق مصمم البلاطات المصمتة — يعمل دون إنترنت',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // 1. بطاقة الترويسة الرئيسية
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'تقرير التصميم الإنشائي للبلاطة المصمتة ${report.slabId}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'المصدر: $sourceLabelAr  |  وضع الحساب: ${mode.titleAr}',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey200,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // 2. شريط الحالة العامة للتصميم
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: verdictColor, width: 1.2),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    report.overallIsSafe
                        ? 'الحكم الهندسي: التصميم آمن ومستوفٍ لمتطلبات الحد الأقصى والتشغيل (ULS & SLS).'
                        : 'الحكم الهندسي: التصميم يحتاج تعديلاً في السماكة أو التسليح (راجع فحص الهطول/القص).',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: verdictColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 3. المعطيات وتصنيف البلاطة
          _sectionTitle('1. المعطيات التصميمية وتصنيف البلاطة', primaryColor),
          pw.TableHelper.fromTextArray(
            context: ctx,
            border: pw.TableBorder.all(color: borderColor, width: 0.6),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headers: ['القيمة', 'المعامل التصميمي', 'القيمة', 'المعامل التصميمي'],
            data: [
              [
                '${topo.shortSpanLxM.toStringAsFixed(2)} m',
                'البحر القصير (lx)',
                '${load.finalDesignLoadN.toStringAsFixed(3)} kN/m²',
                'الحمل التصميمي النهائي (n)',
              ],
              [
                '${topo.longSpanLyM.toStringAsFixed(2)} m',
                'البحر الطويل (ly)',
                '${load.overallDepthHMm.toStringAsFixed(0)} mm',
                'السماكة الكلية (h)',
              ],
              [
                topo.lyOverLx.toStringAsFixed(4),
                'نسبة الاستطالة (ly/lx)',
                '${load.dxMm.toStringAsFixed(0)} / ${load.dyMm.toStringAsFixed(0)} mm',
                'العمق الفعال (dx / dy)',
              ],
              [
                topo.twoWayCase != null
                    ? 'Case ${topo.twoWayCase!.caseNumber}'
                    : 'One-Way',
                'حالة الحواف (Table 3.14)',
                '${report.settingsUsed.fcu.toStringAsFixed(0)} / ${report.settingsUsed.fy.toStringAsFixed(0)} N/mm²',
                'مقاومة المواد (fcu / fy)',
              ],
            ],
          ),
          pw.SizedBox(height: 12),

          // 4. جدول ملخص حديد التسليح النهائي
          _sectionTitle('2. جدول حديد التسليح النهائي (Table 1 & Table 2)', primaryColor),
          pw.TableHelper.fromTextArray(
            context: ctx,
            border: pw.TableBorder.all(color: borderColor, width: 0.6),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: secondaryColor),
            cellStyle: const pw.TextStyle(fontSize: 8.8),
            cellAlignment: pw.Alignment.center,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            headers: [
              'المسافة (Table 2)',
              'العدد (Table 1)',
              'As,gov (mm²)',
              'M/bd²',
              'd (mm)',
              'العزم (kN.m/m)',
              'المنطقة',
            ],
            data: report.allSteelDesigns.map((d) {
              return [
                d.barSpacingSelection?.standardNotation ?? '—',
                '${d.barCountSelection.lectureNotation} (${d.barCountSelection.areaProvidedMm2.toStringAsFixed(0)})',
                d.asGoverningMm2.toStringAsFixed(1),
                d.mOverBd2.toStringAsFixed(3),
                d.effectiveDepthMm.toStringAsFixed(0),
                d.designMomentKnM.toStringAsFixed(2),
                d.requiresDoublyReinforced
                    ? '${d.zoneTitleAr}\nA\'sc = ${d.compressionSteelMm2.toStringAsFixed(0)} mm²/m (${d.compressionBarSelection?.lectureNotation ?? "-"})'
                    : d.zoneTitleAr,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),

          // 5. رسم تخطيطي متجهي (Vector Rebar Plan Sketch) داخل الـ PDF
          _sectionTitle('3. مخطط توزيع التسليح التخطيطي للبلاطة ${report.slabId}', primaryColor),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Center(
                      child: _buildVectorSlabSketch(report),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ملخص الفحوصات والتفاصيل:',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '• فحص الهطول: d_min = ${report.deflectionCheck.dMinRequiredMm.toStringAsFixed(2)} mm (d_x = ${report.deflectionCheck.effectiveDepthMm.toStringAsFixed(0)} mm) — ${report.deflectionCheck.isSafe ? "آمن" : "غير آمن"}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '• فحص القص: v = ${report.shearCheck.designShearStressV.toStringAsFixed(3)} N/mm² مقابل vc = ${report.shearCheck.concreteShearStressVc.toStringAsFixed(3)} N/mm² — ${report.shearCheck.isSafe ? "آمن" : "غير آمن"}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '• امتداد الحديد العلوي المستمر: 0.30L، والطرفي: 0.15L.',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      if (report.torsionDetail.isRequired) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '• تسليح الالتواء عند الأركان: ${report.torsionDetail.recommendedTopMeshNotation} بمسافة ${report.torsionDetail.stripLengthMm.toStringAsFixed(0)} mm.',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 6. خطوات الحل الأكاديمي التفصيلية
          _sectionTitle('4. خطوات الحل الأكاديمي التفصيلية خطوة بخطوة', primaryColor),
          ...report.steps.map(
            (step) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.7),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الخطوة ${step.stepNumber}: ${step.titleAr}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      if (step.tableReference != null)
                        pw.Text(
                          step.tableReference!,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: secondaryColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    step.descriptionAr,
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey800,
                    ),
                  ),
                  if (step.keyValues.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    ...step.keyValues.entries.map(
                      (kv) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '• ${kv.key}:',
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                            pw.Text(
                              kv.value,
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (step.warningNoteAr != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ملاحظة: ${step.warningNoteAr!}',
                      style: pw.TextStyle(fontSize: 8, color: amberColor),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 6-ب. تصميم الكوابيل المتصلة بحواف البلاطة
          if (report.cantileverReports.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionTitle(
                '5. تصميم الكوابيل المتصلة (B.R = 7 ، V = n·lc)', primaryColor),
            pw.TableHelper.fromTextArray(
              context: ctx,
              border: pw.TableBorder.all(color: borderColor, width: 0.6),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: secondaryColor),
              cellStyle: const pw.TextStyle(fontSize: 8.3),
              cellAlignment: pw.Alignment.center,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              headers: [
                'القص',
                'الهطول',
                'حديد التوزيع',
                'الحديد العلوي',
                'العزم (kN.m/m)',
                'h / d (mm)',
                'الطول (m)',
                'الكابولي',
              ],
              data: report.cantileverReports.entries.map((e) {
                final r = e.value;
                return [
                  '${r.shearCheck.isSafe ? "آمن" : "غير آمن"} (v = ${r.shearCheck.designShearStressV.toStringAsFixed(3)} / vc = ${r.shearCheck.concreteShearStressVc.toStringAsFixed(3)})',
                  '${r.deflectionCheck.isSafe ? "آمن" : "غير آمن"} (d_min = ${r.deflectionCheck.dMinRequiredMm.toStringAsFixed(1)} / d = ${r.deflectionCheck.effectiveDepthMm.toStringAsFixed(0)})',
                  r.distributionSteel.barCountSelection.lectureNotation,
                  '${r.topSteel.barCountSelection.lectureNotation} (${r.topSteel.barSpacingSelection?.standardNotation ?? "—"})',
                  '${r.supportMomentKnM.toStringAsFixed(2)} (${r.momentSource.titleAr})',
                  '${r.loadResult.overallDepthHMm.toStringAsFixed(0)} / ${r.loadResult.dxMm.toStringAsFixed(0)}',
                  r.cantilever.lengthM.toStringAsFixed(2),
                  '${r.label} — ${e.key.titleAr}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'يمتد الحديد العلوي للكابولي داخل البلاطة المجاورة 1.5 lc على الأقل.',
              style: const pw.TextStyle(fontSize: 8.3),
            ),
          ],

          // 7. التنبيهات الختامية
          if (report.warningsAr.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FEF3C7'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: amberColor, width: 0.7),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'تنبيهات هندسية هامة:',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: amberColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...report.warningsAr.map(
                    (w) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(
                        '• $w',
                        style: const pw.TextStyle(fontSize: 8.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// تحميل الخطوط العربية واللاتينية المدمجة محلياً لملف PDF.
  /// عند الفشل: يُرمى [PdfFontLoadException] ما لم يُسمح بالبديل [allowFallback].
  static Future<pw.ThemeData> _loadPdfTheme({required bool allowFallback}) async {
    try {
      final arRegData = await rootBundle.load(_arabicRegularAsset);
      final arBoldData = await rootBundle.load(_arabicBoldAsset);
      final latRegData = await rootBundle.load(_latinRegularAsset);
      final latBoldData = await rootBundle.load(_latinBoldAsset);

      final arReg = pw.Font.ttf(arRegData);
      final arBold = pw.Font.ttf(arBoldData);
      final latReg = pw.Font.ttf(latRegData);
      final latBold = pw.Font.ttf(latBoldData);

      return pw.ThemeData.withFont(
        base: arReg,
        bold: arBold,
        fontFallback: [latReg, latBold],
      );
    } catch (e) {
      if (allowFallback) return pw.ThemeData.base();
      throw PdfFontLoadException(
        'تعذّر تحميل خطوط PDF العربية المدمجة (assets/fonts). '
        'تأكد من وجود الخطوط في pubspec.yaml وأعد بناء التطبيق. التفاصيل: $e',
      );
    }
  }

  static pw.Widget _sectionTitle(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// رسم متجهي نظيف لمسقط تسليح البلاطة داخل PDF
  static pw.Widget _buildVectorSlabSketch(SlabDesignReport report) {
    final topo = report.topology;
    final sum = report.summaryRow;

    return pw.Container(
      width: 220,
      height: 155,
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: const PdfPoint(220, 155),
            painter: (PdfGraphics canvas, PdfPoint size) {
              const left = 30.0;
              const bottom = 28.0;
              const w = 160.0;
              const h = 100.0;

              // حدود البلاطة
              canvas
                ..setFillColor(PdfColor.fromHex('#EFF6FF'))
                ..drawRect(left, bottom, w, h)
                ..fillPath()
                ..setStrokeColor(PdfColor.fromHex('#0F3D5E'))
                ..setLineWidth(1.6)
                ..drawRect(left, bottom, w, h)
                ..strokePath();

              // الكوابيل المتصلة (رسم تخطيطي غير مقيّس بطول ثابت)
              const double stub = 24.0;
              for (final cSide in report.cantilevers.keys) {
                final bool horiz =
                    cSide == EdgeSide.left || cSide == EdgeSide.right;
                final double rx = cSide == EdgeSide.left
                    ? left - stub
                    : (cSide == EdgeSide.right ? left + w : left);
                final double ry = cSide == EdgeSide.bottom
                    ? bottom - stub
                    : (cSide == EdgeSide.top ? bottom + h : bottom);
                final double rw = horiz ? stub : w;
                final double rh = horiz ? h : stub;
                canvas
                  ..setFillColor(PdfColor.fromHex('#E2E8F0'))
                  ..drawRect(rx, ry, rw, rh)
                  ..fillPath()
                  ..setStrokeColor(PdfColor.fromHex('#64748B'))
                  ..setLineWidth(1.2)
                  ..drawRect(rx, ry, rw, rh)
                  ..strokePath();
              }

              // الفرش السفلي (أفقي)
              canvas
                ..setStrokeColor(PdfColor.fromHex('#1D4ED8'))
                ..setLineWidth(1.8)
                ..drawLine(left + 8, bottom + h * 0.45, left + w - 8, bottom + h * 0.45)
                ..strokePath();

              // الغطاء السفلي (رأسي)
              canvas
                ..setStrokeColor(PdfColor.fromHex('#0D9488'))
                ..setLineWidth(1.6)
                ..drawLine(left + w * 0.55, bottom + 8, left + w * 0.55, bottom + h - 8)
                ..strokePath();

              // الحديد العلوي (أحمر متقطع على الحواف المستمرة؛ يبدأ من طرف الكابولي الحر إن وُجد)
              final double tipL =
                  report.cantilevers.containsKey(EdgeSide.left) ? stub - 2 : 6;
              final double tipR =
                  report.cantilevers.containsKey(EdgeSide.right) ? stub - 2 : 6;
              final double tipT =
                  report.cantilevers.containsKey(EdgeSide.top) ? stub - 2 : 6;
              final double tipB =
                  report.cantilevers.containsKey(EdgeSide.bottom) ? stub - 2 : 6;
              canvas
                ..setStrokeColor(PdfColor.fromHex('#DC2626'))
                ..setLineWidth(1.4)
                ..setLineDashPattern([4, 3]);
              if (topo.topEdge.isContinuous) {
                canvas.drawLine(
                  left + w * 0.35,
                  bottom + h + tipT,
                  left + w * 0.35,
                  bottom + h - h * 0.3,
                );
              }
              if (topo.bottomEdge.isContinuous) {
                canvas.drawLine(
                  left + w * 0.35,
                  bottom - tipB,
                  left + w * 0.35,
                  bottom + h * 0.3,
                );
              }
              if (topo.leftEdge.isContinuous) {
                canvas.drawLine(
                  left - tipL,
                  bottom + h * 0.65,
                  left + w * 0.3,
                  bottom + h * 0.65,
                );
              }
              if (topo.rightEdge.isContinuous) {
                canvas.drawLine(
                  left + w + tipR,
                  bottom + h * 0.65,
                  left + w - w * 0.3,
                  bottom + h * 0.65,
                );
              }
              canvas.strokePath();
            },
          ),
          // التسميات الرقمية على الرسم
          pw.Positioned(
            top: 4,
            left: 35,
            child: pw.Text(
              'X = ${topo.widthXM.toStringAsFixed(2)} m  |  Y = ${topo.heightYM.toStringAsFixed(2)} m',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ),
          pw.Positioned(
            top: 64,
            left: 58,
            child: pw.Text(
              'Short: ${sum.shortMidLecture}',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1D4ED8'),
              ),
            ),
          ),
          pw.Positioned(
            top: 82,
            left: 58,
            child: pw.Text(
              'Long: ${sum.longMidLecture}',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0D9488'),
              ),
            ),
          ),
          pw.Positioned(
            bottom: 4,
            left: 44,
            child: pw.Text(
              'Top Sup (Y): ${topo.isShortSpanHorizontal ? sum.longSupportAllLecture() : sum.shortSupportAllLecture()} | (X): ${topo.isShortSpanHorizontal ? sum.shortSupportAllLecture() : sum.longSupportAllLecture()}',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#DC2626'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
