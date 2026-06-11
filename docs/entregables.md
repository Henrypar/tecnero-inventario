# Entregables De La Prueba

Este repositorio incluye los entregables reales del proyecto:

## Codigo Fuente

- Frontend Flutter en `lib/`
- Backend NestJS en `backend/src/`
- Migraciones SQL en `backend/sql/`

## Base De Datos

La base se versiona con migraciones SQL.

Respaldo:

```bash
pg_dump -d tecnero_inventario1 > tecnero_inventario_backup.sql
```

Restauracion:

```bash
psql -d tecnero_inventario1 -f tecnero_inventario_backup.sql
```

## Documentacion

- `README.md`: descripcion general, instalacion y arquitectura.
- `docs/modelo-datos.md`: tablas y relaciones.
- `docs/flujo-negocio.md`: proceso operativo real.
- `docs/guia-demo.md`: recorrido para presentar la solucion.
- `docs/estructura-codigo.md`: ubicacion de cada modulo.
- `backend/sql/README.md`: orden de migraciones.

## Datos Demo

El proyecto ya trae datos de ejemplo para mostrar:

- Usuarios por rol.
- Lineas de produccion.
- Materiales y precios.
- Relacion linea-material.
- Inventario y lotes FIFO.
- Produccion diaria.
- Solicitudes y despachos.
- Notificaciones.

## Criterios Cubiertos

- Solicitud de materiales por linea.
- Despacho de bodega con trazabilidad.
- Costeo FIFO real por lote.
- Stock bajo y movimientos de inventario.
- Produccion diaria para costo unitario.
- Dashboard y reportes para administracion.
- Autenticacion JWT y roles.
- Persistencia en PostgreSQL.
- Interfaz responsive.
