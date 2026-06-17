# Base De Datos

Esta guia explica la base de datos del proyecto TECNERO Inventario de forma
funcional: que guarda cada tabla, como se relacionan y que flujo del sistema la
escribe o la consulta.

## Resumen

El proyecto usa **PostgreSQL** como base principal y **NestJS + TypeORM** como
capa de acceso a datos.

Puntos importantes:

- La aplicacion **no usa PostgREST**.
- Las migraciones SQL se aplican manualmente desde `backend/sql/`.
- `TypeORM` tiene `synchronize: false`, asi que el esquema no se genera solo.
- No hay procesos automaticos al arrancar el backend que creen datos nuevos de
  produccion o solicitudes.

## Proposito Del Modelo

La base resuelve cinco necesidades principales:

1. Usuarios y roles.
2. Solicitudes de materiales.
3. Bodega e inventario FIFO.
4. Produccion diaria por linea.
5. Notificaciones internas y trazabilidad.

## Tablas Principales

### `usuarios`

Guarda las cuentas del sistema.

Campos importantes:

- `id`
- `nombre`
- `email`
- `rol`
- `activo`
- `password_hash`

Roles usados por la app:

- `admin`
- `coordinador`
- `operario`
- `bodeguero`
- `asistente_compras`

Esta tabla la consulta el login y define que pantallas ve cada usuario.

### `lineas_produccion`

Guarda las lineas operativas de la planta.

Sirve para:

- Seleccionar la linea en una solicitud.
- Registrar produccion diaria.
- Agrupar reportes y costos por linea.

### `materiales`

Es el catalogo central de materiales.

Campos utiles:

- `codigo`
- `nombre`
- `unidad_medida`
- `categoria`
- `stock_actual`
- `stock_minimo_alerta`
- `costo_promedio`
- `valor_inventario`
- `activo`

Se usa en:

- compras e ingresos
- solicitudes de operario
- despachos de bodega
- alertas de stock
- reportes de costos

### `linea_produccion_materiales`

Relaciona cada linea con los materiales que puede usar o que se sugieren por
defecto.

Campos:

- `linea_produccion_id`
- `material_id`
- `cantidad_sugerida`
- `activo`

Esta tabla alimenta la pantalla de nueva solicitud para mostrar materiales
sugeridos segun la linea.

### `solicitudes`

Es la tabla principal del flujo operativo.

Guarda cada pedido creado por operario o por bodega directa.

Campos importantes:

- `numero`
- `solicitante_id`
- `solicitante_nombre`
- `linea_id`
- `linea_nombre`
- `fecha`
- `estado`
- `origen`
- `costo_total`
- `aprobado_por`
- `fecha_aprobacion`
- `fecha_entrega`

Estados usados:

- `pendiente`
- `entregada`
- `rechazada`
- `aprobada` solo por compatibilidad historica

Origenes:

- `operario`
- `bodega_directo`

### `detalle_solicitud`

Cada solicitud tiene uno o varios materiales.

Campos:

- `solicitud_id`
- `material_id`
- `material_nombre`
- `material_codigo`
- `unidad_medida`
- `cantidad`
- `precio_unitario_momento`
- `subtotal`

Aqui queda el detalle economico de cada pedido.

### `inventario_lotes`

Implementa el inventario FIFO.

Cada ingreso genera un lote propio con:

- cantidad inicial
- cantidad disponible
- precio unitario
- referencia
- fecha de entrada

Cuando bodega despacha, primero se consume el lote mas antiguo con saldo
disponible.

### `detalle_consumo_lotes`

Registra exactamente que lote se uso para cubrir cada detalle de una
solicitud.

Sirve para:

- auditar salidas
- explicar el costo real
- reconstruir el consumo FIFO

### `movimientos_inventario`

Registra entradas, ajustes y salidas de inventario.

Tipos tipicos:

- `entrada_compra`
- `entrada_manual`
- `ajuste_stock`
- `salida_produccion`

Esta tabla es la bitacora historica de inventario.

### `precios_material`

Guarda el historial de precios por material.

Se usa para:

- ver cambios de precio
- comparar precio actual vs anterior
- alimentar reportes de materiales

### `produccion_diaria`

Guarda la produccion real por fecha y linea.

Campos:

- `fecha`
- `linea_id`
- `linea_nombre`
- `cantidad`
- `unidad`
- `registrado_por`
- `observaciones`

El dashboard cruza esta tabla con los despachos entregados para calcular:

```text
costo unitario = costo real de materiales despachados / unidades producidas
```

### `notificaciones`

Guarda eventos internos para cada usuario.

Campos:

- `usuario_id`
- `titulo`
- `mensaje`
- `tipo`
- `leida`
- `solicitud_id`
- `fecha_creacion`

Se usa para avisos de:

- solicitudes nuevas
- solicitudes rechazadas
- entregas confirmadas
- stock bajo

## Relaciones Importantes

### Usuario -> Solicitud

Un usuario puede crear muchas solicitudes.

### Linea -> Solicitud

Cada solicitud pertenece a una linea de produccion.

### Solicitud -> Detalle Solicitud

Una solicitud puede tener varios materiales.

### Material -> Lotes FIFO

Un material puede tener muchos lotes de inventario.

### Detalle Solicitud -> Detalle Consumo Lotes

Cada linea de detalle puede consumir uno o varios lotes.

### Linea -> Produccion Diaria

Cada registro de produccion diaria pertenece a una linea.

### Usuario -> Notificacion

Cada notificacion pertenece a un usuario concreto.

## Flujo De Datos

### 1. Operario crea una solicitud

1. El operario elige una linea.
2. La app carga materiales sugeridos desde `linea_produccion_materiales`.
3. Se guarda la solicitud en `solicitudes`.
4. Se crean los materiales en `detalle_solicitud`.
5. Se emiten notificaciones internas.

### 2. Bodega despacha

1. Bodega revisa la solicitud.
2. El backend valida stock.
3. Se consumen lotes FIFO en `inventario_lotes`.
4. Se guarda el detalle real en `detalle_consumo_lotes`.
5. Se actualiza `materiales.stock_actual`, `costo_promedio` y `valor_inventario`.
6. Se actualiza `solicitudes.estado` a `entregada` o `rechazada`.
7. Se registra la trazabilidad en `movimientos_inventario`.

### 3. Admin registra produccion

1. El admin crea o edita registros en `produccion_diaria`.
2. El dashboard toma esas cantidades junto con los despachos entregados.
3. Se calcula costo unitario por linea.

### 4. Reportes y dashboard

Las consultas agregadas leen principalmente:

- `solicitudes`
- `detalle_solicitud`
- `detalle_consumo_lotes`
- `inventario_lotes`
- `materiales`
- `precios_material`
- `produccion_diaria`

## Migraciones SQL

Las migraciones estan en `backend/sql/` y se aplican en este orden:

1. `001_notificaciones.sql`
2. `002_solicitudes_origen.sql`
3. `003_movimientos_inventario.sql`
4. `004_stock_minimo_alerta.sql`
5. `005_linea_produccion_materiales.sql`
6. `006_costo_promedio_inventario.sql`
7. `007_lotes_fifo_inventario.sql`
8. `008_produccion_diaria.sql`

Ejemplo:

```bash
psql "$DATABASE_URL" -f backend/sql/001_notificaciones.sql
```

## Que Se Ejecuta Manualmente

Se ejecuta manualmente:

- las migraciones SQL
- la carga demo de `produccion_diaria` del archivo `008_produccion_diaria.sql`
- cualquier restauracion desde `tecnero_inventario_demo_backup.sql`

No se ejecuta automaticamente al iniciar el backend.

## Que No Hace El Backend Al Arrancar

El backend no:

- crea produccion diaria automaticamente
- ejecuta seeds ocultos
- corre migraciones solo
- inserta solicitudes solo por iniciar

## Tablas Y Uso Por Modulo

### Admin

Consulta:

- `solicitudes`
- `detalle_solicitud`
- `produccion_diaria`
- `precios_material`
- `materiales`

### Bodega

Consulta y escribe:

- `solicitudes`
- `detalle_solicitud`
- `detalle_consumo_lotes`
- `inventario_lotes`
- `movimientos_inventario`

### Operario

Escribe:

- `solicitudes`
- `detalle_solicitud`

### Coordinador

Consulta:

- `solicitudes`
- `produccion_diaria`
- reportes agregados

### Compras

Escribe y consulta:

- `materiales`
- `precios_material`
- `movimientos_inventario`
- `inventario_lotes`

## Archivo De Respaldo

`backend/sql/tecnero_inventario_demo_backup.sql` es un respaldo con el esquema
completo y datos de demo. No es el flujo normal de arranque de la aplicacion.

## Resumen Final

La base de datos esta pensada para sostener cuatro cosas sin perder trazabilidad:

- solicitudes
- inventario
- produccion
- notificaciones

El valor del sistema esta en que el costo sale del consumo real FIFO y no de un
precio estimado.
