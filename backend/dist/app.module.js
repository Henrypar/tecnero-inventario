"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const auth_module_1 = require("./auth/auth.module");
const materiales_module_1 = require("./materiales/materiales.module");
const lineas_module_1 = require("./lineas/lineas.module");
const solicitudes_module_1 = require("./solicitudes/solicitudes.module");
const precios_module_1 = require("./precios/precios.module");
const dashboard_module_1 = require("./dashboard/dashboard.module");
const notificaciones_module_1 = require("./notificaciones/notificaciones.module");
const produccion_module_1 = require("./produccion/produccion.module");
const app_controller_1 = require("./app.controller");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forRoot(process.env.DATABASE_URL
                ? {
                    type: 'postgres',
                    url: process.env.DATABASE_URL,
                    autoLoadEntities: true,
                    synchronize: false,
                    logging: false,
                    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
                }
                : {
                    type: 'postgres',
                    host: process.env.DB_HOST || '127.0.0.1',
                    port: parseInt(process.env.DB_PORT || '5432', 10),
                    username: process.env.DB_USER || 'yandry',
                    password: process.env.DB_PASSWORD || '',
                    database: process.env.DB_NAME || 'tecnero_inventario1',
                    autoLoadEntities: true,
                    synchronize: false,
                    logging: false,
                    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
                }),
            auth_module_1.AuthModule,
            materiales_module_1.MaterialesModule,
            lineas_module_1.LineasModule,
            solicitudes_module_1.SolicitudesModule,
            precios_module_1.PreciosModule,
            dashboard_module_1.DashboardModule,
            notificaciones_module_1.NotificacionesModule,
            produccion_module_1.ProduccionModule,
        ],
        controllers: [app_controller_1.AppController],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map