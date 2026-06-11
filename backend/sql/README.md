# Migraciones SQL

La API usa TypeORM con `synchronize: false`, por eso la estructura de base se
aplica con migraciones SQL versionadas en esta carpeta.

## Orden De Ejecucion

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

Si no usas `DATABASE_URL`, ejecuta el mismo orden contra tu base local.

## Que Hace Cada Archivo

- `001_notificaciones.sql`: crea la tabla de notificaciones internas.
- `002_solicitudes_origen.sql`: agrega el origen de la solicitud
  (`operario` o `bodega_directo`).
- `003_movimientos_inventario.sql`: registra auditoria de entradas, ajustes y
  salidas.
- `004_stock_minimo_alerta.sql`: agrega el minimo configurable para alertas.
- `005_linea_produccion_materiales.sql`: relaciona lineas con materiales
  permitidos o sugeridos.
- `006_costo_promedio_inventario.sql`: agrega columnas de costo promedio y
  valor de inventario.
- `007_lotes_fifo_inventario.sql`: crea los lotes FIFO y el detalle de consumo.
- `008_produccion_diaria.sql`: crea produccion diaria y carga datos demo.

## Tablas Resultado

Las migraciones y las entidades convergen en estas tablas:

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

## Nota Sobre FIFO

La migracion `007_lotes_fifo_inventario.sql` convierte el saldo inicial en un
lote base para arrancar el historial. Desde ahi, cada ingreso nuevo crea su
propio lote y cada despacho consume los mas antiguos primero.

## Nota Sobre Produccion

La migracion `008_produccion_diaria.sql` crea la tabla de produccion diaria y
precarga registros demo. Si la ejecutas otra vez, no duplica esos datos.
