# Modelo De Datos

Resumen de las tablas reales del proyecto y como se relacionan.

## Esquema General

El sistema usa 12 tablas principales:

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

## Usuarios

Tabla: `usuarios`

Campos clave:

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

## Lineas De Produccion

Tabla: `lineas_produccion`

Registra las lineas operativas de la planta:

- Fabricacion de Cilindros
- Reparacion
- Fabrica Asas
- Fabrica Bases
- Reparacion de Valvulas

## Materiales

Tabla: `materiales`

Campos principales:

- `codigo`
- `nombre`
- `unidad_medida`
- `categoria`
- `stock_actual`
- `stock_minimo_alerta`
- `costo_promedio`
- `valor_inventario`
- `activo`

`stock_actual`, `costo_promedio` y `valor_inventario` se recalculan desde los
lotes FIFO y los ajustes de inventario.

## Materiales Por Linea

Tabla: `linea_produccion_materiales`

Relaciona cada linea con sus materiales sugeridos o permitidos:

- `linea_produccion_id`
- `material_id`
- `cantidad_sugerida`
- `activo`

Esta tabla alimenta las pantallas de operario y bodega sin usar listas fijas.

## Precios

Tabla: `precios_material`

Guarda el historial de precios por material:

- `material_id`
- `precio`
- `registrado_por`
- `fecha_vigencia`

Se usa para ver cambios de precio. El costo real de consumo sigue saliendo por
FIFO.

## Lotes FIFO

Tabla: `inventario_lotes`

Cada compra o ingreso crea un lote:

- `material_id`
- `cantidad_inicial`
- `cantidad_disponible`
- `precio_unitario`
- `referencia`
- `fecha_entrada`

Al despachar, primero se consume el lote mas antiguo con saldo disponible.

## Solicitudes

Tabla: `solicitudes`

Campos principales:

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

Estados que se usan en la app:

- `pendiente`
- `entregada`
- `rechazada`
- `aprobada` solo queda por compatibilidad historica

Origen:

- `operario`
- `bodega_directo`

## Detalle De Solicitud

Tabla: `detalle_solicitud`

Cada solicitud tiene uno o mas materiales:

- `solicitud_id`
- `material_id`
- `material_nombre`
- `material_codigo`
- `unidad_medida`
- `cantidad`
- `precio_unitario_momento`
- `subtotal`

Cuando bodega despacha, este detalle se recalcula con el costo FIFO real.

## Consumo De Lotes

Tabla: `detalle_consumo_lotes`

Registra que lote alimenta cada detalle:

- `detalle_solicitud_id`
- `lote_id`
- `cantidad`
- `precio_unitario`
- `subtotal`

Sirve para auditar salidas que mezclan stock viejo y nuevo.

## Produccion Diaria

Tabla: `produccion_diaria`

Registra la produccion por fecha y linea:

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

## Movimientos De Inventario

Tabla: `movimientos_inventario`

Registra entradas, ajustes y salidas:

- `tipo`
- `cantidad`
- `precio_unitario`
- `stock_anterior`
- `stock_nuevo`
- `registrado_por`
- `observaciones`
- `fecha`

Tipos principales:

- `entrada_compra`
- `entrada_manual`
- `ajuste_stock`
- `salida_produccion`

## Notificaciones

Tabla: `notificaciones`

Guarda eventos internos por usuario:

- `usuario_id`
- `titulo`
- `mensaje`
- `tipo`
- `leida`
- `solicitud_id`
- `fecha_creacion`
