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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MaterialesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("../entities");
let MaterialesService = class MaterialesService {
    constructor(materialesRepo, preciosRepo, movimientosRepo, dataSource) {
        this.materialesRepo = materialesRepo;
        this.preciosRepo = preciosRepo;
        this.movimientosRepo = movimientosRepo;
        this.dataSource = dataSource;
    }
    findAll() {
        return this.materialesRepo.find({ where: { activo: true }, order: { nombre: 'ASC' } });
    }
    async findAllConPrecio() {
        const materiales = await this.materialesRepo.find({ order: { activo: 'DESC', nombre: 'ASC' } });
        return Promise.all(materiales.map(async (m) => {
            const precio = await this.preciosRepo.findOne({
                where: { materialId: m.id },
                order: { fechaVigencia: 'DESC' },
            });
            return {
                ...m,
                precioActual: precio ? Number(precio.precio) : null,
                precioFechaVigencia: precio?.fechaVigencia ?? null,
                costoPromedio: Number(m.costoPromedio ?? 0),
                valorInventario: Number(m.valorInventario ?? 0),
            };
        }));
    }
    async crear(dto, registradoPor) {
        const codigo = (dto.codigo ?? '').toString().trim();
        const nombre = (dto.nombre ?? '').toString().trim();
        const unidadMedida = (dto.unidadMedida ?? dto.unidad_medida ?? '').toString().trim();
        const categoria = (dto.categoria ?? 'produccion').toString().trim();
        const stockActual = Number(dto.stockActual ?? dto.stock_actual ?? 0);
        const stockMinimoAlerta = Number(dto.stockMinimoAlerta ?? dto.stock_minimo_alerta ?? 5);
        const precio = dto.precio == null || dto.precio === '' ? null : Number(dto.precio);
        if (!codigo || !nombre || !unidadMedida) {
            throw new common_1.BadRequestException('Código, nombre y unidad son obligatorios');
        }
        if (Number.isNaN(stockActual) || stockActual < 0) {
            throw new common_1.BadRequestException('El stock inicial no puede ser negativo');
        }
        if (Number.isNaN(stockMinimoAlerta) || stockMinimoAlerta < 0) {
            throw new common_1.BadRequestException('El stock mínimo de alerta no puede ser negativo');
        }
        if (precio != null && (Number.isNaN(precio) || precio <= 0)) {
            throw new common_1.BadRequestException('El precio inicial debe ser mayor a 0');
        }
        const existe = await this.materialesRepo.findOne({ where: { codigo } });
        if (existe) {
            throw new common_1.BadRequestException('Ya existe un material con ese código');
        }
        const costoPromedio = precio != null ? precio : 0;
        const valorInventario = stockActual * costoPromedio;
        const material = await this.materialesRepo.save(this.materialesRepo.create({
            codigo,
            nombre,
            unidadMedida,
            categoria,
            stockActual,
            stockMinimoAlerta,
            costoPromedio,
            valorInventario,
            activo: true,
        }));
        if (precio != null) {
            await this.preciosRepo.save(this.preciosRepo.create({
                materialId: material.id,
                precio,
                registradoPor,
            }));
            if (stockActual > 0) {
                await this.dataSource.manager.save(entities_1.InventarioLote, this.dataSource.manager.create(entities_1.InventarioLote, {
                    materialId: material.id,
                    cantidadInicial: stockActual,
                    cantidadDisponible: stockActual,
                    precioUnitario: precio,
                    referencia: 'Stock inicial',
                }));
            }
        }
        return material;
    }
    async actualizar(id, dto) {
        const material = await this.materialesRepo.findOne({ where: { id } });
        if (!material)
            throw new common_1.NotFoundException('Material no encontrado');
        const codigo = dto.codigo?.toString().trim();
        if (codigo && codigo !== material.codigo) {
            const existe = await this.materialesRepo.findOne({ where: { codigo } });
            if (existe) {
                throw new common_1.BadRequestException('Ya existe un material con ese código');
            }
            material.codigo = codigo;
        }
        if (dto.nombre != null)
            material.nombre = dto.nombre.toString().trim();
        if (dto.unidadMedida != null || dto.unidad_medida != null) {
            material.unidadMedida = (dto.unidadMedida ?? dto.unidad_medida).toString().trim();
        }
        if (dto.categoria != null)
            material.categoria = dto.categoria.toString().trim();
        if (dto.activo != null)
            material.activo = Boolean(dto.activo);
        if (dto.stockMinimoAlerta != null || dto.stock_minimo_alerta != null) {
            const stockMinimoAlerta = Number(dto.stockMinimoAlerta ?? dto.stock_minimo_alerta);
            if (Number.isNaN(stockMinimoAlerta) || stockMinimoAlerta < 0) {
                throw new common_1.BadRequestException('El stock mínimo de alerta no puede ser negativo');
            }
            material.stockMinimoAlerta = stockMinimoAlerta;
        }
        if (!material.codigo || !material.nombre || !material.unidadMedida) {
            throw new common_1.BadRequestException('Código, nombre y unidad son obligatorios');
        }
        return this.materialesRepo.save(material);
    }
    async ajustarStock(id, dto) {
        const material = await this.materialesRepo.findOne({ where: { id } });
        if (!material)
            throw new common_1.NotFoundException('Material no encontrado');
        const cantidad = Number(dto.cantidad);
        const modo = (dto.modo ?? 'sumar').toString();
        if (Number.isNaN(cantidad) || cantidad <= 0) {
            throw new common_1.BadRequestException('La cantidad debe ser mayor a 0');
        }
        const stockActual = Number(material.stockActual);
        const costoPromedio = Number(material.costoPromedio ?? 0);
        const valorActual = Number(material.valorInventario ?? 0) || stockActual * costoPromedio;
        const precioEntrada = Number(dto.precio ?? 0);
        const nuevoStock = modo === 'establecer' ? cantidad : stockActual + cantidad;
        if (nuevoStock < 0) {
            throw new common_1.BadRequestException('El stock no puede quedar negativo');
        }
        let nuevoCostoPromedio = costoPromedio;
        let nuevoValorInventario = nuevoStock * costoPromedio;
        if (modo !== 'establecer' && precioEntrada > 0) {
            nuevoValorInventario = valorActual + cantidad * precioEntrada;
            nuevoCostoPromedio =
                nuevoStock > 0 ? nuevoValorInventario / nuevoStock : 0;
        }
        material.stockActual = nuevoStock;
        material.costoPromedio = nuevoCostoPromedio;
        material.valorInventario = nuevoValorInventario;
        const guardado = await this.materialesRepo.save(material);
        if (modo !== 'establecer' && precioEntrada > 0) {
            const precioActual = await this.preciosRepo.findOne({
                where: { materialId: material.id },
                order: { fechaVigencia: 'DESC' },
            });
            if (!precioActual || Number(precioActual.precio) !== precioEntrada) {
                await this.preciosRepo.save(this.preciosRepo.create({
                    materialId: material.id,
                    precio: precioEntrada,
                    registradoPor: dto.registradoPor ?? dto.registrado_por ?? 'Compras',
                }));
            }
        }
        const movimiento = await this.movimientosRepo.save(this.movimientosRepo.create({
            materialId: material.id,
            materialCodigo: material.codigo,
            materialNombre: material.nombre,
            unidadMedida: material.unidadMedida,
            tipo: modo === 'establecer' ? 'ajuste_stock' : 'entrada_manual',
            cantidad: modo === 'establecer' ? nuevoStock - stockActual : cantidad,
            precioUnitario: Number(dto.precio ?? 0),
            stockAnterior: stockActual,
            stockNuevo: nuevoStock,
            registradoPor: dto.registradoPor ?? dto.registrado_por ?? 'Compras',
            observaciones: dto.observaciones ?? null,
        }));
        if (modo === 'establecer') {
            await this.dataSource.manager.delete(entities_1.InventarioLote, {
                materialId: material.id,
            });
            if (nuevoStock > 0) {
                await this.dataSource.manager.save(entities_1.InventarioLote, this.dataSource.manager.create(entities_1.InventarioLote, {
                    materialId: material.id,
                    cantidadInicial: nuevoStock,
                    cantidadDisponible: nuevoStock,
                    precioUnitario: nuevoCostoPromedio,
                    referencia: `Ajuste stock ${movimiento.id}`,
                }));
            }
        }
        else if (cantidad > 0 && precioEntrada > 0) {
            await this.dataSource.manager.save(entities_1.InventarioLote, this.dataSource.manager.create(entities_1.InventarioLote, {
                materialId: material.id,
                cantidadInicial: cantidad,
                cantidadDisponible: cantidad,
                precioUnitario: precioEntrada,
                referencia: `Entrada manual ${movimiento.id}`,
            }));
        }
        return guardado;
    }
    async registrarIngreso(dto, registradoPor) {
        const items = dto.items ?? [];
        const observaciones = dto.observaciones ?? null;
        if (!Array.isArray(items) || items.length === 0) {
            throw new common_1.BadRequestException('Selecciona al menos un producto');
        }
        return this.dataSource.transaction(async (manager) => {
            const movimientos = [];
            for (const item of items) {
                const materialId = item.materialId ?? item.material_id;
                const cantidad = Number(item.cantidad);
                const precio = Number(item.precio);
                if (!materialId) {
                    throw new common_1.BadRequestException('Uno de los productos no tiene ID');
                }
                if (Number.isNaN(cantidad) || cantidad <= 0) {
                    throw new common_1.BadRequestException('Todas las cantidades deben ser mayores a 0');
                }
                if (Number.isNaN(precio) || precio <= 0) {
                    throw new common_1.BadRequestException('Todos los productos deben tener precio válido');
                }
                const material = await manager.findOne(entities_1.Material, {
                    where: { id: materialId },
                    lock: { mode: 'pessimistic_write' },
                });
                if (!material)
                    throw new common_1.NotFoundException('Material no encontrado');
                const stockAnterior = Number(material.stockActual);
                const costoPromedioAnterior = Number(material.costoPromedio ?? 0);
                const valorAnterior = Number(material.valorInventario ?? 0) || stockAnterior * costoPromedioAnterior;
                const valorEntrada = cantidad * precio;
                const stockNuevo = stockAnterior + cantidad;
                const valorNuevo = valorAnterior + valorEntrada;
                const costoPromedioNuevo = stockNuevo > 0 ? valorNuevo / stockNuevo : 0;
                material.stockActual = stockNuevo;
                material.valorInventario = valorNuevo;
                material.costoPromedio = costoPromedioNuevo;
                await manager.save(entities_1.Material, material);
                const precioActual = await manager.findOne(entities_1.PrecioMaterial, {
                    where: { materialId },
                    order: { fechaVigencia: 'DESC' },
                });
                if (!precioActual || Number(precioActual.precio) !== precio) {
                    await manager.save(entities_1.PrecioMaterial, manager.create(entities_1.PrecioMaterial, {
                        materialId,
                        precio,
                        registradoPor,
                    }));
                }
                const movimiento = await manager.save(entities_1.MovimientoInventario, manager.create(entities_1.MovimientoInventario, {
                    materialId,
                    materialCodigo: material.codigo,
                    materialNombre: material.nombre,
                    unidadMedida: material.unidadMedida,
                    tipo: 'entrada_compra',
                    cantidad,
                    precioUnitario: precio,
                    stockAnterior,
                    stockNuevo,
                    registradoPor,
                    observaciones,
                }));
                await manager.save(entities_1.InventarioLote, manager.create(entities_1.InventarioLote, {
                    materialId: material.id,
                    cantidadInicial: cantidad,
                    cantidadDisponible: cantidad,
                    precioUnitario: precio,
                    referencia: `Ingreso ${movimiento.id}`,
                }));
                movimientos.push(movimiento);
            }
            return movimientos;
        });
    }
    historialIngresos() {
        return this.movimientosRepo.find({
            where: { tipo: 'entrada_compra' },
            order: { fecha: 'DESC' },
            take: 300,
        });
    }
    async desactivar(id) {
        const material = await this.materialesRepo.findOne({ where: { id } });
        if (!material)
            throw new common_1.NotFoundException('Material no encontrado');
        material.activo = false;
        return this.materialesRepo.save(material);
    }
    async getPrecioActual(materialId) {
        const precio = await this.preciosRepo.findOne({
            where: { materialId },
            order: { fechaVigencia: 'DESC' },
        });
        if (!precio)
            throw new common_1.NotFoundException(`Material ${materialId} sin precio registrado`);
        return Number(precio.precio);
    }
};
exports.MaterialesService = MaterialesService;
exports.MaterialesService = MaterialesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.Material)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.PrecioMaterial)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.MovimientoInventario)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.DataSource])
], MaterialesService);
//# sourceMappingURL=materiales.service.js.map