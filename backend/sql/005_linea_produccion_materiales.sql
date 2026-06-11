CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS linea_produccion_materiales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  linea_produccion_id uuid NOT NULL REFERENCES lineas_produccion(id) ON DELETE CASCADE,
  material_id uuid NOT NULL REFERENCES materiales(id) ON DELETE CASCADE,
  cantidad_sugerida numeric NOT NULL DEFAULT 1,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (linea_produccion_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_linea_materiales_linea
  ON linea_produccion_materiales (linea_produccion_id, activo);

CREATE INDEX IF NOT EXISTS idx_linea_materiales_material
  ON linea_produccion_materiales (material_id);

WITH asociaciones(linea_patron, material_codigo, cantidad_sugerida) AS (
  VALUES
    ('%Asas%', 'M-MAPD-014', 1),
    ('%Asas%', 'M-MAPI-001', 1),
    ('%Asas%', 'M-MAPI-004', 4),
    ('%Asas%', 'M-MAPI-006', 1),
    ('%Asas%', 'M-MAPI-051', 2),
    ('%Asas%', 'M-MAPI-052', 2),
    ('%Asas%', 'A-SEGU-006', 1),
    ('%Asas%', 'A-SEGU-025', 1),

    ('%Bases%', 'M-MAPD-015', 1),
    ('%Bases%', 'M-MAPI-001', 1),
    ('%Bases%', 'M-MAPI-004', 4),
    ('%Bases%', 'M-MAPI-006', 1),
    ('%Bases%', 'M-MAPI-007', 1),
    ('%Bases%', 'M-MAPI-016', 1),
    ('%Bases%', 'M-MAPI-051', 2),
    ('%Bases%', 'M-MAPI-052', 2),
    ('%Bases%', 'M-MAPI-061', 1),
    ('%Bases%', 'M-MAPI-077', 1),

    ('%Cilindros%', 'M-MAPD-019', 1),
    ('%Cilindros%', 'M-MAPD-025', 1),
    ('%Cilindros%', 'M-MAPI-001', 1),
    ('%Cilindros%', 'M-MAPI-004', 4),
    ('%Cilindros%', 'M-MAPI-006', 1),
    ('%Cilindros%', 'R-MATL-001', 2),
    ('%Cilindros%', 'M-MAPI-051', 2),
    ('%Cilindros%', 'M-MAPI-052', 2),
    ('%Cilindros%', 'M-MAPI-064', 1),
    ('%Cilindros%', 'M-MAPI-068', 1),
    ('%Cilindros%', 'M-MAPI-069', 1),

    ('%Reparación', 'R-MATL-001', 1),
    ('%Reparación', 'R-MATL-031', 1),
    ('%Reparación', 'R-MATL-047', 1),
    ('%Reparación', 'M-MAPI-051', 2),
    ('%Reparación', 'M-MAPI-052', 2),
    ('%Reparación', 'M-MAPI-001', 1),
    ('%Reparación', 'M-MAPI-004', 4),
    ('%Reparación', 'M-MAPI-006', 1),

    ('%Válvulas%', 'M-MAPI-064', 1),
    ('%Válvulas%', 'M-MAPI-068', 1),
    ('%Válvulas%', 'M-MAPI-069', 1),
    ('%Válvulas%', 'M-MAPI-045', 1),
    ('%Válvulas%', 'M-MAPI-077', 1),
    ('%Válvulas%', 'R-MATL-001', 1),
    ('%Válvulas%', 'R-MATL-031', 1),
    ('%Válvulas%', 'M-MAPI-051', 1),
    ('%Válvulas%', 'M-MAPI-052', 1)
)
INSERT INTO linea_produccion_materiales (
  linea_produccion_id,
  material_id,
  cantidad_sugerida,
  activo
)
SELECT
  lp.id,
  m.id,
  a.cantidad_sugerida,
  true
FROM asociaciones a
JOIN lineas_produccion lp ON lp.nombre ILIKE a.linea_patron
JOIN materiales m ON m.codigo = a.material_codigo
ON CONFLICT (linea_produccion_id, material_id) DO UPDATE
SET cantidad_sugerida = EXCLUDED.cantidad_sugerida,
    activo = true;
