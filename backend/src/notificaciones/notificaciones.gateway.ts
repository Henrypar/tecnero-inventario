// Gateway Socket.IO que entrega notificaciones en tiempo real a cada usuario.
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Notificacion } from './entities/notificacion.entity';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class NotificacionesGateway implements OnGatewayConnection {
  @WebSocketServer()
  server: Server;

  handleConnection(client: Socket) {
    // Si el cliente llega autenticado por handshake, lo unimos de una vez a
    // su sala privada sin esperar el evento explícito.
    const usuarioId = client.handshake.auth?.usuarioId ?? client.handshake.query?.usuarioId;

    if (usuarioId) {
      this.unirUsuarioASala(client, String(usuarioId));
    }
  }

  @SubscribeMessage('registrar_usuario')
  registrarUsuario(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { usuarioId?: string },
  ) {
    // Fallback para clientes que registran el usuario luego de conectar.
    if (!data?.usuarioId) {
      return { ok: false, message: 'usuarioId requerido' };
    }

    this.unirUsuarioASala(client, String(data.usuarioId));
    return { ok: true };
  }

  emitirNuevaNotificacion(usuarioId: string, notificacion: Notificacion) {
    // Cada usuario escucha solo su propia sala privada.
    this.server
      .to(this.salaUsuario(usuarioId))
      .emit('nueva_notificacion', notificacion);
  }

  private unirUsuarioASala(client: Socket, usuarioId: string) {
    client.join(this.salaUsuario(usuarioId));
  }

  private salaUsuario(usuarioId: string) {
    return `usuario-${usuarioId}`;
  }
}
