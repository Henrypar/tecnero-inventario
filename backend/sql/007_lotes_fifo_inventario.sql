CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS inventario_lotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id uuid NOT NULL REFERENCES materiales(id) ON DELETE RESTRICT,
  cantidad_inicial numeric NOT NULL,
  cantidad_disponible numeric NOT NULL,
  precio_unitario numeric(12, 4) NOT NULL,
  referencia varchar NULL,
  fecha_entrada timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventario_lotes_material_fifo
  ON inventario_lotes (material_id, fecha_entrada ASC, id ASC)
  WHERE cantidad_disponible > 0;

CREATE TABLE IF NOT EXISTS detalle_consumo_lotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  detalle_solicitud_id uuid NOT NULL REFERENCES detalle_solicitud(id) ON DELETE CASCADE,
  lote_id uuid NOT NULL REFERENCES inventario_lotes(id) ON DELETE RESTRICT,
  cantidad numeric NOT NULL,
  precio_unitario numeric(12, 4) NOT NULL,
  subtotal numeric(14, 4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_detalle_consumo_lotes_detalle
  ON detalle_consumo_lotes (detalle_solicitud_id);

CREATE INDEX IF NOT EXISTS idx_detalle_consumo_lotes_lote
  ON detalle_consumo_lotes (lote_id);

INSERT INTO inventario_lotes (
  material_id,
  cantidad_inicial,
  cantidad_disponible,
  precio_unitario,
  referencia,
  fecha_entrada
)
SELECT
  m.id,
  m.stock_actual,
  m.stock_actual,
  COALESCE(NULLIF(m.costo_promedio, 0), pa.precio, 0),
  'Saldo inicial migrado a FIFO',
  now()
FROM materiales m
LEFT JOIN LATERAL (
  SELECT precio
  FROM precios_material
  WHERE material_id = m.id
  ORDER BY fecha_vigencia DESC
  LIMIT 1
) pa ON true
WHERE m.stock_actual > 0
  AND NOT EXISTS (
    SELECT 1
    FROM inventario_lotes l
    WHERE l.material_id = m.id
  );
