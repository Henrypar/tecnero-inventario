// Modelo relacional principal del sistema: usuarios, lineas, materiales, solicitudes, inventario FIFO, produccion diaria y notificaciones.
// ═══════════════════════════════════════════════════
// ENTIDADES
// ═══════════════════════════════════════════════════
// Este archivo concentra el modelo relacional principal del demo. Las 12
// tablas cubren usuarios, lineas, materiales, solicitudes, inventario FIFO,
// produccion diaria y notificaciones internas.
import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, ManyToOne, OneToMany, JoinColumn,
} from 'typeorm';

// ─── USUARIO ────────────────────────────────────────
@Entity('usuarios')
export class Usuario {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  nombre: string;

  @Column({ unique: true })
  email: string;

  @Column()
  rol: string; // admin | coordinador | operario | bodeguero

  @Column({ default: true })
  activo: boolean;

  @Column({ name: 'password_hash', nullable: true })
  passwordHash: string;
}

// ─── LINEA PRODUCCION ────────────────────────────────
@Entity('lineas_produccion')
export class LineaProduccion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  nombre: string;

  @Column({ nullable: true })
  descripcion: string;

  @Column({ default: true })
  activa: boolean;
}

// ─── PRODUCCION DIARIA ──────────────────────────────
// Registra cuantas unidades produjo/reparo cada linea en una fecha. Dashboard
// cruza este dato con materiales despachados para obtener costo unitario real.
@Entity('produccion_diaria')
export class ProduccionDiaria {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'date' })
  fecha: string;

  @Column({ name: 'linea_id' })
  lineaId: string;

  @ManyToOne(() => LineaProduccion)
  @JoinColumn({ name: 'linea_id' })
  linea: LineaProduccion;

  @Column({ name: 'linea_nombre' })
  lineaNombre: string;

  @Column({ type: 'decimal' })
  cantidad: number;

  @Column()
  unidad: string;

  @Column({ name: 'registrado_por' })
  registradoPor: string;

  @Column({ nullable: true })
  observaciones: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

// ─── MATERIAL ────────────────────────────────────────
@Entity('materiales')
export class Material {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  codigo: string;

  @Column()
  nombre: string;

  @Column({ name: 'unidad_medida' })
  unidadMedida: string;

  @Column()
  categoria: string;

  @Column({ name: 'stock_actual', type: 'decimal', default: 0 })
  stockActual: number;

  @Column({ name: 'stock_minimo_alerta', type: 'decimal', default: 5 })
  stockMinimoAlerta: number;

  @Column({ name: 'costo_promedio', type: 'decimal', precision: 12, scale: 4, default: 0 })
  costoPromedio: number;

  @Column({ name: 'valor_inventario', type: 'decimal', precision: 14, scale: 4, default: 0 })
  valorInventario: number;

  @Column({ default: true })
  activo: boolean;

  @OneToMany(() => PrecioMaterial, (p) => p.material)
  precios: PrecioMaterial[];

  @OneToMany(() => LineaProduccionMaterial, (lpm) => lpm.material)
  lineasProduccion: LineaProduccionMaterial[];

  @OneToMany(() => InventarioLote, (l) => l.material)
  lotes: InventarioLote[];
}

// ─── RELACIÓN LÍNEA - MATERIAL ─────────────────────
@Entity('linea_produccion_materiales')
export class LineaProduccionMaterial {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'linea_produccion_id' })
  lineaProduccionId: string;

  @ManyToOne(() => LineaProduccion, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'linea_produccion_id' })
  lineaProduccion: LineaProduccion;

  @Column({ name: 'material_id' })
  materialId: string;

  @ManyToOne(() => Material, (m) => m.lineasProduccion, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'material_id' })
  material: Material;

  @Column({ name: 'cantidad_sugerida', type: 'decimal', default: 1 })
  cantidadSugerida: number;

  @Column({ default: true })
  activo: boolean;
}

// ─── MOVIMIENTO INVENTARIO ──────────────────────────
@Entity('movimientos_inventario')
export class MovimientoInventario {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'material_id' })
  materialId: string;

  @ManyToOne(() => Material)
  @JoinColumn({ name: 'material_id' })
  material: Material;

  @Column({ name: 'material_codigo' })
  materialCodigo: string;

  @Column({ name: 'material_nombre' })
  materialNombre: string;

  @Column({ name: 'unidad_medida' })
  unidadMedida: string;

  @Column({ default: 'entrada_compra' })
  tipo: string;

  @Column({ type: 'decimal' })
  cantidad: number;

  @Column({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 })
  precioUnitario: number;

  @Column({ name: 'stock_anterior', type: 'decimal' })
  stockAnterior: number;

  @Column({ name: 'stock_nuevo', type: 'decimal' })
  stockNuevo: number;

  @Column({ name: 'registrado_por' })
  registradoPor: string;

  @Column({ nullable: true })
  observaciones: string;

  @CreateDateColumn()
  fecha: Date;
}

// ─── LOTES DE INVENTARIO FIFO ───────────────────────
// Cada compra/ingreso crea un lote con su propio precio. Al despachar, bodega
// consume primero los lotes mas antiguos para calcular el costo real usado.
@Entity('inventario_lotes')
export class InventarioLote {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'material_id' })
  materialId: string;

  @ManyToOne(() => Material, (m) => m.lotes)
  @JoinColumn({ name: 'material_id' })
  material: Material;

  @Column({ name: 'cantidad_inicial', type: 'decimal' })
  cantidadInicial: number;

  @Column({ name: 'cantidad_disponible', type: 'decimal' })
  cantidadDisponible: number;

  @Column({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 })
  precioUnitario: number;

  @Column({ nullable: true })
  referencia: string;

  @CreateDateColumn({ name: 'fecha_entrada' })
  fechaEntrada: Date;
}

// ─── PRECIO MATERIAL ────────────────────────────────
@Entity('precios_material')
export class PrecioMaterial {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'material_id' })
  materialId: string;

  @ManyToOne(() => Material, (m) => m.precios)
  @JoinColumn({ name: 'material_id' })
  material: Material;

  @Column({ type: 'decimal', precision: 12, scale: 4 })
  precio: number;

  @Column({ name: 'registrado_por' })
  registradoPor: string;

  @CreateDateColumn({ name: 'fecha_vigencia' })
  fechaVigencia: Date;
}

// ─── SOLICITUD ───────────────────────────────────────
@Entity('solicitudes')
export class Solicitud {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  numero: string;

  @Column({ name: 'solicitante_id' })
  solicitanteId: string;

  @Column({ name: 'solicitante_nombre' })
  solicitanteNombre: string;

  @Column({ name: 'linea_id' })
  lineaId: string;

  @Column({ name: 'linea_nombre' })
  lineaNombre: string;

  @CreateDateColumn()
  fecha: Date;

  @Column({ default: 'pendiente' })
  estado: string;

  @Column({ default: 'operario' })
  origen: string; // operario | bodega_directo

  @Column({ name: 'costo_total', type: 'decimal', default: 0 })
  costoTotal: number;

  @Column({ nullable: true })
  observaciones: string;

  @Column({ name: 'aprobado_por', nullable: true })
  aprobadoPor: string;

  @Column({ name: 'fecha_aprobacion', nullable: true })
  fechaAprobacion: Date;

  @Column({ name: 'fecha_entrega', nullable: true })
  fechaEntrega: Date;

  @OneToMany(() => DetalleSolicitud, (d) => d.solicitud)
  detalles: DetalleSolicitud[];
}

// ─── DETALLE SOLICITUD ───────────────────────────────
@Entity('detalle_solicitud')
export class DetalleSolicitud {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'solicitud_id' })
  solicitudId: string;

  @ManyToOne(() => Solicitud, (s) => s.detalles, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'solicitud_id' })
  solicitud: Solicitud;

  @Column({ name: 'material_id' })
  materialId: string;

  @Column({ name: 'material_nombre' })
  materialNombre: string;

  @Column({ name: 'material_codigo' })
  materialCodigo: string;

  @Column({ name: 'unidad_medida' })
  unidadMedida: string;

  @Column({ type: 'decimal' })
  cantidad: number;

  @Column({ name: 'precio_unitario_momento', type: 'decimal' })
  precioUnitarioMomento: number;

  @Column({ type: 'decimal' })
  subtotal: number;
}

@Entity('detalle_consumo_lotes')
export class DetalleConsumoLote {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'detalle_solicitud_id' })
  detalleSolicitudId: string;

  @ManyToOne(() => DetalleSolicitud, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'detalle_solicitud_id' })
  detalleSolicitud: DetalleSolicitud;

  @Column({ name: 'lote_id' })
  loteId: string;

  @ManyToOne(() => InventarioLote)
  @JoinColumn({ name: 'lote_id' })
  lote: InventarioLote;

  @Column({ type: 'decimal' })
  cantidad: number;

  @Column({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 })
  precioUnitario: number;

  @Column({ type: 'decimal', precision: 14, scale: 4 })
  subtotal: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
