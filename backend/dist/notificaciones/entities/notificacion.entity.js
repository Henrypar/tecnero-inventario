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
exports.Notificacion = void 0;
const typeorm_1 = require("typeorm");
const entities_1 = require("../../entities");
let Notificacion = class Notificacion {
};
exports.Notificacion = Notificacion;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Notificacion.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'usuario_id' }),
    __metadata("design:type", String)
], Notificacion.prototype, "usuarioId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Usuario, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'usuario_id' }),
    __metadata("design:type", entities_1.Usuario)
], Notificacion.prototype, "usuario", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Notificacion.prototype, "titulo", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Notificacion.prototype, "mensaje", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Notificacion.prototype, "tipo", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], Notificacion.prototype, "leida", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'solicitud_id', nullable: true }),
    __metadata("design:type", String)
], Notificacion.prototype, "solicitudId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => entities_1.Solicitud, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'solicitud_id' }),
    __metadata("design:type", entities_1.Solicitud)
], Notificacion.prototype, "solicitud", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'fecha_creacion' }),
    __metadata("design:type", Date)
], Notificacion.prototype, "fechaCreacion", void 0);
exports.Notificacion = Notificacion = __decorate([
    (0, typeorm_1.Entity)('notificaciones')
], Notificacion);
//# sourceMappingURL=notificacion.entity.js.map