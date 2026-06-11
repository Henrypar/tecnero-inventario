// Modulo que conecta solicitudes con inventario, FIFO y notificaciones.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  DetalleConsumoLote,
  DetalleSolicitud,
  InventarioLote,
  Material,
  PrecioMaterial,
  Solicitud,
} from '../entities';
import { SolicitudesController } from './solicitudes.controller';
import { SolicitudesService } from './solicitudes.service';
import { AuthModule } from '../auth/auth.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Solicitud,
      DetalleSolicitud,
      Material,
      PrecioMaterial,
      InventarioLote,
      DetalleConsumoLote,
    ]),
    AuthModule,
    NotificacionesModule,
  ],
  controllers: [SolicitudesController],
  providers: [SolicitudesService],
  exports: [SolicitudesService],
})
export class SolicitudesModule {}
