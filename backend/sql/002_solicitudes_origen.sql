ALTER TABLE solicitudes
  ADD COLUMN IF NOT EXISTS origen varchar NOT NULL DEFAULT 'operario';

UPDATE solicitudes
SET origen = 'bodega_directo'
WHERE LOWER(COALESCE(observaciones, '')) LIKE '%despacho registrado directamente en bodega%';

CREATE INDEX IF NOT EXISTS idx_solicitudes_origen
  ON solicitudes (origen);
