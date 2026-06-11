// Controlador para catalogo de materiales, stock y operaciones de compra.
import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { MaterialesService } from './materiales.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard, Roles } from '../auth/jwt.guard';

@Controller('materiales')
@UseGuards(JwtAuthGuard)
export class MaterialesController {
  constructor(private svc: MaterialesService) {}

  @Get()
  findAll() { return this.svc.findAll(); }

  @Get('con-precio')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  findAllConPrecio() { return this.svc.findAllConPrecio(); }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  crear(@Body() body: any, @Request() req) {
    return this.svc.crear(body, req.user.nombre);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  actualizar(@Param('id') id: string, @Body() body: any) {
    return this.svc.actualizar(id, body);
  }

  @Patch(':id/stock')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  ajustarStock(@Param('id') id: string, @Body() body: any, @Request() req) {
    return this.svc.ajustarStock(id, { ...body, registradoPor: req.user.nombre });
  }

  @Post('ingresos')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  registrarIngreso(@Body() body: any, @Request() req) {
    return this.svc.registrarIngreso(body, req.user.nombre);
  }

  @Get('ingresos/historial')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  historialIngresos() {
    return this.svc.historialIngresos();
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('admin', 'asistente_compras')
  desactivar(@Param('id') id: string) {
    return this.svc.desactivar(id);
  }
}
