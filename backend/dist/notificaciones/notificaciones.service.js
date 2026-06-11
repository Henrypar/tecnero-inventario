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
exports.NotificacionesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("../entities");
const notificacion_entity_1 = require("./entities/notificacion.entity");
const notificaciones_gateway_1 = require("./notificaciones.gateway");
let NotificacionesService = class NotificacionesService {
    constructor(notificacionesRepo, usuariosRepo, gateway) {
        this.notificacionesRepo = notificacionesRepo;
        this.usuariosRepo = usuariosRepo;
        this.gateway = gateway;
    }
    async crearNotificacion(data) {
        const notificacion = this.notificacionesRepo.create({
            usuarioId: data.usuarioId,
            titulo: data.titulo,
            mensaje: data.mensaje,
            tipo: data.tipo,
            solicitudId: data.solicitudId ?? null,
            leida: false,
        });
        const guardada = await this.notificacionesRepo.save(notificacion);
        this.gateway.emitirNuevaNotificacion(data.usuarioId, guardada);
        return guardada;
    }
    async crearParaRoles(roles, data) {
        const usuarios = await this.usuariosRepo.find({
            where: {
                rol: (0, typeorm_2.In)(roles),
                activo: true,
            },
        });
        const creadas = [];
        for (const usuario of usuarios) {
            creadas.push(await this.crearNotificacion({
                ...data,
                usuarioId: usuario.id,
            }));
        }
        return creadas;
    }
    async obtenerMisNotificaciones(usuarioId) {
        return this.notificacionesRepo.find({
            where: { usuarioId },
            order: { fechaCreacion: 'DESC' },
            relations: {
                solicitud: true,
            },
        });
    }
    async contarNoLeidas(usuarioId) {
        return this.notificacionesRepo.count({
            where: {
                usuarioId,
                leida: false,
            },
        });
    }
    async marcarComoLeida(id, usuarioId) {
        const notificacion = await this.notificacionesRepo.findOne({
            where: { id, usuarioId },
        });
        if (!notificacion) {
            throw new common_1.NotFoundException('Notificación no encontrada');
        }
        notificacion.leida = true;
        return this.notificacionesRepo.save(notificacion);
    }
    async marcarTodasComoLeidas(usuarioId) {
        const result = await this.notificacionesRepo.update({ usuarioId, leida: false }, { leida: true });
        return { updated: result.affected ?? 0 };
    }
};
exports.NotificacionesService = NotificacionesService;
exports.NotificacionesService = NotificacionesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(notificacion_entity_1.Notificacion)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.Usuario)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        notificaciones_gateway_1.NotificacionesGateway])
], NotificacionesService);
//# sourceMappingURL=notificaciones.service.js.map