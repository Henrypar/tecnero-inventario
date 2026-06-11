CREATE TABLE IF NOT EXISTS notificaciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  titulo varchar NOT NULL,
  mensaje varchar NOT NULL,
  tipo varchar NOT NULL,
  leida boolean NOT NULL DEFAULT false,
  solicitud_id uuid NULL REFERENCES solicitudes(id) ON DELETE SET NULL,
  fecha_creacion timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_fecha
  ON notificaciones (usuario_id, fecha_creacion DESC);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_leida
  ON notificaciones (usuario_id, leida);
