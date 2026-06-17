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
exports.ProduccionModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_module_1 = require("../auth/auth.module");
const jwt_guard_1 = require("../auth/jwt.guard");
const entities_1 = require("../entities");
function normalizarFecha(value) {
    return (value ?? '').toString().slice(0, 10);
}
function normalizarLineaIds(value) {
    if (!value)
        return [];
    if (Array.isArray(value)) {
        return value
            .flatMap((item) => item.toString().split(','))
            .map((item) => item.trim())
            .filter((item) => item.length > 0);
    }
    return value
        .toString()
        .split(',')
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
}
let ProduccionService = class ProduccionService {
    constructor(produccionRepo, lineasRepo) {
        this.produccionRepo = produccionRepo;
        this.lineasRepo = lineasRepo;
    }
    async listar(desde, hasta, lineaId, lineaIds) {
        const lineasFiltro = normalizarLineaIds(lineaIds);
        const fechaDesde = normalizarFecha(desde);
        const fechaHasta = normalizarFecha(hasta);
        const params = [
            fechaDesde,
            fechaHasta,
            lineaId ?? null,
            lineasFiltro.length > 0 ? lineasFiltro : null,
        ];
        const whereLinea = `
      ($3::uuid IS NULL OR p.linea_id = $3::uuid)
      AND ($4::text[] IS NULL OR p.linea_id::text = ANY($4::text[]))
    `;
        return this.produccionRepo.manager.query(`
      WITH produccion AS (
        SELECT
          (ARRAY_AGG(p.id ORDER BY p.created_at ASC))[1]::text AS id,
          p.fecha::date AS fecha,
          p.linea_id,
          MAX(p.linea_nombre) AS linea_nombre,
          SUM(p.cantidad)::float AS cantidad,
          MAX(NULLIF(p.unidad, '')) AS unidad,
          MAX(p.registrado_por) AS registrado_por,
          MAX(p.observaciones) AS observaciones,
          MIN(p.created_at) AS created_at
        FROM produccion_diaria p
        WHERE p.fecha BETWEEN $1::date AND $2::date
          AND ${whereLinea}
        GROUP BY p.fecha::date, p.linea_id
      ),
      actividad AS (
        SELECT DISTINCT
          COALESCE(s.fecha_entrega, s.fecha)::date AS fecha,
          s.linea_id,
          COALESCE(s.linea_nombre, 'Sin línea') AS linea_nombre
        FROM solicitudes s
        WHERE s.estado = 'entregada'
          AND COALESCE(s.fecha_entrega, s.fecha)::date BETWEEN $1::date AND $2::date
          AND ($3::uuid IS NULL OR s.linea_id = $3::uuid)
          AND ($4::text[] IS NULL OR s.linea_id::text = ANY($4::text[]))
      )
      SELECT
        p.id AS id,
        COALESCE(p.fecha, a.fecha)::date AS fecha,
        COALESCE(p.linea_id, a.linea_id)::text AS linea_id,
        COALESCE(p.linea_nombre, a.linea_nombre) AS linea_nombre,
        COALESCE(p.cantidad, 0)::float AS cantidad,
        COALESCE(NULLIF(p.unidad, ''), 'unidades') AS unidad,
        COALESCE(p.registrado_por, '') AS registrado_por,
        COALESCE(p.observaciones, '') AS observaciones,
        COALESCE(p.created_at, NOW()) AS created_at,
        CASE WHEN p.fecha IS NULL THEN true ELSE false END AS pendiente_produccion
      FROM actividad a
      FULL OUTER JOIN produccion p
        ON p.fecha = a.fecha
       AND p.linea_id = a.linea_id
      ORDER BY COALESCE(p.fecha, a.fecha) DESC, COALESCE(p.created_at, NOW()) DESC, linea_nombre ASC
      `, params);
    }
    async obtenerDetalle(fecha, lineaId) {
        const fechaFiltro = normalizarFecha(fecha);
        if (!fechaFiltro) {
            throw new common_1.BadRequestException('La fecha es obligatoria');
        }
        if (!lineaId) {
            throw new common_1.BadRequestException('La línea de producción es obligatoria');
        }
        const dataSource = this.produccionRepo.manager;
        const produccion = await this.produccionRepo.findOne({
            where: {
                fecha: fechaFiltro,
                lineaId,
            },
        });
        const cantidadProducida = Number(produccion?.cantidad ?? 0);
        const materialesGastados = await dataSource.query(`
      SELECT
        d.material_id,
        d.material_nombre,
        d.material_codigo,
        d.unidad_medida,
        COALESCE(SUM(d.cantidad), 0)::float AS cantidad_total,
        COALESCE(SUM(d.subtotal), 0)::float AS costo_total,
        COALESCE(
          SUM(d.subtotal) / NULLIF($3::numeric, 0),
          0
        )::float AS costo_unitario
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE s.estado = 'entregada'
        AND COALESCE(s.fecha_entrega, s.fecha)::date = $1::date
        AND s.linea_id = $2::uuid
      GROUP BY
        d.material_id,
        d.material_nombre,
        d.material_codigo,
        d.unidad_medida
      ORDER BY costo_total DESC
      `, [fechaFiltro, lineaId, cantidadProducida]);
        const costoTotalMateriales = materialesGastados.reduce((sum, item) => sum + Number(item.costo_total ?? 0), 0);
        const costoUnitarioTotal = cantidadProducida > 0 ? costoTotalMateriales / cantidadProducida : 0;
        return {
            fecha: fechaFiltro,
            linea_id: lineaId,
            linea_nombre: produccion?.lineaNombre ?? null,
            produccion,
            cantidad_producida: cantidadProducida,
            unidad: produccion?.unidad ?? null,
            costo_total_materiales: costoTotalMateriales,
            costo_unitario_total: costoUnitarioTotal,
            materiales: materialesGastados,
        };
    }
    async crear(dto, registradoPor) {
        const lineaId = dto.lineaId ?? dto.linea_id;
        const fecha = normalizarFecha(dto.fecha);
        const cantidad = Number(dto.cantidad);
        const unidad = (dto.unidad ?? '').toString().trim();
        const observaciones = dto.observaciones ?? null;
        if (!fecha) {
            throw new common_1.BadRequestException('La fecha es obligatoria');
        }
        if (!lineaId) {
            throw new common_1.BadRequestException('Selecciona una línea');
        }
        if (Number.isNaN(cantidad) || cantidad <= 0) {
            throw new common_1.BadRequestException('La cantidad producida debe ser mayor a 0');
        }
        if (!unidad) {
            throw new common_1.BadRequestException('La unidad es obligatoria');
        }
        const linea = await this.lineasRepo.findOne({
            where: { id: lineaId },
        });
        if (!linea) {
            throw new common_1.NotFoundException('Línea de producción no encontrada');
        }
        const existente = await this.produccionRepo.findOne({
            where: {
                fecha,
                lineaId: linea.id,
            },
        });
        if (existente) {
            existente.cantidad = cantidad;
            existente.unidad = unidad;
            existente.lineaNombre = linea.nombre;
            existente.registradoPor = registradoPor;
            existente.observaciones = observaciones;
            return this.produccionRepo.save(existente);
        }
        return this.produccionRepo.save(this.produccionRepo.create({
            fecha,
            lineaId: linea.id,
            lineaNombre: linea.nombre,
            cantidad,
            unidad,
            registradoPor,
            observaciones,
        }));
    }
    async actualizar(id, dto, registradoPor) {
        const item = await this.produccionRepo.findOne({
            where: { id },
        });
        if (!item) {
            throw new common_1.NotFoundException('Registro de producción no encontrado');
        }
        const cantidad = Number(dto.cantidad);
        const unidad = (dto.unidad ?? '').toString().trim();
        const observaciones = dto.observaciones ?? null;
        if (Number.isNaN(cantidad) || cantidad <= 0) {
            throw new common_1.BadRequestException('La cantidad producida debe ser mayor a 0');
        }
        if (!unidad) {
            throw new common_1.BadRequestException('La unidad es obligatoria');
        }
        item.cantidad = cantidad;
        item.unidad = unidad;
        item.observaciones = observaciones;
        item.registradoPor = registradoPor;
        return this.produccionRepo.save(item);
    }
    async eliminar(id) {
        const item = await this.produccionRepo.findOne({
            where: { id },
        });
        if (!item) {
            throw new common_1.NotFoundException('Registro de producción no encontrado');
        }
        await this.produccionRepo.delete(id);
        return { ok: true };
    }
};
ProduccionService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.ProduccionDiaria)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.LineaProduccion)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], ProduccionService);
let ProduccionController = class ProduccionController {
    constructor(svc) {
        this.svc = svc;
    }
    listar(desde, hasta, lineaId, lineaIds) {
        return this.svc.listar(desde, hasta, lineaId, lineaIds);
    }
    obtenerDetalle(fecha, lineaId) {
        return this.svc.obtenerDetalle(fecha, lineaId);
    }
    crear(body, req) {
        return this.svc.crear(body, req.user.nombre);
    }
    actualizar(id, body, req) {
        return this.svc.actualizar(id, body, req.user.nombre);
    }
    eliminar(id) {
        return this.svc.eliminar(id);
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('desde')),
    __param(1, (0, common_1.Query)('hasta')),
    __param(2, (0, common_1.Query)('linea_id')),
    __param(3, (0, common_1.Query)('linea_ids')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", void 0)
], ProduccionController.prototype, "listar", null);
__decorate([
    (0, common_1.Get)('detalle'),
    __param(0, (0, common_1.Query)('fecha')),
    __param(1, (0, common_1.Query)('linea_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], ProduccionController.prototype, "obtenerDetalle", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], ProduccionController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], ProduccionController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], ProduccionController.prototype, "eliminar", null);
ProduccionController = __decorate([
    (0, common_1.Controller)('produccion'),
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard, jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador', 'asistente_compras'),
    __metadata("design:paramtypes", [ProduccionService])
], ProduccionController);
let ProduccionModule = class ProduccionModule {
};
exports.ProduccionModule = ProduccionModule;
exports.ProduccionModule = ProduccionModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([entities_1.ProduccionDiaria, entities_1.LineaProduccion]),
            auth_module_1.AuthModule,
        ],
        controllers: [ProduccionController],
        providers: [ProduccionService],
    })
], ProduccionModule);
//# sourceMappingURL=produccion.module.js.map