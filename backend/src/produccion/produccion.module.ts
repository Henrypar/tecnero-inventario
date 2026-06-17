// Modulo para registrar y consultar la produccion diaria por linea.
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthModule } from '../auth/auth.module';
import { JwtAuthGuard, RolesGuard, Roles } from '../auth/jwt.guard';
import { LineaProduccion, ProduccionDiaria } from '../entities';

function normalizarFecha(value: any): string {
  return (value ?? '').toString().slice(0, 10);
}

function normalizarLineaIds(value?: string | string[]): string[] {
  if (!value) return [];

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

@Injectable()
class ProduccionService {
  constructor(
    @InjectRepository(ProduccionDiaria)
    private produccionRepo: Repository<ProduccionDiaria>,

    @InjectRepository(LineaProduccion)
    private lineasRepo: Repository<LineaProduccion>,
  ) {}

  async listar(
    desde?: string,
    hasta?: string,
    lineaId?: string,
    lineaIds?: string | string[],
  ) {
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

    return this.produccionRepo.manager.query(
      `
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
      `,
      params,
    );
  }

  async obtenerDetalle(fecha: string, lineaId: string) {
    const fechaFiltro = normalizarFecha(fecha);

    if (!fechaFiltro) {
      throw new BadRequestException('La fecha es obligatoria');
    }

    if (!lineaId) {
      throw new BadRequestException('La línea de producción es obligatoria');
    }

    const dataSource = this.produccionRepo.manager;

    const produccion = await this.produccionRepo.findOne({
      where: {
        fecha: fechaFiltro,
        lineaId,
      },
    });

    const cantidadProducida = Number(produccion?.cantidad ?? 0);

    const materialesGastados = await dataSource.query(
      `
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
      `,
      [fechaFiltro, lineaId, cantidadProducida],
    );

    const costoTotalMateriales = materialesGastados.reduce(
      (sum: number, item: any) => sum + Number(item.costo_total ?? 0),
      0,
    );

    const costoUnitarioTotal =
      cantidadProducida > 0 ? costoTotalMateriales / cantidadProducida : 0;

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

  async crear(dto: any, registradoPor: string) {
    const lineaId = dto.lineaId ?? dto.linea_id;
    const fecha = normalizarFecha(dto.fecha);
    const cantidad = Number(dto.cantidad);
    const unidad = (dto.unidad ?? '').toString().trim();
    const observaciones = dto.observaciones ?? null;

    if (!fecha) {
      throw new BadRequestException('La fecha es obligatoria');
    }

    if (!lineaId) {
      throw new BadRequestException('Selecciona una línea');
    }

    if (Number.isNaN(cantidad) || cantidad <= 0) {
      throw new BadRequestException('La cantidad producida debe ser mayor a 0');
    }

    if (!unidad) {
      throw new BadRequestException('La unidad es obligatoria');
    }

    const linea = await this.lineasRepo.findOne({
      where: { id: lineaId },
    });

    if (!linea) {
      throw new NotFoundException('Línea de producción no encontrada');
    }

    /**
     * IMPORTANTE:
     * Antes siempre insertaba un nuevo registro.
     * Ahora si ya existe fecha + línea, actualiza ese mismo registro.
     * Esto evita duplicados y permite que la pantalla funcione como "editar cantidad producida".
     */
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

    return this.produccionRepo.save(
      this.produccionRepo.create({
        fecha,
        lineaId: linea.id,
        lineaNombre: linea.nombre,
        cantidad,
        unidad,
        registradoPor,
        observaciones,
      }),
    );
  }

  async actualizar(id: string, dto: any, registradoPor: string) {
    const item = await this.produccionRepo.findOne({
      where: { id },
    });

    if (!item) {
      throw new NotFoundException('Registro de producción no encontrado');
    }

    const cantidad = Number(dto.cantidad);
    const unidad = (dto.unidad ?? '').toString().trim();
    const observaciones = dto.observaciones ?? null;

    if (Number.isNaN(cantidad) || cantidad <= 0) {
      throw new BadRequestException('La cantidad producida debe ser mayor a 0');
    }

    if (!unidad) {
      throw new BadRequestException('La unidad es obligatoria');
    }

    item.cantidad = cantidad;
    item.unidad = unidad;
    item.observaciones = observaciones;
    item.registradoPor = registradoPor;

    return this.produccionRepo.save(item);
  }

  async eliminar(id: string) {
    const item = await this.produccionRepo.findOne({
      where: { id },
    });

    if (!item) {
      throw new NotFoundException('Registro de producción no encontrado');
    }

    await this.produccionRepo.delete(id);

    return { ok: true };
  }
}

@Controller('produccion')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin', 'coordinador', 'asistente_compras')
class ProduccionController {
  constructor(private readonly svc: ProduccionService) {}

  @Get()
  listar(
    @Query('desde') desde?: string,
    @Query('hasta') hasta?: string,
    @Query('linea_id') lineaId?: string,
    @Query('linea_ids') lineaIds?: string | string[],
  ) {
    return this.svc.listar(desde, hasta, lineaId, lineaIds);
  }

  @Get('detalle')
  obtenerDetalle(
    @Query('fecha') fecha: string,
    @Query('linea_id') lineaId: string,
  ) {
    return this.svc.obtenerDetalle(fecha, lineaId);
  }

  @Post()
  crear(@Body() body: any, @Request() req) {
    return this.svc.crear(body, req.user.nombre);
  }

  @Patch(':id')
  actualizar(@Param('id') id: string, @Body() body: any, @Request() req) {
    return this.svc.actualizar(id, body, req.user.nombre);
  }

  @Delete(':id')
  eliminar(@Param('id') id: string) {
    return this.svc.eliminar(id);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([ProduccionDiaria, LineaProduccion]),
    AuthModule,
  ],
  controllers: [ProduccionController],
  providers: [ProduccionService],
})
export class ProduccionModule {}
