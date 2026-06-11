// Icono de campana con contador de notificaciones no leidas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

class NotificationBell extends ConsumerWidget {
  final Color? iconColor;

  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contador = ref.watch(contadorNotificacionesNoLeidasProvider);
    final usuario = ref.watch(usuarioActualProvider).valueOrNull;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.go(_rutaNotificaciones(usuario?.rol)),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none,
            color: iconColor,
          ),
          contador.when(
            data: (cantidad) {
              if (cantidad <= 0) return const SizedBox.shrink();

              return Positioned(
                right: -7,
                top: -7,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: TecneroTheme.naranja,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      cantidad > 99 ? '99+' : '$cantidad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

String _rutaNotificaciones(RolUsuario? rol) {
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
    case null:
      return '/notificaciones';
  }
}
