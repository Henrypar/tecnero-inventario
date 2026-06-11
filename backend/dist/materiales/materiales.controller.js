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
exports.MaterialesController = void 0;
const common_1 = require("@nestjs/common");
const materiales_service_1 = require("./materiales.service");
const jwt_guard_1 = require("../auth/jwt.guard");
const jwt_guard_2 = require("../auth/jwt.guard");
let MaterialesController = class MaterialesController {
    constructor(svc) {
        this.svc = svc;
    }
    findAll() { return this.svc.findAll(); }
    findAllConPrecio() { return this.svc.findAllConPrecio(); }
    crear(body, req) {
        return this.svc.crear(body, req.user.nombre);
    }
    actualizar(id, body) {
        return this.svc.actualizar(id, body);
    }
    ajustarStock(id, body, req) {
        return this.svc.ajustarStock(id, { ...body, registradoPor: req.user.nombre });
    }
    registrarIngreso(body, req) {
        return this.svc.registrarIngreso(body, req.user.nombre);
    }
    historialIngresos() {
        return this.svc.historialIngresos();
    }
    desactivar(id) {
        return this.svc.desactivar(id);
    }
};
exports.MaterialesController = MaterialesController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('con-precio'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "findAllConPrecio", null);
__decorate([
    (0, common_1.Post)(),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "crear", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "actualizar", null);
__decorate([
    (0, common_1.Patch)(':id/stock'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "ajustarStock", null);
__decorate([
    (0, common_1.Post)('ingresos'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "registrarIngreso", null);
__decorate([
    (0, common_1.Get)('ingresos/historial'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "historialIngresos", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, common_1.UseGuards)(jwt_guard_2.RolesGuard),
    (0, jwt_guard_2.Roles)('admin', 'asistente_compras'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], MaterialesController.prototype, "desactivar", null);
exports.MaterialesController = MaterialesController = __decorate([
    (0, common_1.Controller)('materiales'),
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [materiales_service_1.MaterialesService])
], MaterialesController);
//# sourceMappingURL=materiales.controller.js.map