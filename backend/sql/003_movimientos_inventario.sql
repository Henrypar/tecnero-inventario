CREATE TABLE IF NOT EXISTS movimientos_inventario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id uuid NOT NULL REFERENCES materiales(id) ON DELETE RESTRICT,
  material_codigo varchar NOT NULL,
  material_nombre varchar NOT NULL,
  unidad_medida varchar NOT NULL,
  tipo varchar NOT NULL DEFAULT 'entrada_compra',
  cantidad numeric NOT NULL,
  precio_unitario numeric(12, 4) NOT NULL DEFAULT 0,
  stock_anterior numeric NOT NULL,
  stock_nuevo numeric NOT NULL,
  registrado_por varchar NOT NULL,
  observaciones varchar NULL,
  fecha timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_movimientos_inventario_fecha
  ON movimientos_inventario (fecha DESC);

CREATE INDEX IF NOT EXISTS idx_movimientos_inventario_material_fecha
  ON movimientos_inventario (material_id, fecha DESC);

CREATE INDEX IF NOT EXISTS idx_movimientos_inventario_tipo_fecha
  ON movimientos_inventario (tipo, fecha DESC);
