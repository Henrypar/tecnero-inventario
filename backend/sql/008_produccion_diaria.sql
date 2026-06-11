CREATE TABLE IF NOT EXISTS produccion_diaria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha date NOT NULL,
  linea_id uuid NOT NULL REFERENCES lineas_produccion(id) ON DELETE RESTRICT,
  linea_nombre varchar NOT NULL,
  cantidad numeric NOT NULL,
  unidad varchar NOT NULL,
  registrado_por varchar NOT NULL,
  observaciones varchar NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_produccion_diaria_fecha
  ON produccion_diaria (fecha DESC);

CREATE INDEX IF NOT EXISTS idx_produccion_diaria_linea_fecha
  ON produccion_diaria (linea_id, fecha DESC);

INSERT INTO produccion_diaria (
  fecha,
  linea_id,
  linea_nombre,
  cantidad,
  unidad,
  registrado_por,
  observaciones
)
SELECT
  base.fecha,
  base.linea_id,
  base.linea_nombre,
  CASE
    WHEN LOWER(base.linea_nombre) LIKE '%asas%' THEN 80
    WHEN LOWER(base.linea_nombre) LIKE '%bases%' THEN 70
    WHEN LOWER(base.linea_nombre) LIKE '%valv%' THEN 45
    WHEN LOWER(base.linea_nombre) LIKE '%repar%' THEN 40
    WHEN LOWER(base.linea_nombre) LIKE '%cilind%' THEN 30
    ELSE 50
  END AS cantidad,
  CASE
    WHEN LOWER(base.linea_nombre) LIKE '%asas%' THEN 'asas'
    WHEN LOWER(base.linea_nombre) LIKE '%bases%' THEN 'bases'
    WHEN LOWER(base.linea_nombre) LIKE '%valv%' THEN 'valvulas reparadas'
    WHEN LOWER(base.linea_nombre) LIKE '%repar%' THEN 'cilindros reparados'
    WHEN LOWER(base.linea_nombre) LIKE '%cilind%' THEN 'cilindros fabricados'
    ELSE 'unidades'
  END AS unidad,
  'Carga inicial TECNERO' AS registrado_por,
  'Carga inicial demo para costo unitario' AS observaciones
FROM (
  SELECT DISTINCT
    COALESCE(fecha_entrega, fecha)::date AS fecha,
    linea_id,
    linea_nombre
  FROM solicitudes
  WHERE estado = 'entregada'
    AND linea_id IS NOT NULL
) base
WHERE NOT EXISTS (
  SELECT 1
  FROM produccion_diaria p
  WHERE p.fecha = base.fecha
    AND p.linea_id = base.linea_id
    AND p.observaciones = 'Carga inicial demo para costo unitario'
);
