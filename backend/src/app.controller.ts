// Punto de estado del backend para validar rapidamente que la API responde.
import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  getStatus() {
    return {
      name: 'TECNERO Backend',
      status: 'ok',
      basePath: '/api',
    };
  }
}
