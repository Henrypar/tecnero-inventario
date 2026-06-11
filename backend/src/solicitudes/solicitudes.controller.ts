// Controlador del ciclo de vida de solicitudes: crear, aprobar, rechazar y entregar.
import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { SolicitudesService } from './solicitudes.service';
import { JwtAuthGuard, RolesGuard, Roles } from '../auth/jwt.guard';

@Controller('solicitudes')
@UseGuards(JwtAuthGuard)
export class SolicitudesController {
  constructor(private svc: SolicitudesService) {}

  @Post()
  crear(@Body() body: any, @Request() req) {
    return this.svc.crear({
      ...body,
      solicitanteId: req.user.userId,
      solicitanteNombre: req.user.nombre,
    });
  }

  @Post('despacho-bodega')
  @UseGuards(RolesGuard)
  @Roles('admin', 'bodeguero')
  crearDespachoBodega(@Body() body: any, @Request() req) {
    return this.svc.crearDespachoBodega(body, req.user.nombre);
  }

  @Get('mis-solicitudes')
  misSolicitudes(@Request() req) {
    return this.svc.findAll({
      solicitanteId: req.user.userId,
    });
  }

  @Get('aprobadas')
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador', 'bodeguero')
  aprobadas() {
    return this.svc.findAll({
      estado: 'aprobada',
    });
  }
  @Get('pendientes-bodega')
  @UseGuards(RolesGuard)
  @Roles('admin', 'bodeguero')
  pendientesBodega() {
    return this.svc.findAll({
      estado: 'pendiente',
    });
  }
  @Get('entregadas')
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador', 'bodeguero')
  entregadas() {
    return this.svc.findAll({
      estado: 'entregada',
    });
  }

  @Get('historial-bodega')
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador', 'bodeguero')
  historialBodega() {
    return this.svc.findHistoricoBodega();
  }

  @Get()
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador')
  findAll(@Query() q: any) {
    return this.svc.findAll(q);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.svc.findById(id);
  }

  @Patch(':id')
  editar(@Param('id') id: string, @Body() body: any, @Request() req) {
    return this.svc.editar(id, body, req.user.userId);
  }

  @Patch(':id/aprobar')
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador')
  aprobar(@Param('id') id: string, @Request() req) {
    return this.svc.aprobar(id, req.user.nombre);
  }

  @Patch(':id/rechazar')
  @UseGuards(RolesGuard)
  @Roles('admin', 'coordinador', 'bodeguero')
  rechazar(
    @Param('id') id: string,
    @Body() body: { motivo: string },
    @Request() req,
  ) {
    return this.svc.rechazar(id, req.user.nombre, body.motivo);
  }

  @Patch(':id/entregar')
  @UseGuards(RolesGuard)
  @Roles('admin', 'bodeguero')
  entregar(@Param('id') id: string, @Request() req) {
    return this.svc.marcarEntregada(id, req.user.nombre);
  }
}
