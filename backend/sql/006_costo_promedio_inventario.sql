ALTER TABLE materiales
  ADD COLUMN IF NOT EXISTS costo_promedio DECIMAL(12, 4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_inventario DECIMAL(14, 4) NOT NULL DEFAULT 0;

WITH precio_actual AS (
  SELECT DISTINCT ON (material_id)
    material_id,
    precio
  FROM precios_material
  ORDER BY material_id, fecha_vigencia DESC
)
UPDATE materiales m
SET
  costo_promedio = COALESCE(pa.precio, 0),
  valor_inventario = COALESCE(m.stock_actual, 0) * COALESCE(pa.precio, 0)
FROM precio_actual pa
WHERE pa.material_id = m.id
  AND (m.costo_promedio = 0 OR m.valor_inventario = 0);

UPDATE materiales
SET valor_inventario = COALESCE(stock_actual, 0) * COALESCE(costo_promedio, 0)
WHERE valor_inventario IS NULL;
