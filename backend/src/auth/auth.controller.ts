// Controlador de autenticacion y usuarios del backend.
import { Controller, Post, Body, Get, UseGuards, Request, Query } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard, Roles, RolesGuard } from './jwt.guard';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  login(@Body() body: { email: string; password: string }) {
    return this.authService.login(body.email, body.password);
  }

  @UseGuards(JwtAuthGuard)
  @Get('perfil')
  perfil(@Request() req) {
    return this.authService.perfil(req.user.userId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'bodeguero', 'coordinador')
  @Get('usuarios')
  usuarios(@Query('rol') rol?: string) {
    return this.authService.listarUsuarios(rol);
  }
}
