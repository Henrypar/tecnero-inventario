# Estructura Del Codigo

Resumen rapido de donde vive cada parte del sistema.

## Frontend Flutter

### `lib/main.dart`

Punto de entrada. Inicializa Flutter, Riverpod, tema y router.

### `lib/router.dart`

Define las rutas por rol y las pantallas principales:

- Admin: dashboard, compras, produccion, solicitudes y reportes.
- Coordinador: aprobaciones, dashboard y notificaciones.
- Operario: nueva solicitud y mis solicitudes.
- Bodeguero: entregas, historial y notificaciones.

### `lib/services/api_service.dart`

Cliente HTTP central. Resuelve:

- Login y perfil.
- Materiales, precios y stock.
- Solicitudes y despachos.
- Produccion diaria.
- Dashboard y reportes.
- Notificaciones.

### `lib/services/providers.dart`

Providers Riverpod para compartir datos y refrescar pantallas despues de crear,
editar o despachar.

### `lib/models/models.dart`

Modelos compartidos entre JSON del backend y la UI.

### `lib/screens/admin/`

- `dashboard_screen.dart`: costos, produccion, materiales, precios y simulador.
- `precios_screen.dart`: catalogo, ingresos, stock, historial y alertas.
- `produccion_screen.dart`: registro y edicion de produccion diaria por linea.
- `solicitudes_admin_screen.dart`: consulta general de solicitudes.
- `reportes_screen.dart`: reportes y exportacion.

### `lib/screens/operario/`

- `nueva_solicitud_screen.dart`: crea solicitudes por linea.
- `mis_solicitudes_screen.dart`: lista solicitudes y sus estados.

### `lib/screens/bodeguero/`

- `entregas_screen.dart`: pendientes, despacho directo y rechazos.
- `historial_screen.dart`: entregas y rechazos agrupados por fecha.

### `lib/screens/coordinador/`

- `aprobaciones_screen.dart`: consulta de solicitudes/aprobaciones.
- `dashboard_coord_screen.dart`: resumen de costos.

### `lib/features/notificaciones/`

Campana, lista y servicio de notificaciones internas.

## Backend NestJS

### `backend/src/main.ts`

Bootstrap del backend. Activa CORS, prefijo `/api` y el puerto HTTP.

### `backend/src/app.module.ts`

Configura PostgreSQL con TypeORM y registra los modulos funcionales.

### `backend/src/entities.ts`

Entidades principales:

- Usuarios
- Lineas de produccion
- Materiales
- Relacion linea-material
- Precios
- Solicitudes
- Detalle de solicitud
- Lotes FIFO
- Consumo por lote
- Movimientos de inventario
- Produccion diaria
- Notificaciones

### `backend/src/auth/`

Login, JWT, perfil y listado de usuarios.

### `backend/src/materiales/`

Gestion de catalogo, precios, stock e ingresos de inventario.

### `backend/src/solicitudes/`

Gestion del flujo operativo. El despacho:

1. Valida stock.
2. Consume lotes FIFO.
3. Guarda el detalle por lote.
4. Recalcula el costo real.
5. Actualiza inventario.
6. Emite notificaciones.

### `backend/src/dashboard/`

Consultas agregadas para:

- Costo total.
- Costo por linea.
- Costo por dia.
- Materiales por costo.
- Materiales por cantidad.
- Cambios de precio.
- Produccion unitaria por linea.

### `backend/src/produccion/`

Registro de produccion diaria. El dashboard usa este dato para calcular costo
unitario real por linea.

### `backend/src/notificaciones/`

Persistencia de notificaciones y envio en tiempo real con Socket.IO.

### `backend/sql/`

Migraciones SQL que construyen y mantienen la base de datos del proyecto.
