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
exports.SolicitudesController = void 0;
const common_1 = require("@nestjs/common");
const solicitudes_service_1 = require("./solicitudes.service");
const jwt_guard_1 = require("../auth/jwt.guard");
let SolicitudesController = class SolicitudesController {
    constructor(svc) {
        this.svc = svc;
    }
    crear(body, req) {
        return this.svc.crear({
            ...body,
            solicitanteId: req.user.userId,
            solicitanteNombre: req.user.nombre,
        });
    }
    crearDespachoBodega(body, req) {
        return this.svc.crearDespachoBodega(body, req.user.nombre);
    }
    misSolicitudes(req) {
        return this.svc.findAll({
            solicitanteId: req.user.userId,
        });
    }
    aprobadas() {
        return this.svc.findAll({
            estado: 'aprobada',
        });
    }
    pendientesBodega() {
        return this.svc.findAll({
            estado: 'pendiente',
        });
    }
    entregadas() {
        return this.svc.findAll({
            estado: 'entregada',
        });
    }
    historialBodega() {
        return this.svc.findHistoricoBodega();
    }
    findAll(q) {
        return this.svc.findAll(q);
    }
    findOne(id) {
        return this.svc.findById(id);
    }
    editar(id, body, req) {
        return this.svc.editar(id, body, req.user.userId);
    }
    aprobar(id, req) {
        return this.svc.aprobar(id, req.user.nombre);
    }
    rechazar(id, body, req) {
        return this.svc.rechazar(id, req.user.nombre, body.motivo);
    }
    entregar(id, req) {
        return this.svc.marcarEntregada(id, req.user.nombre);
    }
};
exports.SolicitudesController = SolicitudesController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "crear", null);
__decorate([
    (0, common_1.Post)('despacho-bodega'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'bodeguero'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "crearDespachoBodega", null);
__decorate([
    (0, common_1.Get)('mis-solicitudes'),
    __param(0, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "misSolicitudes", null);
__decorate([
    (0, common_1.Get)('aprobadas'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador', 'bodeguero'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "aprobadas", null);
__decorate([
    (0, common_1.Get)('pendientes-bodega'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'bodeguero'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "pendientesBodega", null);
__decorate([
    (0, common_1.Get)('entregadas'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador', 'bodeguero'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "entregadas", null);
__decorate([
    (0, common_1.Get)('historial-bodega'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador', 'bodeguero'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "historialBodega", null);
__decorate([
    (0, common_1.Get)(),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador'),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "editar", null);
__decorate([
    (0, common_1.Patch)(':id/aprobar'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "aprobar", null);
__decorate([
    (0, common_1.Patch)(':id/rechazar'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'coordinador', 'bodeguero'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "rechazar", null);
__decorate([
    (0, common_1.Patch)(':id/entregar'),
    (0, common_1.UseGuards)(jwt_guard_1.RolesGuard),
    (0, jwt_guard_1.Roles)('admin', 'bodeguero'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], SolicitudesController.prototype, "entregar", null);
exports.SolicitudesController = SolicitudesController = __decorate([
    (0, common_1.Controller)('solicitudes'),
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [solicitudes_service_1.SolicitudesService])
], SolicitudesController);
//# sourceMappingURL=solicitudes.controller.js.map