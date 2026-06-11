// Servicio que valida credenciales, emite JWT y resuelve datos del usuario.
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { Usuario } from '../entities';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(Usuario)
    private usuariosRepo: Repository<Usuario>,
    private jwtService: JwtService,
  ) {}

  async login(email: string, password: string) {
    const usuario = await this.usuariosRepo.findOne({
      where: { email, activo: true },
    });
    if (!usuario) throw new UnauthorizedException('Credenciales inválidas');

    // Si no tiene password_hash, usar password directa para demo
    if (usuario.passwordHash) {
      const valido = await bcrypt.compare(password, usuario.passwordHash);
      if (!valido) throw new UnauthorizedException('Credenciales inválidas');
    } else {
      // Para demo: aceptar '123456' si no hay hash
      if (password !== '123456') throw new UnauthorizedException('Credenciales inválidas');
    }

    const payload = {
      sub: usuario.id,
      email: usuario.email,
      rol: usuario.rol,
      nombre: usuario.nombre,
    };

    return {
      access_token: this.jwtService.sign(payload),
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        email: usuario.email,
        rol: usuario.rol,
      },
    };
  }

  async perfil(userId: string) {
    return this.usuariosRepo.findOne({
      where: { id: userId },
      select: ['id', 'nombre', 'email', 'rol', 'activo'],
    });
  }

  async listarUsuarios(rol?: string) {
    return this.usuariosRepo.find({
      where: {
        ...(rol ? { rol } : {}),
        activo: true,
      },
      select: ['id', 'nombre', 'email', 'rol', 'activo'],
      order: { nombre: 'ASC' },
    });
  }
}
