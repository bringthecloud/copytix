import 'package:flutter/material.dart';

import 'app_config.dart';
import '../core/theme/app_theme.dart';
import 'design_system_preview_page.dart';

class CopytixApp extends StatelessWidget {
  const CopytixApp({super.key, this.home});

  /// Runtime app passes [AuthGate]. Tests and design previews can omit it.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      title: AppConfig.appName,
      theme: AppTheme.light,
      home: home ?? const DesignSystemPreviewPage(),
    );
  }
}
