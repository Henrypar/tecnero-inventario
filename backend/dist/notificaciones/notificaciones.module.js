"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificacionesModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const entities_1 = require("../entities");
const notificacion_entity_1 = require("./entities/notificacion.entity");
const notificaciones_controller_1 = require("./notificaciones.controller");
const notificaciones_gateway_1 = require("./notificaciones.gateway");
const notificaciones_service_1 = require("./notificaciones.service");
let NotificacionesModule = class NotificacionesModule {
};
exports.NotificacionesModule = NotificacionesModule;
exports.NotificacionesModule = NotificacionesModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([notificacion_entity_1.Notificacion, entities_1.Usuario])],
        controllers: [notificaciones_controller_1.NotificacionesController],
        providers: [notificaciones_service_1.NotificacionesService, notificaciones_gateway_1.NotificacionesGateway],
        exports: [notificaciones_service_1.NotificacionesService],
    })
], NotificacionesModule);
//# sourceMappingURL=notificaciones.module.js.map