import 'package:flutter/material.dart';

import 'app_config.dart';

class DesignSystemPreviewPage extends StatefulWidget {
  const DesignSystemPreviewPage({super.key});

  @override
  State<DesignSystemPreviewPage> createState() =>
      _DesignSystemPreviewPageState();
}

class _DesignSystemPreviewPageState extends State<DesignSystemPreviewPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to ${AppConfig.appName}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(AppConfig.appTagline, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            const Text(
              'Design System Preview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('$_counter', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _incrementCounter,
              icon: const Icon(Icons.add),
              label: const Text('Test Button'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Secondary Button'),
            ),
          ],
        ),
      ),
    );
  }
}
