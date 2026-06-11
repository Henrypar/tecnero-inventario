// Modelos compartidos entre la UI y la API para usuarios, materiales, solicitudes y notificaciones.
// ─── USUARIO ───────────────────────────────────────────────
enum RolUsuario { admin, coordinador, operario, bodeguero, asistenteCompras }

class Usuario {
  final String id;
  final String nombre;
  final String email;
  final RolUsuario rol;
  final bool activo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.activo = true,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: (json['id'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        rol: _rolFromJson((json['rol'] ?? 'operario').toString()),
        activo: json['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol.apiValue,
        'activo': activo,
      };

  String get rolLabel {
    switch (rol) {
      case RolUsuario.admin:
        return 'Administrador';
      case RolUsuario.coordinador:
        return 'Coordinador de Producción';
      case RolUsuario.operario:
        return 'Operario';
      case RolUsuario.bodeguero:
        return 'Bodeguero';
      case RolUsuario.asistenteCompras:
        return 'Asistente de compras';
    }
  }

  String get iniciales {
    if (nombre.trim().isEmpty) return '';
    return nombre
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
  }
}

RolUsuario _rolFromJson(String value) {
  if (value == 'asistente_compras') return RolUsuario.asistenteCompras;

  return RolUsuario.values.firstWhere(
    (r) => r.name == value,
    orElse: () => RolUsuario.operario,
  );
}

extension RolUsuarioApi on RolUsuario {
  String get apiValue {
    switch (this) {
      case RolUsuario.asistenteCompras:
        return 'asistente_compras';
      default:
        return name;
    }
  }
}

// ─── LÍNEA DE PRODUCCIÓN ───────────────────────────────────
class LineaProduccion {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activa;

  const LineaProduccion({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.activa = true,
  });

  factory LineaProduccion.fromJson(Map<String, dynamic> json) =>
      LineaProduccion(
        id: (json['id'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        descripcion: (json['descripcion'] ?? '').toString(),
        activa: json['activa'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'activa': activa,
      };
}

// ─── MATERIAL ──────────────────────────────────────────────
class Material {
  final String id;
  final String codigo;
  final String nombre;
  final String unidadMedida;
  final String categoria;
  final double stockActual;
  final double stockMinimoAlerta;
  final double costoPromedio;
  final double valorInventario;
  final bool activo;

  const Material({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.unidadMedida,
    required this.categoria,
    this.stockActual = 0,
    this.stockMinimoAlerta = 5,
    this.costoPromedio = 0,
    this.valorInventario = 0,
    this.activo = true,
  });

  factory Material.fromJson(Map<String, dynamic> json) => Material(
        id: (json['id'] ?? '').toString(),
        codigo: (json['codigo'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        unidadMedida:
            (json['unidadMedida'] ?? json['unidad_medida'] ?? '').toString(),
        categoria: (json['categoria'] ?? '').toString(),
        stockActual: double.tryParse(
              (json['stockActual'] ?? json['stock_actual'] ?? 0).toString(),
            ) ??
            0,
        stockMinimoAlerta: double.tryParse(
              (json['stockMinimoAlerta'] ?? json['stock_minimo_alerta'] ?? 5)
                  .toString(),
            ) ??
            5,
        costoPromedio: double.tryParse(
              (json['costoPromedio'] ?? json['costo_promedio'] ?? 0).toString(),
            ) ??
            0,
        valorInventario: double.tryParse(
              (json['valorInventario'] ?? json['valor_inventario'] ?? 0)
                  .toString(),
            ) ??
            0,
        activo: json['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'unidad_medida': unidadMedida,
        'categoria': categoria,
        'stock_actual': stockActual,
        'stock_minimo_alerta': stockMinimoAlerta,
        'costo_promedio': costoPromedio,
        'valor_inventario': valorInventario,
        'activo': activo,
      };
}

class LineaMaterialSugerido {
  final String id;
  final String lineaProduccionId;
  final String materialId;
  final double cantidadSugerida;
  final bool activo;
  final Material material;

  const LineaMaterialSugerido({
    required this.id,
    required this.lineaProduccionId,
    required this.materialId,
    required this.cantidadSugerida,
    required this.activo,
    required this.material,
  });

  factory LineaMaterialSugerido.fromJson(Map<String, dynamic> json) =>
      LineaMaterialSugerido(
        id: (json['id'] ?? '').toString(),
        lineaProduccionId:
            (json['lineaProduccionId'] ?? json['linea_produccion_id'] ?? '')
                .toString(),
        materialId:
            (json['materialId'] ?? json['material_id'] ?? '').toString(),
        cantidadSugerida: double.tryParse(
              (json['cantidadSugerida'] ?? json['cantidad_sugerida'] ?? 1)
                  .toString(),
            ) ??
            1,
        activo: json['activo'] ?? true,
        material: Material.fromJson(
          Map<String, dynamic>.from(json['material'] ?? {}),
        ),
      );
}

// ─── PRECIO MATERIAL ───────────────────────────────────────
class PrecioMaterial {
  final String id;
  final String materialId;
  final double precio;
  final DateTime fechaVigencia;
  final String registradoPor;

  const PrecioMaterial({
    required this.id,
    required this.materialId,
    required this.precio,
    required this.fechaVigencia,
    required this.registradoPor,
  });

  factory PrecioMaterial.fromJson(Map<String, dynamic> json) => PrecioMaterial(
        id: (json['id'] ?? '').toString(),
        materialId:
            (json['materialId'] ?? json['material_id'] ?? '').toString(),
        precio: double.tryParse((json['precio'] ?? 0).toString()) ?? 0,
        fechaVigencia: DateTime.tryParse(
              (json['fechaVigencia'] ??
                      json['fecha_vigencia'] ??
                      DateTime.now().toIso8601String())
                  .toString(),
            ) ??
            DateTime.now(),
        registradoPor:
            (json['registradoPor'] ?? json['registrado_por'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'material_id': materialId,
        'precio': precio,
        'fecha_vigencia': fechaVigencia.toIso8601String(),
        'registrado_por': registradoPor,
      };
}

// ─── DETALLE SOLICITUD ─────────────────────────────────────
class DetalleSolicitud {
  final String id;
  final String solicitudId;
  final String materialId;
  final String materialNombre;
  final String materialCodigo;
  final String unidadMedida;
  final double cantidad;
  final double precioUnitarioMomento;
  final double subtotal;

  const DetalleSolicitud({
    required this.id,
    required this.solicitudId,
    required this.materialId,
    required this.materialNombre,
    required this.materialCodigo,
    required this.unidadMedida,
    required this.cantidad,
    required this.precioUnitarioMomento,
    required this.subtotal,
  });

  factory DetalleSolicitud.fromJson(Map<String, dynamic> json) =>
      DetalleSolicitud(
        id: (json['id'] ?? '').toString(),
        solicitudId:
            (json['solicitudId'] ?? json['solicitud_id'] ?? '').toString(),
        materialId:
            (json['materialId'] ?? json['material_id'] ?? '').toString(),
        materialNombre:
            (json['materialNombre'] ?? json['material_nombre'] ?? '')
                .toString(),
        materialCodigo:
            (json['materialCodigo'] ?? json['material_codigo'] ?? '')
                .toString(),
        unidadMedida:
            (json['unidadMedida'] ?? json['unidad_medida'] ?? '').toString(),
        cantidad: double.tryParse((json['cantidad'] ?? 0).toString()) ?? 0,
        precioUnitarioMomento: double.tryParse(
              (json['precioUnitarioMomento'] ??
                      json['precio_unitario_momento'] ??
                      0)
                  .toString(),
            ) ??
            0,
        subtotal: double.tryParse((json['subtotal'] ?? 0).toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'solicitud_id': solicitudId,
        'material_id': materialId,
        'material_nombre': materialNombre,
        'material_codigo': materialCodigo,
        'unidad_medida': unidadMedida,
        'cantidad': cantidad,
        'precio_unitario_momento': precioUnitarioMomento,
        'subtotal': subtotal,
      };
}

// ─── SOLICITUD ─────────────────────────────────────────────
class Solicitud {
  final String id;
  final String numero;
  final String solicitanteId;
  final String solicitanteNombre;
  final String lineaId;
  final String lineaNombre;
  final DateTime fecha;
  final String estado;
  final String origen;
  final double costoTotal;
  final String? observaciones;
  final String? aprobadoPor;
  final DateTime? fechaAprobacion;
  final DateTime? fechaEntrega;
  final List<DetalleSolicitud> detalles;

  const Solicitud({
    required this.id,
    required this.numero,
    required this.solicitanteId,
    required this.solicitanteNombre,
    required this.lineaId,
    required this.lineaNombre,
    required this.fecha,
    required this.estado,
    this.origen = 'operario',
    required this.costoTotal,
    this.observaciones,
    this.aprobadoPor,
    this.fechaAprobacion,
    this.fechaEntrega,
    this.detalles = const [],
  });

  factory Solicitud.fromJson(Map<String, dynamic> json) => Solicitud(
        id: (json['id'] ?? '').toString(),
        numero: (json['numero'] ?? '').toString(),
        solicitanteId:
            (json['solicitanteId'] ?? json['solicitante_id'] ?? '').toString(),
        solicitanteNombre:
            (json['solicitanteNombre'] ?? json['solicitante_nombre'] ?? '')
                .toString(),
        lineaId: (json['lineaId'] ?? json['linea_id'] ?? '').toString(),
        lineaNombre:
            (json['lineaNombre'] ?? json['linea_nombre'] ?? '').toString(),
        fecha: (DateTime.tryParse(
                  (json['fecha'] ?? DateTime.now().toIso8601String())
                      .toString(),
                ) ??
                DateTime.now())
            .toLocal(),
        estado: (json['estado'] ?? 'pendiente').toString(),
        origen: (json['origen'] ?? 'operario').toString(),
        costoTotal: double.tryParse(
              (json['costoTotal'] ?? json['costo_total'] ?? 0).toString(),
            ) ??
            0,
        observaciones: json['observaciones']?.toString(),
        aprobadoPor: (json['aprobadoPor'] ?? json['aprobado_por'])?.toString(),
        fechaAprobacion:
            (json['fechaAprobacion'] ?? json['fecha_aprobacion']) == null
                ? null
                : DateTime.tryParse(
                    (json['fechaAprobacion'] ?? json['fecha_aprobacion'])
                        .toString(),
                  )?.toLocal(),
        fechaEntrega: (json['fechaEntrega'] ?? json['fecha_entrega']) == null
            ? null
            : DateTime.tryParse(
                (json['fechaEntrega'] ?? json['fecha_entrega']).toString(),
              )?.toLocal(),
        detalles: ((json['detalles'] ?? []) as List)
            .map((d) => DetalleSolicitud.fromJson(d))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'solicitante_id': solicitanteId,
        'solicitante_nombre': solicitanteNombre,
        'linea_id': lineaId,
        'linea_nombre': lineaNombre,
        'fecha': fecha.toIso8601String(),
        'estado': estado,
        'origen': origen,
        'costo_total': costoTotal,
        'observaciones': observaciones,
        'aprobado_por': aprobadoPor,
        'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
        'fecha_entrega': fechaEntrega?.toIso8601String(),
        'detalles': detalles.map((d) => d.toJson()).toList(),
      };
}

// ─── BADGE ESTADO ──────────────────────────────────────────
class EstadoBadgeData {
  final String label;
  final String colorHex;

  const EstadoBadgeData({
    required this.label,
    required this.colorHex,
  });
}

// ─── NOTIFICACIÓN INTERNA ─────────────────────────────────
class NotificacionInterna {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final String? solicitudId;
  final DateTime fechaCreacion;

  const NotificacionInterna({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.leida,
    required this.fechaCreacion,
    this.solicitudId,
  });

  factory NotificacionInterna.fromJson(Map<String, dynamic> json) {
    final solicitudId = json['solicitudId'] ??
        json['solicitud_id'] ??
        (json['solicitud'] is Map ? json['solicitud']['id'] : null);

    return NotificacionInterna(
      id: (json['id'] ?? '').toString(),
      usuarioId: (json['usuarioId'] ?? json['usuario_id'] ?? '').toString(),
      titulo: (json['titulo'] ?? '').toString(),
      mensaje: (json['mensaje'] ?? '').toString(),
      tipo: (json['tipo'] ?? '').toString(),
      leida: json['leida'] == true,
      solicitudId: solicitudId?.toString(),
      fechaCreacion: (DateTime.tryParse(
                (json['fechaCreacion'] ??
                        json['fecha_creacion'] ??
                        DateTime.now().toIso8601String())
                    .toString(),
              ) ??
              DateTime.now())
          .toLocal(),
    );
  }
}
