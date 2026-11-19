import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/code_browser/code_browser_screen.dart';
import '../../presentation/screens/floor_grid/floor_grid_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/projects/saved_projects_screen.dart';
import '../../presentation/screens/report/slab_report_screen.dart';
import '../../presentation/screens/single_slab/single_slab_screen.dart';

/// مسارات التنقل المركزية للتطبيق
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String singleSlab = '/single-slab';
  static const String slabReport = '/slab-report';
  static const String floorGrid = '/floor-grid';
  static const String codeBrowser = '/code-browser';
  static const String savedProjects = '/saved-projects';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.singleSlab,
        name: 'singleSlab',
        builder: (context, state) => const SingleSlabScreen(),
      ),
      GoRoute(
        path: AppRoutes.slabReport,
        name: 'slabReport',
        builder: (context, state) => const SlabReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.floorGrid,
        name: 'floorGrid',
        builder: (context, state) => const FloorGridScreen(),
      ),
      GoRoute(
        path: AppRoutes.codeBrowser,
        name: 'codeBrowser',
        builder: (context, state) => const CodeBrowserScreen(),
      ),
      GoRoute(
        path: AppRoutes.savedProjects,
        name: 'savedProjects',
        builder: (context, state) => const SavedProjectsScreen(),
      ),
    ],
  );
});
