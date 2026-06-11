// Modulo de materiales, precios, ingresos de stock y consultas asociadas.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  InventarioLote,
  Material,
  MovimientoInventario,
  PrecioMaterial,
} from '../entities';
import { MaterialesController } from './materiales.controller';
import { MaterialesService } from './materiales.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Material,
      PrecioMaterial,
      MovimientoInventario,
      InventarioLote,
    ]),
    AuthModule,
  ],
  controllers: [MaterialesController],
  providers: [MaterialesService],
  exports: [MaterialesService],
})
export class MaterialesModule {}
