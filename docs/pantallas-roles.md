# Pantallas Y Funciones Por Rol

Este documento describe que hace cada pantalla de la aplicacion, organizado por rol.

## Resumen General

La app tiene cinco perfiles principales:

- `admin`
- `coordinador`
- `operario`
- `bodeguero`
- `asistente de compras`

Cada rol entra a una pantalla inicial distinta despues del login y solo ve los
modulos que necesita para su trabajo.

---

## Rol Admin

El rol admin tiene acceso a la vista mas completa del sistema. Puede revisar
costos, produccion, materiales, solicitudes, reportes y notificaciones.

### `Dashboard`

Ruta: `/admin/dashboard`

Que hace:

- Muestra el gasto total del periodo.
- Resume entregas cerradas, promedio por pedido y materiales usados.
- Presenta costo por linea de produccion.
- Muestra costo diario por linea y por dia.
- Calcula costo unitario de produccion.
- Muestra materiales por costo y por cantidad usada.
- Lista los ultimos consumos registrados.
- Permite descargar un PDF con la informacion filtrada.
- Incluye simulador de gastos adicionales.

### `Precios / Compras`

Ruta: `/admin/precios`

Que hace:

- Permite administrar materiales.
- Crear y editar materiales.
- Registrar ingresos de inventario.
- Revisar precios y cambios de precio.
- Consultar stock y alertas de stock minimo.
- Ver historial de ingresos.

### `Produccion`

Ruta: `/admin/produccion`

Que hace:

- Permite registrar produccion diaria por linea.
- Editar o eliminar registros existentes.
- Ver el detalle de produccion por fecha y linea.
- Usar la produccion para calcular el costo unitario.

### `Solicitudes`

Ruta: `/admin/solicitudes`

Que hace:

- Muestra todas las solicitudes del sistema.
- Permite revisar estado, fechas y costos.
- Sirve como consulta general para control administrativo.

### `Reportes`

Ruta: `/admin/reportes`

Que hace:

- Presenta graficas y tablas de costos.
- Permite filtrar por fecha y por linea.
- Muestra distribucion por linea y otros resumentes.
- Tiene exportacion de reporte.

### `Notificaciones`

Ruta: `/admin/notificaciones`

Que hace:

- Muestra notificaciones internas del admin.
- Permite marcarlas como leidas.
- Permite marcarlas todas como leidas.
- Muestra alertas de solicitudes, entregas y stock bajo.

---

## Rol Coordinador

El coordinador revisa aprobaciones y un resumen de costos.

### `Aprobaciones`

Ruta: `/coordinador/aprobaciones`

Que hace:

- Permite ver solicitudes entregadas y su estado.
- Sirve para revisar el flujo despues de bodega.
- Muestra trazabilidad operativa de los pedidos.



### `Notificaciones`

Ruta: `/coordinador/notificaciones`

Que hace:

- Muestra avisos internos del coordinador.
- Permite revisar cambios del flujo operativo.
- Permite marcar notificaciones como leidas.

---

## Rol Operario

El operario crea solicitudes de materiales y revisa sus pedidos.

### `Nueva Solicitud`

Ruta: `/operario/nueva-solicitud`

Que hace:

- Permite crear solicitudes por linea de produccion.
- Muestra materiales sugeridos segun la linea.
- Permite ajustar cantidades antes de enviar.
- Genera la solicitud para que bodega la despache.

### `Mis Solicitudes`

Ruta: `/operario/mis-solicitudes`

Que hace:

- Lista las solicitudes creadas por el operario.
- Muestra estados como pendiente, aprobada, entregada o rechazada.
- Permite revisar el historial personal de pedidos.

### `Notificaciones`

Ruta: `/operario/notificaciones`

Que hace:

- Muestra avisos sobre sus solicitudes.
- Informa cuando un pedido cambia de estado.
- Permite marcar las notificaciones como leidas.

---

## Rol Bodeguero

El bodeguero revisa solicitudes, despacha materiales y registra rechazos.

### `Entregas`

Ruta: `/bodeguero/entregas`

Que hace:

- Muestra solicitudes pendientes de despacho.
- Permite confirmar entregas.
- Permite rechazar solicitudes con motivo.
- Permite registrar despachos directos de bodega.
- Actualiza inventario al despachar.

### `Historial`

Ruta: `/bodeguero/historial`

Que hace:

- Muestra el historial de entregas y rechazos.
- Permite revisar movimientos pasados de bodega.
- Sirve como trazabilidad operativa.

### `Notificaciones`

Ruta: `/bodeguero/notificaciones`

Que hace:

- Muestra notificaciones relacionadas con despacho.
- Informa cuando entra una nueva solicitud.
- Permite marcar notificaciones como leidas.

---

## Rol Asistente De Compras

Este rol entra al modulo de materiales y precios, que comparte la base con el
admin pero con foco en compras.

### `Precios / Compras`

Ruta: `/admin/precios`

Que hace:

- Administra materiales.
- Registra ingresos de inventario.
- Revisa precios y stock.
- Puede apoyar la gestion de compras y abastecimiento.

### `Notificaciones`

Ruta: `/admin/notificaciones`

Que hace:

- Recibe alertas de stock bajo.
- Puede ver avisos de materiales y compras.

---

## Pantalla De Login

Ruta: `/login`

Que hace:

- Permite iniciar sesion.
- Redirige automaticamente al rol correspondiente.
- Si el usuario ya tiene sesion, lo manda a su modulo inicial.

---

## Pantalla Compartida De Notificaciones

Ruta base: `/notificaciones`

Que hace:

- Redirige automaticamente al centro de notificaciones correcto segun el rol.
- Evita duplicar rutas y mantiene una sola logica de acceso.

---

## Resumen Rapido Por Rol

- Admin: monitorea todo el sistema, costos, produccion, materiales y reportes.
- Coordinador: revisa aprobaciones y seguimiento de costos.
- Operario: crea solicitudes y revisa sus pedidos.
- Bodeguero: despacha, rechaza y deja trazabilidad.
- Asistente de compras: administra materiales, precios y stock.


