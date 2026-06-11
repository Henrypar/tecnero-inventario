// Guardia y decoradores para proteger rutas y restringirlas por rol.
import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

export const ROLES_KEY = 'roles';
import { SetMetadata } from '@nestjs/common';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(), context.getClass(),
    ]);
    if (!required) return true;
    const { user } = context.switchToHttp().getRequest();
    if (!required.includes(user.rol)) throw new ForbiddenException('Sin permiso');
    return true;
  }
}
