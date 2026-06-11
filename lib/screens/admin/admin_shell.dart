// Layout base de administracion con sidebar, campana y conexion a notificaciones.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../widgets/responsive.dart';
import '../../features/notificaciones/notification_bell.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final mobile = Responsive.isMobile(context);
    usuario.whenData((u) => _conectarNotificaciones(context, ref, u));
    final sidebar = _AdminSidebar(
      usuario: usuario,
      location: location,
      noLeidas: ref.watch(contadorNotificacionesNoLeidasProvider),
      onLogout: () async {
        ref.read(notificationSocketServiceProvider).disconnect();
        await ref.read(apiServiceProvider).logout();
        ref.invalidate(usuarioActualProvider);
        ref.invalidate(notificacionesProvider);
        ref.invalidate(contadorNotificacionesNoLeidasProvider);

        if (context.mounted) {
          context.go('/login');
        }
      },
    );

    return Scaffold(
      appBar: mobile
          ? AppBar(
              title: const Text('TECNERO'),
              actions: const [NotificationBell()],
            )
          : null,
      drawer: mobile ? Drawer(child: sidebar) : null,
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

class _AdminSidebar extends StatelessWidget {
  final AsyncValue<dynamic> usuario;
  final String location;
  final AsyncValue<int> noLeidas;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.usuario,
    required this.location,
    required this.noLeidas,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TecneroTheme.azulOscuro,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Logo(),
            usuario.when(
              data: (u) => u == null ? const SizedBox() : _UsuarioCard(u: u),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  const SizedBox(height: 6),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    path: '/admin/dashboard',
                    active: location == '/admin/dashboard',
                  ),
                  _NavItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Compras',
                    path: '/admin/precios',
                    active: location == '/admin/precios',
                  ),
                  _NavItem(
                    icon: Icons.precision_manufacturing_outlined,
                    label: 'Producción',
                    path: '/admin/produccion',
                    active: location == '/admin/produccion',
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Solicitudes',
                    path: '/admin/solicitudes',
                    active: location == '/admin/solicitudes',
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reportes',
                    path: '/admin/reportes',
                    active: location == '/admin/reportes',
                  ),
                  _NavItem(
                    icon: Icons.notifications_none,
                    label: 'Notificaciones',
                    path: '/admin/notificaciones',
                    active: location == '/admin/notificaciones',
                    badge: noLeidas.when(
                      data: (n) => n > 0 ? '$n' : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _NavItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                path: '/login',
                active: false,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

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
              color: TecneroTheme.naranja,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: TecneroTheme.azulOscuro,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TECNERO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  final dynamic u;

  const _UsuarioCard({required this.u});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: TecneroTheme.naranja,
            child: Text(
              u.iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombre.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  u.rolLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.active,
    this.badge,
    this.onTap,
  });

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
            Icon(
              icon,
              size: 18,
              color: active ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? Colors.white : Colors.white54,
                  fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TecneroTheme.naranja,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
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
          ref.read(dashboardRefreshProvider.notifier).state++;

          if (!context.mounted) return;
          _mostrarNotificacion(
            context,
            titulo: notificacion.titulo,
            mensaje: notificacion.mensaje,
            onVer: () => context.go('/admin/notificaciones'),
          );
        },
      );
}

void _refrescarDatosPorNotificacion(WidgetRef ref) {
  ref.invalidate(solicitudesPendientesProvider);
  ref.invalidate(contadorPendientesProvider);
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
