"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SolicitudesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("../entities");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
let SolicitudesService = class SolicitudesService {
    constructor(solicitudesRepo, detallesRepo, materialesRepo, preciosRepo, dataSource, notificacionesService) {
        this.solicitudesRepo = solicitudesRepo;
        this.detallesRepo = detallesRepo;
        this.materialesRepo = materialesRepo;
        this.preciosRepo = preciosRepo;
        this.dataSource = dataSource;
        this.notificacionesService = notificacionesService;
    }
    async getPrecioActual(materialId) {
        const precio = await this.preciosRepo.findOne({
            where: { materialId },
            order: { fechaVigencia: 'DESC' },
        });
        if (!precio) {
            throw new common_1.BadRequestException('Material sin precio registrado');
        }
        return Number(precio.precio);
    }
    async generarNumero(manager) {
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
    async validarStockDisponible(items) {
        const itemsAgrupados = new Map();
        for (const item of items ?? []) {
            const materialId = item.materialId ?? item.material_id;
            const cantidad = Number(item.cantidad);
            if (!materialId || !cantidad || cantidad <= 0) {
                throw new common_1.BadRequestException('Material o cantidad inválida');
            }
            itemsAgrupados.set(materialId, (itemsAgrupados.get(materialId) ?? 0) + cantidad);
        }
        for (const [materialId, cantidad] of itemsAgrupados.entries()) {
            const material = await this.materialesRepo.findOne({
                where: { id: materialId, activo: true },
            });
            if (!material) {
                throw new common_1.NotFoundException(`Material no encontrado: ${materialId}`);
            }
            const stockActual = Number(material.stockActual);
            if (stockActual < cantidad) {
                throw new common_1.BadRequestException(`Stock insuficiente para ${material.nombre}. Disponible: ${stockActual}, solicitado: ${cantidad}`);
            }
        }
    }
    async crear(dto) {
        console.log('=== DTO RECIBIDO ===', JSON.stringify(dto, null, 2));
        const lineaId = dto.lineaId ?? dto.linea_id;
        const lineaNombre = dto.lineaNombre ?? dto.linea_nombre;
        const solicitanteId = dto.solicitanteId ?? dto.solicitante_id;
        const solicitanteNombre = dto.solicitanteNombre ?? dto.solicitante_nombre;
        if (!dto.items || dto.items.length === 0) {
            throw new common_1.BadRequestException('La solicitud debe tener al menos un material');
        }
        if (!lineaId) {
            throw new common_1.BadRequestException('Debes seleccionar una línea de producción');
        }
        if (!solicitanteId) {
            throw new common_1.BadRequestException('No se pudo identificar al solicitante');
        }
        const solicitudCreada = await this.dataSource.transaction(async (manager) => {
            let costoTotal = 0;
            const itemsAgrupados = new Map();
            for (const item of dto.items) {
                const materialId = item.materialId ?? item.material_id;
                if (!materialId) {
                    throw new common_1.BadRequestException('Uno de los materiales no tiene ID');
                }
                const cantidad = Number(item.cantidad);
                if (!cantidad || cantidad <= 0) {
                    throw new common_1.BadRequestException('La cantidad debe ser mayor a 0');
                }
                itemsAgrupados.set(materialId, (itemsAgrupados.get(materialId) ?? 0) + cantidad);
            }
            const detalles = [];
            for (const [materialId, cantidad] of itemsAgrupados.entries()) {
                const material = await manager.findOne(entities_1.Material, {
                    where: {
                        id: materialId,
                        activo: true,
                    },
                });
                if (!material) {
                    throw new common_1.NotFoundException(`Material no encontrado: ${materialId}`);
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
            const solicitud = manager.create(entities_1.Solicitud, {
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
            const saved = await manager.save(entities_1.Solicitud, solicitud);
            for (const detalle of detalles) {
                await manager.save(entities_1.DetalleSolicitud, {
                    ...detalle,
                    solicitudId: saved.id,
                });
            }
            const solicitudCompleta = await manager.findOne(entities_1.Solicitud, {
                where: { id: saved.id },
                relations: {
                    detalles: true,
                },
            });
            if (!solicitudCompleta) {
                throw new common_1.NotFoundException('Solicitud no encontrada después de crearla');
            }
            return solicitudCompleta;
        });
        if (dto.notificarBodega !== false &&
            (solicitudCreada.origen ?? dto.origen ?? 'operario') !== 'bodega_directo') {
            await this.notificarSolicitudCreada(solicitudCreada);
        }
        return solicitudCreada;
    }
    async crearDespachoBodega(dto, despachadoPor) {
        const solicitanteId = dto.solicitanteId ?? dto.solicitante_id;
        const solicitanteNombre = dto.solicitanteNombre ?? dto.solicitante_nombre;
        if (!solicitanteId || !solicitanteNombre) {
            throw new common_1.BadRequestException('Debes seleccionar el colaborador de planta');
        }
        await this.validarStockDisponible(dto.items);
        const observacionDirecta = `Despacho registrado directamente en bodega por ${despachadoPor}`;
        const observacionUsuario = (dto.observaciones ?? '').toString().trim();
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
    async editar(id, dto, usuarioId) {
        const solicitud = await this.findById(id);
        if (solicitud.solicitanteId !== usuarioId) {
            throw new common_1.BadRequestException('No puedes editar una solicitud de otro usuario');
        }
        if (solicitud.estado !== 'pendiente') {
            throw new common_1.BadRequestException('Solo se pueden editar solicitudes pendientes');
        }
        const lineaId = dto.lineaId ?? dto.linea_id ?? solicitud.lineaId;
        const lineaNombre = dto.lineaNombre ?? dto.linea_nombre ?? solicitud.lineaNombre;
        if (!dto.items || dto.items.length === 0) {
            throw new common_1.BadRequestException('La solicitud debe tener al menos un material');
        }
        const solicitudEditada = await this.dataSource.transaction(async (manager) => {
            let costoTotal = 0;
            const materialesUsados = new Set();
            for (const item of dto.items) {
                const materialId = item.materialId ?? item.material_id;
                if (!materialId) {
                    throw new common_1.BadRequestException('Uno de los materiales no tiene ID');
                }
                const cantidad = Number(item.cantidad);
                if (!cantidad || cantidad <= 0) {
                    throw new common_1.BadRequestException('La cantidad debe ser mayor a 0');
                }
                if (materialesUsados.has(materialId)) {
                    throw new common_1.BadRequestException('No puedes repetir el mismo material en una solicitud. Edita la cantidad de la fila existente.');
                }
                materialesUsados.add(materialId);
            }
            const nuevosDetalles = [];
            for (const item of dto.items) {
                const materialId = item.materialId ?? item.material_id;
                const cantidad = Number(item.cantidad);
                const material = await manager.findOne(entities_1.Material, {
                    where: {
                        id: materialId,
                        activo: true,
                    },
                });
                if (!material) {
                    throw new common_1.NotFoundException(`Material no encontrado: ${materialId}`);
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
                .from(entities_1.DetalleSolicitud)
                .where('solicitud_id = :id', { id })
                .execute();
            await manager.update(entities_1.Solicitud, { id }, {
                lineaId,
                lineaNombre,
                observaciones: dto.observaciones ?? null,
                costoTotal,
            });
            for (const detalle of nuevosDetalles) {
                await manager.save(entities_1.DetalleSolicitud, {
                    ...detalle,
                    solicitudId: id,
                });
            }
            const actualizada = await manager.findOne(entities_1.Solicitud, {
                where: { id },
                relations: {
                    detalles: true,
                },
            });
            if (!actualizada) {
                throw new common_1.NotFoundException('Solicitud no encontrada después de editar');
            }
            return actualizada;
        });
        await this.notificarSolicitudEditada(solicitudEditada);
        return solicitudEditada;
    }
    async findAll(filtros) {
        const qb = this.solicitudesRepo
            .createQueryBuilder('s')
            .leftJoinAndSelect('s.detalles', 'd')
            .orderBy('s.fecha', 'DESC');
        const estado = filtros?.estado;
        const solicitanteId = filtros?.solicitanteId ?? filtros?.solicitante_id;
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
    async findHistoricoBodega() {
        return this.solicitudesRepo
            .createQueryBuilder('s')
            .leftJoinAndSelect('s.detalles', 'd')
            .where('s.estado IN (:...estados)', {
            estados: ['entregada', 'rechazada'],
        })
            .orderBy('COALESCE(s.fecha_entrega, s.fecha_aprobacion, s.fecha)', 'DESC')
            .addOrderBy('s.fecha', 'DESC')
            .getMany();
    }
    async findById(id) {
        const solicitud = await this.solicitudesRepo.findOne({
            where: { id },
            relations: {
                detalles: true,
            },
        });
        if (!solicitud) {
            throw new common_1.NotFoundException('Solicitud no encontrada');
        }
        return solicitud;
    }
    async aprobar(id, aprobadoPor) {
        const solicitud = await this.findById(id);
        if (solicitud.estado !== 'pendiente') {
            throw new common_1.BadRequestException('Solo se pueden aprobar solicitudes pendientes');
        }
        solicitud.estado = 'aprobada';
        solicitud.aprobadoPor = aprobadoPor;
        solicitud.fechaAprobacion = new Date();
        const actualizada = await this.solicitudesRepo.save(solicitud);
        await this.notificarSolicitudAprobada(actualizada);
        return actualizada;
    }
    async rechazar(id, aprobadoPor, motivo) {
        const solicitud = await this.findById(id);
        if (solicitud.estado !== 'pendiente') {
            throw new common_1.BadRequestException('Solo se pueden rechazar solicitudes pendientes');
        }
        solicitud.estado = 'rechazada';
        solicitud.aprobadoPor = aprobadoPor;
        solicitud.fechaAprobacion = new Date();
        solicitud.observaciones = motivo;
        const actualizada = await this.solicitudesRepo.save(solicitud);
        await this.notificarSolicitudRechazada(actualizada, motivo);
        return actualizada;
    }
    async stockDisponibleFifo(manager, materialId) {
        const result = await manager
            .createQueryBuilder(entities_1.InventarioLote, 'lote')
            .select('COALESCE(SUM(lote.cantidad_disponible), 0)', 'total')
            .where('lote.material_id = :materialId', { materialId })
            .andWhere('lote.cantidad_disponible > 0')
            .getRawOne();
        return Number(result?.total ?? 0);
    }
    async recalcularCostoMaterialDesdeLotes(manager, material) {
        const result = await manager
            .createQueryBuilder(entities_1.InventarioLote, 'lote')
            .select('COALESCE(SUM(lote.cantidad_disponible), 0)', 'stock')
            .addSelect('COALESCE(SUM(lote.cantidad_disponible * lote.precio_unitario), 0)', 'valor')
            .where('lote.material_id = :materialId', { materialId: material.id })
            .andWhere('lote.cantidad_disponible > 0')
            .getRawOne();
        const stock = Number(result?.stock ?? 0);
        const valor = Number(result?.valor ?? 0);
        material.stockActual = stock;
        material.valorInventario = valor;
        material.costoPromedio = stock > 0 ? valor / stock : 0;
    }
    async marcarEntregada(id, despachadoPor) {
        const solicitud = await this.findById(id);
        const alertasStockBajo = [];
        if (!['pendiente', 'aprobada'].includes(solicitud.estado)) {
            throw new common_1.BadRequestException(`Solo se pueden entregar solicitudes pendientes o aprobadas. Estado actual: ${solicitud.estado}`);
        }
        if (!solicitud.detalles || solicitud.detalles.length === 0) {
            throw new common_1.BadRequestException('La solicitud no tiene materiales para entregar');
        }
        const entregada = await this.dataSource.transaction(async (manager) => {
            for (const detalle of solicitud.detalles) {
                const material = await manager.findOne(entities_1.Material, {
                    where: {
                        id: detalle.materialId,
                    },
                });
                if (!material) {
                    throw new common_1.NotFoundException(`Material no encontrado: ${detalle.materialNombre}`);
                }
                const stockActual = await this.stockDisponibleFifo(manager, material.id);
                const cantidadSolicitada = Number(detalle.cantidad);
                if (stockActual < cantidadSolicitada) {
                    throw new common_1.BadRequestException(`Stock insuficiente para ${material.nombre}. Disponible: ${stockActual}, solicitado: ${cantidadSolicitada}`);
                }
            }
            solicitud.estado = 'entregada';
            solicitud.aprobadoPor = despachadoPor ?? solicitud.aprobadoPor;
            solicitud.fechaAprobacion = solicitud.fechaAprobacion ?? new Date();
            solicitud.fechaEntrega = new Date();
            let costoTotalReal = 0;
            for (const detalle of solicitud.detalles) {
                const material = await manager.findOne(entities_1.Material, {
                    where: {
                        id: detalle.materialId,
                    },
                    lock: { mode: 'pessimistic_write' },
                });
                if (!material) {
                    throw new common_1.NotFoundException(`Material no encontrado: ${detalle.materialNombre}`);
                }
                const stockAnterior = Number(material.stockActual);
                const cantidadSolicitada = Number(detalle.cantidad);
                const stockMinimo = Number(material.stockMinimoAlerta ?? 5);
                let cantidadPendiente = cantidadSolicitada;
                let subtotalReal = 0;
                const lotes = await manager
                    .createQueryBuilder(entities_1.InventarioLote, 'lote')
                    .setLock('pessimistic_write')
                    .where('lote.material_id = :materialId', { materialId: material.id })
                    .andWhere('lote.cantidad_disponible > 0')
                    .orderBy('lote.fecha_entrada', 'ASC')
                    .addOrderBy('lote.id', 'ASC')
                    .getMany();
                for (const lote of lotes) {
                    if (cantidadPendiente <= 0)
                        break;
                    const disponible = Number(lote.cantidadDisponible);
                    if (disponible <= 0)
                        continue;
                    const cantidadConsumida = Math.min(disponible, cantidadPendiente);
                    const precioLote = Number(lote.precioUnitario);
                    const subtotalLote = cantidadConsumida * precioLote;
                    lote.cantidadDisponible = disponible - cantidadConsumida;
                    await manager.save(entities_1.InventarioLote, lote);
                    await manager.save(entities_1.DetalleConsumoLote, manager.create(entities_1.DetalleConsumoLote, {
                        detalleSolicitudId: detalle.id,
                        loteId: lote.id,
                        cantidad: cantidadConsumida,
                        precioUnitario: precioLote,
                        subtotal: subtotalLote,
                    }));
                    subtotalReal += subtotalLote;
                    cantidadPendiente -= cantidadConsumida;
                }
                if (cantidadPendiente > 0.0001) {
                    throw new common_1.BadRequestException(`Stock insuficiente por lotes para ${material.nombre}. Faltan ${cantidadPendiente}`);
                }
                const costoUnitarioReal = cantidadSolicitada > 0 ? subtotalReal / cantidadSolicitada : 0;
                costoTotalReal += subtotalReal;
                detalle.precioUnitarioMomento = costoUnitarioReal;
                detalle.subtotal = subtotalReal;
                await manager.save(entities_1.DetalleSolicitud, detalle);
                await this.recalcularCostoMaterialDesdeLotes(manager, material);
                await manager.save(entities_1.Material, material);
                const stockNuevo = Number(material.stockActual);
                await manager.save(entities_1.MovimientoInventario, manager.create(entities_1.MovimientoInventario, {
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
                }));
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
            await manager.save(entities_1.Solicitud, solicitud);
            const actualizada = await manager.findOne(entities_1.Solicitud, {
                where: { id: solicitud.id },
                relations: {
                    detalles: true,
                },
            });
            if (!actualizada) {
                throw new common_1.NotFoundException('Solicitud no encontrada después de entregar');
            }
            return actualizada;
        });
        await this.notificarSolicitudEntregada(entregada);
        await this.notificarStockBajo(alertasStockBajo);
        return entregada;
    }
    async notificarSolicitudCreada(solicitud) {
        await this.crearNotificacionesSeguro(() => this.notificacionesService.crearParaRoles(['admin', 'bodeguero'], {
            titulo: 'Nueva solicitud para despacho',
            mensaje: `La solicitud ${solicitud.numero} fue creada y está pendiente de despacho en bodega.`,
            tipo: 'SOLICITUD_CREADA',
            solicitudId: solicitud.id,
        }));
    }
    async notificarSolicitudEditada(solicitud) {
        if (solicitud.estado !== 'pendiente')
            return;
        await this.crearNotificacionesSeguro(() => this.notificacionesService.crearParaRoles(['bodeguero'], {
            titulo: 'Solicitud editada',
            mensaje: `La solicitud ${solicitud.numero} fue modificada por el solicitante. Revisa los materiales para despacho.`,
            tipo: 'SOLICITUD_EDITADA',
            solicitudId: solicitud.id,
        }));
    }
    async notificarSolicitudAprobada(solicitud) {
        await this.crearNotificacionesSeguro(async () => {
            await this.notificacionesService.crearParaRoles(['admin', 'bodeguero'], {
                titulo: 'Solicitud aprobada',
                mensaje: `La solicitud ${solicitud.numero} fue aprobada y está lista para entrega.`,
                tipo: 'SOLICITUD_APROBADA',
                solicitudId: solicitud.id,
            });
            await this.notificacionesService.crearNotificacion({
                usuarioId: solicitud.solicitanteId,
                titulo: 'Solicitud aprobada',
                mensaje: `Tu solicitud ${solicitud.numero} fue aprobada.`,
                tipo: 'SOLICITUD_APROBADA',
                solicitudId: solicitud.id,
            });
        });
    }
    async notificarSolicitudRechazada(solicitud, motivo) {
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
    async notificarSolicitudEntregada(solicitud) {
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
    async notificarStockBajo(alertas) {
        if (alertas.length === 0)
            return;
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
    formatearCantidad(value) {
        return Number.isInteger(value) ? value.toString() : value.toFixed(2);
    }
    async crearNotificacionesSeguro(crear) {
        try {
            await crear();
        }
        catch (error) {
            console.error('No se pudo crear la notificación', error);
        }
    }
};
exports.SolicitudesService = SolicitudesService;
exports.SolicitudesService = SolicitudesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.Solicitud)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.DetalleSolicitud)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.Material)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.PrecioMaterial)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.DataSource,
        notificaciones_service_1.NotificacionesService])
], SolicitudesService);
//# sourceMappingURL=solicitudes.service.js.map