# TECNERO Inventario

Sistema para controlar solicitudes de materiales, despachos de bodega, stock,
produccion diaria y costo real por linea para una planta industrial.

La app permite responder rapido a estas preguntas:

- Que material se pidio y quien lo pidio.
- Que despacho realizo bodega y en que fecha.
- Cuanto costo realmente cada entrega usando FIFO por lotes.
- Cuanto cuesta producir por linea usando material consumido vs produccion.
- Que materiales tienen stock bajo.
- Como cambiaron los precios de compra.

## Estado Actual

El proyecto esta terminado como demo funcional con:

- Frontend Flutter responsive para web, tablet y celular.
- Backend NestJS con autenticacion JWT.
- PostgreSQL como base principal.
- Socket.IO para notificaciones internas.
- Migraciones SQL versionadas en `backend/sql/`.
- Costeo FIFO por lotes en compras y despachos.
- Dashboard admin con costos, materiales, precios, produccion y reportes.
- Registro de produccion diaria por linea para costo unitario.

La app consume directamente la API NestJS en `/api`. No usa PostgREST.

## Roles

- `admin`: ve dashboard, reportes, solicitudes, produccion, compras y alertas.
- `coordinador`: revisa resumen y consulta de costos por linea.
- `operario`: crea solicitudes por linea y revisa sus movimientos.
- `bodeguero`: despacha, rechaza si hace falta y registra despachos directos.
- `asistente de compras`: administra materiales, precios, stock e ingresos.

## Arquitectura

```text
Flutter
  |
  | HTTP / WebSocket
  v
NestJS API (/api)
  |
  | TypeORM
  v
PostgreSQL
```

## Estructura Principal

```text
lib/
  screens/admin/         Dashboard, compras, produccion, solicitudes y reportes
  screens/operario/      Nueva solicitud y mis solicitudes
  screens/bodeguero/     Entregas pendientes e historial
  screens/coordinador/   Consulta de despachos y resumen
  features/notificaciones/  Notificaciones internas
  services/              Cliente API y providers Riverpod
  models/                Modelos compartidos

backend/src/
  auth/                  Login, perfil y usuarios
  materiales/            Materiales, ingresos, stock y precios
  solicitudes/           Solicitudes, despacho, FIFO y notificaciones
  dashboard/             Consultas agregadas para el dashboard
  produccion/            Produccion diaria por linea
  notificaciones/        Persistencia y WebSocket
  entities.ts            Entidades TypeORM

backend/sql/             Migraciones SQL del esquema
docs/                    Documentacion del proyecto
```

## Flujo Operativo

1. El operario elige una linea de produccion.
2. La app carga materiales sugeridos desde la base de datos.
3. El operario ajusta cantidades y envia la solicitud.
4. Bodega recibe la notificacion.
5. El bodeguero revisa stock y despacha.
6. El backend consume lotes FIFO y recalcula el costo real.
7. El sistema actualiza stock, costo promedio, valor de inventario y
   notificaciones.
8. El admin registra produccion diaria por linea y fecha.
9. El dashboard cruza despachos con produccion para mostrar costo unitario.
10. Si queda stock bajo, se genera alerta para administracion y compras.

## Costeo

Cada compra crea un lote con su propio precio. Al despachar:

1. Se consume primero el lote mas antiguo disponible.
2. Se guarda que lote se uso y cuanto costo tuvo.
3. Se actualiza stock, costo promedio y valor de inventario.
4. El dashboard usa el costo real consumido, no un precio estimado.

Ejemplo:

```text
Lote 1: 1 unidad a $5.00
Lote 2: 2 unidades a $3.50

Despacho de 2 unidades:
  costo real = $5.00 + $3.50 = $8.50
```

## Costo Unitario

La seccion de costo unitario del dashboard cruza:

```text
costo unitario = costo real de materiales / unidades producidas
```

Esto sirve para ver, por ejemplo:

- Costo por cilindro reparado.
- Costo por cilindro fabricado.
- Costo por asa producida.
- Costo por base producida.

## Base De Datos

El sistema se documenta y versiona con migraciones SQL. Las tablas principales
son:

- `usuarios`
- `lineas_produccion`
- `produccion_diaria`
- `materiales`
- `linea_produccion_materiales`
- `movimientos_inventario`
- `inventario_lotes`
- `precios_material`
- `solicitudes`
- `detalle_solicitud`
- `detalle_consumo_lotes`
- `notificaciones`

## Instalacion Backend

Requisitos:

- Node.js
- PostgreSQL

Variables de entorno sugeridas:

```text
DATABASE_URL=postgresql://tu_usuario:tu_password@127.0.0.1:5432/tecnero_inventario1
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=tu_usuario
DB_PASSWORD=
DB_NAME=tecnero_inventario1
JWT_SECRET=tecnero_demo_secret
PORT=3000
```

Pasos:

```bash
cd backend
npm install
npm run start:dev
```

El backend carga automaticamente `backend/.env`.

La API queda en:

```text
http://localhost:3000/api
```

## Instalacion Flutter

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

En Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

En celular fisico, usa la IP local de tu computadora:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
```

## Usuarios Demo

Accesos rapidos del login:

```text
admin@tecnero.com      / 123456
coord@tecnero.com      / 123456
operario@tecnero.com   / 123456
bodega@tecnero.com     / 123456
```

Si un usuario no tiene `password_hash`, el backend acepta la clave `123456`.
El rol `asistente_compras` entra en la seccion de `admin/precios` y puede
usarse con una cuenta registrada en la base si la tienes cargada para la demo.

## Notificaciones

Modulo: `backend/src/notificaciones`

Endpoints:

- `GET /api/notificaciones`
- `GET /api/notificaciones/no-leidas`
- `PATCH /api/notificaciones/:id/leida`
- `PATCH /api/notificaciones/marcar-todas-leidas`

Eventos de negocio:

- Solicitud creada o editada: notifica a bodega.
- Solicitud entregada: notifica al solicitante y a coordinacion.
- Despacho directo: notifica al colaborador de planta.
- Stock bajo: notifica a admin y compras.

## Documentacion

- [Modelo de datos](docs/modelo-datos.md)
- [Flujo de negocio](docs/flujo-negocio.md)
- [Guia de demo](docs/guia-demo.md)
- [Entregables](docs/entregables.md)
- [Estructura del codigo](docs/estructura-codigo.md)
- [Migraciones SQL](backend/sql/README.md)

## Verificacion Rapida

```bash
cd backend
npm run build
```

```bash
flutter analyze
```
