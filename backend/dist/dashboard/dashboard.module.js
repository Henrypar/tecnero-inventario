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
exports.DashboardModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_module_1 = require("../auth/auth.module");
const jwt_guard_1 = require("../auth/jwt.guard");
function normalizarLineaIds(value) {
    if (!value)
        return null;
    const ids = Array.isArray(value)
        ? value.flatMap((item) => item.toString().split(','))
        : value.toString().split(',');
    const limpio = ids
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
    return limpio.length > 0 ? limpio : null;
}
const FECHA_SOLICITUD_LOCAL = `(COALESCE(s.fecha_entrega, s.fecha) AT TIME ZONE 'America/Guayaquil')`;
const FECHA_SOLICITUD_LOCAL_DATE = `${FECHA_SOLICITUD_LOCAL}::date`;
const FECHA_SOLICITUD_LOCAL_SIN_ALIAS = `(COALESCE(fecha_entrega, fecha) AT TIME ZONE 'America/Guayaquil')::date`;
let DashboardService = class DashboardService {
    constructor(dataSource) {
        this.dataSource = dataSource;
    }
    async getResumen(desde, hasta, lineaId, lineaIds) {
        const ahora = new Date();
        const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1);
        const d = desde ? new Date(desde) : inicioMes;
        const h = hasta ? new Date(hasta) : ahora;
        const lineaFiltro = lineaId || null;
        const lineasFiltro = normalizarLineaIds(lineaIds);
        const params = [d, h, lineaFiltro, lineasFiltro];
        const filtroBase = `
      s.estado = 'entregada'
      AND ${FECHA_SOLICITUD_LOCAL_DATE} BETWEEN $1::date AND $2::date
      AND ($3::uuid IS NULL OR s.linea_id = $3::uuid)
      AND ($4::text[] IS NULL OR s.linea_id::text = ANY($4::text[]))
    `;
        const totalesResult = await this.dataSource.query(`
      SELECT 
        COALESCE(SUM(d.subtotal), 0)::float AS costo_total,
        COUNT(DISTINCT s.id)::int AS total_solicitudes,
        0::int AS pendientes,
        0::int AS aprobadas,
        COUNT(DISTINCT s.id)::int AS entregadas,
        0::int AS rechazadas,
        COALESCE(SUM(d.subtotal) / NULLIF(COUNT(DISTINCT s.id), 0), 0)::float AS promedio_solicitud
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE ${filtroBase}
      `, params);
        const materialesActivosResult = await this.dataSource.query(`
      SELECT COUNT(*)::int AS total
      FROM materiales
      `);
        const materialesConsumidosResult = await this.dataSource.query(`
      SELECT COUNT(DISTINCT d.material_id)::int AS total
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE ${filtroBase}
      `, params);
        const porLinea = await this.dataSource.query(`
      SELECT
        COALESCE(s.linea_id::text, '') AS linea_id,
        COALESCE(s.linea_nombre, 'Sin línea') AS linea_nombre,
        COALESCE(SUM(d.subtotal), 0)::float AS costo_total,
        COUNT(DISTINCT s.id)::int AS total_solicitudes,
        COALESCE(SUM(d.subtotal) / NULLIF(COUNT(DISTINCT s.id), 0), 0)::float AS promedio_solicitud
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE ${filtroBase}
      GROUP BY s.linea_id, s.linea_nombre
      ORDER BY costo_total DESC
      `, params);
        const gastoPorDia = await this.dataSource.query(`
      SELECT
        TO_CHAR(${FECHA_SOLICITUD_LOCAL_DATE}, 'YYYY-MM-DD') AS dia,
        COALESCE(SUM(d.subtotal), 0)::float AS costo_total,
        COUNT(DISTINCT s.id)::int AS total_solicitudes
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE ${filtroBase}
      GROUP BY ${FECHA_SOLICITUD_LOCAL_DATE}
      ORDER BY ${FECHA_SOLICITUD_LOCAL_DATE} ASC
      `, params);
        const gastoLineaDia = await this.dataSource.query(`
      SELECT
        TO_CHAR(${FECHA_SOLICITUD_LOCAL_DATE}, 'YYYY-MM-DD') AS dia,
        COALESCE(s.linea_id::text, '') AS linea_id,
        COALESCE(s.linea_nombre, 'Sin línea') AS linea_nombre,
        COALESCE(SUM(d.subtotal), 0)::float AS costo_total
      FROM detalle_solicitud d
      INNER JOIN solicitudes s ON s.id = d.solicitud_id
      WHERE ${filtroBase}
      GROUP BY ${FECHA_SOLICITUD_LOCAL_DATE}, s.linea_id, s.linea_nombre
      ORDER BY ${FECHA_SOLICITUD_LOCAL_DATE} ASC, costo_total DESC
      `, params);
        const topMaterialesCosto = await this.dataSource.query(`
      WITH base AS (
        SELECT
          d.material_id,
          COALESCE(d.material_codigo, '') AS codigo,
          COALESCE(d.material_nombre, '') AS material_nombre,
          COALESCE(d.unidad_medida, '') AS unidad_medida,
          COALESCE(s.linea_id::text, '') AS linea_id,
          COALESCE(s.linea_nombre, 'Sin línea') AS linea_nombre,
          COALESCE(d.cantidad, 0)::numeric AS cantidad,
          COALESCE(d.subtotal, 0)::numeric AS subtotal,
          COALESCE(d.precio_unitario_momento, 0)::numeric AS precio_unitario_momento
        FROM detalle_solicitud d
        INNER JOIN solicitudes s ON s.id = d.solicitud_id
        WHERE ${filtroBase}
      ),
      lotes_usados AS (
        SELECT
          d.material_id,
          MIN(dcl.precio_unitario)::float AS precio_min_usado,
          MAX(dcl.precio_unitario)::float AS precio_max_usado,
          COUNT(DISTINCT dcl.precio_unitario)::int AS precios_usados
        FROM detalle_consumo_lotes dcl
        INNER JOIN detalle_solicitud d ON d.id = dcl.detalle_solicitud_id
        INNER JOIN solicitudes s ON s.id = d.solicitud_id
        WHERE ${filtroBase}
        GROUP BY d.material_id
      ),
      resumen_material AS (
        SELECT
          material_id,
          codigo,
          material_nombre,
          unidad_medida,
          COALESCE(SUM(cantidad), 0)::float AS cantidad_total,
          COALESCE(SUM(subtotal), 0)::float AS costo_total,
          MIN(precio_unitario_momento)::float AS precio_min_momento,
          MAX(precio_unitario_momento)::float AS precio_max_momento,
          COUNT(DISTINCT precio_unitario_momento)::int AS precios_momento
        FROM base
        GROUP BY material_id, codigo, material_nombre, unidad_medida
      ),
      resumen_linea AS (
        SELECT
          material_id,
          linea_id,
          linea_nombre,
          COALESCE(SUM(cantidad), 0)::float AS cantidad_total,
          COALESCE(SUM(subtotal), 0)::float AS costo_total
        FROM base
        GROUP BY material_id, linea_id, linea_nombre
      )
      SELECT
        rm.codigo,
        rm.material_nombre,
        rm.unidad_medida,
        rm.cantidad_total,
        rm.costo_total,
        COALESCE(lu.precio_min_usado, rm.precio_min_momento, 0)::float AS precio_min_usado,
        COALESCE(lu.precio_max_usado, rm.precio_max_momento, 0)::float AS precio_max_usado,
        COALESCE(lu.precios_usados, rm.precios_momento, 0)::int AS precios_usados,
        COALESCE(
          JSON_AGG(
            JSON_BUILD_OBJECT(
              'linea_id', rl.linea_id,
              'linea_nombre', rl.linea_nombre,
              'cantidad_total', rl.cantidad_total,
              'costo_total', rl.costo_total
            )
            ORDER BY rl.costo_total DESC
          ) FILTER (WHERE rl.material_id IS NOT NULL),
          '[]'::json
        ) AS lineas
      FROM resumen_material rm
      LEFT JOIN lotes_usados lu ON lu.material_id = rm.material_id
      LEFT JOIN resumen_linea rl ON rl.material_id = rm.material_id
      GROUP BY
        rm.material_id,
        rm.codigo,
        rm.material_nombre,
        rm.unidad_medida,
        rm.cantidad_total,
        rm.costo_total,
        rm.precio_min_momento,
        rm.precio_max_momento,
        rm.precios_momento,
        lu.precio_min_usado,
        lu.precio_max_usado,
        lu.precios_usados
      ORDER BY rm.costo_total DESC
      `, params);
        const topMaterialesCantidad = await this.dataSource.query(`
      WITH base AS (
        SELECT
          d.material_id,
          COALESCE(d.material_codigo, '') AS codigo,
          COALESCE(d.material_nombre, '') AS material_nombre,
          COALESCE(d.unidad_medida, '') AS unidad_medida,
          COALESCE(s.linea_id::text, '') AS linea_id,
          COALESCE(s.linea_nombre, 'Sin línea') AS linea_nombre,
          COALESCE(d.cantidad, 0)::numeric AS cantidad,
          COALESCE(d.subtotal, 0)::numeric AS subtotal
        FROM detalle_solicitud d
        INNER JOIN solicitudes s ON s.id = d.solicitud_id
        WHERE ${filtroBase}
      ),
      resumen_material AS (
        SELECT
          material_id,
          codigo,
          material_nombre,
          unidad_medida,
          COALESCE(SUM(cantidad), 0)::float AS cantidad_total,
          COALESCE(SUM(subtotal), 0)::float AS costo_total
        FROM base
        GROUP BY material_id, codigo, material_nombre, unidad_medida
      ),
      resumen_linea AS (
        SELECT
          material_id,
          linea_id,
          linea_nombre,
          COALESCE(SUM(cantidad), 0)::float AS cantidad_total,
          COALESCE(SUM(subtotal), 0)::float AS costo_total
        FROM base
        GROUP BY material_id, linea_id, linea_nombre
      )
      SELECT
        rm.codigo,
        rm.material_nombre,
        rm.unidad_medida,
        rm.cantidad_total,
        rm.costo_total,
        COALESCE(
          JSON_AGG(
            JSON_BUILD_OBJECT(
              'linea_id', rl.linea_id,
              'linea_nombre', rl.linea_nombre,
              'cantidad_total', rl.cantidad_total,
              'costo_total', rl.costo_total
            )
            ORDER BY rl.cantidad_total DESC
          ) FILTER (WHERE rl.material_id IS NOT NULL),
          '[]'::json
        ) AS lineas
      FROM resumen_material rm
      LEFT JOIN resumen_linea rl ON rl.material_id = rm.material_id
      GROUP BY
        rm.material_id,
        rm.codigo,
        rm.material_nombre,
        rm.unidad_medida,
        rm.cantidad_total,
        rm.costo_total
      ORDER BY rm.cantidad_total DESC
      `, params);
        const variacionPrecios = await this.dataSource.query(`
      WITH ranked AS (
        SELECT
          pm.material_id,
          pm.precio::float AS precio,
          pm.fecha_vigencia,
          ROW_NUMBER() OVER (
            PARTITION BY pm.material_id
            ORDER BY pm.fecha_vigencia DESC
          ) AS rn
        FROM precios_material pm
        WHERE pm.fecha_vigencia <= $1
          AND (
            $2::uuid IS NULL OR EXISTS (
              SELECT 1
              FROM linea_produccion_materiales lpm
              WHERE lpm.material_id = pm.material_id
                AND lpm.linea_produccion_id = $2::uuid
                AND lpm.activo = true
            )
          )
          AND (
            $3::text[] IS NULL OR EXISTS (
              SELECT 1
              FROM linea_produccion_materiales lpm
              WHERE lpm.material_id = pm.material_id
                AND lpm.linea_produccion_id::text = ANY($3::text[])
                AND lpm.activo = true
            )
          )
      ),
      pivot AS (
        SELECT
          material_id,
          MAX(CASE WHEN rn = 1 THEN precio END) AS precio_actual,
          MAX(CASE WHEN rn = 2 THEN precio END) AS precio_anterior,
          MAX(CASE WHEN rn = 1 THEN fecha_vigencia END) AS fecha_actual
        FROM ranked
        WHERE rn <= 2
        GROUP BY material_id
      )
      SELECT
        m.codigo,
        m.nombre AS material_nombre,
        m.unidad_medida,
        COALESCE(p.precio_actual, 0)::float AS precio_actual,
        COALESCE(p.precio_anterior, 0)::float AS precio_anterior,
        CASE
          WHEN COALESCE(p.precio_anterior, 0) > 0
          THEN ((p.precio_actual - p.precio_anterior) / p.precio_anterior * 100)::float
          ELSE 0::float
        END AS variacion_pct,
        p.fecha_actual
      FROM pivot p
      INNER JOIN materiales m ON m.id = p.material_id
      WHERE m.activo = true
        AND p.precio_actual IS NOT NULL
        AND p.precio_anterior IS NOT NULL
        AND ABS(p.precio_actual - p.precio_anterior) > 0.0001
      ORDER BY ABS(
        CASE
          WHEN COALESCE(p.precio_anterior, 0) > 0
          THEN ((p.precio_actual - p.precio_anterior) / p.precio_anterior * 100)
          ELSE 0
        END
      ) DESC,
      ABS(p.precio_actual - p.precio_anterior) DESC
      `, [h, lineaFiltro, lineasFiltro]);
        const produccionUnitaria = await this.dataSource.query(`
      WITH lineas AS (
        SELECT
          lp.id,
          lp.nombre
        FROM lineas_produccion lp
        WHERE lp.activa = true
          AND ($3::uuid IS NULL OR lp.id = $3::uuid)
          AND ($4::text[] IS NULL OR lp.id::text = ANY($4::text[]))
      ),
      costos AS (
        SELECT
          s.linea_id,
          COALESCE(SUM(d.subtotal), 0)::float AS costo_materiales,
          COUNT(DISTINCT s.id)::int AS despachos
        FROM detalle_solicitud d
        INNER JOIN solicitudes s ON s.id = d.solicitud_id
        WHERE ${filtroBase}
        GROUP BY s.linea_id
      ),
      produccion AS (
        SELECT
          linea_id,
          linea_nombre,
          unidad,
          SUM(cantidad)::float AS cantidad_producida,
          COALESCE(
            JSON_AGG(TO_CHAR(fecha, 'YYYY-MM-DD') ORDER BY fecha DESC)
              FILTER (WHERE fecha IS NOT NULL),
            '[]'::json
          ) AS fechas
        FROM produccion_diaria
        WHERE fecha BETWEEN $1::date AND $2::date
          AND ($3::uuid IS NULL OR linea_id = $3::uuid)
          AND ($4::text[] IS NULL OR linea_id::text = ANY($4::text[]))
        GROUP BY linea_id, linea_nombre, unidad
      )
      SELECT
        COALESCE(p.linea_id, l.id)::text AS linea_id,
        COALESCE(p.linea_nombre, l.nombre) AS linea_nombre,
        COALESCE(NULLIF(p.unidad, ''), 'unidades') AS unidad,
        COALESCE(p.cantidad_producida, 0)::float AS cantidad_producida,
        COALESCE(p.cantidad_producida, 0)::float AS cantidad_total,
        COALESCE(c.costo_materiales, 0)::float AS costo_materiales,
        COALESCE(c.despachos, 0)::int AS despachos,
        COALESCE(p.fechas, '[]'::json) AS fechas,
        CASE
          WHEN COALESCE(p.cantidad_producida, 0) > 0
          THEN (COALESCE(c.costo_materiales, 0) / COALESCE(p.cantidad_producida, 0))::float
          ELSE 0::float
        END AS costo_unitario
      FROM lineas l
      LEFT JOIN produccion p ON p.linea_id = l.id
      LEFT JOIN costos c ON c.linea_id = l.id
      WHERE COALESCE(p.cantidad_producida, 0) > 0
        OR COALESCE(c.costo_materiales, 0) > 0
        OR COALESCE(c.despachos, 0) > 0
      ORDER BY COALESCE(p.cantidad_producida, 0) DESC, l.nombre ASC
      `, params);
        const detallePorEstado = await this.dataSource.query(`
      SELECT
        estado,
        COUNT(*)::int AS total,
        COALESCE(SUM(costo_total), 0)::float AS costo_total
      FROM solicitudes
      WHERE ${FECHA_SOLICITUD_LOCAL_SIN_ALIAS} BETWEEN $1::date AND $2::date
        AND ($3::uuid IS NULL OR linea_id = $3::uuid)
        AND ($4::text[] IS NULL OR linea_id::text = ANY($4::text[]))
      GROUP BY estado
      ORDER BY total DESC
      `, params);
        const ultimasSolicitudes = await this.dataSource.query(`
      SELECT
        id,
        numero,
        solicitante_nombre,
        linea_nombre,
        estado,
        fecha,
        COALESCE(costo_total, 0)::float AS costo_total
      FROM solicitudes s
      WHERE ${filtroBase}
      ORDER BY ${FECHA_SOLICITUD_LOCAL_DATE} DESC
      LIMIT 12
      `, params);
        const totales = totalesResult[0] ?? {};
        return {
            filtros: {
                desde: d.toISOString(),
                hasta: h.toISOString(),
                linea_id: lineaFiltro,
                linea_ids: lineasFiltro,
            },
            totales: {
                costo_total: totales.costo_total ?? 0,
                total_solicitudes: totales.total_solicitudes ?? 0,
                pendientes: totales.pendientes ?? 0,
                aprobadas: totales.aprobadas ?? 0,
                entregadas: totales.entregadas ?? 0,
                rechazadas: totales.rechazadas ?? 0,
                promedio_solicitud: totales.promedio_solicitud ?? 0,
                materiales_activos: materialesActivosResult[0]?.total ?? 0,
                materiales_consumidos: materialesConsumidosResult[0]?.total ?? 0,
            },
            por_linea: porLinea,
            gasto_por_dia: gastoPorDia,
            gasto_linea_dia: gastoLineaDia,
            top_materiales: topMaterialesCosto,
            top_materiales_cantidad: topMaterialesCantidad,
            variacion_precios: variacionPrecios,
            produccion_unitaria: produccionUnitaria,
            detalle_por_estado: detallePorEstado,
            ultimas_solicitudes: ultimasSolicitudes,
        };
    }
};
DashboardService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [typeorm_2.DataSource])
], DashboardService);
let DashboardController = class DashboardController {
    constructor(svc) {
        this.svc = svc;
    }
    getResumen(desde, hasta, lineaId, lineaIds) {
        return this.svc.getResumen(desde, hasta, lineaId, lineaIds);
    }
};
__decorate([
    (0, common_1.Get)('resumen'),
    __param(0, (0, common_1.Query)('desde')),
    __param(1, (0, common_1.Query)('hasta')),
    __param(2, (0, common_1.Query)('linea_id')),
    __param(3, (0, common_1.Query)('linea_ids')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", void 0)
], DashboardController.prototype, "getResumen", null);
DashboardController = __decorate([
    (0, common_1.Controller)('dashboard'),
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard, jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador'),
    __metadata("design:paramtypes", [DashboardService])
], DashboardController);
let DashboardModule = class DashboardModule {
};
exports.DashboardModule = DashboardModule;
exports.DashboardModule = DashboardModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([]), auth_module_1.AuthModule],
        controllers: [DashboardController],
        providers: [DashboardService],
    })
], DashboardModule);
//# sourceMappingURL=dashboard.module.js.map