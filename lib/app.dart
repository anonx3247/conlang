import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

/// Root application widget. Wires up MaterialApp.router with go_router.
class ConlangApp extends ConsumerWidget {
  const ConlangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Conlang Workbench',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

/// Professional dark theme for a desktop linguistic tool.
ThemeData _buildDarkTheme() {
  const seedColor = Color(0xFF5B8DEF); // Professional blue

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'monospace',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 12),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.5),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}

ThemeData _buildLightTheme() {
  const seedColor = Color(0xFF1A56DB);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 12),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.5),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}
