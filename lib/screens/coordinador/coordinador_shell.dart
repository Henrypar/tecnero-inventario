// Layout base del coordinador con sidebar y notificaciones.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../widgets/responsive.dart';
import '../../features/notificaciones/notification_bell.dart';

class CoordinadorShell extends ConsumerWidget {
  final Widget child;
  const CoordinadorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final location = GoRouterState.of(context).matchedLocation;
    usuario.whenData((u) => _conectarNotificaciones(context, ref, u));

    return _ResponsiveShell(
      sidebar: Container(
        color: TecneroTheme.azulOscuro,
        child: Column(
          children: [
            _Logo(),
            usuario.when(
              data: (u) =>
                  u == null ? const SizedBox() : _UsuarioCard(usuario: u),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    _NavItem(
                      icon: Icons.visibility_outlined,
                      label: 'Despachos',
                      path: '/coordinador/aprobaciones',
                      active: location == '/coordinador/aprobaciones',
                    ),
                    /* _NavItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Dashboard costos',
                      path: '/coordinador/dashboard',
                      active: location == '/coordinador/dashboard',
                    ), */
                    _NavItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      path: '/coordinador/notificaciones',
                      active: location == '/coordinador/notificaciones',
                      badge: ref
                          .watch(contadorNotificacionesNoLeidasProvider)
                          .when(
                            data: (n) => n > 0 ? '$n' : null,
                            loading: () => null,
                            error: (_, __) => null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _NavItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                path: '/login',
                active: false,
                onTap: () async {
                  await ref.read(apiServiceProvider).logout();

                  ref.invalidate(usuarioActualProvider);
                  ref.invalidate(contadorPendientesProvider);
                  ref.invalidate(solicitudesPendientesBodegaProvider);
                  ref.invalidate(notificacionesProvider);
                  ref.invalidate(contadorNotificacionesNoLeidasProvider);
                  ref.read(notificationSocketServiceProvider).disconnect();

                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class OperarioShell extends ConsumerWidget {
  final Widget child;
  const OperarioShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final location = GoRouterState.of(context).matchedLocation;
    usuario.whenData((u) => _conectarNotificaciones(context, ref, u));

    return _ResponsiveShell(
      sidebar: Container(
        color: TecneroTheme.azulOscuro,
        child: Column(
          children: [
            _Logo(),
            usuario.when(
              data: (u) =>
                  u == null ? const SizedBox() : _UsuarioCard(usuario: u),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    _NavItem(
                      icon: Icons.add_circle_outline,
                      label: 'Nueva solicitud',
                      path: '/operario/nueva-solicitud',
                      active: location == '/operario/nueva-solicitud',
                    ),
                    _NavItem(
                      icon: Icons.list_alt_outlined,
                      label: 'Mis solicitudes',
                      path: '/operario/mis-solicitudes',
                      active: location == '/operario/mis-solicitudes',
                    ),
                    _NavItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      path: '/operario/notificaciones',
                      active: location == '/operario/notificaciones',
                      badge: ref
                          .watch(contadorNotificacionesNoLeidasProvider)
                          .when(
                            data: (n) => n > 0 ? '$n' : null,
                            loading: () => null,
                            error: (_, __) => null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _NavItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                path: '/login',
                active: false,
                onTap: () async {
                  await ref.read(apiServiceProvider).logout();

                  ref.invalidate(usuarioActualProvider);
                  ref.invalidate(contadorPendientesProvider);
                  ref.invalidate(solicitudesPendientesBodegaProvider);
                  ref.invalidate(notificacionesProvider);
                  ref.invalidate(contadorNotificacionesNoLeidasProvider);
                  ref.read(notificationSocketServiceProvider).disconnect();

                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class BodegueroShell extends ConsumerWidget {
  final Widget child;
  const BodegueroShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final pendientes = ref.watch(solicitudesPendientesBodegaProvider);
    final location = GoRouterState.of(context).matchedLocation;
    usuario.whenData((u) => _conectarNotificaciones(context, ref, u));

    return _ResponsiveShell(
      sidebar: Container(
        color: TecneroTheme.azulOscuro,
        child: Column(
          children: [
            _Logo(),
            usuario.when(
              data: (u) =>
                  u == null ? const SizedBox() : _UsuarioCard(usuario: u),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Entregas pendientes',
                      path: '/bodeguero/entregas',
                      active: location == '/bodeguero/entregas',
                      badge: pendientes.when(
                        data: (l) => l.isNotEmpty ? '${l.length}' : null,
                        loading: () => null,
                        error: (_, __) => null,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.history,
                      label: 'Historial',
                      path: '/bodeguero/historial',
                      active: location == '/bodeguero/historial',
                    ),
                    _NavItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      path: '/bodeguero/notificaciones',
                      active: location == '/bodeguero/notificaciones',
                      badge: ref
                          .watch(contadorNotificacionesNoLeidasProvider)
                          .when(
                            data: (n) => n > 0 ? '$n' : null,
                            loading: () => null,
                            error: (_, __) => null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _NavItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                path: '/login',
                active: false,
                onTap: () async {
                  await ref.read(apiServiceProvider).logout();

                  ref.invalidate(usuarioActualProvider);
                  ref.invalidate(contadorPendientesProvider);
                  ref.invalidate(solicitudesPendientesBodegaProvider);
                  ref.invalidate(notificacionesProvider);
                  ref.invalidate(contadorNotificacionesNoLeidasProvider);
                  ref.read(notificationSocketServiceProvider).disconnect();

                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ── Widgets compartidos entre shells ───────────────────────

class _ResponsiveShell extends ConsumerWidget {
  final Widget child;
  final Widget sidebar;

  const _ResponsiveShell({
    required this.child,
    required this.sidebar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: mobile
          ? AppBar(
              title: const Text('TECNERO'),
              actions: const [NotificationBell()],
            )
          : null,
      drawer: mobile
          ? Drawer(child: SafeArea(bottom: false, child: sidebar))
          : null,
      body: mobile
          ? child
          : Row(
              children: [
                SizedBox(width: 220, child: sidebar),
                Expanded(child: child),
              ],
            ),
    );
  }
}

void _conectarNotificaciones(
  BuildContext context,
  WidgetRef ref,
  dynamic usuario,
) {
  if (usuario == null) return;

  ref.read(notificationSocketServiceProvider).connect(
        usuarioId: usuario.id,
        onNuevaNotificacion: (notificacion) {
          ref.invalidate(notificacionesProvider);
          ref.invalidate(contadorNotificacionesNoLeidasProvider);
          _refrescarDatosPorNotificacion(ref);

          if (!context.mounted) return;
          _mostrarNotificacion(
            context,
            titulo: notificacion.titulo,
            mensaje: notificacion.mensaje,
            onVer: () => context.go(_rutaNotificaciones(usuario.rol)),
          );
        },
      );
}

void _refrescarDatosPorNotificacion(WidgetRef ref) {
  ref.invalidate(solicitudesPendientesProvider);
  ref.invalidate(contadorPendientesProvider);
  ref.invalidate(solicitudesPendientesBodegaProvider);
  ref.invalidate(solicitudesAprobadasProvider);
  ref.invalidate(misSolicitudesProvider);
  ref.invalidate(todasSolicitudesProvider);
  ref.invalidate(solicitudesEntregadasProvider);
  ref.invalidate(dashboardProvider);
}

void _mostrarNotificacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required VoidCallback onVer,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$titulo: $mensaje'),
      action: SnackBarAction(
        label: 'Ver',
        onPressed: onVer,
      ),
      showCloseIcon: true,
      closeIconColor: Colors.white,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String _rutaNotificaciones(dynamic rol) {
  switch (rol.toString().split('.').last) {
    case 'coordinador':
      return '/coordinador/notificaciones';
    case 'operario':
      return '/operario/notificaciones';
    case 'bodeguero':
      return '/bodeguero/notificaciones';
    case 'admin':
      return '/admin/notificaciones';
    default:
      return '/notificaciones';
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: TecneroTheme.naranja, shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                    color: TecneroTheme.azulOscuro, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('TECNERO',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  final dynamic usuario;
  const _UsuarioCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: TecneroTheme.naranja,
            child: Text(usuario.iniciales,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario.nombre.split(' ').first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                Text(usuario.rolLabel,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool active;
  final String? badge;
  final VoidCallback? onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.path,
      required this.active,
      this.badge,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final drawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
        if (drawerOpen) Navigator.of(context).pop();

        if (onTap != null) {
          onTap!();
          return;
        }

        context.go(path);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? TecneroTheme.naranja.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : Colors.white54),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: active ? Colors.white : Colors.white54,
                        fontWeight:
                            active ? FontWeight.w500 : FontWeight.normal))),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: TecneroTheme.naranja,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
