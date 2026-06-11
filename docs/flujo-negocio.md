# Flujo De Negocio Y Supuestos

## Contexto

La empresa necesita registrar solicitudes, despachos, stock y costos reales sin
depender de hojas de calculo manuales.

## Supuesto Principal

El flujo operativo real del proyecto es este:

- Planta solicita materiales a bodega.
- Bodega verifica stock y despacha.
- Coordinacion consulta resumen y trazabilidad, pero no forma parte del flujo
  diario principal.
- Compras administra materiales, precios y stock.

Los endpoints historicos de aprobacion se conservan por compatibilidad, pero el
flujo usado en la app prioriza solicitud, despacho y consulta.

## Flujo Principal

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

## Despacho Directo

Si alguien llega directamente a bodega, el bodeguero puede registrar el
despacho como directo:

- Selecciona colaborador.
- Selecciona linea.
- Carga materiales sugeridos.
- Ajusta cantidades.
- Confirma el despacho.

La solicitud queda con `origen = bodega_directo` para conservar trazabilidad.

## Compras

Compras o admin puede:

- Crear y editar materiales.
- Registrar ingresos de inventario.
- Definir precio de compra.
- Ajustar stock minimo de alerta.
- Revisar historial de ingresos y valor de inventario.

Cada ingreso crea un lote FIFO. Eso permite que el costo real no dependa del
ultimo precio, sino del stock realmente consumido.

## Costeo FIFO

Ejemplo:

```text
Lote antiguo: 1 unidad a $5.00
Lote nuevo:   2 unidades a $3.50

Despacho de 2 unidades:
  costo real = $5.00 + $3.50 = $8.50
```

Ese costo se guarda en la solicitud, en el movimiento de inventario y en los
reportes del dashboard.

## Costo Unitario De Produccion

El sistema guarda produccion diaria por linea y fecha. Luego calcula:

```text
costo unitario = costo real de materiales despachados / unidades producidas
```

Ejemplo:

```text
Linea: Reparacion
Fecha: 10/06/2026
Materiales despachados: $120.00
Produccion: 40 cilindros

Costo unitario = $3.00 por cilindro
```

La misma logica sirve para cilindros, asas, bases y valvulas.

## Alertas

Si un material queda por debajo del minimo configurado al despachar, se genera
notificacion de stock bajo para admin y compras.
