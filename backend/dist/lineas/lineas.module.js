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
exports.LineasModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const entities_1 = require("../entities");
const auth_module_1 = require("../auth/auth.module");
const common_2 = require("@nestjs/common");
const typeorm_2 = require("@nestjs/typeorm");
const typeorm_3 = require("typeorm");
const common_3 = require("@nestjs/common");
const jwt_guard_1 = require("../auth/jwt.guard");
let LineasService = class LineasService {
    constructor(repo, lineaMaterialRepo) {
        this.repo = repo;
        this.lineaMaterialRepo = lineaMaterialRepo;
    }
    findAll() { return this.repo.find({ where: { activa: true }, order: { nombre: 'ASC' } }); }
    async findMateriales(lineaId) {
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
};
LineasService = __decorate([
    (0, common_3.Injectable)(),
    __param(0, (0, typeorm_2.InjectRepository)(entities_1.LineaProduccion)),
    __param(1, (0, typeorm_2.InjectRepository)(entities_1.LineaProduccionMaterial)),
    __metadata("design:paramtypes", [typeorm_3.Repository,
        typeorm_3.Repository])
], LineasService);
let LineasController = class LineasController {
    constructor(svc) {
        this.svc = svc;
    }
    findAll() { return this.svc.findAll(); }
    findMateriales(id) {
        return this.svc.findMateriales(id);
    }
};
__decorate([
    (0, common_2.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], LineasController.prototype, "findAll", null);
__decorate([
    (0, common_2.Get)(':id/materiales'),
    __param(0, (0, common_2.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], LineasController.prototype, "findMateriales", null);
LineasController = __decorate([
    (0, common_2.Controller)('lineas'),
    (0, common_2.UseGuards)(jwt_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [LineasService])
], LineasController);
let LineasModule = class LineasModule {
};
exports.LineasModule = LineasModule;
exports.LineasModule = LineasModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([entities_1.LineaProduccion, entities_1.LineaProduccionMaterial]), auth_module_1.AuthModule],
        controllers: [LineasController],
        providers: [LineasService],
    })
], LineasModule);
//# sourceMappingURL=lineas.module.js.map