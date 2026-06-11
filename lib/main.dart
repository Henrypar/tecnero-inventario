// Punto de entrada de Flutter y configuracion global de la aplicacion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: TecneroApp(),
    ),
  );
}

class TecneroApp extends ConsumerWidget {
  const TecneroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TECNERO — Gestión de Inventarios',
      debugShowCheckedModeBanner: false,
      theme: TecneroTheme.light,
      routerConfig: router,
    );
  }
}
