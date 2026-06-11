// Modulo raiz de NestJS. Conecta la base de datos y registra todos los modulos funcionales del sistema.
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { MaterialesModule } from './materiales/materiales.module';
import { LineasModule } from './lineas/lineas.module';
import { SolicitudesModule } from './solicitudes/solicitudes.module';
import { PreciosModule } from './precios/precios.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { NotificacionesModule } from './notificaciones/notificaciones.module';
import { ProduccionModule } from './produccion/produccion.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    TypeOrmModule.forRoot(
      process.env.DATABASE_URL
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
            username: process.env.DB_USER || 'henrymarin',
            password: process.env.DB_PASSWORD || '',
            database: process.env.DB_NAME || 'tecnero_inventario1',
            autoLoadEntities: true,
            synchronize: false,
            logging: false,
            ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
          },
    ),
    AuthModule,
    MaterialesModule,
    LineasModule,
    SolicitudesModule,
    PreciosModule,
    DashboardModule,
    NotificacionesModule,
    ProduccionModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
