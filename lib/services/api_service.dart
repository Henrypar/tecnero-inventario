// Cliente HTTP central que consume la API NestJS y traduce JSON a modelos de la app.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiConnectionException extends ApiException {
  const ApiConnectionException(super.message);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static String get baseUrl {
    final uri = Uri.parse(_configuredBaseUrl);

    if (!kIsWeb && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return uri.replace(host: '10.0.2.2').toString();
      }
    }

    return _configuredBaseUrl;
  }

  final http.Client _client = http.Client();
  String? _token;
  Usuario? _usuarioActual;

  Usuario? get currentUser => _usuarioActual;
  String? get token => _token;

  static String get socketBaseUrl {
    final apiUri = Uri.parse(baseUrl);
    final path = apiUri.path.endsWith('/api')
        ? apiUri.path.substring(0, apiUri.path.length - 4)
        : apiUri.path;
    return apiUri.replace(path: path.isEmpty ? '/' : path).toString();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Usuario> login(String email, String password) async {
    final data = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );

    _token = data['access_token'] as String?;
    _usuarioActual = Usuario.fromJson(data['usuario']);
    return _usuarioActual!;
  }

  Future<void> logout() async {
    _token = null;
    _usuarioActual = null;
  }

  Future<void> editarSolicitud({
    required String id,
    required String lineaId,
    required String lineaNombre,
    required String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    await _request(
      'PATCH',
      '/solicitudes/$id',
      body: {
        'linea_id': lineaId,
        'linea_nombre': lineaNombre,
        'observaciones': observaciones,
        'items': items,
      },
    );
  }

  Future<Usuario?> getUsuarioActual() async {
    if (_token == null) return _usuarioActual;

    final data = await _request('GET', '/auth/perfil');
    _usuarioActual = Usuario.fromJson(data);
    return _usuarioActual;
  }

  Future<List<Usuario>> getUsuarios({String? rol}) async {
    final data = await _request(
      'GET',
      '/auth/usuarios',
      query: {
        if (rol != null) 'rol': rol,
      },
    );
    return (data as List).map((u) => Usuario.fromJson(u)).toList();
  }

  Future<List<Material>> getMateriales() async {
    final data = await _request('GET', '/materiales');
    return (data as List).map((m) => Material.fromJson(m)).toList();
  }

  Future<double> getPrecioActual(String materialId) async {
    final data = await _request('GET', '/precios/$materialId/actual');
    return (data['precio'] as num).toDouble();
  }

  Future<List<PrecioMaterial>> getHistorialPrecios(String materialId) async {
    final data = await _request('GET', '/precios/$materialId/historial');
    return (data as List).map((p) => PrecioMaterial.fromJson(p)).toList();
  }

  Future<List<Map<String, dynamic>>> getMaterialesConPrecios() async {
    final data = await _request('GET', '/materiales/con-precio');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> actualizarPrecio({
    required String materialId,
    required double nuevoPrecio,
    required String registradoPor,
  }) async {
    await _request(
      'POST',
      '/precios/$materialId',
      body: {
        'precio': nuevoPrecio,
        'registrado_por': registradoPor,
      },
    );
  }

  Future<void> crearMaterial({
    required String codigo,
    required String nombre,
    required String unidadMedida,
    required String categoria,
    required double stockActual,
    required double stockMinimoAlerta,
    double? precio,
  }) async {
    await _request(
      'POST',
      '/materiales',
      body: {
        'codigo': codigo,
        'nombre': nombre,
        'unidad_medida': unidadMedida,
        'categoria': categoria,
        'stock_actual': stockActual,
        'stock_minimo_alerta': stockMinimoAlerta,
        'precio': precio,
      },
    );
  }

  Future<void> actualizarMaterial({
    required String id,
    required String codigo,
    required String nombre,
    required String unidadMedida,
    required String categoria,
    required double stockMinimoAlerta,
    required bool activo,
  }) async {
    await _request(
      'PATCH',
      '/materiales/$id',
      body: {
        'codigo': codigo,
        'nombre': nombre,
        'unidad_medida': unidadMedida,
        'categoria': categoria,
        'stock_minimo_alerta': stockMinimoAlerta,
        'activo': activo,
      },
    );
  }

  Future<void> ajustarStockMaterial({
    required String id,
    required double cantidad,
    String modo = 'sumar',
    double? precio,
    String? observaciones,
  }) async {
    await _request(
      'PATCH',
      '/materiales/$id/stock',
      body: {
        'cantidad': cantidad,
        'modo': modo,
        'precio': precio,
        'observaciones': observaciones,
      },
    );
  }

  Future<void> registrarIngresoInventario({
    required List<Map<String, dynamic>> items,
    String? observaciones,
  }) async {
    await _request(
      'POST',
      '/materiales/ingresos',
      body: {
        'items': items,
        'observaciones': observaciones,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getHistorialIngresosInventario() async {
    final data = await _request('GET', '/materiales/ingresos/historial');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> desactivarMaterial(String id) async {
    await _request('DELETE', '/materiales/$id');
  }

  Future<List<LineaProduccion>> getLineas() async {
    final data = await _request('GET', '/lineas');
    return (data as List).map((l) => LineaProduccion.fromJson(l)).toList();
  }

  Future<List<LineaMaterialSugerido>> getMaterialesPorLinea(
    String lineaId,
  ) async {
    final data = await _request('GET', '/lineas/$lineaId/materiales');
    return (data as List)
        .map((m) => LineaMaterialSugerido.fromJson(m))
        .toList();
  }

  Future<List<Solicitud>> getSolicitudes({
    String? estado,
    String? solicitanteId,
    String? lineaId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final params = <String, String>{
      if (estado != null) 'estado': estado,
      if (solicitanteId != null) 'solicitante_id': solicitanteId,
      if (lineaId != null) 'linea_id': lineaId,
      if (desde != null) 'desde': desde.toIso8601String(),
      if (hasta != null) 'hasta': hasta.toIso8601String(),
    };

    final data = await _request('GET', '/solicitudes', query: params);
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<List<Solicitud>> getMisSolicitudes() async {
    final data = await _request('GET', '/solicitudes/mis-solicitudes');
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<List<Solicitud>> getSolicitudesEntregadas() async {
    final data = await _request('GET', '/solicitudes/entregadas');
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<List<Solicitud>> getHistorialBodega() async {
    final data = await _request('GET', '/solicitudes/historial-bodega');
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<List<Solicitud>> getSolicitudesAprobadas() async {
    final data = await _request('GET', '/solicitudes/aprobadas');
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<List<Solicitud>> getSolicitudesPendientesBodega() async {
    final data = await _request('GET', '/solicitudes/pendientes-bodega');
    return (data as List).map((s) => Solicitud.fromJson(s)).toList();
  }

  Future<Solicitud?> getSolicitudById(String id) async {
    final data = await _request('GET', '/solicitudes/$id');
    return Solicitud.fromJson(data);
  }

  Future<String> crearSolicitud({
    required String solicitanteId,
    required String solicitanteNombre,
    required String lineaId,
    required String lineaNombre,
    required String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _request(
      'POST',
      '/solicitudes',
      body: {
        'solicitante_id': solicitanteId,
        'solicitante_nombre': solicitanteNombre,
        'linea_id': lineaId,
        'linea_nombre': lineaNombre,
        'observaciones': observaciones,
        'items': items,
      },
    );

    return data['id'] as String;
  }

  Future<String> crearDespachoBodega({
    required String solicitanteId,
    required String solicitanteNombre,
    required String lineaId,
    required String lineaNombre,
    required String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _request(
      'POST',
      '/solicitudes/despacho-bodega',
      body: {
        'solicitante_id': solicitanteId,
        'solicitante_nombre': solicitanteNombre,
        'linea_id': lineaId,
        'linea_nombre': lineaNombre,
        'observaciones': observaciones,
        'items': items,
      },
    );

    return data['id'] as String;
  }

  Future<void> aprobarSolicitud(String id, String aprobadoPor) async {
    await _request(
      'PATCH',
      '/solicitudes/$id/aprobar',
      body: {'aprobado_por': aprobadoPor},
    );
  }

  Future<void> rechazarSolicitud(
    String id,
    String aprobadoPor,
    String motivo,
  ) async {
    await _request(
      'PATCH',
      '/solicitudes/$id/rechazar',
      body: {
        'aprobado_por': aprobadoPor,
        'motivo': motivo,
      },
    );
  }

  Future<void> marcarEntregada(String id) async {
    await _request(
      'PATCH',
      '/solicitudes/$id/entregar',
      body: {},
    );
  }

  Future<List<NotificacionInterna>> getNotificaciones() async {
    final data = await _request('GET', '/notificaciones');
    return (data as List).map((n) => NotificacionInterna.fromJson(n)).toList();
  }

  Future<int> getCantidadNotificacionesNoLeidas() async {
    final data = await _request('GET', '/notificaciones/no-leidas');
    return int.tryParse((data['cantidad'] ?? 0).toString()) ?? 0;
  }

  Future<void> marcarNotificacionComoLeida(String id) async {
    await _request('PATCH', '/notificaciones/$id/leida', body: {});
  }

  Future<void> marcarTodasNotificacionesComoLeidas() async {
    await _request('PATCH', '/notificaciones/marcar-todas-leidas', body: {});
  }

  Future<Map<String, dynamic>> getDashboardData({
    required DateTime desde,
    required DateTime hasta,
    String? lineaId,
    List<String>? lineaIds,
  }) async {
    final query = <String, String>{
      'desde': desde.toIso8601String(),
      'hasta': hasta.toIso8601String(),
      if (lineaId != null) 'linea_id': lineaId,
    };
    final queryAll = <String, List<String>>{};

    if (lineaIds != null && lineaIds.isNotEmpty) {
      queryAll['linea_ids'] = lineaIds;
    }

    final data = await _request(
      'GET',
      '/dashboard/resumen',
      query: query,
      queryAll: queryAll.isEmpty ? null : queryAll,
    );

    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getProduccionDiaria({
    DateTime? desde,
    DateTime? hasta,
    String? lineaId,
    List<String>? lineaIds,
  }) async {
    final query = <String, String>{
      if (desde != null) 'desde': desde.toIso8601String(),
      if (hasta != null) 'hasta': hasta.toIso8601String(),
      if (lineaId != null) 'linea_id': lineaId,
    };
    final queryAll = <String, List<String>>{};

    if (lineaIds != null && lineaIds.isNotEmpty) {
      queryAll['linea_ids'] = lineaIds;
    }

    final data = await _request(
      'GET',
      '/produccion',
      query: query,
      queryAll: queryAll.isEmpty ? null : queryAll,
    );

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> crearProduccionDiaria({
    required DateTime fecha,
    required String lineaId,
    required double cantidad,
    required String unidad,
    String? observaciones,
  }) async {
    await _request(
      'POST',
      '/produccion',
      body: {
        'fecha': fecha.toIso8601String(),
        'linea_id': lineaId,
        'cantidad': cantidad,
        'unidad': unidad,
        'observaciones': observaciones,
      },
    );
  }

  Future<void> eliminarProduccionDiaria(String id) async {
    await _request('DELETE', '/produccion/$id');
  }

  Future<void> actualizarProduccionDiaria({
    required String id,
    required double cantidad,
    required String unidad,
    String? observaciones,
  }) async {
    await _request(
      'PATCH',
      '/produccion/$id',
      body: {
        'cantidad': cantidad,
        'unidad': unidad,
        'observaciones': observaciones,
      },
    );
  }

  Future<Map<String, dynamic>> getDetalleProduccion({
    required String fecha,
    required String lineaId,
  }) async {
    final data = await _request(
      'GET',
      '/produccion/detalle',
      query: {
        'fecha': fecha,
        'linea_id': lineaId,
      },
    );
    return Map<String, dynamic>.from(data);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, List<String>>? queryAll,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (authenticated && _token == null) {
      throw const ApiException('Sesión no iniciada', 401);
    }

    final queryPairs = <MapEntry<String, String>>[];
    if (query != null) {
      queryPairs.addAll(query.entries);
    }
    if (queryAll != null) {
      for (final entry in queryAll.entries) {
        for (final value in entry.value) {
          queryPairs.add(MapEntry(entry.key, value));
        }
      }
    }

    final queryString = queryPairs.isEmpty
        ? ''
        : queryPairs
            .map(
              (entry) =>
                  '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&');

    final uri = Uri.parse(
      queryString.isEmpty ? '$baseUrl$path' : '$baseUrl$path?$queryString',
    );

    late final http.Response response;
    try {
      response = await switch (method) {
        'GET' => _client.get(
            uri,
            headers: _headers,
          ),
        'POST' => _client.post(
            uri,
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          ),
        'PATCH' => _client.patch(
            uri,
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          ),
        'DELETE' => _client.delete(
            uri,
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          ),
        _ => throw ApiException('Método HTTP no soportado: $method'),
      }
          .timeout(const Duration(seconds: 12));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiConnectionException(
        'No se pudo conectar con el servidor. Verifica que el backend esté encendido.',
      );
    } catch (_) {
      throw ApiConnectionException(
        'No se pudo conectar con el servidor en $baseUrl. Si estás usando un celular físico, ejecuta la app con API_BASE_URL apuntando a la IP de tu computadora.',
      );
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? 'Error de API'
          : 'Error de API';

      throw ApiException(message, response.statusCode);
    }

    return decoded;
  }
}
