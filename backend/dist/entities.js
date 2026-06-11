"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DetalleConsumoLote = exports.DetalleSolicitud = exports.Solicitud = exports.PrecioMaterial = exports.InventarioLote = exports.MovimientoInventario = exports.LineaProduccionMaterial = exports.Material = exports.ProduccionDiaria = exports.LineaProduccion = exports.Usuario = void 0;
const typeorm_1 = require("typeorm");
let Usuario = class Usuario {
};
exports.Usuario = Usuario;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Usuario.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Usuario.prototype, "nombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], Usuario.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Usuario.prototype, "rol", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], Usuario.prototype, "activo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'password_hash', nullable: true }),
    __metadata("design:type", String)
], Usuario.prototype, "passwordHash", void 0);
exports.Usuario = Usuario = __decorate([
    (0, typeorm_1.Entity)('usuarios')
], Usuario);
let LineaProduccion = class LineaProduccion {
};
exports.LineaProduccion = LineaProduccion;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], LineaProduccion.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], LineaProduccion.prototype, "nombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], LineaProduccion.prototype, "descripcion", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], LineaProduccion.prototype, "activa", void 0);
exports.LineaProduccion = LineaProduccion = __decorate([
    (0, typeorm_1.Entity)('lineas_produccion')
], LineaProduccion);
let ProduccionDiaria = class ProduccionDiaria {
};
exports.ProduccionDiaria = ProduccionDiaria;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'date' }),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "fecha", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'linea_id' }),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "lineaId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => LineaProduccion),
    (0, typeorm_1.JoinColumn)({ name: 'linea_id' }),
    __metadata("design:type", LineaProduccion)
], ProduccionDiaria.prototype, "linea", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'linea_nombre' }),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "lineaNombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal' }),
    __metadata("design:type", Number)
], ProduccionDiaria.prototype, "cantidad", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "unidad", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'registrado_por' }),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "registradoPor", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], ProduccionDiaria.prototype, "observaciones", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], ProduccionDiaria.prototype, "createdAt", void 0);
exports.ProduccionDiaria = ProduccionDiaria = __decorate([
    (0, typeorm_1.Entity)('produccion_diaria')
], ProduccionDiaria);
let Material = class Material {
};
exports.Material = Material;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Material.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], Material.prototype, "codigo", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Material.prototype, "nombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unidad_medida' }),
    __metadata("design:type", String)
], Material.prototype, "unidadMedida", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Material.prototype, "categoria", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_actual', type: 'decimal', default: 0 }),
    __metadata("design:type", Number)
], Material.prototype, "stockActual", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_minimo_alerta', type: 'decimal', default: 5 }),
    __metadata("design:type", Number)
], Material.prototype, "stockMinimoAlerta", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'costo_promedio', type: 'decimal', precision: 12, scale: 4, default: 0 }),
    __metadata("design:type", Number)
], Material.prototype, "costoPromedio", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'valor_inventario', type: 'decimal', precision: 14, scale: 4, default: 0 }),
    __metadata("design:type", Number)
], Material.prototype, "valorInventario", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], Material.prototype, "activo", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => PrecioMaterial, (p) => p.material),
    __metadata("design:type", Array)
], Material.prototype, "precios", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => LineaProduccionMaterial, (lpm) => lpm.material),
    __metadata("design:type", Array)
], Material.prototype, "lineasProduccion", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => InventarioLote, (l) => l.material),
    __metadata("design:type", Array)
], Material.prototype, "lotes", void 0);
exports.Material = Material = __decorate([
    (0, typeorm_1.Entity)('materiales')
], Material);
let LineaProduccionMaterial = class LineaProduccionMaterial {
};
exports.LineaProduccionMaterial = LineaProduccionMaterial;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], LineaProduccionMaterial.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'linea_produccion_id' }),
    __metadata("design:type", String)
], LineaProduccionMaterial.prototype, "lineaProduccionId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => LineaProduccion, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'linea_produccion_id' }),
    __metadata("design:type", LineaProduccion)
], LineaProduccionMaterial.prototype, "lineaProduccion", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_id' }),
    __metadata("design:type", String)
], LineaProduccionMaterial.prototype, "materialId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Material, (m) => m.lineasProduccion, {
        onDelete: 'CASCADE',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'material_id' }),
    __metadata("design:type", Material)
], LineaProduccionMaterial.prototype, "material", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cantidad_sugerida', type: 'decimal', default: 1 }),
    __metadata("design:type", Number)
], LineaProduccionMaterial.prototype, "cantidadSugerida", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], LineaProduccionMaterial.prototype, "activo", void 0);
exports.LineaProduccionMaterial = LineaProduccionMaterial = __decorate([
    (0, typeorm_1.Entity)('linea_produccion_materiales')
], LineaProduccionMaterial);
let MovimientoInventario = class MovimientoInventario {
};
exports.MovimientoInventario = MovimientoInventario;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_id' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "materialId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Material),
    (0, typeorm_1.JoinColumn)({ name: 'material_id' }),
    __metadata("design:type", Material)
], MovimientoInventario.prototype, "material", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_codigo' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "materialCodigo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_nombre' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "materialNombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unidad_medida' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "unidadMedida", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 'entrada_compra' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "tipo", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal' }),
    __metadata("design:type", Number)
], MovimientoInventario.prototype, "cantidad", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 }),
    __metadata("design:type", Number)
], MovimientoInventario.prototype, "precioUnitario", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_anterior', type: 'decimal' }),
    __metadata("design:type", Number)
], MovimientoInventario.prototype, "stockAnterior", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'stock_nuevo', type: 'decimal' }),
    __metadata("design:type", Number)
], MovimientoInventario.prototype, "stockNuevo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'registrado_por' }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "registradoPor", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], MovimientoInventario.prototype, "observaciones", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], MovimientoInventario.prototype, "fecha", void 0);
exports.MovimientoInventario = MovimientoInventario = __decorate([
    (0, typeorm_1.Entity)('movimientos_inventario')
], MovimientoInventario);
let InventarioLote = class InventarioLote {
};
exports.InventarioLote = InventarioLote;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], InventarioLote.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_id' }),
    __metadata("design:type", String)
], InventarioLote.prototype, "materialId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Material, (m) => m.lotes),
    (0, typeorm_1.JoinColumn)({ name: 'material_id' }),
    __metadata("design:type", Material)
], InventarioLote.prototype, "material", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cantidad_inicial', type: 'decimal' }),
    __metadata("design:type", Number)
], InventarioLote.prototype, "cantidadInicial", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cantidad_disponible', type: 'decimal' }),
    __metadata("design:type", Number)
], InventarioLote.prototype, "cantidadDisponible", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 }),
    __metadata("design:type", Number)
], InventarioLote.prototype, "precioUnitario", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], InventarioLote.prototype, "referencia", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'fecha_entrada' }),
    __metadata("design:type", Date)
], InventarioLote.prototype, "fechaEntrada", void 0);
exports.InventarioLote = InventarioLote = __decorate([
    (0, typeorm_1.Entity)('inventario_lotes')
], InventarioLote);
let PrecioMaterial = class PrecioMaterial {
};
exports.PrecioMaterial = PrecioMaterial;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], PrecioMaterial.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_id' }),
    __metadata("design:type", String)
], PrecioMaterial.prototype, "materialId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Material, (m) => m.precios),
    (0, typeorm_1.JoinColumn)({ name: 'material_id' }),
    __metadata("design:type", Material)
], PrecioMaterial.prototype, "material", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 12, scale: 4 }),
    __metadata("design:type", Number)
], PrecioMaterial.prototype, "precio", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'registrado_por' }),
    __metadata("design:type", String)
], PrecioMaterial.prototype, "registradoPor", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'fecha_vigencia' }),
    __metadata("design:type", Date)
], PrecioMaterial.prototype, "fechaVigencia", void 0);
exports.PrecioMaterial = PrecioMaterial = __decorate([
    (0, typeorm_1.Entity)('precios_material')
], PrecioMaterial);
let Solicitud = class Solicitud {
};
exports.Solicitud = Solicitud;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Solicitud.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], Solicitud.prototype, "numero", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'solicitante_id' }),
    __metadata("design:type", String)
], Solicitud.prototype, "solicitanteId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'solicitante_nombre' }),
    __metadata("design:type", String)
], Solicitud.prototype, "solicitanteNombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'linea_id' }),
    __metadata("design:type", String)
], Solicitud.prototype, "lineaId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'linea_nombre' }),
    __metadata("design:type", String)
], Solicitud.prototype, "lineaNombre", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], Solicitud.prototype, "fecha", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 'pendiente' }),
    __metadata("design:type", String)
], Solicitud.prototype, "estado", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 'operario' }),
    __metadata("design:type", String)
], Solicitud.prototype, "origen", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'costo_total', type: 'decimal', default: 0 }),
    __metadata("design:type", Number)
], Solicitud.prototype, "costoTotal", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Solicitud.prototype, "observaciones", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'aprobado_por', nullable: true }),
    __metadata("design:type", String)
], Solicitud.prototype, "aprobadoPor", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'fecha_aprobacion', nullable: true }),
    __metadata("design:type", Date)
], Solicitud.prototype, "fechaAprobacion", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'fecha_entrega', nullable: true }),
    __metadata("design:type", Date)
], Solicitud.prototype, "fechaEntrega", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => DetalleSolicitud, (d) => d.solicitud),
    __metadata("design:type", Array)
], Solicitud.prototype, "detalles", void 0);
exports.Solicitud = Solicitud = __decorate([
    (0, typeorm_1.Entity)('solicitudes')
], Solicitud);
let DetalleSolicitud = class DetalleSolicitud {
};
exports.DetalleSolicitud = DetalleSolicitud;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'solicitud_id' }),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "solicitudId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Solicitud, (s) => s.detalles, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'solicitud_id' }),
    __metadata("design:type", Solicitud)
], DetalleSolicitud.prototype, "solicitud", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_id' }),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "materialId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_nombre' }),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "materialNombre", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'material_codigo' }),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "materialCodigo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'unidad_medida' }),
    __metadata("design:type", String)
], DetalleSolicitud.prototype, "unidadMedida", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal' }),
    __metadata("design:type", Number)
], DetalleSolicitud.prototype, "cantidad", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'precio_unitario_momento', type: 'decimal' }),
    __metadata("design:type", Number)
], DetalleSolicitud.prototype, "precioUnitarioMomento", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal' }),
    __metadata("design:type", Number)
], DetalleSolicitud.prototype, "subtotal", void 0);
exports.DetalleSolicitud = DetalleSolicitud = __decorate([
    (0, typeorm_1.Entity)('detalle_solicitud')
], DetalleSolicitud);
let DetalleConsumoLote = class DetalleConsumoLote {
};
exports.DetalleConsumoLote = DetalleConsumoLote;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], DetalleConsumoLote.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'detalle_solicitud_id' }),
    __metadata("design:type", String)
], DetalleConsumoLote.prototype, "detalleSolicitudId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => DetalleSolicitud, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'detalle_solicitud_id' }),
    __metadata("design:type", DetalleSolicitud)
], DetalleConsumoLote.prototype, "detalleSolicitud", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'lote_id' }),
    __metadata("design:type", String)
], DetalleConsumoLote.prototype, "loteId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => InventarioLote),
    (0, typeorm_1.JoinColumn)({ name: 'lote_id' }),
    __metadata("design:type", InventarioLote)
], DetalleConsumoLote.prototype, "lote", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal' }),
    __metadata("design:type", Number)
], DetalleConsumoLote.prototype, "cantidad", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'precio_unitario', type: 'decimal', precision: 12, scale: 4 }),
    __metadata("design:type", Number)
], DetalleConsumoLote.prototype, "precioUnitario", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 14, scale: 4 }),
    __metadata("design:type", Number)
], DetalleConsumoLote.prototype, "subtotal", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], DetalleConsumoLote.prototype, "createdAt", void 0);
exports.DetalleConsumoLote = DetalleConsumoLote = __decorate([
    (0, typeorm_1.Entity)('detalle_consumo_lotes')
], DetalleConsumoLote);
//# sourceMappingURL=entities.js.map