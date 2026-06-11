// DTO minimo para crear una notificacion persistida y emitida por socket.
export class CrearNotificacionDto {
  usuarioId: string;
  titulo: string;
  mensaje: string;
  tipo: string;
  solicitudId?: string;
}
