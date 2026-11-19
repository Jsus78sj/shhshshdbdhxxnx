import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../../data/bs8110/bs8110_tables.dart';
import '../models/slab_design_report.dart';
import '../models/slab_enums.dart';
import '../models/slab_project_settings.dart';

/// فاحص إجهاد القص للبلاطة المصمتة وفق Table 3.15, Table 3.8, Table 3.16
class ShearChecker {
  ShearChecker._();

  static ShearCheckResult check({
    required ResolvedTopology topology,
    required double designLoadN,
    required double dxMm,
    required double dyMm,
    required double overallDepthHMm,
    required SectionReinforcementDesign shortSupportSteel,
    required SectionReinforcementDesign longSupportSteel,
    required SlabProjectSettings settings,
  }) {
    const double b = AppConstants.stripWidth;
    final double lx = topology.shortSpanLxM;

    double? bVxCont;
    double? bVxDisc;
    double? bVyCont;
    double? bVyDisc;
    double govBetaV;
    String govEdgeAr;
    double govDepthMm;
    double govAsProvidedMm2;

    if (topology.spanningType == SlabSpanningType.twoWay &&
        topology.twoWayCase != null) {
      final sh = SlabMomentShearTables.getShearCoefficients(
        panelCase: topology.twoWayCase!,
        lyOverLx: topology.lyOverLx,
      );
      bVxCont = sh.betaVxCont;
      bVxDisc = sh.betaVxDisc;
      bVyCont = sh.betaVyCont;
      bVyDisc = sh.betaVyDisc;

      final double maxVx = math.max(bVxCont ?? 0.0, bVxDisc ?? 0.0);
      final double maxVy = math.max(bVyCont ?? 0.0, bVyDisc ?? 0.0);

      // اختيار الحافة الحاكمة (مع الأخذ بالحسبان أن dy أصغر من dx)
      final double vRatioX = maxVx / dxMm;
      final double vRatioY = maxVy / dyMm;

      if (vRatioY >= vRatioX && maxVy > 0) {
        govBetaV = maxVy;
        govEdgeAr = (bVyCont != null && bVyCont >= (bVyDisc ?? 0.0))
            ? 'الحافة المستمرة في الاتجاه الطويل (βvy)'
            : 'الحافة غير المستمرة في الاتجاه الطويل (βvy)';
        govDepthMm = dyMm;
        govAsProvidedMm2 = longSupportSteel.barCountSelection.areaProvidedMm2;
      } else {
        govBetaV = maxVx;
        govEdgeAr = (bVxCont != null && bVxCont >= (bVxDisc ?? 0.0))
            ? 'الحافة المستمرة في الاتجاه القصير (βvx)'
            : 'الحافة غير المستمرة في الاتجاه القصير (βvx)';
        govDepthMm = dxMm;
        govAsProvidedMm2 = shortSupportSteel.barCountSelection.areaProvidedMm2;
      }
    } else if (topology.spanningType == SlabSpanningType.cantilever) {
      govBetaV = 1.0;
      govEdgeAr = 'مسند الكابولي (V = n · lc)';
      govDepthMm = dxMm;
      govAsProvidedMm2 = shortSupportSteel.barCountSelection.areaProvidedMm2;
    } else {
      // One-Way Slab
      govBetaV = topology.isShortSpanContinuous ? 0.60 : 0.50;
      govEdgeAr = topology.isShortSpanContinuous
          ? 'المسند الداخلي الأول لبلاطة اتجاه واحد (0.60 F)'
          : 'مسند بلاطة اتجاه واحد بسيطة (0.50 F)';
      govDepthMm = dxMm;
      govAsProvidedMm2 = shortSupportSteel.barCountSelection.areaProvidedMm2;
    }

    final double vMaxKnPerM = govBetaV * designLoadN * lx;
    final double designShearStressV = (vMaxKnPerM * 1000.0) / (b * govDepthMm);
    final double rhoPercent = (100.0 * govAsProvidedMm2) / (b * govDepthMm);

    final double vc = ShearTables.calculateConcreteShearStressVc(
      asProvidedMm2: govAsProvidedMm2,
      bvMm: b,
      dMm: govDepthMm,
      fcu: settings.fcu,
    );

    final table316 = ShearTables.checkSolidSlabShear(
      designShearStressV: designShearStressV,
      concreteShearStressVc: vc,
      fcu: settings.fcu,
      overallDepthHMm: overallDepthHMm,
    );

    return ShearCheckResult(
      betaVxCont: bVxCont,
      betaVxDisc: bVxDisc,
      betaVyCont: bVyCont,
      betaVyDisc: bVyDisc,
      governingBetaV: govBetaV,
      governingEdgeAr: govEdgeAr,
      vMaxKnPerM: vMaxKnPerM,
      governingDepthMm: govDepthMm,
      designShearStressV: designShearStressV,
      tensionSteelPercent: rhoPercent,
      concreteShearStressVc: vc,
      table316Result: table316,
    );
  }
}
