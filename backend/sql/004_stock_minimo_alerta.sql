ALTER TABLE materiales
  ADD COLUMN IF NOT EXISTS stock_minimo_alerta numeric NOT NULL DEFAULT 5;

UPDATE materiales
SET stock_minimo_alerta = 5
WHERE stock_minimo_alerta IS NULL;
