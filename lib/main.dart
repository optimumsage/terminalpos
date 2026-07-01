import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'data/repositories.dart';

void main() {
  runApp(const ProviderScope(child: TerminalPosApp()));
}

class TerminalPosApp extends ConsumerWidget {
  const TerminalPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings so theme reacts to changes; also triggers first-run
    // seeding of defaults + preset templates.
    final settings = ref.watch(settingsProvider);
    final seed = settings.value?.seedColor ?? 0xFF3D5AFE;
    final mode = themeModeFromString(settings.value?.themeMode ?? 'system');

    return MaterialApp.router(
      title: 'TerminalPOS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(seed, Brightness.light),
      darkTheme: buildTheme(seed, Brightness.dark),
      themeMode: mode,
      routerConfig: appRouter,
    );
  }
}
