// Modulo que expone las lineas de produccion y su catalogo asociado.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LineaProduccion, LineaProduccionMaterial } from '../entities';
import { AuthModule } from '../auth/auth.module';
import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Injectable } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';

@Injectable()
class LineasService {
  constructor(
    @InjectRepository(LineaProduccion)
    private repo: Repository<LineaProduccion>,
    @InjectRepository(LineaProduccionMaterial)
    private lineaMaterialRepo: Repository<LineaProduccionMaterial>,
  ) {}

  findAll() { return this.repo.find({ where: { activa: true }, order: { nombre: 'ASC' } }); }

  async findMateriales(lineaId: string) {
    const relaciones = await this.lineaMaterialRepo.find({
      where: {
        lineaProduccionId: lineaId,
        activo: true,
        material: { activo: true },
      },
      relations: { material: true },
      order: {
        material: { nombre: 'ASC' },
      },
    });

    return relaciones.map((relacion) => ({
      id: relacion.id,
      lineaProduccionId: relacion.lineaProduccionId,
      materialId: relacion.materialId,
      cantidadSugerida: Number(relacion.cantidadSugerida),
      activo: relacion.activo,
      material: relacion.material,
    }));
  }
}

@Controller('lineas')
@UseGuards(JwtAuthGuard)
class LineasController {
  constructor(private svc: LineasService) {}
  @Get() findAll() { return this.svc.findAll(); }
  @Get(':id/materiales') findMateriales(@Param('id') id: string) {
    return this.svc.findMateriales(id);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([LineaProduccion, LineaProduccionMaterial]), AuthModule],
  controllers: [LineasController],
  providers: [LineasService],
})
export class LineasModule {}
