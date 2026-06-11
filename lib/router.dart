// Rutas de la app organizadas por rol y shell principal.
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/providers.dart';
import '../features/notificaciones/notificaciones_page.dart';
import '../screens/login_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/precios_screen.dart';
import '../screens/admin/produccion_screen.dart';
import '../screens/admin/solicitudes_admin_screen.dart' hide ReportesScreen;
import '../screens/admin/reportes_screen.dart';
import '../screens/coordinador/coordinador_shell.dart';
import '../screens/coordinador/aprobaciones_screen.dart';
import '../screens/coordinador/dashboard_coord_screen.dart';
import '../screens/operario/operario_shell.dart';
import '../screens/operario/nueva_solicitud_screen.dart';
import '../screens/operario/mis_solicitudes_screen.dart';
import '../screens/bodeguero/bodeguero_shell.dart';
import '../screens/bodeguero/entregas_screen.dart';
import '../screens/bodeguero/historial_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final usuario = await ref.read(usuarioActualProvider.future);
      final enLogin = state.matchedLocation == '/login';

      if (usuario == null && !enLogin) return '/login';
      if (usuario != null && state.matchedLocation == '/notificaciones') {
        return _rutaNotificacionesPorRol(usuario.rol);
      }
      if (usuario != null && enLogin) {
        return _rutaPorRol(usuario.rol);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/notificaciones',
        redirect: (context, state) async {
          final usuario = await ref.read(usuarioActualProvider.future);
          return usuario == null
              ? '/login'
              : _rutaNotificacionesPorRol(usuario.rol);
        },
      ),
      GoRoute(
        path: '/admin/notificaciones',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminShell(
            child: NotificacionesPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/coordinador/notificaciones',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CoordinadorShell(
            child: NotificacionesPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/operario/notificaciones',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: OperarioShell(
            child: NotificacionesPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/bodeguero/notificaciones',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: BodegueroShell(
            child: NotificacionesPage(),
          ),
        ),
      ),

      // ── ADMIN ──────────────────────────────────────────
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: AdminShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/precios',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PreciosScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/produccion',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProduccionScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/solicitudes',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SolicitudesAdminScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/reportes',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportesScreen(),
            ),
          ),
        ],
      ),

      // ── COORDINADOR ────────────────────────────────────
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: CoordinadorShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/coordinador/aprobaciones',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AprobacionesScreen(),
            ),
          ),
          GoRoute(
            path: '/coordinador/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardCoordScreen(),
            ),
          ),
        ],
      ),
      // ── OPERARIO ───────────────────────────────────────
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: OperarioShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/operario/nueva-solicitud',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NuevaSolicitudScreen(),
            ),
          ),
          GoRoute(
            path: '/operario/mis-solicitudes',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MisSolicitudesScreen(),
            ),
          ),
        ],
      ),

      // ── BODEGUERO ──────────────────────────────────────
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: BodegueroShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/bodeguero/entregas',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EntregasScreen(),
            ),
          ),
          GoRoute(
            path: '/bodeguero/historial',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistorialScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

String _rutaPorRol(RolUsuario rol) {
  switch (rol) {
    case RolUsuario.admin:
      return '/admin/dashboard';
    case RolUsuario.coordinador:
      return '/coordinador/aprobaciones';
    case RolUsuario.operario:
      return '/operario/nueva-solicitud';
    case RolUsuario.bodeguero:
      return '/bodeguero/entregas';
    case RolUsuario.asistenteCompras:
      return '/admin/precios';
  }
}

String _rutaNotificacionesPorRol(RolUsuario rol) {
  switch (rol) {
    case RolUsuario.admin:
      return '/admin/notificaciones';
    case RolUsuario.coordinador:
      return '/coordinador/notificaciones';
    case RolUsuario.operario:
      return '/operario/notificaciones';
    case RolUsuario.bodeguero:
      return '/bodeguero/notificaciones';
    case RolUsuario.asistenteCompras:
      return '/admin/notificaciones';
  }
}
