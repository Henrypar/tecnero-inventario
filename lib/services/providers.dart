// Providers Riverpod para compartir estado, servicios y refrescos entre pantallas.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_socket_service.dart';
import '../features/notificaciones/notificaciones_service.dart';
import '../models/models.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final notificacionesServiceProvider = Provider<NotificacionesService>((ref) {
  return NotificacionesService(ref.read(apiServiceProvider));
});

final notificationSocketServiceProvider =
    Provider<NotificationSocketService>((ref) {
  final service = NotificationSocketService();
  ref.onDispose(service.dispose);
  return service;
});

// Usuario autenticado actual
final usuarioActualProvider = FutureProvider<Usuario?>((ref) async {
  return await ref.read(apiServiceProvider).getUsuarioActual();
});

final operariosProvider = FutureProvider<List<Usuario>>((ref) async {
  return await ref.read(apiServiceProvider).getUsuarios(rol: 'operario');
});

// Materiales
final materialesProvider = FutureProvider<List<Material>>((ref) async {
  return await ref.read(apiServiceProvider).getMateriales();
});

// Materiales con precios (solo admin)
final materialesConPreciosProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await ref.read(apiServiceProvider).getMaterialesConPrecios();
});

final historialIngresosInventarioProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await ref.read(apiServiceProvider).getHistorialIngresosInventario();
});
final misSolicitudesProvider = FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getMisSolicitudes();
});
// Líneas de producción
final lineasProvider = FutureProvider<List<LineaProduccion>>((ref) async {
  return await ref.read(apiServiceProvider).getLineas();
});

final materialesPorLineaProvider =
    FutureProvider.family<List<LineaMaterialSugerido>, String>((ref, lineaId) {
  return ref.read(apiServiceProvider).getMaterialesPorLinea(lineaId);
});

// Solicitudes pendientes de despacho (bodega)
final solicitudesPendientesProvider =
    FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getSolicitudes(estado: 'pendiente');
});

final solicitudesPendientesBodegaProvider =
    FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getSolicitudesPendientesBodega();
});

// Solicitudes aprobadas (compatibilidad con flujo anterior)
final solicitudesAprobadasProvider =
    FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getSolicitudesAprobadas();
});

// Todas las solicitudes (admin/coordinador)
final todasSolicitudesProvider = FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getSolicitudes();
});

// Contador de pendientes para badge
final contadorPendientesProvider = FutureProvider<int>((ref) async {
  final solicitudes = await ref.watch(solicitudesPendientesProvider.future);
  return solicitudes.length;
});

// Dashboard data
final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final ahora = DateTime.now();
  final inicioMes = DateTime(ahora.year, ahora.month, 1);
  return await ref.read(apiServiceProvider).getDashboardData(
        desde: inicioMes,
        hasta: ahora,
      );
});

// Disparador ligero para refrescar los dashboards cuando entra una notificacion
// o se modifica un flujo que impacta en costos y solicitudes.
final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

final produccionDiariaProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final ahora = DateTime.now();
  final inicioMes = DateTime(ahora.year, ahora.month, 1);
  return ref.read(apiServiceProvider).getProduccionDiaria(
        desde: inicioMes,
        hasta: ahora,
      );
});
final solicitudesEntregadasProvider =
    FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getSolicitudesEntregadas();
});

final solicitudesHistorialBodegaProvider =
    FutureProvider<List<Solicitud>>((ref) async {
  return await ref.read(apiServiceProvider).getHistorialBodega();
});

final notificacionesProvider =
    FutureProvider<List<NotificacionInterna>>((ref) async {
  final usuario = await ref.watch(usuarioActualProvider.future);
  final api = ref.read(apiServiceProvider);
  if (usuario == null || api.token == null) return [];

  return await ref.read(notificacionesServiceProvider).obtenerNotificaciones();
});

final contadorNotificacionesNoLeidasProvider = FutureProvider<int>((ref) async {
  final usuario = await ref.watch(usuarioActualProvider.future);
  final api = ref.read(apiServiceProvider);
  if (usuario == null || api.token == null) return 0;

  return await ref
      .read(notificacionesServiceProvider)
      .obtenerCantidadNoLeidas();
});
