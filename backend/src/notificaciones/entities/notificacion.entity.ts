// Entidad de notificaciones internas por usuario con lectura y relacion a solicitud.
import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Solicitud, Usuario } from '../../entities';

@Entity('notificaciones')
export class Notificacion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'usuario_id' })
  usuarioId: string;

  @ManyToOne(() => Usuario, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'usuario_id' })
  usuario: Usuario;

  @Column()
  titulo: string;

  @Column()
  mensaje: string;

  @Column()
  tipo: string;

  @Column({ default: false })
  leida: boolean;

  @Column({ name: 'solicitud_id', nullable: true })
  solicitudId: string;

  @ManyToOne(() => Solicitud, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'solicitud_id' })
  solicitud: Solicitud;

  @CreateDateColumn({ name: 'fecha_creacion' })
  fechaCreacion: Date;
}
