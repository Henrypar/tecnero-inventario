# Instalacion Y Ejecucion

Guia para instalar y correr TECNERO Inventario en Windows y macOS.

## Resumen Del Stack

- Frontend: Flutter `>=3.0.0 <4.0.0`
- Dart: el que viene con Flutter 3.x
- Backend: NestJS `10.x`
- TypeScript: `5.x`
- Base de datos: PostgreSQL
- Cliente de BD: `psql`
- Gestor de paquetes backend: `npm`

El proyecto **no usa PostgREST**. La app se conecta directo al backend NestJS en `/api`.

## Herramientas Necesarias

Instala estas herramientas antes de correr el proyecto:

- Flutter SDK
- Node.js LTS
- npm
- PostgreSQL
- Git
- Un editor de codigo como VS Code

Recomendado:

- Android Studio si vas a correr en Android o usar emuladores
- Xcode si vas a correr en macOS/iOS
- Chrome o Edge si vas a correr la version web

## Verificaciones Rapidas

Comprueba que tengas todo instalado:

```bash
flutter --version
node -v
npm -v
psql --version
git --version
```

En Flutter, ejecuta:

```bash
flutter doctor
```

## Versiones Del Proyecto

Estas son las versiones declaradas en el repositorio:

- Flutter: `>=3.0.0 <4.0.0`
- Dart: incluido con Flutter 3.x
- NestJS: `10.x`
- TypeScript: `5.x`
- PostgreSQL: compatible con `pg` y TypeORM `0.3.x`

Dependencias principales del frontend:

- `flutter_riverpod ^2.5.1`
- `go_router ^13.2.0`
- `socket_io_client ^2.0.3+1`
- `audioplayers ^6.1.0`
- `fl_chart ^0.67.0`
- `pdf ^3.10.8`
- `printing ^5.12.0`

Dependencias principales del backend:

- `@nestjs/common ^10.0.0`
- `@nestjs/core ^10.0.0`
- `@nestjs/typeorm ^10.0.0`
- `typeorm ^0.3.17`
- `pg ^8.11.0`
- `typescript ^5.0.0`

## Estructura De Arranque

El proyecto tiene dos partes:

```text
backend/   -> API NestJS
lib/       -> App Flutter
backend/sql/ -> Migraciones SQL
```

Primero se levanta la base de datos, luego el backend y al final el frontend.

## 1) Instalar Y Configurar PostgreSQL

### Windows

1. Instala PostgreSQL desde el instalador oficial.
2. Asegurate de recordar el usuario y la contraseña.
3. Verifica que el servicio quede corriendo.
4. Abre `psql` o PgAdmin para confirmar que puedes entrar.

### macOS

1. Instala PostgreSQL con Homebrew o con el instalador oficial.
2. Verifica que el servicio este activo.
3. Confirma acceso con `psql`.

### Base De Datos

Crea una base para el proyecto, por ejemplo:

```sql
CREATE DATABASE tecnero_inventario1;
```

Si ya existe, usa esa misma.

## 2) Aplicar Migraciones SQL

Las migraciones estan en `backend/sql/` y se aplican manualmente.

Orden sugerido:

```bash
psql "$DATABASE_URL" -f backend/sql/001_notificaciones.sql
psql "$DATABASE_URL" -f backend/sql/002_solicitudes_origen.sql
psql "$DATABASE_URL" -f backend/sql/003_movimientos_inventario.sql
psql "$DATABASE_URL" -f backend/sql/004_stock_minimo_alerta.sql
psql "$DATABASE_URL" -f backend/sql/005_linea_produccion_materiales.sql
psql "$DATABASE_URL" -f backend/sql/006_costo_promedio_inventario.sql
psql "$DATABASE_URL" -f backend/sql/007_lotes_fifo_inventario.sql
psql "$DATABASE_URL" -f backend/sql/008_produccion_diaria.sql
```

Si no usas `DATABASE_URL`, ejecuta el mismo orden apuntando a tu base local con `psql`.

## 3) Configurar El Backend

En la carpeta `backend/`, crea un archivo `.env` con estos datos:

```text
DATABASE_URL=postgresql://tu_usuario:tu_password@127.0.0.1:5432/tecnero_inventario1
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=tu_usuario
DB_PASSWORD=tu_password
DB_NAME=tecnero_inventario1
JWT_SECRET=tecnero_demo_secret
PORT=3000
```

Si usas `DATABASE_URL`, es suficiente. Si no, el backend toma `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` y `DB_NAME`.

## 4) Instalar Y Correr El Backend

```bash
cd backend
npm install
npm run start:dev
```

Si quieres compilarlo:

```bash
cd backend
npm run build
npm run start:prod
```

La API queda disponible en:

```text
http://localhost:3000/api
```

## 5) Instalar Y Correr El Frontend

En la raiz del proyecto:

```bash
flutter pub get
```

### Windows

Si vas a correr en escritorio Windows:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

Si prefieres correrlo en navegador:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

### macOS

Si vas a correr en escritorio macOS:

```bash
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:3000/api
```

Si prefieres navegador:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

### Android Emulator

Si usas emulador Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

### Celular Fisico

Usa la IP local de tu computadora:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
```

## 6) Flujo Recomendado Para Levantar Todo

1. Inicia PostgreSQL.
2. Confirma que la base existe y tiene las migraciones aplicadas.
3. Abre una terminal y corre el backend.
4. Abre otra terminal y corre el frontend con la `API_BASE_URL` correcta.

## 7) Credenciales Demo

El proyecto incluye accesos demo para el login:

```text
admin@tecnero.com      / 123456
coord@tecnero.com      / 123456
operario@tecnero.com   / 123456
bodega@tecnero.com     / 123456
```

Si un usuario no tiene `password_hash`, el backend acepta la clave `123456`.

## 8) Errores Comunes

- `connect ECONNREFUSED 127.0.0.1:5432`: PostgreSQL no esta corriendo o no esta escuchando en ese puerto.
- `No se pudo conectar con el servidor`: el frontend no apunta al backend correcto o el backend no esta activo.
- Pantalla vacia en web: revisa que `API_BASE_URL` tenga `/api` al final.
- En Android Emulator, no uses `localhost`; usa `10.0.2.2`.

## 9) Comandos De Verificacion

```bash
cd backend
npm run build
```

```bash
flutter analyze
```


