// Modulo de precios de materiales y su historial de vigencias.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PrecioMaterial, Material } from '../entities';
import { AuthModule } from '../auth/auth.module';
import { Controller, Get, Post, Body, Param, UseGuards, Request } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Injectable, NotFoundException } from '@nestjs/common';
import { JwtAuthGuard, RolesGuard, Roles } from '../auth/jwt.guard';

@Injectable()
class PreciosService {
  constructor(
    @InjectRepository(PrecioMaterial) private preciosRepo: Repository<PrecioMaterial>,
    @InjectRepository(Material) private materialesRepo: Repository<Material>,
  ) {}

  async getPrecioActual(materialId: string) {
    return this.preciosRepo.findOne({ where: { materialId }, order: { fechaVigencia: 'DESC' } });
  }

  async getHistorial(materialId: string) {
    return this.preciosRepo.find({ where: { materialId }, order: { fechaVigencia: 'DESC' }, take: 10 });
  }

  async actualizarPrecio(materialId: string, precio: number, registradoPor: string) {
    const m = await this.materialesRepo.findOne({ where: { id: materialId } });
    if (!m) throw new NotFoundException('Material no encontrado');
    const nuevo = this.preciosRepo.create({ materialId, precio, registradoPor });
    return this.preciosRepo.save(nuevo);
  }
}

@Controller('precios')
@UseGuards(JwtAuthGuard)
class PreciosController {
  constructor(private svc: PreciosService) {}

  @Get(':materialId/actual')
  getActual(@Param('materialId') id: string) { return this.svc.getPrecioActual(id); }

  @Get(':materialId/historial')
  @UseGuards(RolesGuard) @Roles('admin', 'asistente_compras')
  getHistorial(@Param('materialId') id: string) { return this.svc.getHistorial(id); }

  @Post(':materialId')
  @UseGuards(RolesGuard) @Roles('admin', 'asistente_compras')
  actualizar(@Param('materialId') id: string, @Body() body: { precio: number }, @Request() req) {
    return this.svc.actualizarPrecio(id, body.precio, req.user.nombre);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([PrecioMaterial, Material]), AuthModule],
  controllers: [PreciosController],
  providers: [PreciosService],
  exports: [PreciosService],
})
export class PreciosModule {}
