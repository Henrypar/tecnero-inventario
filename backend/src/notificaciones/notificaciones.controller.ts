// API HTTP para consultar y marcar notificaciones del usuario autenticado.
import { Controller, Get, Param, Patch, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { NotificacionesService } from './notificaciones.service';

@Controller('notificaciones')
@UseGuards(JwtAuthGuard)
export class NotificacionesController {
  constructor(private readonly service: NotificacionesService) {}

  @Get()
  obtenerMisNotificaciones(@Request() req) {
    return this.service.obtenerMisNotificaciones(req.user.userId);
  }

  @Get('no-leidas')
  async contarNoLeidas(@Request() req) {
    const cantidad = await this.service.contarNoLeidas(req.user.userId);
    return { cantidad };
  }

  @Patch('marcar-todas-leidas')
  marcarTodasComoLeidas(@Request() req) {
    return this.service.marcarTodasComoLeidas(req.user.userId);
  }

  @Patch(':id/leida')
  marcarComoLeida(@Param('id') id: string, @Request() req) {
    return this.service.marcarComoLeida(id, req.user.userId);
  }
}
