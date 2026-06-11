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
exports.PreciosModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const entities_1 = require("../entities");
const auth_module_1 = require("../auth/auth.module");
const common_2 = require("@nestjs/common");
const typeorm_2 = require("@nestjs/typeorm");
const typeorm_3 = require("typeorm");
const common_3 = require("@nestjs/common");
const jwt_guard_1 = require("../auth/jwt.guard");
let PreciosService = class PreciosService {
    constructor(preciosRepo, materialesRepo) {
        this.preciosRepo = preciosRepo;
        this.materialesRepo = materialesRepo;
    }
    async getPrecioActual(materialId) {
        return this.preciosRepo.findOne({ where: { materialId }, order: { fechaVigencia: 'DESC' } });
    }
    async getHistorial(materialId) {
        return this.preciosRepo.find({ where: { materialId }, order: { fechaVigencia: 'DESC' }, take: 10 });
    }
    async actualizarPrecio(materialId, precio, registradoPor) {
        const m = await this.materialesRepo.findOne({ where: { id: materialId } });
        if (!m)
            throw new common_3.NotFoundException('Material no encontrado');
        const nuevo = this.preciosRepo.create({ materialId, precio, registradoPor });
        return this.preciosRepo.save(nuevo);
    }
};
PreciosService = __decorate([
    (0, common_3.Injectable)(),
    __param(0, (0, typeorm_2.InjectRepository)(entities_1.PrecioMaterial)),
    __param(1, (0, typeorm_2.InjectRepository)(entities_1.Material)),
    __metadata("design:paramtypes", [typeorm_3.Repository,
        typeorm_3.Repository])
], PreciosService);
let PreciosController = class PreciosController {
    constructor(svc) {
        this.svc = svc;
    }
    getActual(id) { return this.svc.getPrecioActual(id); }
    getHistorial(id) { return this.svc.getHistorial(id); }
    actualizar(id, body, req) {
        return this.svc.actualizarPrecio(id, body.precio, req.user.nombre);
    }
};
__decorate([
    (0, common_2.Get)(':materialId/actual'),
    __param(0, (0, common_2.Param)('materialId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PreciosController.prototype, "getActual", null);
__decorate([
    (0, common_2.Get)(':materialId/historial'),
    (0, common_2.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_2.Param)('materialId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PreciosController.prototype, "getHistorial", null);
__decorate([
    (0, common_2.Post)(':materialId'),
    (0, common_2.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_2.Param)('materialId')),
    __param(1, (0, common_2.Body)()),
    __param(2, (0, common_2.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], PreciosController.prototype, "actualizar", null);
PreciosController = __decorate([
    (0, common_2.Controller)('precios'),
    (0, common_2.UseGuards)(jwt_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [PreciosService])
], PreciosController);
let PreciosModule = class PreciosModule {
};
exports.PreciosModule = PreciosModule;
exports.PreciosModule = PreciosModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([entities_1.PrecioMaterial, entities_1.Material]), auth_module_1.AuthModule],
        controllers: [PreciosController],
        providers: [PreciosService],
        exports: [PreciosService],
    })
], PreciosModule);
//# sourceMappingURL=precios.module.js.map