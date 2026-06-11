# Guia De Demo

Recorrido corto para presentar el sistema en una entrega o defensa.

## 1. Login

Usar uno de estos accesos:

```text
admin@tecnero.com      / 123456
coord@tecnero.com      / 123456
operario@tecnero.com   / 123456
bodega@tecnero.com     / 123456
```

Mostrar que el menu cambia segun el rol.
Si deseas mostrar el rol `asistente_compras`, entra con una cuenta registrada
en la seccion de `admin/precios`, porque ese perfil comparte la vista de
materiales, precios y stock.

## 2. Dashboard Admin

Entrar como admin y mostrar:

- Filtros por fecha y linea.
- Costo total del periodo.
- Costo por linea y por dia.
- Costo unitario por produccion.
- Materiales por gasto.
- Materiales por cantidad.
- Precios usados por material.
- Cambios de precio.
- Simulador de gasto adicional.

Mensaje clave:

> El dashboard muestra costo real, no solo precios estimados.

## 3. Produccion Diaria

Entrar a `Produccion` y demostrar:

- Registrar fecha.
- Elegir linea.
- Ingresar cantidad producida.
- Definir unidad.
- Editar un registro existente si ya hay fecha + linea.

Mensaje clave:

> El costo unitario sale de cruzar materiales despachados con unidades producidas.

## 4. Compras

Entrar a `Compras` y mostrar:

- Crear o editar material.
- Registrar ingreso de inventario.
- Asignar precio de compra.
- Ver costo promedio y valor de inventario.
- Revisar historial de ingresos.
- Ver alertas de stock bajo.

Mensaje clave:

> Cada ingreso crea un lote FIFO y ese lote queda listo para costear despachos.

## 5. Operario

Entrar como operario y crear una solicitud:

1. Elegir linea de produccion.
2. Revisar materiales sugeridos.
3. Ajustar cantidades.
4. Enviar la solicitud.

Mensaje clave:

> Los materiales sugeridos se cargan desde la base de datos por linea.

## 6. Bodeguero

Entrar como bodeguero y mostrar:

- Solicitudes pendientes.
- Despacho de materiales.
- Rechazo con motivo.
- Despacho directo desde bodega.
- Historial de entregas y rechazos.

Mensaje clave:

> Al despachar, el sistema descuenta stock y calcula el costo real con FIFO.

## 7. Notificaciones

Mostrar la campana o pantalla de notificaciones:

- Bodega recibe una solicitud nueva.
- Operario recibe confirmacion de entrega.
- Coordinacion ve los eventos de consulta.
- Admin recibe stock bajo.

## 8. Reportes

Entrar a `Reportes` y mostrar:

- Filtros por fecha y linea.
- Evolucion del gasto.
- Ranking de materiales.
- Costos por linea.
- Exportacion PDF.

## 9. Cierre

Frase de cierre sugerida:

> El sistema digitaliza la solicitud y el despacho de materiales, registra
> inventario con trazabilidad FIFO, calcula costos reales y genera costo
> unitario por produccion para apoyar decisiones de planta.
