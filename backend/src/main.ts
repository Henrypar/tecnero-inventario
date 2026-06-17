// Bootstrap del backend NestJS: CORS, prefijo /api y puerto de escucha.
import 'dotenv/config';
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { loadEnvFile } from './config/load-env';

async function bootstrap() {
  loadEnvFile();

  const { AppModule } = await import('./app.module');
  const app = await NestFactory.create(AppModule);

  app.enableCors({ origin: '*' });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  app.setGlobalPrefix('api');

  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(port, host);
  console.log(`TECNERO Backend corriendo en: http://${host}:${port}/api`);
}
bootstrap();
