// Estrategia JWT que traduce el token en usuario autenticado dentro de NestJS.
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET || 'tecnero_secret_2024',
    });
  }

  validate(payload: any) {
    return {
      userId: payload.sub,
      email: payload.email,
      rol: payload.rol,
      nombre: payload.nombre,
    };
  }
}
