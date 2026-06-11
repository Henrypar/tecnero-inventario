// Fachada de API para consultas y actualizacion de notificaciones.
import '../../models/models.dart';
import '../../services/api_service.dart';

class NotificacionesService {
  final ApiService _api;

  const NotificacionesService(this._api);

  Future<List<NotificacionInterna>> obtenerNotificaciones() {
    return _api.getNotificaciones();
  }

  Future<int> obtenerCantidadNoLeidas() {
    return _api.getCantidadNotificacionesNoLeidas();
  }

  Future<void> marcarComoLeida(String id) {
    return _api.marcarNotificacionComoLeida(id);
  }

  Future<void> marcarTodasComoLeidas() {
    return _api.marcarTodasNotificacionesComoLeidas();
  }
}
