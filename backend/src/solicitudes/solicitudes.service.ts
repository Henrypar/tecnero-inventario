// Servicio central del flujo de materiales: solicita, aprueba, despacha, costea con FIFO y emite notificaciones de negocio.
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, EntityManager } from 'typeorm';
import {
  Solicitud,
  DetalleSolicitud,
  Material,
  PrecioMaterial,
  MovimientoInventario,
  InventarioLote,
  DetalleConsumoLote,
} from '../entities';
import { NotificacionesService } from '../notificaciones/notificaciones.service';

type StockBajoAlerta = {
  codigo: string;
  nombre: string;
  unidadMedida: string;
  stockNuevo: number;
  stockMinimo: number;
};

@Injectable()
export class SolicitudesService {
  constructor(
    @InjectRepository(Solicitud)
    private solicitudesRepo: Repository<Solicitud>,

    @InjectRepository(DetalleSolicitud)
    private detallesRepo: Repository<DetalleSolicitud>,

    @InjectRepository(Material)
    private materialesRepo: Repository<Material>,

    @InjectRepository(PrecioMaterial)
    private preciosRepo: Repository<PrecioMaterial>,

    private dataSource: DataSource,

    private notificacionesService: NotificacionesService,
  ) {}

  private async getPrecioActual(materialId: string): Promise<number> {
    const precio = await this.preciosRepo.findOne({
      where: { materialId },
      order: { fechaVigencia: 'DESC' },
    });

    if (!precio) {
      throw new BadRequestException('Material sin precio registrado');
    }

    return Number(precio.precio);
  }

  private async generarNumero(manager: EntityManager): Promise<string> {
    // Bloqueo transaccional para evitar que dos solicitudes generen el mismo
    // consecutivo cuando entran al mismo tiempo.
    await manager.query(`SELECT pg_advisory_xact_lock(hashtext('solicitudes_numero'))`);

    const result = await manager.query(`
      SELECT COALESCE(
        MAX(CAST(SUBSTRING(numero FROM '^SOL-([0-9]+)$') AS INTEGER)),
        0
      ) AS ultimo
      FROM solicitudes
      WHERE numero ~ '^SOL-[0-9]+$'
    `);

    const siguiente = Number(result?.[0]?.ultimo ?? 0) + 1;

    return `SOL-${String(siguiente).padStart(4, '0')}`;
  }

  private async validarStockDisponible(items: any[]): Promise<void> {
    const itemsAgrupados = new Map<string, number>();

    for (const item of items ?? []) {
      const materialId = item.materialId ?? item.material_id;
      const cantidad = Number(item.cantidad);

      if (!materialId || !cantidad || cantidad <= 0) {
        throw new BadRequestException('Material o cantidad inválida');
      }

      itemsAgrupados.set(
        materialId,
        (itemsAgrupados.get(materialId) ?? 0) + cantidad,
      );
    }

    for (const [materialId, cantidad] of itemsAgrupados.entries()) {
      const material = await this.materialesRepo.findOne({
        where: { id: materialId, activo: true },
      });

      if (!material) {
        throw new NotFoundException(`Material no encontrado: ${materialId}`);
      }

      const stockActual = Number(material.stockActual);

      if (stockActual < cantidad) {
        throw new BadRequestException(
          `Stock insuficiente para ${material.nombre}. Disponible: ${stockActual}, solicitado: ${cantidad}`,
        );
      }
    }
  }

  async crear(dto: any): Promise<Solicitud> {
    console.log('=== DTO RECIBIDO ===', JSON.stringify(dto, null, 2));

    const lineaId = dto.lineaId ?? dto.linea_id;
    const lineaNombre = dto.lineaNombre ?? dto.linea_nombre;

    const solicitanteId = dto.solicitanteId ?? dto.solicitante_id;
    const solicitanteNombre = dto.solicitanteNombre ?? dto.solicitante_nombre;

    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException(
        'La solicitud debe tener al menos un material',
      );
    }

    if (!lineaId) {
      throw new BadRequestException(
        'Debes seleccionar una línea de producción',
      );
    }

    if (!solicitanteId) {
      throw new BadRequestException('No se pudo identificar al solicitante');
    }

    // La creación se hace dentro de transacción para que cabecera, detalles y
    // cálculo de costos queden consistentes incluso si falla una validación.
    const solicitudCreada = await this.dataSource.transaction(async (manager) => {
      let costoTotal = 0;

      const itemsAgrupados = new Map<string, number>();

      for (const item of dto.items) {
        const materialId = item.materialId ?? item.material_id;

        if (!materialId) {
          throw new BadRequestException('Uno de los materiales no tiene ID');
        }

        const cantidad = Number(item.cantidad);

        if (!cantidad || cantidad <= 0) {
          throw new BadRequestException('La cantidad debe ser mayor a 0');
        }

        itemsAgrupados.set(
          materialId,
          (itemsAgrupados.get(materialId) ?? 0) + cantidad,
        );
      }

      // Cada item se normaliza en un detalle para guardar trazabilidad por
      // material, cantidad y precio vigente al momento de la solicitud.
      const detalles: Partial<DetalleSolicitud>[] = [];

      for (const [materialId, cantidad] of itemsAgrupados.entries()) {
        const material = await manager.findOne(Material, {
          where: {
            id: materialId,
            activo: true,
          },
        });

        if (!material) {
          throw new NotFoundException(`Material no encontrado: ${materialId}`);
        }

        const precio = await this.getPrecioActual(materialId);
        const subtotal = precio * cantidad;

        costoTotal += subtotal;

        detalles.push({
          materialId: material.id,
          materialNombre: material.nombre,
          materialCodigo: material.codigo,
          unidadMedida: material.unidadMedida,
          cantidad,
          precioUnitarioMomento: precio,
          subtotal,
        });
      }

      const numero = await this.generarNumero(manager);

      const solicitud = manager.create(Solicitud, {
        numero,
        solicitanteId,
        solicitanteNombre,
        lineaId,
        lineaNombre,
        estado: 'pendiente',
        origen: dto.origen ?? 'operario',
        costoTotal,
        observaciones: dto.observaciones ?? null,
      });

      const saved = await manager.save(Solicitud, solicitud);

      for (const detalle of detalles) {
        await manager.save(DetalleSolicitud, {
          ...detalle,
          solicitudId: saved.id,
        });
      }

      const solicitudCompleta = await manager.findOne(Solicitud, {
        where: { id: saved.id },
        relations: {
          detalles: true,
        },
      });

      if (!solicitudCompleta) {
        throw new NotFoundException(
          'Solicitud no encontrada después de crearla',
        );
      }

      return solicitudCompleta;
    });

    if (
      dto.notificarBodega !== false &&
      (solicitudCreada.origen ?? dto.origen ?? 'operario') !== 'bodega_directo'
    ) {
      await this.notificarSolicitudCreada(solicitudCreada);
    }

    return solicitudCreada;
  }

  async crearDespachoBodega(dto: any, despachadoPor: string): Promise<Solicitud> {
    const solicitanteId = dto.solicitanteId ?? dto.solicitante_id;
    const solicitanteNombre = dto.solicitanteNombre ?? dto.solicitante_nombre;

    if (!solicitanteId || !solicitanteNombre) {
      throw new BadRequestException('Debes seleccionar el colaborador de planta');
    }

    await this.validarStockDisponible(dto.items);

    const observacionDirecta = `Despacho registrado directamente en bodega por ${despachadoPor}`;
    const observacionUsuario = (dto.observaciones ?? '').toString().trim();

    // El despacho directo reutiliza el mismo flujo de solicitud para no
    // duplicar validaciones ni estructura de persistencia.
    const solicitud = await this.crear({
      ...dto,
      solicitanteId,
      solicitanteNombre,
      origen: 'bodega_directo',
      observaciones: observacionUsuario
        ? `${observacionDirecta}. Comentario: ${observacionUsuario}`
        : observacionDirecta,
      notificarBodega: false,
    });

    return this.marcarEntregada(solicitud.id, despachadoPor);
  }

  async editar(
    id: string,
    dto: any,
    usuarioId: string,
  ): Promise<Solicitud> {
    const solicitud = await this.findById(id);

    if (solicitud.solicitanteId !== usuarioId) {
      throw new BadRequestException(
        'No puedes editar una solicitud de otro usuario',
      );
    }

    if (solicitud.estado !== 'pendiente') {
      throw new BadRequestException(
        'Solo se pueden editar solicitudes pendientes',
      );
    }

    const lineaId = dto.lineaId ?? dto.linea_id ?? solicitud.lineaId;
    const lineaNombre =
      dto.lineaNombre ?? dto.linea_nombre ?? solicitud.lineaNombre;

    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException(
        'La solicitud debe tener al menos un material',
      );
    }

    const solicitudEditada = await this.dataSource.transaction(async (manager) => {
      let costoTotal = 0;

      const materialesUsados = new Set<string>();

      for (const item of dto.items) {
        const materialId = item.materialId ?? item.material_id;

        if (!materialId) {
          throw new BadRequestException('Uno de los materiales no tiene ID');
        }

        const cantidad = Number(item.cantidad);

        if (!cantidad || cantidad <= 0) {
          throw new BadRequestException('La cantidad debe ser mayor a 0');
        }

        if (materialesUsados.has(materialId)) {
          throw new BadRequestException(
            'No puedes repetir el mismo material en una solicitud. Edita la cantidad de la fila existente.',
          );
        }

        materialesUsados.add(materialId);
      }

      const nuevosDetalles: Partial<DetalleSolicitud>[] = [];

      for (const item of dto.items) {
        const materialId = item.materialId ?? item.material_id;
        const cantidad = Number(item.cantidad);

        const material = await manager.findOne(Material, {
          where: {
            id: materialId,
            activo: true,
          },
        });

        if (!material) {
          throw new NotFoundException(`Material no encontrado: ${materialId}`);
        }

        const precio = await this.getPrecioActual(materialId);
        const subtotal = precio * cantidad;

        costoTotal += subtotal;

        nuevosDetalles.push({
          materialId: material.id,
          materialNombre: material.nombre,
          materialCodigo: material.codigo,
          unidadMedida: material.unidadMedida,
          cantidad,
          precioUnitarioMomento: precio,
          subtotal,
        });
      }

      await manager
        .createQueryBuilder()
        .delete()
        .from(DetalleSolicitud)
        .where('solicitud_id = :id', { id })
        .execute();

      await manager.update(
        Solicitud,
        { id },
        {
          lineaId,
          lineaNombre,
          observaciones: dto.observaciones ?? null,
          costoTotal,
        },
      );

      for (const detalle of nuevosDetalles) {
        await manager.save(DetalleSolicitud, {
          ...detalle,
          solicitudId: id,
        });
      }

      const actualizada = await manager.findOne(Solicitud, {
        where: { id },
        relations: {
          detalles: true,
        },
      });

      if (!actualizada) {
        throw new NotFoundException(
          'Solicitud no encontrada después de editar',
        );
      }

      return actualizada;
    });

    await this.notificarSolicitudEditada(solicitudEditada);

    return solicitudEditada;
  }

  async findAll(filtros?: any): Promise<Solicitud[]> {
    const qb = this.solicitudesRepo
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.detalles', 'd')
      .orderBy('s.fecha', 'DESC');

    const estado = filtros?.estado;
    const solicitanteId =
      filtros?.solicitanteId ?? filtros?.solicitante_id;
    const lineaId = filtros?.lineaId ?? filtros?.linea_id;

    if (estado) {
      qb.andWhere('s.estado = :estado', { estado });
    }

    if (solicitanteId) {
      qb.andWhere('s.solicitanteId = :solicitanteId', {
        solicitanteId,
      });
    }

    if (lineaId) {
      qb.andWhere('s.lineaId = :lineaId', {
        lineaId,
      });
    }

    return qb.getMany();
  }

  async findHistoricoBodega(): Promise<Solicitud[]> {
    // El historial de bodega reúne lo entregado y lo rechazado para tener una
    // vista completa de la atención operativa.
    return this.solicitudesRepo
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.detalles', 'd')
      .where('s.estado IN (:...estados)', {
        estados: ['entregada', 'rechazada'],
      })
      // Ordenar en SQL evita depender de valores parcialmente cargados o de
      // conversiones en memoria cuando el historial tiene muchos registros.
      .orderBy(
        'COALESCE(s.fecha_entrega, s.fecha_aprobacion, s.fecha)',
        'DESC',
      )
      .addOrderBy('s.fecha', 'DESC')
      .getMany();
  }

  async findById(id: string): Promise<Solicitud> {
    const solicitud = await this.solicitudesRepo.findOne({
      where: { id },
      relations: {
        detalles: true,
      },
    });

    if (!solicitud) {
      throw new NotFoundException('Solicitud no encontrada');
    }

    return solicitud;
  }

  async aprobar(id: string, aprobadoPor: string): Promise<Solicitud> {
    // Compatibilidad con el flujo pedido por la prueba técnica original.
    const solicitud = await this.findById(id);

    if (solicitud.estado !== 'pendiente') {
      throw new BadRequestException(
        'Solo se pueden aprobar solicitudes pendientes',
      );
    }

    solicitud.estado = 'aprobada';
    solicitud.aprobadoPor = aprobadoPor;
    solicitud.fechaAprobacion = new Date();

    const actualizada = await this.solicitudesRepo.save(solicitud);

    await this.notificarSolicitudAprobada(actualizada);

    return actualizada;
  }

  async rechazar(
    id: string,
    aprobadoPor: string,
    motivo: string,
  ): Promise<Solicitud> {
    // El rechazo deja evidencia del motivo para trazabilidad operativa.
    const solicitud = await this.findById(id);

    if (solicitud.estado !== 'pendiente') {
      throw new BadRequestException(
        'Solo se pueden rechazar solicitudes pendientes',
      );
    }

    solicitud.estado = 'rechazada';
    solicitud.aprobadoPor = aprobadoPor;
    solicitud.fechaAprobacion = new Date();
    solicitud.observaciones = motivo;

    const actualizada = await this.solicitudesRepo.save(solicitud);

    await this.notificarSolicitudRechazada(actualizada, motivo);

    return actualizada;
  }

  private async stockDisponibleFifo(
    manager: EntityManager,
    materialId: string,
  ): Promise<number> {
    // La disponibilidad real se calcula desde lotes, no desde el ultimo precio.
    // Esto permite mezclar stock antiguo y nuevo sin perder trazabilidad.
    const result = await manager
      .createQueryBuilder(InventarioLote, 'lote')
      .select('COALESCE(SUM(lote.cantidad_disponible), 0)', 'total')
      .where('lote.material_id = :materialId', { materialId })
      .andWhere('lote.cantidad_disponible > 0')
      .getRawOne();

    return Number(result?.total ?? 0);
  }

  private async recalcularCostoMaterialDesdeLotes(
    manager: EntityManager,
    material: Material,
  ): Promise<void> {
    // Despues de cada salida FIFO se reconstruyen los totales visibles del
    // material para que compras vea stock, costo promedio y valor inventario.
    const result = await manager
      .createQueryBuilder(InventarioLote, 'lote')
      .select('COALESCE(SUM(lote.cantidad_disponible), 0)', 'stock')
      .addSelect(
        'COALESCE(SUM(lote.cantidad_disponible * lote.precio_unitario), 0)',
        'valor',
      )
      .where('lote.material_id = :materialId', { materialId: material.id })
      .andWhere('lote.cantidad_disponible > 0')
      .getRawOne();

    const stock = Number(result?.stock ?? 0);
    const valor = Number(result?.valor ?? 0);

    material.stockActual = stock;
    material.valorInventario = valor;
    material.costoPromedio = stock > 0 ? valor / stock : 0;
  }

  async marcarEntregada(id: string, despachadoPor?: string): Promise<Solicitud> {
  // El despacho es el punto crítico: valida stock, consume lotes FIFO y
  // actualiza costos reales y notificaciones en una sola operación.
  const solicitud = await this.findById(id);
  const alertasStockBajo: StockBajoAlerta[] = [];

  if (!['pendiente', 'aprobada'].includes(solicitud.estado)) {
    throw new BadRequestException(
      `Solo se pueden entregar solicitudes pendientes o aprobadas. Estado actual: ${solicitud.estado}`,
    );
  }

  if (!solicitud.detalles || solicitud.detalles.length === 0) {
    throw new BadRequestException(
      'La solicitud no tiene materiales para entregar',
    );
  }

  const entregada = await this.dataSource.transaction(async (manager) => {
    /**
     * Primero validamos stock.
     * No descontamos nada hasta estar seguros de que todos los materiales alcanzan.
     */
    for (const detalle of solicitud.detalles) {
      // Se valida primero todo el pedido para no descontar inventario parcial si
      // falta stock en uno de los materiales.
      const material = await manager.findOne(Material, {
        where: {
          id: detalle.materialId,
        },
      });

      if (!material) {
        throw new NotFoundException(
          `Material no encontrado: ${detalle.materialNombre}`,
        );
      }

      const stockActual = await this.stockDisponibleFifo(manager, material.id);
      const cantidadSolicitada = Number(detalle.cantidad);

      if (stockActual < cantidadSolicitada) {
        throw new BadRequestException(
          `Stock insuficiente para ${material.nombre}. Disponible: ${stockActual}, solicitado: ${cantidadSolicitada}`,
        );
      }
    }

    /**
     * Si todo está bien, ahora sí marcamos entregada, valorizamos con FIFO
     * real y descontamos lotes antiguos primero.
     */
    solicitud.estado = 'entregada';
    solicitud.aprobadoPor = despachadoPor ?? solicitud.aprobadoPor;
    solicitud.fechaAprobacion = solicitud.fechaAprobacion ?? new Date();
    solicitud.fechaEntrega = new Date();

    let costoTotalReal = 0;

    for (const detalle of solicitud.detalles) {
      const material = await manager.findOne(Material, {
        where: {
          id: detalle.materialId,
        },
        lock: { mode: 'pessimistic_write' },
      });

      if (!material) {
        throw new NotFoundException(
          `Material no encontrado: ${detalle.materialNombre}`,
        );
      }

      const stockAnterior = Number(material.stockActual);
      const cantidadSolicitada = Number(detalle.cantidad);
      const stockMinimo = Number(material.stockMinimoAlerta ?? 5);
      let cantidadPendiente = cantidadSolicitada;
      let subtotalReal = 0;

      // FIFO: se consume primero el lote más antiguo disponible.
      const lotes = await manager
        .createQueryBuilder(InventarioLote, 'lote')
        .setLock('pessimistic_write')
        .where('lote.material_id = :materialId', { materialId: material.id })
        .andWhere('lote.cantidad_disponible > 0')
        .orderBy('lote.fecha_entrada', 'ASC')
        .addOrderBy('lote.id', 'ASC')
        .getMany();

      for (const lote of lotes) {
        if (cantidadPendiente <= 0) break;

        const disponible = Number(lote.cantidadDisponible);
        if (disponible <= 0) continue;

        const cantidadConsumida = Math.min(disponible, cantidadPendiente);
        const precioLote = Number(lote.precioUnitario);
        const subtotalLote = cantidadConsumida * precioLote;

        lote.cantidadDisponible = disponible - cantidadConsumida;
        await manager.save(InventarioLote, lote);

        await manager.save(
          DetalleConsumoLote,
          manager.create(DetalleConsumoLote, {
            detalleSolicitudId: detalle.id,
            loteId: lote.id,
            cantidad: cantidadConsumida,
            precioUnitario: precioLote,
            subtotal: subtotalLote,
          }),
        );

        subtotalReal += subtotalLote;
        cantidadPendiente -= cantidadConsumida;
      }

      if (cantidadPendiente > 0.0001) {
        throw new BadRequestException(
          `Stock insuficiente por lotes para ${material.nombre}. Faltan ${cantidadPendiente}`,
        );
      }

      const costoUnitarioReal =
        cantidadSolicitada > 0 ? subtotalReal / cantidadSolicitada : 0;

      costoTotalReal += subtotalReal;

      detalle.precioUnitarioMomento = costoUnitarioReal;
      detalle.subtotal = subtotalReal;
      await manager.save(DetalleSolicitud, detalle);

      await this.recalcularCostoMaterialDesdeLotes(manager, material);
      await manager.save(Material, material);

      const stockNuevo = Number(material.stockActual);

      await manager.save(
        MovimientoInventario,
        manager.create(MovimientoInventario, {
          materialId: material.id,
          materialCodigo: material.codigo,
          materialNombre: material.nombre,
          unidadMedida: material.unidadMedida,
          tipo: 'salida_produccion',
          cantidad: -cantidadSolicitada,
          precioUnitario: costoUnitarioReal,
          stockAnterior,
          stockNuevo,
          registradoPor: despachadoPor ?? 'Bodega',
          observaciones: `Despacho ${solicitud.numero} - ${solicitud.lineaNombre}`,
        }),
      );

      if (material.activo && stockNuevo <= stockMinimo) {
        alertasStockBajo.push({
          codigo: material.codigo,
          nombre: material.nombre,
          unidadMedida: material.unidadMedida,
          stockNuevo,
          stockMinimo,
        });
      }
    }

    solicitud.costoTotal = costoTotalReal;
    await manager.save(Solicitud, solicitud);

    const actualizada = await manager.findOne(Solicitud, {
      where: { id: solicitud.id },
      relations: {
        detalles: true,
      },
    });

    if (!actualizada) {
      throw new NotFoundException(
        'Solicitud no encontrada después de entregar',
      );
    }

    return actualizada;
  });

  await this.notificarSolicitudEntregada(entregada);
  await this.notificarStockBajo(alertasStockBajo);

  return entregada;
}

  private async notificarSolicitudCreada(solicitud: Solicitud) {
    // La notificación se envía al rol que opera la bodega y administra la
    // recepción de pedidos diarios.
    await this.crearNotificacionesSeguro(() =>
      this.notificacionesService.crearParaRoles(['admin', 'bodeguero'], {
        titulo: 'Nueva solicitud para despacho',
        mensaje: `La solicitud ${solicitud.numero} fue creada y está pendiente de despacho en bodega.`,
        tipo: 'SOLICITUD_CREADA',
        solicitudId: solicitud.id,
      }),
    );
  }

  private async notificarSolicitudEditada(solicitud: Solicitud) {
    if (solicitud.estado !== 'pendiente') return;

    await this.crearNotificacionesSeguro(() =>
      this.notificacionesService.crearParaRoles(['bodeguero'], {
        titulo: 'Solicitud editada',
        mensaje: `La solicitud ${solicitud.numero} fue modificada por el solicitante. Revisa los materiales para despacho.`,
        tipo: 'SOLICITUD_EDITADA',
        solicitudId: solicitud.id,
      }),
    );
  }

  private async notificarSolicitudAprobada(solicitud: Solicitud) {
    // Se notifica a bodega y admin, y además se informa al solicitante.
    await this.crearNotificacionesSeguro(async () => {
      await this.notificacionesService.crearParaRoles(
        ['admin', 'bodeguero'],
        {
          titulo: 'Solicitud aprobada',
          mensaje: `La solicitud ${solicitud.numero} fue aprobada y está lista para entrega.`,
          tipo: 'SOLICITUD_APROBADA',
          solicitudId: solicitud.id,
        },
      );

      await this.notificacionesService.crearNotificacion({
        usuarioId: solicitud.solicitanteId,
        titulo: 'Solicitud aprobada',
        mensaje: `Tu solicitud ${solicitud.numero} fue aprobada.`,
        tipo: 'SOLICITUD_APROBADA',
        solicitudId: solicitud.id,
      });
    });
  }

  private async notificarSolicitudRechazada(solicitud: Solicitud, motivo: string) {
    await this.crearNotificacionesSeguro(async () => {
      await this.notificacionesService.crearParaRoles(['admin'], {
        titulo: 'Solicitud rechazada',
        mensaje: `La solicitud ${solicitud.numero} fue rechazada. Motivo: ${motivo}`,
        tipo: 'SOLICITUD_RECHAZADA',
        solicitudId: solicitud.id,
      });

      await this.notificacionesService.crearNotificacion({
        usuarioId: solicitud.solicitanteId,
        titulo: 'Solicitud rechazada',
        mensaje: `Tu solicitud ${solicitud.numero} fue rechazada. Motivo: ${motivo}`,
        tipo: 'SOLICITUD_RECHAZADA',
        solicitudId: solicitud.id,
      });
    });
  }

  private async notificarSolicitudEntregada(solicitud: Solicitud) {
    // El despacho final debe llegar al solicitante y al área de control.
    await this.crearNotificacionesSeguro(async () => {
      await this.notificacionesService.crearNotificacion({
        usuarioId: solicitud.solicitanteId,
        titulo: 'Solicitud entregada',
        mensaje: `Tu solicitud ${solicitud.numero} fue entregada por bodega.`,
        tipo: 'SOLICITUD_ENTREGADA',
        solicitudId: solicitud.id,
      });

      await this.notificacionesService.crearParaRoles(['admin', 'coordinador'], {
        titulo: 'Despacho registrado',
        mensaje: `Bodega registró el despacho ${solicitud.numero} para ${solicitud.lineaNombre}.`,
        tipo: 'SOLICITUD_ENTREGADA',
        solicitudId: solicitud.id,
      });
    });
  }

  private async notificarStockBajo(alertas: StockBajoAlerta[]) {
    if (alertas.length === 0) return;

    // Cada alerta se persiste y se emite a administracion/compras.
    await this.crearNotificacionesSeguro(async () => {
      for (const alerta of alertas) {
        await this.notificacionesService.crearParaRoles(['admin'], {
          titulo: 'Stock bajo',
          mensaje: `${alerta.codigo} - ${alerta.nombre} quedó en ${this.formatearCantidad(alerta.stockNuevo)} ${alerta.unidadMedida}. Umbral configurado: ${this.formatearCantidad(alerta.stockMinimo)}.`,
          tipo: 'STOCK_BAJO',
        });
      }
    });
  }

  private formatearCantidad(value: number): string {
    return Number.isInteger(value) ? value.toString() : value.toFixed(2);
  }

  private async crearNotificacionesSeguro(crear: () => Promise<unknown>) {
    try {
      await crear();
    } catch (error) {
      console.error('No se pudo crear la notificación', error);
    }
  }
}
