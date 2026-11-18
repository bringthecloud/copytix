import 'package:flutter/material.dart';

import 'app_config.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import 'design_system_preview_page.dart';

class CopytixApp extends StatelessWidget {
  const CopytixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      title: AppConfig.appName,
      theme: AppTheme.light,

      initialRoute: AppRoutes.designSystemPreview,

      routes: {
        AppRoutes.designSystemPreview: (context) =>
            const DesignSystemPreviewPage(),
      },
    );
  }
}
