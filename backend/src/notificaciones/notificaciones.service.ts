// Servicio que guarda notificaciones y las publica por WebSocket.
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Usuario } from '../entities';
import { CrearNotificacionDto } from './dto/crear-notificacion.dto';
import { Notificacion } from './entities/notificacion.entity';
import { NotificacionesGateway } from './notificaciones.gateway';

@Injectable()
export class NotificacionesService {
  constructor(
    @InjectRepository(Notificacion)
    private notificacionesRepo: Repository<Notificacion>,

    @InjectRepository(Usuario)
    private usuariosRepo: Repository<Usuario>,

    private gateway: NotificacionesGateway,
  ) {}

  async crearNotificacion(data: CrearNotificacionDto): Promise<Notificacion> {
    // Persistimos primero y luego emitimos por WebSocket para no perder el
    // evento si el cliente estaba desconectado.
    const notificacion = this.notificacionesRepo.create({
      usuarioId: data.usuarioId,
      titulo: data.titulo,
      mensaje: data.mensaje,
      tipo: data.tipo,
      solicitudId: data.solicitudId ?? null,
      leida: false,
    });

    const guardada = await this.notificacionesRepo.save(notificacion);
    this.gateway.emitirNuevaNotificacion(data.usuarioId, guardada);

    return guardada;
  }

  async crearParaRoles(
    roles: string[],
    data: Omit<CrearNotificacionDto, 'usuarioId'>,
  ): Promise<Notificacion[]> {
    // Resuelve todos los usuarios activos de los roles indicados y genera una
    // notificación individual para cada uno.
    const usuarios = await this.usuariosRepo.find({
      where: {
        rol: In(roles),
        activo: true,
      },
    });

    const creadas: Notificacion[] = [];

    for (const usuario of usuarios) {
      creadas.push(
        await this.crearNotificacion({
          ...data,
          usuarioId: usuario.id,
        }),
      );
    }

    return creadas;
  }

  async obtenerMisNotificaciones(usuarioId: string): Promise<Notificacion[]> {
    return this.notificacionesRepo.find({
      where: { usuarioId },
      order: { fechaCreacion: 'DESC' },
      relations: {
        solicitud: true,
      },
    });
  }

  async contarNoLeidas(usuarioId: string): Promise<number> {
    return this.notificacionesRepo.count({
      where: {
        usuarioId,
        leida: false,
      },
    });
  }

  async marcarComoLeida(id: string, usuarioId: string): Promise<Notificacion> {
    // La marca como leída solo puede afectar notificaciones del usuario
    // autenticado.
    const notificacion = await this.notificacionesRepo.findOne({
      where: { id, usuarioId },
    });

    if (!notificacion) {
      throw new NotFoundException('Notificación no encontrada');
    }

    notificacion.leida = true;
    return this.notificacionesRepo.save(notificacion);
  }

  async marcarTodasComoLeidas(usuarioId: string): Promise<{ updated: number }> {
    // Operación masiva para la bandeja de notificaciones.
    const result = await this.notificacionesRepo.update(
      { usuarioId, leida: false },
      { leida: true },
    );

    return { updated: result.affected ?? 0 };
  }
}
