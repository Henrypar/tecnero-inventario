// Modulo de persistencia y emision en tiempo real de notificaciones.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Usuario } from '../entities';
import { Notificacion } from './entities/notificacion.entity';
import { NotificacionesController } from './notificaciones.controller';
import { NotificacionesGateway } from './notificaciones.gateway';
import { NotificacionesService } from './notificaciones.service';

@Module({
  imports: [TypeOrmModule.forFeature([Notificacion, Usuario])],
  controllers: [NotificacionesController],
  providers: [NotificacionesService, NotificacionesGateway],
  exports: [NotificacionesService],
})
export class NotificacionesModule {}
