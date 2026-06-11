--
-- PostgreSQL database dump
--

\restrict 9lKmO6uJydsEpRrdB1StclaznHTeiT4MOGXBVn5mlcJc195gVw7tGvKEbnvU7Vu

-- Dumped from database version 18.3 (Homebrew)
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: crear_solicitud_completa(uuid, text, uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: henrymarin
--

CREATE FUNCTION public.crear_solicitud_completa(p_solicitante_id uuid, p_solicitante_nombre text, p_linea_id uuid, p_linea_nombre text, p_observaciones text, p_items jsonb) RETURNS TABLE(id uuid)
    LANGUAGE plpgsql
    AS $_$
declare
  v_solicitud_id uuid;
  v_numero text;
  v_correlativo integer;
  v_item jsonb;
  v_precio numeric(12, 4);
  v_cantidad numeric(12, 2);
  v_subtotal numeric(12, 4);
  v_total numeric(12, 4) := 0;
begin
  if jsonb_array_length(p_items) = 0 then
    raise exception 'La solicitud debe tener al menos un item';
  end if;

  select coalesce(max((regexp_match(numero, 'SOL-(\d+)'))[1]::integer), 0) + 1
    into v_correlativo
  from solicitudes
  where numero ~ '^SOL-\d+$';

  v_numero := 'SOL-' || lpad(v_correlativo::text, 4, '0');

  insert into solicitudes (
    numero,
    solicitante_id,
    solicitante_nombre,
    linea_id,
    linea_nombre,
    observaciones,
    estado,
    fecha
  ) values (
    v_numero,
    p_solicitante_id,
    p_solicitante_nombre,
    p_linea_id,
    p_linea_nombre,
    p_observaciones,
    'pendiente',
    now()
  )
  returning solicitudes.id into v_solicitud_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_cantidad := (v_item ->> 'cantidad')::numeric;

    select precio into v_precio
    from precios_material
    where material_id = (v_item ->> 'materialId')::uuid
    order by fecha_vigencia desc
    limit 1;

    if v_precio is null then
      raise exception 'El material % no tiene precio vigente', v_item ->> 'materialNombre';
    end if;

    v_subtotal := v_precio * v_cantidad;
    v_total := v_total + v_subtotal;

    insert into detalle_solicitud (
      solicitud_id,
      material_id,
      material_nombre,
      material_codigo,
      unidad_medida,
      cantidad,
      precio_unitario_momento,
      subtotal
    ) values (
      v_solicitud_id,
      (v_item ->> 'materialId')::uuid,
      v_item ->> 'materialNombre',
      v_item ->> 'materialCodigo',
      v_item ->> 'unidadMedida',
      v_cantidad,
      v_precio,
      v_subtotal
    );
  end loop;

  update solicitudes
  set costo_total = v_total
  where solicitudes.id = v_solicitud_id;

  return query select v_solicitud_id;
end;
$_$;


ALTER FUNCTION public.crear_solicitud_completa(p_solicitante_id uuid, p_solicitante_nombre text, p_linea_id uuid, p_linea_nombre text, p_observaciones text, p_items jsonb) OWNER TO henrymarin;

--
-- Name: marcar_solicitud_entregada(uuid); Type: FUNCTION; Schema: public; Owner: henrymarin
--

CREATE FUNCTION public.marcar_solicitud_entregada(p_solicitud_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_detalle record;
begin
  update solicitudes
  set estado = 'entregada',
      fecha_entrega = now()
  where solicitudes.id = p_solicitud_id
    and estado = 'aprobada';

  if not found then
    raise exception 'Solo se pueden entregar solicitudes aprobadas';
  end if;

  for v_detalle in
    select material_id, cantidad
    from detalle_solicitud
    where solicitud_id = p_solicitud_id
  loop
    update materiales
    set stock_actual = stock_actual - v_detalle.cantidad
    where id = v_detalle.material_id;
  end loop;
end;
$$;


ALTER FUNCTION public.marcar_solicitud_entregada(p_solicitud_id uuid) OWNER TO henrymarin;

--
-- Name: reporte_costo_por_linea(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: henrymarin
--

CREATE FUNCTION public.reporte_costo_por_linea(p_desde timestamp with time zone, p_hasta timestamp with time zone) RETURNS TABLE(linea_nombre text, costo_total numeric)
    LANGUAGE sql STABLE
    AS $$
  select linea_nombre, coalesce(sum(costo_total), 0) as costo_total
  from solicitudes
  where fecha between p_desde and p_hasta
    and estado in ('aprobada', 'entregada')
  group by linea_nombre
  order by costo_total desc;
$$;


ALTER FUNCTION public.reporte_costo_por_linea(p_desde timestamp with time zone, p_hasta timestamp with time zone) OWNER TO henrymarin;

--
-- Name: reporte_top_materiales(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: henrymarin
--

CREATE FUNCTION public.reporte_top_materiales(p_desde timestamp with time zone, p_hasta timestamp with time zone) RETURNS TABLE(material_nombre text, cantidad numeric, costo_total numeric)
    LANGUAGE sql STABLE
    AS $$
  select
    d.material_nombre,
    sum(d.cantidad) as cantidad,
    sum(d.subtotal) as costo_total
  from detalle_solicitud d
  join solicitudes s on s.id = d.solicitud_id
  where s.fecha between p_desde and p_hasta
    and s.estado in ('aprobada', 'entregada')
  group by d.material_nombre
  order by cantidad desc
  limit 10;
$$;


ALTER FUNCTION public.reporte_top_materiales(p_desde timestamp with time zone, p_hasta timestamp with time zone) OWNER TO henrymarin;

--
-- Name: reporte_totales(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: henrymarin
--

CREATE FUNCTION public.reporte_totales(p_desde timestamp with time zone, p_hasta timestamp with time zone) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select jsonb_build_object(
    'solicitudes', count(*),
    'pendientes', count(*) filter (where estado = 'pendiente'),
    'aprobadas', count(*) filter (where estado = 'aprobada'),
    'rechazadas', count(*) filter (where estado = 'rechazada'),
    'entregadas', count(*) filter (where estado = 'entregada'),
    'costo_total', coalesce(sum(costo_total), 0)
  )
  from solicitudes
  where fecha between p_desde and p_hasta;
$$;


ALTER FUNCTION public.reporte_totales(p_desde timestamp with time zone, p_hasta timestamp with time zone) OWNER TO henrymarin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: detalle_consumo_lotes; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.detalle_consumo_lotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    detalle_solicitud_id uuid NOT NULL,
    lote_id uuid NOT NULL,
    cantidad numeric NOT NULL,
    precio_unitario numeric(12,4) NOT NULL,
    subtotal numeric(14,4) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.detalle_consumo_lotes OWNER TO henrymarin;

--
-- Name: detalle_solicitud; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.detalle_solicitud (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    solicitud_id uuid NOT NULL,
    material_id uuid NOT NULL,
    material_nombre text NOT NULL,
    material_codigo text NOT NULL,
    unidad_medida text NOT NULL,
    cantidad numeric(12,2) NOT NULL,
    precio_unitario_momento numeric(12,4) NOT NULL,
    subtotal numeric(12,4) NOT NULL,
    CONSTRAINT detalle_solicitud_cantidad_check CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT detalle_solicitud_precio_unitario_momento_check CHECK ((precio_unitario_momento >= (0)::numeric)),
    CONSTRAINT detalle_solicitud_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE public.detalle_solicitud OWNER TO henrymarin;

--
-- Name: inventario_lotes; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.inventario_lotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_id uuid NOT NULL,
    cantidad_inicial numeric NOT NULL,
    cantidad_disponible numeric NOT NULL,
    precio_unitario numeric(12,4) NOT NULL,
    referencia character varying,
    fecha_entrada timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.inventario_lotes OWNER TO henrymarin;

--
-- Name: linea_produccion_materiales; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.linea_produccion_materiales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    linea_produccion_id uuid NOT NULL,
    material_id uuid NOT NULL,
    cantidad_sugerida numeric DEFAULT 1 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.linea_produccion_materiales OWNER TO henrymarin;

--
-- Name: lineas_produccion; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.lineas_produccion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.lineas_produccion OWNER TO henrymarin;

--
-- Name: materiales; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.materiales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    unidad_medida text NOT NULL,
    categoria text NOT NULL,
    stock_actual numeric(12,2) DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    stock_minimo_alerta numeric DEFAULT 5 NOT NULL,
    costo_promedio numeric(12,4) DEFAULT 0 NOT NULL,
    valor_inventario numeric(14,4) DEFAULT 0 NOT NULL
);


ALTER TABLE public.materiales OWNER TO henrymarin;

--
-- Name: movimientos_inventario; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.movimientos_inventario (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_id uuid NOT NULL,
    material_codigo character varying NOT NULL,
    material_nombre character varying NOT NULL,
    unidad_medida character varying NOT NULL,
    tipo character varying DEFAULT 'entrada_compra'::character varying NOT NULL,
    cantidad numeric NOT NULL,
    precio_unitario numeric(12,4) DEFAULT 0 NOT NULL,
    stock_anterior numeric NOT NULL,
    stock_nuevo numeric NOT NULL,
    registrado_por character varying NOT NULL,
    observaciones character varying,
    fecha timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.movimientos_inventario OWNER TO henrymarin;

--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.notificaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    solicitud_id uuid,
    titulo character varying(150) NOT NULL,
    mensaje text NOT NULL,
    tipo character varying(50) NOT NULL,
    leida boolean DEFAULT false NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.notificaciones OWNER TO henrymarin;

--
-- Name: precios_material; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.precios_material (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_id uuid NOT NULL,
    precio numeric(12,4) NOT NULL,
    fecha_vigencia timestamp with time zone DEFAULT now() NOT NULL,
    registrado_por text NOT NULL,
    CONSTRAINT precios_material_precio_check CHECK ((precio >= (0)::numeric))
);


ALTER TABLE public.precios_material OWNER TO henrymarin;

--
-- Name: produccion_diaria; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.produccion_diaria (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fecha date NOT NULL,
    linea_id uuid NOT NULL,
    linea_nombre character varying NOT NULL,
    cantidad numeric NOT NULL,
    unidad character varying NOT NULL,
    registrado_por character varying NOT NULL,
    observaciones character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.produccion_diaria OWNER TO henrymarin;

--
-- Name: solicitudes; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.solicitudes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    numero text NOT NULL,
    solicitante_id uuid NOT NULL,
    solicitante_nombre text NOT NULL,
    linea_id uuid NOT NULL,
    linea_nombre text NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    costo_total numeric(12,4) DEFAULT 0 NOT NULL,
    observaciones text,
    aprobado_por text,
    fecha_aprobacion timestamp with time zone,
    fecha_entrega timestamp with time zone,
    origen character varying DEFAULT 'operario'::character varying NOT NULL,
    CONSTRAINT solicitudes_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'aprobada'::text, 'rechazada'::text, 'entregada'::text])))
);


ALTER TABLE public.solicitudes OWNER TO henrymarin;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: henrymarin
--

CREATE TABLE public.usuarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    email text NOT NULL,
    rol text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    password_hash text,
    CONSTRAINT usuarios_rol_check CHECK ((rol = ANY (ARRAY['admin'::text, 'coordinador'::text, 'operario'::text, 'bodeguero'::text])))
);


ALTER TABLE public.usuarios OWNER TO henrymarin;

--
-- Name: vista_materiales_precio_actual; Type: VIEW; Schema: public; Owner: henrymarin
--

CREATE VIEW public.vista_materiales_precio_actual AS
 SELECT m.id,
    m.codigo,
    m.nombre,
    m.unidad_medida,
    m.categoria,
    m.stock_actual,
    m.activo,
    pm.precio AS precio_actual,
    pm.fecha_vigencia AS precio_fecha_vigencia
   FROM (public.materiales m
     LEFT JOIN LATERAL ( SELECT precios_material.precio,
            precios_material.fecha_vigencia
           FROM public.precios_material
          WHERE (precios_material.material_id = m.id)
          ORDER BY precios_material.fecha_vigencia DESC
         LIMIT 1) pm ON (true));


ALTER VIEW public.vista_materiales_precio_actual OWNER TO henrymarin;

--
-- Name: vista_solicitudes_detalle; Type: VIEW; Schema: public; Owner: henrymarin
--

CREATE VIEW public.vista_solicitudes_detalle AS
SELECT
    NULL::uuid AS id,
    NULL::text AS numero,
    NULL::uuid AS solicitante_id,
    NULL::text AS solicitante_nombre,
    NULL::uuid AS linea_id,
    NULL::text AS linea_nombre,
    NULL::timestamp with time zone AS fecha,
    NULL::text AS estado,
    NULL::numeric(12,4) AS costo_total,
    NULL::text AS observaciones,
    NULL::text AS aprobado_por,
    NULL::timestamp with time zone AS fecha_aprobacion,
    NULL::timestamp with time zone AS fecha_entrega,
    NULL::jsonb AS detalles;


ALTER VIEW public.vista_solicitudes_detalle OWNER TO henrymarin;

--
-- Data for Name: detalle_consumo_lotes; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.detalle_consumo_lotes (id, detalle_solicitud_id, lote_id, cantidad, precio_unitario, subtotal, created_at) FROM stdin;
5d3bea24-af73-449e-9e11-ec12fceef8e8	575fe9e5-88f8-406d-b288-21df0699bfbd	c94909c5-a99b-4a9f-9ae0-bbfd9f21fb9d	1	3.5000	3.5000	2026-06-10 18:33:37.944001-05
477a8898-5ffe-4203-bb13-be7c390ab0d4	8f0b6ee7-d9c2-461f-bd6f-72f212483369	78fa6275-6596-4c34-aadb-6de1aebb3595	2	3.0000	6.0000	2026-06-10 18:33:37.944001-05
35fb354c-bc40-4f5d-9019-8b7783b25b0f	0506e526-a30a-4285-9c69-67fb14fca083	c96147d1-5b22-4a1e-9ba8-e3200b90cca6	6	1.2000	7.2000	2026-06-10 18:33:37.944001-05
cdc907ed-6b4a-4665-b1cb-47e471761b10	0506e526-a30a-4285-9c69-67fb14fca083	df8e6d9a-b083-4b0d-b5db-90e6b3e7c79f	14	1.5000	21.0000	2026-06-10 18:33:37.944001-05
9476cf15-7813-4fbe-91e7-8261aceab38e	d61179e4-2e4d-42b5-9a25-bdcf1658b4b6	b0b9b550-5772-4e95-8bcd-1309ca5cbfef	4	21.0000	84.0000	2026-06-10 18:33:37.944001-05
c8ad927e-e1b9-4911-aaed-593f6abd5e5c	d61179e4-2e4d-42b5-9a25-bdcf1658b4b6	5c0a7e23-4a51-49a8-b0f6-5de9e962ab18	4	20.0000	80.0000	2026-06-10 18:33:37.944001-05
d01aeb45-20bf-4a91-83b1-deeddd3effc0	023793a3-27ad-4e7c-8571-e7b748d0c0fb	65753497-8505-4ebd-86f8-5c40a88d3acc	2	1.2000	2.4000	2026-06-10 18:33:37.944001-05
45bc7bc5-0132-4d7c-90ea-1766fa3184bd	ac646f51-a854-44c9-a89d-4ee494a0954a	9aadacb0-cbeb-4f16-9505-72c647ac8780	2	1.5000	3.0000	2026-06-10 18:33:37.944001-05
d2984b0c-296b-4300-a518-623cbceaa650	e9a9c4bf-21d7-4a5a-9468-af4acc3ce27e	30bfd041-9d24-489d-9772-d5f942a452f3	2	13.5000	27.0000	2026-06-10 18:33:37.944001-05
b7ccd9d9-e412-4d30-be17-697f4a936b90	fb8f7db0-6f06-4d86-9361-2d83769ee563	7126b1cc-e0c3-4c74-9410-be80cec19f97	3	7.2000	21.6000	2026-06-10 18:33:37.944001-05
a8e35be6-27de-4d8e-b80d-2dce8afe7144	f8787e73-e504-408e-a891-e90997528c89	c2359dec-98f4-445d-a94f-ca7722957766	3	3.2000	9.6000	2026-06-10 18:33:37.944001-05
bd0bef0b-6046-4362-b3ae-0e172e7a93e4	3945efd7-4eb5-42cb-bdb9-a7a2fe000802	d850c9b9-c601-4cae-8f68-279280913da1	2	4.8000	9.6000	2026-06-10 18:33:37.944001-05
221759a7-3f03-4c1f-90d5-27925a285679	2346befe-e726-4fae-8ce7-5795c7ec66c0	125ffbdf-e748-4ae8-aa77-34ae41dfde53	2	0.3000	0.6000	2026-06-10 18:33:37.944001-05
\.


--
-- Data for Name: detalle_solicitud; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.detalle_solicitud (id, solicitud_id, material_id, material_nombre, material_codigo, unidad_medida, cantidad, precio_unitario_momento, subtotal) FROM stdin;
67ef35a9-1e13-4a37-ad1b-2410169fd461	df1b4e82-07a6-4036-9618-5b83171c36c5	02c0f97b-7439-4f07-9038-e23030d1e19a	FUNDENTE	M-MAPI-009	kg	25.00	2.8000	70.0000
5f11b3bb-a9b8-49a5-a999-46c5bc38a77f	df1b4e82-07a6-4036-9618-5b83171c36c5	bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	GRANALLA	M-MAPI-011	kg	30.00	1.9500	58.5000
689ed41a-c02c-4b08-ae46-d981bea5bc98	df1b4e82-07a6-4036-9618-5b83171c36c5	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	12.00	1.2000	14.4000
c76c948f-8ddd-4af2-92d5-983b2ecc1207	2ff6aec1-e006-46ba-a6cc-3e8f4ea663cd	7630dcc6-0eb0-48ea-b017-17991a569904	TEFLON	M-MAPI-064	unidad	20.00	0.3000	6.0000
724e161e-866d-44f0-b612-cf6b72082381	2ff6aec1-e006-46ba-a6cc-3e8f4ea663cd	652a95d4-7b9e-4d9e-9dd4-8af95653127d	DISCO DE LIJA DE 4 PULGADAS	M-MAPI-050	unidad	15.00	0.8500	12.7500
e108daef-8d64-472a-b270-e1d7c9678a2e	2ff6aec1-e006-46ba-a6cc-3e8f4ea663cd	63db3445-d5ae-4baa-a442-3a40e5139c8a	PINTURA AZUL DURAGAS	M-MAPI-057	galon	4.00	14.0000	56.0000
063c9523-49b0-49cc-b193-0f56acdb1a76	941b6fe0-a31c-434f-a40f-0a1de50c0c3c	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	FLEJE LC DE 120 X 2 PARA ASAS	M-MAPD-014	kg	40.00	2.1000	84.0000
1e04a0e3-34e4-467f-920f-bc100bac4700	941b6fe0-a31c-434f-a40f-0a1de50c0c3c	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	8.00	1.2000	9.6000
d2e0e89b-a1bb-4384-9437-2832d347c0ca	de05a598-2e51-442d-852c-c8ae2e094c9a	3d02777a-3d19-465c-8ba3-aa25bf918031	FLEJE LC DE 70 X 2 PARA BASES	M-MAPD-015	kg	35.00	1.9500	68.2500
84693482-f4ca-4556-a568-ab542fa14bb6	de05a598-2e51-442d-852c-c8ae2e094c9a	652a95d4-7b9e-4d9e-9dd4-8af95653127d	DISCO DE LIJA DE 4 PULGADAS	M-MAPI-050	unidad	10.00	0.8500	8.5000
610e12c7-58a3-43db-b884-c4ee1c9c23b0	b77012aa-00cf-47d7-921a-2513e97d92ff	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	18.00	8.0000	144.0000
beed4a06-f31c-4978-b7e3-0bea106b75cd	b77012aa-00cf-47d7-921a-2513e97d92ff	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	22.00	5.0000	110.0000
743e6c07-b933-4556-a017-b90cc6a60ed6	b77012aa-00cf-47d7-921a-2513e97d92ff	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	24.00	3.0000	72.0000
48d26412-3082-4279-840f-bedac73401d6	b77012aa-00cf-47d7-921a-2513e97d92ff	02c0f97b-7439-4f07-9038-e23030d1e19a	FUNDENTE	M-MAPI-009	kg	19.00	4.0000	76.0000
ee030f58-d1cf-445a-9db5-fa59b94f19e5	b77012aa-00cf-47d7-921a-2513e97d92ff	bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	GRANALLA	M-MAPI-011	kg	52.00	3.0000	156.0000
48764bf7-ec85-4aa8-a24a-92ce57376bbe	90f5eeff-83ce-43cb-be79-5a7a4858d7a5	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	10.00	8.0000	80.0000
df00f89a-ab6d-4128-b2e3-3e9d20403b01	90f5eeff-83ce-43cb-be79-5a7a4858d7a5	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	16.00	5.0000	80.0000
4fb04d97-082a-40a8-91d7-8a8327530e20	90f5eeff-83ce-43cb-be79-5a7a4858d7a5	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	20.00	3.0000	60.0000
9d74d264-ad9a-49be-865c-0b6f58507b47	90f5eeff-83ce-43cb-be79-5a7a4858d7a5	02c0f97b-7439-4f07-9038-e23030d1e19a	FUNDENTE	M-MAPI-009	kg	12.00	4.0000	48.0000
eba1a576-3f33-4890-bd12-676af297548a	4bafdc09-d60e-4eab-97b5-d64d42a884ff	eb93c6cf-73ee-4b76-818d-60dd884df4c4	ACEITE EN SPRAY WD-40	M-MAPI-069	unidad	1.00	3.5000	3.5000
9dc3da28-a591-4ff0-a3d6-728c47272ad0	4bafdc09-d60e-4eab-97b5-d64d42a884ff	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	1.00	3.0000	3.0000
aa9adf0d-b718-471e-b469-f1817510c67e	4bafdc09-d60e-4eab-97b5-d64d42a884ff	f093b7bb-8e0e-43e8-ac38-16852ac8047e	BOQUILLA DE CONTACTO 0.9 MM	M-MAPI-004	unidad	4.00	1.2000	4.8000
023a7cf3-14de-4236-94e7-8677b13dd10d	4bafdc09-d60e-4eab-97b5-d64d42a884ff	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	1.00	21.0000	21.0000
519b6a8d-e534-45d5-b77a-505a596ec2fb	4bafdc09-d60e-4eab-97b5-d64d42a884ff	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	2.00	1.2000	2.4000
0fd52ccd-5c97-4184-b7d2-2d4be53cacb1	4bafdc09-d60e-4eab-97b5-d64d42a884ff	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	2.00	1.5000	3.0000
97943b87-8f29-4141-907e-572a38e02825	4bafdc09-d60e-4eab-97b5-d64d42a884ff	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	1.00	13.5000	13.5000
8c7b15b6-ee52-42e6-95d3-a22b5af77aba	4bafdc09-d60e-4eab-97b5-d64d42a884ff	cc277369-9b0d-48a6-a365-35c74c5b6063	PINTURA EN POLVO AZUL	M-MAPD-025	kg	1.00	7.2000	7.2000
6a86e29b-6106-4dce-bb90-6c66c724cc26	4bafdc09-d60e-4eab-97b5-d64d42a884ff	a832ba99-f4e0-44e5-b299-e70de5266fba	SILICON TRANSPARENTE	M-MAPI-068	unidad	1.00	3.2000	3.2000
1f49306d-b478-459d-ba8d-2ccdb037bc7b	4bafdc09-d60e-4eab-97b5-d64d42a884ff	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	SUELDA 6011	R-MATL-001	kg	2.00	4.8000	9.6000
a155a2e2-1a1a-4d07-aad2-5a372afba31b	4bafdc09-d60e-4eab-97b5-d64d42a884ff	7630dcc6-0eb0-48ea-b017-17991a569904	TEFLON	M-MAPI-064	unidad	1.00	0.3000	0.3000
52876870-7de7-4bc5-ac8b-0659d145daf4	42d3aae3-0983-4750-b74a-7f16cd6b03e6	c6c92514-ebbb-4edf-ac23-23fc3617e3cd	CARETAS DE ESMERIL	A-SEGU-008	unidad	1.00	22.0000	22.0000
d80f5818-0f3e-4284-adc7-6ed9c2063956	42d3aae3-0983-4750-b74a-7f16cd6b03e6	510bb613-5f3b-431e-b8e8-3367950aae43	GAFAS OSCURAS	A-SEGU-016	unidad	1.00	4.0000	4.0000
0a6d3bec-bc6d-4e90-81ab-e6ec9ecc549a	42d3aae3-0983-4750-b74a-7f16cd6b03e6	7c5c7999-ca3c-4c11-a2b0-d50655898a60	GAFAS TRANSPARENTES	A-SEGU-015	unidad	1.00	3.5000	3.5000
df7ebea7-6ecc-4ecc-8adf-b0d837f563aa	42d3aae3-0983-4750-b74a-7f16cd6b03e6	d2698ef6-a310-4ba4-93ba-8e3a1b2200f9	GUANTE CUERO NARANJA TIPO API	A-SEGU-006	par	1.00	9.5000	9.5000
575fe9e5-88f8-406d-b288-21df0699bfbd	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	eb93c6cf-73ee-4b76-818d-60dd884df4c4	ACEITE EN SPRAY WD-40	M-MAPI-069	unidad	1.00	3.5000	3.5000
8f0b6ee7-d9c2-461f-bd6f-72f212483369	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	2.00	3.0000	6.0000
0506e526-a30a-4285-9c69-67fb14fca083	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	f093b7bb-8e0e-43e8-ac38-16852ac8047e	BOQUILLA DE CONTACTO 0.9 MM	M-MAPI-004	unidad	20.00	1.4100	28.2000
d61179e4-2e4d-42b5-9a25-bdcf1658b4b6	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	8.00	20.5000	164.0000
023793a3-27ad-4e7c-8571-e7b748d0c0fb	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	2.00	1.2000	2.4000
ac646f51-a854-44c9-a89d-4ee494a0954a	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	2.00	1.5000	3.0000
e9a9c4bf-21d7-4a5a-9468-af4acc3ce27e	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	2.00	13.5000	27.0000
fb8f7db0-6f06-4d86-9361-2d83769ee563	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	cc277369-9b0d-48a6-a365-35c74c5b6063	PINTURA EN POLVO AZUL	M-MAPD-025	kg	3.00	7.2000	21.6000
f8787e73-e504-408e-a891-e90997528c89	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	a832ba99-f4e0-44e5-b299-e70de5266fba	SILICON TRANSPARENTE	M-MAPI-068	unidad	3.00	3.2000	9.6000
3945efd7-4eb5-42cb-bdb9-a7a2fe000802	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	SUELDA 6011	R-MATL-001	kg	2.00	4.8000	9.6000
2346befe-e726-4fae-8ce7-5795c7ec66c0	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	7630dcc6-0eb0-48ea-b017-17991a569904	TEFLON	M-MAPI-064	unidad	2.00	0.3000	0.6000
cba226c7-608e-4d18-8130-ffd2950bed2c	5fa6f536-1357-4929-a51b-74219dc0b39e	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	FLEJE LC DE 120 X 2 PARA ASAS	M-MAPD-014	kg	12.00	2.5000	30.0000
b83eb79d-c5e4-4742-878f-2fee0d10cbdb	5fa6f536-1357-4929-a51b-74219dc0b39e	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	4.00	2.5000	10.0000
8ff6072d-2055-416e-873c-0bd975cfccd6	5fa6f536-1357-4929-a51b-74219dc0b39e	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	2.00	3.0000	6.0000
47b35d05-a8aa-47fb-bcb3-58454de4363f	5fa6f536-1357-4929-a51b-74219dc0b39e	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	2.00	18.0000	36.0000
c5e4bfb8-1758-48e7-a67a-67ca4833fc29	ba8c75ec-0254-416d-b065-ca75526d86b4	a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	ALAMBRE DE SUELDA 1.2 MM	M-MAPI-002	kg	2.00	2.5000	5.0000
e58df97d-1c8d-45e6-b9dd-193744403856	b2b4da0c-356f-4b02-9000-573a40e7ad0a	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	5.00	3.0000	15.0000
92443949-5551-4d63-afb8-063546cd61b4	b2b4da0c-356f-4b02-9000-573a40e7ad0a	fc29bad1-e8b4-4133-ab70-177845eb357a	GUANTE NITRILO G40 TALLA 8	A-SEGU-002	par	3.00	4.5000	13.5000
de87b748-5d7d-4a16-9bd7-f5eb82a054f1	0c824fc8-2107-4932-99bd-6a0126ddbd10	fc29bad1-e8b4-4133-ab70-177845eb357a	GUANTE NITRILO G40 TALLA 8	A-SEGU-002	par	2.00	4.5000	9.0000
fdeffa77-fda7-4610-8e50-d17495ec4ee3	0c824fc8-2107-4932-99bd-6a0126ddbd10	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	2.00	2.5000	5.0000
b2350435-6a20-44d0-b82c-f0e8b4b5beb1	0c824fc8-2107-4932-99bd-6a0126ddbd10	d20fd6d7-1b7f-49b0-ab27-4a123132a1a0	BOQUILLA DE CONTACTO 1.2 MM	M-MAPI-005	unidad	4.00	3.0000	12.0000
298870e2-6651-497d-9c59-08a35490f7ee	0c824fc8-2107-4932-99bd-6a0126ddbd10	3d02777a-3d19-465c-8ba3-aa25bf918031	FLEJE LC DE 70 X 2 PARA BASES	M-MAPD-015	kg	11.00	2.5000	27.5000
9d376615-dc9c-4e06-bd65-9140b94b5f33	8eb44242-167f-43bc-ae3c-aa0fe3255a26	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	4.00	18.0000	72.0000
077204c6-09d3-444e-9e49-6126c1dc9cef	8eb44242-167f-43bc-ae3c-aa0fe3255a26	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	FLEJE LC DE 120 X 2 PARA ASAS	M-MAPD-014	kg	12.00	2.5000	30.0000
3ddef27c-126b-4952-ab63-33b61ea6f13b	8eb44242-167f-43bc-ae3c-aa0fe3255a26	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	6.00	3.0000	18.0000
0aed3854-aec9-4068-b670-9475a5d2df55	356b2609-d0a4-42d8-bded-b46a31d72b2e	a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	ALAMBRE DE SUELDA 1.2 MM	M-MAPI-002	kg	3.00	2.5000	7.5000
9da24280-47ac-4ddd-a08f-c00c700f242d	356b2609-d0a4-42d8-bded-b46a31d72b2e	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	1.00	3.0000	3.0000
1fcb6570-d78c-45bf-8590-637cd5f4e8a7	79c4e646-48a2-4f70-8083-18ff3f0235eb	3d02777a-3d19-465c-8ba3-aa25bf918031	FLEJE LC DE 70 X 2 PARA BASES	M-MAPD-015	kg	10.00	2.5000	25.0000
dc9fc737-62b4-4fa8-a38d-b74e2a3940e2	79c4e646-48a2-4f70-8083-18ff3f0235eb	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	8.00	3.0000	24.0000
38e3ad28-d2fb-413a-8646-a565ac887fd5	79c4e646-48a2-4f70-8083-18ff3f0235eb	f093b7bb-8e0e-43e8-ac38-16852ac8047e	BOQUILLA DE CONTACTO 0.9 MM	M-MAPI-004	unidad	4.00	3.0000	12.0000
7ffc5a8f-622e-4966-9b94-dabffd6ca765	cc9dcb32-57e6-4000-b4e6-996831b76cc5	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	1.00	3.0000	3.0000
a7f61df8-fd11-447f-9680-1cb77f41d8dd	cc9dcb32-57e6-4000-b4e6-996831b76cc5	f093b7bb-8e0e-43e8-ac38-16852ac8047e	BOQUILLA DE CONTACTO 0.9 MM	M-MAPI-004	unidad	4.00	1.2000	4.8000
ab57403d-7d99-4a84-965b-6427b5ae5c55	cc9dcb32-57e6-4000-b4e6-996831b76cc5	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	1.00	21.0000	21.0000
181d844c-ce98-4971-9d15-bec425c6dbfe	cc9dcb32-57e6-4000-b4e6-996831b76cc5	d5a1dc92-29b3-4c33-8b98-05d0209c1b49	ANILLO DIFUSOR	M-MAPI-045	unidad	1.00	1.8000	1.8000
2c59d017-4123-4ac7-bf0e-202fee7cdbb5	cc9dcb32-57e6-4000-b4e6-996831b76cc5	14362e48-7ade-4492-949f-fe80ed42dfde	TOBERA	M-MAPI-016	unidad	1.00	4.2000	4.2000
a2c1b675-3675-4965-91e2-6dfc9ea6d179	cc9dcb32-57e6-4000-b4e6-996831b76cc5	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	2.00	1.2000	2.4000
727057c3-57bb-40b7-ae34-31e019880611	cc9dcb32-57e6-4000-b4e6-996831b76cc5	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	2.00	1.5000	3.0000
6ae45cdd-05cd-451c-8877-100c3f11aa79	cc9dcb32-57e6-4000-b4e6-996831b76cc5	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	CEPILLO DE BRONCE 1/4	M-MAPI-061	unidad	1.00	2.8000	2.8000
969e49ba-b9fe-47e4-8901-1a5fa23a6323	cc9dcb32-57e6-4000-b4e6-996831b76cc5	1647111b-2f79-4796-9e09-54f98970e95b	RETENEDOR M14	M-MAPI-077	unidad	1.00	1.1000	1.1000
02264a73-d61c-4766-b984-3540575a117f	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	1.00	3.0000	3.0000
65f05d3b-d94f-47de-8f48-dd55c2c50a08	42f84c1f-ee73-44f0-9af2-8c52ea735390	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	12.00	8.0000	96.0000
b6bb0eb5-785f-48fa-becb-37fae3fc7e0c	42f84c1f-ee73-44f0-9af2-8c52ea735390	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	18.00	5.0000	90.0000
8b82201b-d8e7-4099-99f8-aebfc1c1f7f4	42f84c1f-ee73-44f0-9af2-8c52ea735390	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	20.00	3.0000	60.0000
8c83b514-c353-4a75-8e69-0a2053fefed4	42f84c1f-ee73-44f0-9af2-8c52ea735390	02c0f97b-7439-4f07-9038-e23030d1e19a	FUNDENTE	M-MAPI-009	kg	15.00	4.0000	60.0000
42da94b9-d6ff-4aa9-b944-9549b94d86fb	42f84c1f-ee73-44f0-9af2-8c52ea735390	bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	GRANALLA	M-MAPI-011	kg	38.00	3.0000	114.0000
ac9235a2-978c-49a8-8d79-288d3f8878e2	414fe3fe-ba37-4389-b2c4-5754e749f783	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	8.00	8.0000	64.0000
e927ec43-497c-43a3-8308-b80d4722a199	414fe3fe-ba37-4389-b2c4-5754e749f783	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	12.00	5.0000	60.0000
c9ac2402-a19b-4349-96ee-3bf47ea6e667	414fe3fe-ba37-4389-b2c4-5754e749f783	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	18.00	3.0000	54.0000
4e48b396-af2c-4821-880c-b5606bed2b6a	414fe3fe-ba37-4389-b2c4-5754e749f783	02c0f97b-7439-4f07-9038-e23030d1e19a	FUNDENTE	M-MAPI-009	kg	10.00	4.0000	40.0000
42eb13df-5105-46d4-b099-9569ea617896	1729b21b-1e80-4775-b051-062ea9bdf13e	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	FLEJE LC DE 120 X 2 PARA ASAS	M-MAPD-014	kg	180.00	0.5000	90.0000
8f09afc9-68c9-4fdc-8916-6b54e0dc1e8b	1729b21b-1e80-4775-b051-062ea9bdf13e	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	10.00	5.0000	50.0000
eaf26095-d999-4151-85b9-8c3d827fa014	1729b21b-1e80-4775-b051-062ea9bdf13e	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	15.00	3.0000	45.0000
0d0b54b1-4caa-4ebb-bccd-61d944028e58	1729b21b-1e80-4775-b051-062ea9bdf13e	9c120e1a-f7de-4866-9f33-37af8a69443e	ALAMBRE DE SUELDA 0.9 MM	M-MAPI-001	kg	15.00	5.0000	75.0000
95a26840-2b09-407a-b2d6-4ee9d9925240	ba366d6d-5fbf-4fa9-a2ae-61273fd10dc9	3d02777a-3d19-465c-8ba3-aa25bf918031	FLEJE LC DE 70 X 2 PARA BASES	M-MAPD-015	kg	150.00	1.2000	180.0000
63c9ebaa-fe78-440c-be47-d850f58199b5	ba366d6d-5fbf-4fa9-a2ae-61273fd10dc9	4ca5983f-1611-4407-befe-2675868b6fea	MASCARILLA N95B PARA SOLDADURA 8515	A-SEGU-035	unidad	14.00	5.0000	70.0000
d1df49b9-8e51-440c-9e5e-47a6d464b158	ba366d6d-5fbf-4fa9-a2ae-61273fd10dc9	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	20.00	3.0000	60.0000
293cae22-704b-46fa-b2ce-55a14e093818	ba366d6d-5fbf-4fa9-a2ae-61273fd10dc9	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	PINTURA AMARILLA DURAGAS	M-MAPD-019	galon	8.75	8.0000	70.0000
05c893ba-9b48-49a6-8db3-427650e57ffb	073297a7-ee7c-43d9-8278-1ddff45ebced	7630dcc6-0eb0-48ea-b017-17991a569904	TEFLON	M-MAPI-064	unidad	15.00	3.0000	45.0000
1dbf2a12-5c80-40b6-bb3c-4b0e37270d3c	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	ALAMBRE DE SUELDA 1.2 MM	M-MAPI-002	kg	1.00	5.2000	5.2000
40488aac-cdf2-4c7b-8343-f3d1d0b3dfcf	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	28c662dc-c232-41b0-a40b-0d77e010d34e	ALAMBRE DE SUELDA SAW 1/8	M-MAPI-003	kg	1.00	6.8000	6.8000
69c70ee9-fce4-46fb-b0e1-52b69be46ae5	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	f093b7bb-8e0e-43e8-ac38-16852ac8047e	BOQUILLA DE CONTACTO 0.9 MM	M-MAPI-004	unidad	4.00	1.5000	6.0000
2706a9af-0c6f-496a-bcf5-3ceb5e6085db	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	CEPILLO DE BRONCE 1/4	M-MAPI-061	unidad	1.00	2.8000	2.8000
1f2ab813-a288-42f3-817e-b54ff3f637d3	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	CO2	M-MAPI-006	unidad	1.00	20.0000	20.0000
40035100-54c4-42f3-a4b8-a74d37de1150	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	bc66b3bc-9a95-4d7b-9183-bd151aa9710c	DIFUSOR	M-MAPI-007	unidad	1.00	3.5000	3.5000
757a0ac6-0479-4403-83ea-8a9512803bc4	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	DISCO DE CORTE DE 4 PULGADAS	M-MAPI-051	unidad	2.00	1.2000	2.4000
b59c5175-9d6f-404f-b66e-de2c4f0aeb6b	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	55d67d8b-389d-49ec-a217-e08b48b2ca77	DISCO DE DESBASTE DE 4 PULGADAS	M-MAPI-052	unidad	2.00	1.5000	3.0000
9d210748-56a1-48e7-bddf-31b2880add38	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	3d02777a-3d19-465c-8ba3-aa25bf918031	FLEJE LC DE 70 X 2 PARA BASES	M-MAPD-015	kg	1.00	1.9500	1.9500
a944eb90-2571-4310-8214-a2ce1825111f	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	1647111b-2f79-4796-9e09-54f98970e95b	RETENEDOR M14	M-MAPI-077	unidad	1.00	1.1000	1.1000
e8fb241b-557a-418d-8594-285925905ecb	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	14362e48-7ade-4492-949f-fe80ed42dfde	TOBERA	M-MAPI-016	unidad	1.00	4.2000	4.2000
\.


--
-- Data for Name: inventario_lotes; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.inventario_lotes (id, material_id, cantidad_inicial, cantidad_disponible, precio_unitario, referencia, fecha_entrada, created_at) FROM stdin;
6e3a7bd4-568d-4f59-8f4d-872d54a735f3	e54c015a-0fb9-42a5-aca1-92b267f8279b	20.00	20.00	5.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
83a91641-0590-4bf1-b574-327d3492257b	ab487064-d5f9-4b7b-b75d-b66f721a663b	80.00	80.00	0.6000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
33018c70-7ad1-4530-b7a9-7da1f90bb1f5	abb6b731-2df8-44f5-9835-7a7ff8354bf7	30.00	30.00	2.1000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
f64162ae-f6b1-47c4-817a-739cb966083e	02c0f97b-7439-4f07-9038-e23030d1e19a	471.00	471.00	2.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
788f4bef-2f61-4bb2-918a-5114972fd0aa	690d7ab3-93c9-49c5-bbfa-088965475fde	100.00	100.00	0.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
3e5b9ce2-c224-441e-9541-cf4fc784e887	e5177991-6e10-4a0c-a5c8-d4c1ac060885	10.00	10.00	6.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
05daaf3d-2067-4a78-b105-909f7a06b95d	1eaf7dda-7564-40a6-8aac-0ab412345c0c	20.00	20.00	8.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
2e71f948-ac0a-4321-ae34-0f890a56e408	3d02777a-3d19-465c-8ba3-aa25bf918031	117.00	117.00	1.9500	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
b8e733bc-5343-4f2d-a483-6619a0383b75	28c662dc-c232-41b0-a40b-0d77e010d34e	60.00	60.00	6.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
c2634226-6711-44cb-ba2e-4687d5b92b27	fa8659f1-ee08-47cd-b313-ead68a9c69a0	10.00	10.00	25.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
4ca1d794-dbdb-4603-8bee-5be04dc0c834	f1e76c71-8f29-43c2-a161-0416264b0de0	15.00	15.00	18.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
681bc328-8483-4dd3-a1ee-80c2e764ed69	0c19bf99-4c17-4079-b52b-e259337c86f6	18.00	18.00	2.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
d548517d-a677-436c-80e8-a1efa936483c	0fc385d9-81a7-4a39-a6a3-fbee835a22d5	20.00	20.00	12.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
15c8baa3-439c-444c-a44f-43ce4dbe7413	a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	54.00	54.00	5.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
61b8afa2-7710-4282-b7e5-6e14b7610149	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	47.00	47.00	2.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
530ef728-04a8-4b3c-9816-a9db87e632d9	d2698ef6-a310-4ba4-93ba-8e3a1b2200f9	28.00	28.00	9.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
514b618b-c339-4120-951c-241618ca671c	c406c468-a7e0-4bec-9fba-353050eccd71	15.00	15.00	15.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
0032b5ea-dec3-4c04-b411-a2edcdda7c80	98e9cc52-96bb-40e1-afd6-69f01f8c62ba	10.00	10.00	15.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
54b03af1-7b48-45a3-bf76-f7b58c31e9bd	d7adb844-b7ff-4221-acb2-44a941c419ed	12.00	12.00	5.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
5bcc344e-0d1c-4025-a7d4-fbe6f8458660	293f8475-dafd-4626-a50c-f4466ba35d53	30.00	30.00	0.9000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
5d43baaf-12fc-498f-a425-0078e779c0e4	f7b236c0-e0ac-4581-9250-43421fc8af7f	50.00	50.00	3.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
aca1899a-0083-49f1-8c08-f430053706a1	c6c92514-ebbb-4edf-ac23-23fc3617e3cd	5.00	5.00	22.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
959fc472-0652-4ab8-9b1e-da1b0423ba5b	63db3445-d5ae-4baa-a442-3a40e5139c8a	23.00	23.00	14.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
b624c896-4f54-4863-9ff1-9085a04757b3	d5a1dc92-29b3-4c33-8b98-05d0209c1b49	36.00	36.00	1.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
6e5a2aba-6da6-4874-8d9b-c882e0a037d7	33c0fe54-7f8b-47b4-8bbd-fac73a2503ea	90.00	90.00	3.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
23b08ac4-298e-47b2-a9fc-9eb12e1d603a	1a150db7-1299-41fc-99eb-ce80b7cd250e	40.00	40.00	1.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
89cac7ee-a915-49e6-bf37-582492a9d760	3676bbc2-b054-45f9-9224-c7e52193ec03	20.00	20.00	12.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
aba5fdc2-20df-4ddb-9c4a-a4e8e03a1172	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	141.00	141.00	2.1000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
958d4ae0-8a3e-4881-8764-da36aa79a696	1d375542-56d9-42df-851a-74af1425ec8f	10.00	10.00	4.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
d1468670-bbcf-403f-94ee-5ab27ec13d25	4d740d92-60e2-4806-9c3b-2ac3cd6cdfb6	60.00	60.00	1.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
6e1cd795-4148-47a1-8863-bae4b05e62ec	3e7876f2-1083-4d32-9eb9-1d24605b492c	11.00	11.00	18.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
65dda7ed-92db-4a04-84a9-1611031fe58e	2532e477-6397-46e0-8209-1ceb949c24ce	15.00	15.00	5.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
9e109a37-c11e-498d-a4a9-f85e150b01b2	0428139f-2d39-4bfd-9464-e3e1048baf9f	100.00	100.00	2.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
c33f89f8-0fb1-474a-b2de-968521ac0d71	510bb613-5f3b-431e-b8e8-3367950aae43	15.00	15.00	4.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
4f250cae-20c4-450e-9da6-b96f92c8f243	ac3af26a-20ee-4a8c-99a9-2ee80060f1a0	25.00	25.00	7.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
187b0330-a038-4813-8de8-b2341fb2cc21	ec5cc9ca-406f-4f65-af35-c6c15d31162f	15.00	15.00	20.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
f6eae903-64f0-4466-a4ca-65cc9e550cfc	7c5c7999-ca3c-4c11-a2b0-d50655898a60	27.00	27.00	3.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
4160bf97-5f6b-4928-a6d8-550a24919971	408c1629-ed6c-4ce9-9d37-173c4db6ba31	10.00	10.00	18.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
da01aa35-5d3a-412a-9b49-c6eed8b2ab68	06105932-3a6d-4f0b-a464-cbadf502dd12	50.00	50.00	3.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
6a815ccd-9289-4034-9ef4-700744404d05	73d9c58d-e229-4f86-9d7e-d6fb3f50eac4	100.00	100.00	0.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
835d4a30-44d9-4bac-a8c9-f83610ffab43	652a95d4-7b9e-4d9e-9dd4-8af95653127d	179.00	179.00	0.8500	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
49fd3373-f39d-4867-a152-8ac2731876a6	f704747c-e261-49c8-8f2d-1b06fc7fef04	20.00	20.00	8.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
80da9606-c958-4d5e-bff0-1adb137372b4	bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	935.00	935.00	1.9500	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
4e30df5d-1634-4e86-8374-72487993ef3d	3d4958bf-6d76-490b-a6cd-6682487b11aa	13.00	13.00	38.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
b2253b20-7f25-4896-8786-b5cf68b11ccb	8da8d572-404d-42b9-abc7-72312318236d	20.00	20.00	15.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
fc062978-bccd-4db0-98fb-24bdd4868247	ff1862f5-2a46-4fc3-a2fa-fc0a701a39ff	15.00	15.00	18.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
718b566d-37a8-4e1c-9c2f-3787abf9f7d9	fc29bad1-e8b4-4133-ab70-177845eb357a	9.00	9.00	8.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
3cab0921-8fae-4d14-b66e-175ca7360ba7	f74e3bb2-24df-48e6-87c7-4a8b38881817	60.00	60.00	7.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
b714ae05-161b-406a-87e2-142c4812faa9	1647111b-2f79-4796-9e09-54f98970e95b	57.00	57.00	1.1000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
345a1222-9aeb-44f0-bb34-b64ac8365064	bbb57a51-ecce-41d1-9f7e-8fedea8bda40	15.00	15.00	8.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
565655d9-4bd9-40e1-9361-3e9e8dfefb0f	bc66b3bc-9a95-4d7b-9183-bd151aa9710c	30.00	30.00	3.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
9acdd1ee-b5f6-4777-b6fb-ae272d5563de	d20fd6d7-1b7f-49b0-ab27-4a123132a1a0	10.00	10.00	1.3500	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
e3c95864-617b-4d88-89c9-cb8c3b1a14e6	14362e48-7ade-4492-949f-fe80ed42dfde	22.00	22.00	4.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
0e67f362-f4d6-4d93-9df8-0f625babfc76	b4c19ec6-3e76-430d-8705-222aaca9ce4b	30.00	30.00	1.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
b3efa482-4b92-4157-8398-eb8eb08849b8	c36ccf4c-8acb-4eb3-bfa8-9842659db9b5	30.00	30.00	2.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
bcaa6cb7-bddf-40fa-85c3-ce122e7ee244	4ca5983f-1611-4407-befe-2675868b6fea	50.00	50.00	1.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
16c105f0-9381-4700-add0-b271dc1f6c56	e2ebbe5b-0b4e-4330-89ee-6d87c730190d	50.00	50.00	0.4000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
c94909c5-a99b-4a9f-9ae0-bbfd9f21fb9d	eb93c6cf-73ee-4b76-818d-60dd884df4c4	15.00	14	3.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
78fa6275-6596-4c34-aadb-6de1aebb3595	9c120e1a-f7de-4866-9f33-37af8a69443e	86.00	84	3.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
c96147d1-5b22-4a1e-9ba8-e3200b90cca6	f093b7bb-8e0e-43e8-ac38-16852ac8047e	6.00	0	1.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
df8e6d9a-b083-4b0d-b5db-90e6b3e7c79f	f093b7bb-8e0e-43e8-ac38-16852ac8047e	20	6	1.5000	Ingreso 6cc56675-face-4aa3-91c2-53d8b37026c6	2026-06-10 18:31:45.449674-05	2026-06-10 18:31:45.449674-05
b0b9b550-5772-4e95-8bcd-1309ca5cbfef	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	4.00	0	21.0000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
5c0a7e23-4a51-49a8-b0f6-5de9e962ab18	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	20	16	20.0000	Ingreso daff9c9a-b6dd-4fa5-b0c8-3207c779546a	2026-06-10 18:32:06.761149-05	2026-06-10 18:32:06.761149-05
65753497-8505-4ebd-86f8-5c40a88d3acc	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	245.00	243	1.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
9aadacb0-cbeb-4f16-9505-72c647ac8780	55d67d8b-389d-49ec-a217-e08b48b2ca77	163.00	161	1.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
30bfd041-9d24-489d-9772-d5f942a452f3	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	43.00	41	13.5000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
7126b1cc-e0c3-4c74-9410-be80cec19f97	cc277369-9b0d-48a6-a365-35c74c5b6063	79.00	76	7.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
c2359dec-98f4-445d-a94f-ca7722957766	a832ba99-f4e0-44e5-b299-e70de5266fba	29.00	26	3.2000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
d850c9b9-c601-4cae-8f68-279280913da1	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	17.00	15	4.8000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
125ffbdf-e748-4ae8-aa77-34ae41dfde53	7630dcc6-0eb0-48ea-b017-17991a569904	184.00	182	0.3000	Saldo inicial migrado a FIFO	2026-06-10 10:23:32.942948-05	2026-06-10 10:23:32.942948-05
\.


--
-- Data for Name: linea_produccion_materiales; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.linea_produccion_materiales (id, linea_produccion_id, material_id, cantidad_sugerida, activo, created_at) FROM stdin;
d144913c-5b8f-4c54-a01a-21c15706cffa	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	1	t	2026-06-09 21:55:40.1172-05
b491b5c8-70df-4660-9012-3df32518d088	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	cc277369-9b0d-48a6-a365-35c74c5b6063	1	t	2026-06-09 21:55:40.1172-05
60e8d130-0f99-4580-b10a-f1ee45aedbe8	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	9c120e1a-f7de-4866-9f33-37af8a69443e	1	t	2026-06-09 21:55:40.1172-05
b7ed65d9-5fb6-4bfd-a1b4-40e8d09ec2d5	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	f093b7bb-8e0e-43e8-ac38-16852ac8047e	4	t	2026-06-09 21:55:40.1172-05
1eb7fc83-6157-4156-8622-0fd71384b023	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	1	t	2026-06-09 21:55:40.1172-05
c84e1c93-2015-434d-aa40-f3ce3878933d	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	2	t	2026-06-09 21:55:40.1172-05
b343ae62-1818-4063-a103-bdceeff575a1	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	2	t	2026-06-09 21:55:40.1172-05
461881ef-c85a-4a46-9340-30f3fde79f21	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	55d67d8b-389d-49ec-a217-e08b48b2ca77	2	t	2026-06-09 21:55:40.1172-05
cee9acd2-8bd6-48ec-8f49-4a444b23af47	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	7630dcc6-0eb0-48ea-b017-17991a569904	1	t	2026-06-09 21:55:40.1172-05
386f1f1c-3be8-4e64-93b6-511c7c14dfcf	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	a832ba99-f4e0-44e5-b299-e70de5266fba	1	t	2026-06-09 21:55:40.1172-05
c5832b69-38a3-48b4-8960-844daa6eba4a	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	eb93c6cf-73ee-4b76-818d-60dd884df4c4	1	t	2026-06-09 21:55:40.1172-05
8339a81e-70dd-456a-b855-3d90c6eca01d	09b35c57-bfc1-4130-a020-d97355a16f48	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	1	t	2026-06-09 21:55:40.1172-05
bb7ea1ee-326a-4964-8ad2-c82b97579a3c	09b35c57-bfc1-4130-a020-d97355a16f48	2532e477-6397-46e0-8209-1ceb949c24ce	1	t	2026-06-09 21:55:40.1172-05
0a7bce8d-c69e-48cf-847b-1e2ca29cf947	09b35c57-bfc1-4130-a020-d97355a16f48	06105932-3a6d-4f0b-a464-cbadf502dd12	1	t	2026-06-09 21:55:40.1172-05
b0b40c33-445e-411f-86ee-5e56758745e2	09b35c57-bfc1-4130-a020-d97355a16f48	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	2	t	2026-06-09 21:55:40.1172-05
49ca9ca5-bc9d-47bd-bbbd-d2966715aa99	09b35c57-bfc1-4130-a020-d97355a16f48	55d67d8b-389d-49ec-a217-e08b48b2ca77	2	t	2026-06-09 21:55:40.1172-05
bf38f2f0-9c46-4f96-8db1-5ddadb8d7429	09b35c57-bfc1-4130-a020-d97355a16f48	9c120e1a-f7de-4866-9f33-37af8a69443e	1	t	2026-06-09 21:55:40.1172-05
ab36b010-e14a-48ff-bd4f-c832d1b79350	09b35c57-bfc1-4130-a020-d97355a16f48	f093b7bb-8e0e-43e8-ac38-16852ac8047e	4	t	2026-06-09 21:55:40.1172-05
696fcb22-30ef-469a-b12a-7bfc88417313	09b35c57-bfc1-4130-a020-d97355a16f48	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	1	t	2026-06-09 21:55:40.1172-05
9a69f01f-ab1c-4ed1-abf5-fdf245b728b4	885604ed-9b04-48bd-919a-c76da573e8f6	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	1	t	2026-06-09 21:55:40.1172-05
a44b218a-f7d8-466f-a68e-75c61c88cfb9	885604ed-9b04-48bd-919a-c76da573e8f6	9c120e1a-f7de-4866-9f33-37af8a69443e	1	t	2026-06-09 21:55:40.1172-05
d7c44ffa-ea9b-41c6-aaf9-2b3326af7204	885604ed-9b04-48bd-919a-c76da573e8f6	f093b7bb-8e0e-43e8-ac38-16852ac8047e	4	t	2026-06-09 21:55:40.1172-05
3d9d3e57-baaf-4660-b639-3ef9a17c27f2	885604ed-9b04-48bd-919a-c76da573e8f6	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	1	t	2026-06-09 21:55:40.1172-05
5fe31c5f-5798-4acf-964e-edac754311cf	885604ed-9b04-48bd-919a-c76da573e8f6	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	2	t	2026-06-09 21:55:40.1172-05
c4ee1ed3-468b-4b61-a924-4a17bf327667	885604ed-9b04-48bd-919a-c76da573e8f6	55d67d8b-389d-49ec-a217-e08b48b2ca77	2	t	2026-06-09 21:55:40.1172-05
22da1b1a-edce-4379-8d0d-44053b53089d	885604ed-9b04-48bd-919a-c76da573e8f6	d2698ef6-a310-4ba4-93ba-8e3a1b2200f9	1	t	2026-06-09 21:55:40.1172-05
c5e5a0fa-68c4-4e71-b2a7-9a5f5dd9c962	885604ed-9b04-48bd-919a-c76da573e8f6	3d4958bf-6d76-490b-a6cd-6682487b11aa	1	t	2026-06-09 21:55:40.1172-05
1a025920-e428-4f76-a4d4-c69b405e46ce	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	3d02777a-3d19-465c-8ba3-aa25bf918031	1	t	2026-06-09 21:55:40.1172-05
c78c187b-90f7-4a08-9a51-07ab97152d9e	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	9c120e1a-f7de-4866-9f33-37af8a69443e	1	t	2026-06-09 21:55:40.1172-05
e60c6c48-9c4a-4674-a956-61ee8b03e0b0	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	f093b7bb-8e0e-43e8-ac38-16852ac8047e	4	t	2026-06-09 21:55:40.1172-05
1578b95a-9965-4524-8366-944002702d5c	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	1	t	2026-06-09 21:55:40.1172-05
6bd1b2ed-049b-48b3-80ce-1800ddd79f2a	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	bc66b3bc-9a95-4d7b-9183-bd151aa9710c	1	t	2026-06-09 21:55:40.1172-05
f9a8df10-819c-440e-b2e3-04ca2ee747da	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	14362e48-7ade-4492-949f-fe80ed42dfde	1	t	2026-06-09 21:55:40.1172-05
b63baa05-6046-4e0f-a79a-142d06ed7059	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	2	t	2026-06-09 21:55:40.1172-05
58230d32-1664-4b3b-9035-6ca96da34271	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	55d67d8b-389d-49ec-a217-e08b48b2ca77	2	t	2026-06-09 21:55:40.1172-05
a023c3f6-60d6-4580-a18e-aefb5be7d300	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	1	t	2026-06-09 21:55:40.1172-05
e1ecfcb7-bb30-422a-b26d-101461beb89e	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	1647111b-2f79-4796-9e09-54f98970e95b	1	t	2026-06-09 21:55:40.1172-05
fe47fd95-9f13-4512-ad1b-196a2b4d038a	9e1c4cd7-f253-4c66-b383-23c85a257324	7630dcc6-0eb0-48ea-b017-17991a569904	1	t	2026-06-09 21:55:40.1172-05
7b029c09-d6ae-45e7-b9aa-06290fea4768	9e1c4cd7-f253-4c66-b383-23c85a257324	a832ba99-f4e0-44e5-b299-e70de5266fba	1	t	2026-06-09 21:55:40.1172-05
64c9b00b-5b84-4feb-812c-13d256062e19	9e1c4cd7-f253-4c66-b383-23c85a257324	eb93c6cf-73ee-4b76-818d-60dd884df4c4	1	t	2026-06-09 21:55:40.1172-05
c1fe3db8-10c0-482c-89ee-d22de79286fd	9e1c4cd7-f253-4c66-b383-23c85a257324	d5a1dc92-29b3-4c33-8b98-05d0209c1b49	1	t	2026-06-09 21:55:40.1172-05
86531dc7-d1b6-49ac-8f86-9d07c037b4d2	9e1c4cd7-f253-4c66-b383-23c85a257324	1647111b-2f79-4796-9e09-54f98970e95b	1	t	2026-06-09 21:55:40.1172-05
94e90760-81ae-4c1c-8e1e-3d0015a28408	9e1c4cd7-f253-4c66-b383-23c85a257324	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	1	t	2026-06-09 21:55:40.1172-05
f96bd155-86ed-4ef5-b789-46ec568df349	9e1c4cd7-f253-4c66-b383-23c85a257324	2532e477-6397-46e0-8209-1ceb949c24ce	1	t	2026-06-09 21:55:40.1172-05
460ea710-f082-45ba-8adc-984aab92720a	9e1c4cd7-f253-4c66-b383-23c85a257324	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	1	t	2026-06-09 21:55:40.1172-05
c5b11b4a-da59-4d70-b6b0-b2cfb8ecaf2c	9e1c4cd7-f253-4c66-b383-23c85a257324	55d67d8b-389d-49ec-a217-e08b48b2ca77	1	t	2026-06-09 21:55:40.1172-05
\.


--
-- Data for Name: lineas_produccion; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.lineas_produccion (id, nombre, descripcion, activa) FROM stdin;
b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	Fabricación completa de cilindros de gas de 15kg desde cero	t
09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	Reparación y rehabilitación de cilindros de gas de 15kg	t
885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	Fabricación de asas para cilindros de gas	t
c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	Fabricación de bases para cilindros de gas	t
9e1c4cd7-f253-4c66-b383-23c85a257324	Reparación de Válvulas	Reparación e instalación de válvulas de cilindros	t
\.


--
-- Data for Name: materiales; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.materiales (id, codigo, nombre, unidad_medida, categoria, stock_actual, activo, stock_minimo_alerta, costo_promedio, valor_inventario) FROM stdin;
14362e48-7ade-4492-949f-fe80ed42dfde	M-MAPI-016	TOBERA	unidad	produccion	22.00	t	5	4.2000	92.4000
6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	M-MAPI-061	CEPILLO DE BRONCE 1/4	unidad	produccion	47.00	t	5	2.8000	131.6000
1647111b-2f79-4796-9e09-54f98970e95b	M-MAPI-077	RETENEDOR M14	unidad	produccion	57.00	t	5	1.1000	62.7000
2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	R-MATL-001	SUELDA 6011	kg	mantenimiento	15.00	t	5	4.8000	72.0000
0428139f-2d39-4bfd-9464-e3e1048baf9f	M-MAPI-066	DISCO DE DESBASTE DE 7 PULGADAS	unidad	produccion	100.00	t	5	2.8000	280.0000
0c19bf99-4c17-4079-b52b-e259337c86f6	A-SEGU-044	MASCARILLA MEDIA CARA	unidad	epp	18.00	t	5	2.0000	36.0000
0fc385d9-81a7-4a39-a6a3-fbee835a22d5	M-MAPI-021	CERAMICA AISLANTE PARA EL PLASMA	unidad	produccion	20.00	t	5	12.0000	240.0000
1a150db7-1299-41fc-99eb-ce80b7cd250e	M-MAPI-085	GRATA	unidad	produccion	40.00	t	5	1.2000	48.0000
1d375542-56d9-42df-851a-74af1425ec8f	M-MAPI-008	DISOLVENTE (X GALON / ENVASE 50 GALON)	galon	produccion	10.00	t	5	4.8000	48.0000
1eaf7dda-7564-40a6-8aac-0ab412345c0c	M-MAPI-023	BOQUILLA PARA ELECTRODO EXTENDIDO DEL PLASMA	unidad	produccion	20.00	t	5	8.5000	170.0000
2532e477-6397-46e0-8209-1ceb949c24ce	R-MATL-031	SUELDA 7018	kg	mantenimiento	15.00	t	5	5.5000	82.5000
28c662dc-c232-41b0-a40b-0d77e010d34e	M-MAPI-003	ALAMBRE DE SUELDA SAW 1/8	kg	produccion	60.00	t	5	6.8000	408.0000
293f8475-dafd-4626-a50c-f4466ba35d53	M-MAPI-083	PUNTA DE CONTACTO 1/8 ARCO SUMERGIDO	unidad	produccion	30.00	t	5	0.9000	27.0000
33c0fe54-7f8b-47b4-8bbd-fac73a2503ea	M-MAPI-063	VASTAGO CUELLO CORTO	unidad	produccion	90.00	t	5	3.5000	315.0000
3676bbc2-b054-45f9-9224-c7e52193ec03	A-SEGU-004	GUANTE HYCRON TALLA 8 MASTER NITRILO	par	epp	20.00	t	5	12.0000	240.0000
408c1629-ed6c-4ce9-9d37-173c4db6ba31	A-SEGU-011	POLINAS DE CUERO	par	epp	10.00	t	5	18.0000	180.0000
4ca5983f-1611-4407-befe-2675868b6fea	A-SEGU-035	MASCARILLA N95B PARA SOLDADURA 8515	unidad	epp	50.00	t	5	1.2000	60.0000
4d740d92-60e2-4806-9c3b-2ac3cd6cdfb6	M-MAPI-095	BANDAS DE LIJA	unidad	produccion	60.00	t	5	1.8000	108.0000
510bb613-5f3b-431e-b8e8-3367950aae43	A-SEGU-016	GAFAS OSCURAS	unidad	epp	15.00	t	5	4.0000	60.0000
690d7ab3-93c9-49c5-bbfa-088965475fde	M-MAPI-075	RESORTE	unidad	produccion	100.00	t	5	0.8000	80.0000
a832ba99-f4e0-44e5-b299-e70de5266fba	M-MAPI-068	SILICON TRANSPARENTE	unidad	produccion	26.00	t	5	3.2000	83.2000
7630dcc6-0eb0-48ea-b017-17991a569904	M-MAPI-064	TEFLON	unidad	produccion	182.00	t	5	0.3000	54.6000
d5a1dc92-29b3-4c33-8b98-05d0209c1b49	M-MAPI-045	ANILLO DIFUSOR	unidad	produccion	36.00	t	5	1.8000	64.8000
eb93c6cf-73ee-4b76-818d-60dd884df4c4	M-MAPI-069	ACEITE EN SPRAY WD-40	unidad	produccion	14.00	t	5	3.5000	49.0000
9c120e1a-f7de-4866-9f33-37af8a69443e	M-MAPI-001	ALAMBRE DE SUELDA 0.9 MM	kg	produccion	84.00	t	5	3.0000	252.0000
2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	M-MAPI-006	CO2	unidad	produccion	16.00	t	5	20.0000	320.0000
02c0f97b-7439-4f07-9038-e23030d1e19a	M-MAPI-009	FUNDENTE	kg	produccion	471.00	t	5	2.8000	1318.8000
06105932-3a6d-4f0b-a464-cbadf502dd12	R-MATL-047	CEMENTO DE CONTACTO 1/4	unidad	mantenimiento	50.00	t	5	3.5000	175.0000
3d02777a-3d19-465c-8ba3-aa25bf918031	M-MAPD-015	FLEJE LC DE 70 X 2 PARA BASES	kg	produccion	117.00	t	5	1.9500	228.1500
3d4958bf-6d76-490b-a6cd-6682487b11aa	A-SEGU-025	CARETA DE SUELDA	unidad	epp	13.00	t	5	38.0000	494.0000
3e7876f2-1083-4d32-9eb9-1d24605b492c	A-SEGU-007	PECHERA PARA SOLDAR	unidad	epp	11.00	t	5	18.0000	198.0000
975e6ef0-3de0-41d5-8f63-b5f10c2b1566	M-MAPI-051	DISCO DE CORTE DE 4 PULGADAS	unidad	produccion	243.00	t	5	1.2000	291.6000
63db3445-d5ae-4baa-a442-3a40e5139c8a	M-MAPI-057	PINTURA AZUL DURAGAS	galon	produccion	23.00	t	5	14.0000	322.0000
652a95d4-7b9e-4d9e-9dd4-8af95653127d	M-MAPI-050	DISCO DE LIJA DE 4 PULGADAS	unidad	produccion	179.00	t	5	0.8500	152.1500
73d9c58d-e229-4f86-9d7e-d6fb3f50eac4	A-SEGU-012	TAPONES AUDITIVOS	par	epp	100.00	t	5	0.5000	50.0000
55d67d8b-389d-49ec-a217-e08b48b2ca77	M-MAPI-052	DISCO DE DESBASTE DE 4 PULGADAS	unidad	produccion	161.00	t	5	1.5000	241.5000
61e4b65c-c301-479e-b93a-fae9b3b7eeaf	M-MAPD-019	PINTURA AMARILLA DURAGAS	galon	produccion	41.00	t	5	13.5000	553.5000
7c5c7999-ca3c-4c11-a2b0-d50655898a60	A-SEGU-015	GAFAS TRANSPARENTES	unidad	epp	27.00	t	5	3.5000	94.5000
8da8d572-404d-42b9-abc7-72312318236d	A-SEGU-005	GUANTE SOL-VEX TALLA 9	par	epp	20.00	t	5	15.0000	300.0000
cc277369-9b0d-48a6-a365-35c74c5b6063	M-MAPD-025	PINTURA EN POLVO AZUL	kg	produccion	76.00	t	5	7.2000	547.2000
98e9cc52-96bb-40e1-afd6-69f01f8c62ba	A-SEGU-009	PANTALLA PARA ESMERIL	unidad	epp	10.00	t	5	15.0000	150.0000
a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	M-MAPI-002	ALAMBRE DE SUELDA 1.2 MM	kg	produccion	54.00	t	5	5.2000	280.8000
ab487064-d5f9-4b7b-b75d-b66f721a663b	M-MAPI-076	GUIA PLASTICA	unidad	produccion	80.00	t	5	0.6000	48.0000
abb6b731-2df8-44f5-9835-7a7ff8354bf7	M-MAPI-044	MANTECA	kg	produccion	30.00	t	5	2.1000	63.0000
ac3af26a-20ee-4a8c-99a9-2ee80060f1a0	A-SEGU-003	GUANTE LATEX G40 TALLA 8	par	epp	25.00	t	5	7.2000	180.0000
b4c19ec6-3e76-430d-8705-222aaca9ce4b	A-SEGU-027	VIDRIO TRANSPARENTE	unidad	epp	30.00	t	5	1.8000	54.0000
bbb57a51-ecce-41d1-9f7e-8fedea8bda40	A-SEGU-017	MONOGAFA ANTIEMPANANTE	unidad	epp	15.00	t	5	8.0000	120.0000
bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	M-MAPI-011	GRANALLA	kg	produccion	935.00	t	5	1.9500	1823.2500
bc66b3bc-9a95-4d7b-9183-bd151aa9710c	M-MAPI-007	DIFUSOR	unidad	produccion	30.00	t	5	3.5000	105.0000
c36ccf4c-8acb-4eb3-bfa8-9842659db9b5	A-SEGU-026	VIDRIO OBSCURO	unidad	epp	30.00	t	5	2.5000	75.0000
c406c468-a7e0-4bec-9fba-353050eccd71	M-MAPI-022	DEFLECTOR PARA EL PLASMA	unidad	produccion	15.00	t	5	15.0000	225.0000
c6c92514-ebbb-4edf-ac23-23fc3617e3cd	A-SEGU-008	CARETAS DE ESMERIL	unidad	epp	5.00	t	5	22.0000	110.0000
d20fd6d7-1b7f-49b0-ab27-4a123132a1a0	M-MAPI-005	BOQUILLA DE CONTACTO 1.2 MM	unidad	produccion	10.00	t	5	1.3500	13.5000
d2698ef6-a310-4ba4-93ba-8e3a1b2200f9	A-SEGU-006	GUANTE CUERO NARANJA TIPO API	par	epp	28.00	t	5	9.5000	266.0000
d7adb844-b7ff-4221-acb2-44a941c419ed	A-SEGU-043	TRAJE KALEENGUARD	unidad	epp	12.00	t	5	5.0000	60.0000
e2ebbe5b-0b4e-4330-89ee-6d87c730190d	M-MAPI-074	ESPONJA	unidad	produccion	50.00	t	5	0.4000	20.0000
e5177991-6e10-4a0c-a5c8-d4c1ac060885	M-MAPI-084	DISOLVENTE LACA	galon	produccion	10.00	t	5	6.0000	60.0000
e54c015a-0fb9-42a5-aca1-92b267f8279b	M-MAPI-094	DISOLVENTE DE POLIURETANO	litro	produccion	20.00	t	5	5.5000	110.0000
e863acc3-fa68-4fcf-bef2-9610bf38f8e9	M-MAPD-014	FLEJE LC DE 120 X 2 PARA ASAS	kg	produccion	141.00	t	5	2.1000	296.1000
ec5cc9ca-406f-4f65-af35-c6c15d31162f	A-SEGU-010	MANGAS DE CUERO	par	epp	15.00	t	5	20.0000	300.0000
f1e76c71-8f29-43c2-a161-0416264b0de0	M-MAPI-020	ELECTRODO EXTENDIDO PLASMA	unidad	produccion	15.00	t	5	18.5000	277.5000
f704747c-e261-49c8-8f2d-1b06fc7fef04	M-MAPI-054	RETARDANTE	litro	produccion	20.00	t	5	8.0000	160.0000
f74e3bb2-24df-48e6-87c7-4a8b38881817	M-MAPD-026	PINTURA EN POLVO AMARILLA DURAGAS	kg	produccion	60.00	t	5	7.5000	450.0000
f7b236c0-e0ac-4581-9250-43421fc8af7f	M-MAPI-039	INDURMIG	kg	produccion	50.00	t	5	3.2000	160.0000
fa8659f1-ee08-47cd-b313-ead68a9c69a0	M-MAPI-067	PLASTICO DE EMBALAJE	rollo	produccion	10.00	t	5	25.0000	250.0000
fc29bad1-e8b4-4133-ab70-177845eb357a	A-SEGU-002	GUANTE NITRILO G40 TALLA 8	par	epp	9.00	t	5	8.5000	76.5000
ff1862f5-2a46-4fc3-a2fa-fc0a701a39ff	M-MAPI-093	PINTURA BLANCA AUTOMOTRIZ CON CATALIZADOR	galon	produccion	15.00	t	5	18.0000	270.0000
f093b7bb-8e0e-43e8-ac38-16852ac8047e	M-MAPI-004	BOQUILLA DE CONTACTO 0.9 MM	unidad	produccion	6.00	t	5	1.5000	9.0000
\.


--
-- Data for Name: movimientos_inventario; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.movimientos_inventario (id, material_id, material_codigo, material_nombre, unidad_medida, tipo, cantidad, precio_unitario, stock_anterior, stock_nuevo, registrado_por, observaciones, fecha) FROM stdin;
ce7c762f-8d38-4d89-bf45-3013be7072bf	3d4958bf-6d76-490b-a6cd-6682487b11aa	A-SEGU-025	CARETA DE SUELDA	unidad	entrada_compra	5	35.0000	0	5	Admin TECNERO	na	2026-06-09 14:42:14.458469-05
b089cbca-50e0-4cd3-a701-5c9518164d49	06105932-3a6d-4f0b-a464-cbadf502dd12	R-MATL-047	CEMENTO DE CONTACTO 1/4	unidad	entrada_compra	50	3.5000	0	50	Admin TECNERO	\N	2026-06-09 14:42:47.487431-05
f9b22994-dad3-442b-b729-a71c20e3b901	0c19bf99-4c17-4079-b52b-e259337c86f6	A-SEGU-044	MASCARILLA MEDIA CARA	unidad	entrada_compra	8	2.0000	10	18	Admin TECNERO	\N	2026-06-09 15:15:16.268363-05
1b72ecf0-cafd-41b0-88de-198a85a2c286	d7adb844-b7ff-4221-acb2-44a941c419ed	A-SEGU-043	TRAJE KALEENGUARD	unidad	entrada_compra	2	5.0000	10	12	Admin TECNERO	\N	2026-06-09 15:15:26.791509-05
5c2fdafe-ef40-4242-a713-cff47d618f6f	3d4958bf-6d76-490b-a6cd-6682487b11aa	A-SEGU-025	CARETA DE SUELDA	unidad	entrada_compra	8	38.0000	5	13	Admin TECNERO	ns	2026-06-09 15:15:46.457448-05
5c1f3f88-3586-43ad-b42c-b16a9a422a7a	3e7876f2-1083-4d32-9eb9-1d24605b492c	A-SEGU-007	PECHERA PARA SOLDAR	unidad	entrada_compra	10	18.0000	1	11	Admin TECNERO	\N	2026-06-09 15:49:19.895785-05
bfe02de2-e3a9-4634-80e0-fcc8448d7ad5	9c120e1a-f7de-4866-9f33-37af8a69443e	M-MAPI-001	ALAMBRE DE SUELDA 0.9 MM	kg	salida_produccion	-1	3.0000	88	87	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
5d8d82fb-07b0-4da7-a00a-5d5ee53eb207	f093b7bb-8e0e-43e8-ac38-16852ac8047e	M-MAPI-004	BOQUILLA DE CONTACTO 0.9 MM	unidad	salida_produccion	-4	1.2000	14	10	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
14a179b3-5d3a-49d7-a7e8-e0c2582817d9	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	M-MAPI-006	CO2	unidad	salida_produccion	-1	21.0000	6	5	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
acaa644b-83fc-40b5-9ef5-4e048f5876ba	d5a1dc92-29b3-4c33-8b98-05d0209c1b49	M-MAPI-045	ANILLO DIFUSOR	unidad	salida_produccion	-1	1.8000	37	36	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
5effa043-2dc5-487c-9288-60feaa168590	14362e48-7ade-4492-949f-fe80ed42dfde	M-MAPI-016	TOBERA	unidad	salida_produccion	-1	4.2000	23	22	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
6b8094ec-794d-4311-8079-f9db6ecf1501	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	M-MAPI-051	DISCO DE CORTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.2000	249	247	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
7223a2be-960e-457b-b519-d6febfd18c21	55d67d8b-389d-49ec-a217-e08b48b2ca77	M-MAPI-052	DISCO DE DESBASTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.5000	167	165	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
97b99383-dff5-4379-a7ce-70760f67edce	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	M-MAPI-061	CEPILLO DE BRONCE 1/4	unidad	salida_produccion	-1	2.8000	48	47	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
929200c1-6760-4230-9f27-5674c6135be1	1647111b-2f79-4796-9e09-54f98970e95b	M-MAPI-077	RETENEDOR M14	unidad	salida_produccion	-1	1.1000	58	57	Bodeguero TECNERO	Despacho SOL-2064 - Fabrica Bases	2026-06-09 23:15:39.843751-05
72215c19-91ba-410f-9f27-88b050520649	eb93c6cf-73ee-4b76-818d-60dd884df4c4	M-MAPI-069	ACEITE EN SPRAY WD-40	unidad	salida_produccion	-1	3.5000	16	15	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
3dee198c-a3c6-4752-ad49-397df476e4c6	9c120e1a-f7de-4866-9f33-37af8a69443e	M-MAPI-001	ALAMBRE DE SUELDA 0.9 MM	kg	salida_produccion	-1	3.0000	87	86	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
088ae92f-e78a-4cba-9c5d-56bfd0b27b97	f093b7bb-8e0e-43e8-ac38-16852ac8047e	M-MAPI-004	BOQUILLA DE CONTACTO 0.9 MM	unidad	salida_produccion	-4	1.2000	10	6	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
890fa235-d902-45c3-b89d-b225a3419513	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	M-MAPI-006	CO2	unidad	salida_produccion	-1	21.0000	5	4	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
d84ed52f-dcb2-44be-895f-8832e2bc097e	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	M-MAPI-051	DISCO DE CORTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.2000	247	245	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
002a7ffa-108d-4a0a-af84-db9293547ab6	55d67d8b-389d-49ec-a217-e08b48b2ca77	M-MAPI-052	DISCO DE DESBASTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.5000	165	163	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
1d7ed94f-3918-4f70-a8ed-7344c61d917c	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	M-MAPD-019	PINTURA AMARILLA DURAGAS	galon	salida_produccion	-1	13.5000	44	43	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
323350f5-284e-4205-9064-1e63fda93f48	cc277369-9b0d-48a6-a365-35c74c5b6063	M-MAPD-025	PINTURA EN POLVO AZUL	kg	salida_produccion	-1	7.2000	80	79	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
efe3cd15-fd2f-4456-961a-c6ba29e8b916	a832ba99-f4e0-44e5-b299-e70de5266fba	M-MAPI-068	SILICON TRANSPARENTE	unidad	salida_produccion	-1	3.2000	30	29	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
81602ed6-6648-4e46-a6a5-e2f33608e5cb	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	R-MATL-001	SUELDA 6011	kg	salida_produccion	-2	4.8000	19	17	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
98406477-8431-4be3-a220-da7a823ae8ee	7630dcc6-0eb0-48ea-b017-17991a569904	M-MAPI-064	TEFLON	unidad	salida_produccion	-1	0.3000	185	184	Bodeguero TECNERO	Despacho SOL-2065 - Fabricación de Cilindros	2026-06-10 09:48:30.062867-05
6cc56675-face-4aa3-91c2-53d8b37026c6	f093b7bb-8e0e-43e8-ac38-16852ac8047e	M-MAPI-004	BOQUILLA DE CONTACTO 0.9 MM	unidad	entrada_compra	20	1.5000	6	26	Admin TECNERO	\N	2026-06-10 18:31:45.449674-05
daff9c9a-b6dd-4fa5-b0c8-3207c779546a	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	M-MAPI-006	CO2	unidad	entrada_compra	20	20.0000	4	24	Admin TECNERO	\N	2026-06-10 18:32:06.761149-05
32d2d776-5125-440c-b0b6-31490ad5d209	eb93c6cf-73ee-4b76-818d-60dd884df4c4	M-MAPI-069	ACEITE EN SPRAY WD-40	unidad	salida_produccion	-1	3.5000	15	14	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
ad6397a5-fef2-45e9-b423-9e7a4347142c	9c120e1a-f7de-4866-9f33-37af8a69443e	M-MAPI-001	ALAMBRE DE SUELDA 0.9 MM	kg	salida_produccion	-2	3.0000	86	84	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
0f44028a-e1c3-4891-b883-a64b1d322add	f093b7bb-8e0e-43e8-ac38-16852ac8047e	M-MAPI-004	BOQUILLA DE CONTACTO 0.9 MM	unidad	salida_produccion	-20	1.4100	26	6	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
f21c0810-4bce-4f03-a321-6ed186b6441d	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	M-MAPI-006	CO2	unidad	salida_produccion	-8	20.5000	24	16	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
76443a1f-e169-46c1-93f4-4b84c4906c00	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	M-MAPI-051	DISCO DE CORTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.2000	245	243	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
c084da07-7d84-412e-a23a-b9457cd30072	55d67d8b-389d-49ec-a217-e08b48b2ca77	M-MAPI-052	DISCO DE DESBASTE DE 4 PULGADAS	unidad	salida_produccion	-2	1.5000	163	161	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
313536d7-cabd-480e-ae07-d5137a638eb5	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	M-MAPD-019	PINTURA AMARILLA DURAGAS	galon	salida_produccion	-2	13.5000	43	41	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
6922c6e2-d5a7-4025-80be-9603fce6b87a	cc277369-9b0d-48a6-a365-35c74c5b6063	M-MAPD-025	PINTURA EN POLVO AZUL	kg	salida_produccion	-3	7.2000	79	76	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
2e532041-48e8-48cb-8968-9929a255ea52	a832ba99-f4e0-44e5-b299-e70de5266fba	M-MAPI-068	SILICON TRANSPARENTE	unidad	salida_produccion	-3	3.2000	29	26	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
d5867f39-3209-407b-a150-64b176f20dd6	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	R-MATL-001	SUELDA 6011	kg	salida_produccion	-2	4.8000	17	15	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
446c1645-7a9e-483c-995f-109f322ca2bd	7630dcc6-0eb0-48ea-b017-17991a569904	M-MAPI-064	TEFLON	unidad	salida_produccion	-2	0.3000	184	182	Bodeguero TECNERO	Despacho SOL-2066 - Fabricación de Cilindros	2026-06-10 18:33:37.944001-05
\.


--
-- Data for Name: notificaciones; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.notificaciones (id, usuario_id, solicitud_id, titulo, mensaje, tipo, leida, fecha_creacion) FROM stdin;
07c8188d-e3fa-4d75-b81a-814f0c779df3	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2063 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 21:49:36.107735
7eccb24f-b5ba-424e-8727-2d734ae9bebf	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud aprobada	Tu solicitud SOL-2063 fue aprobada.	SOLICITUD_APROBADA	t	2026-06-08 21:52:56.832782
3b2b4106-e8e4-44e8-8ace-cac4c11db781	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Solicitud aprobada	La solicitud SOL-2063 fue aprobada y está lista para entrega.	SOLICITUD_APROBADA	t	2026-06-08 21:52:56.825049
2c80bf4d-e149-4b7c-a035-6c12df6adb1b	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Solicitud editada	La solicitud SOL-2065 fue modificada por el solicitante. Revisa nuevamente los materiales.	SOLICITUD_EDITADA	t	2026-06-08 22:23:45.65176
10eaaa6f-c134-4494-9d4b-49a9fd98c330	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2065 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 22:23:45.596746
1a74dde4-c516-4b6e-b25f-b0ab2732300c	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2065 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-08 22:23:45.731522
5a304e63-5229-4a1e-8adc-85247827881f	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud aprobada	Tu solicitud SOL-2065 fue aprobada.	SOLICITUD_APROBADA	t	2026-06-08 22:23:45.689485
3d7ac9d7-ebea-4446-8b37-3fb446876ff9	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Solicitud aprobada	La solicitud SOL-2065 fue aprobada y está lista para entrega.	SOLICITUD_APROBADA	t	2026-06-08 22:23:45.687256
6ce363b6-8ee0-4f5f-b99d-02ad99d308e1	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2066 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 22:23:45.845931
f95c24bc-b063-4b57-b3d8-e9d0a14e2adc	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud rechazada	Tu solicitud SOL-2066 fue rechazada. Motivo: Prueba matriz Codex	SOLICITUD_RECHAZADA	t	2026-06-08 22:23:45.902784
6eef9902-e534-4f4c-80e5-f7ffb0a1157f	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2069 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 11:13:37.795224
a251e207-9eba-41ab-8881-37ed94f3095f	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2069 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 11:13:37.791855
0762a189-60b2-4384-97a6-aea837538ccd	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Nueva solicitud para despacho	La solicitud SOL-2069 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-09 11:13:06.51861
a7a415f8-e0ea-42c9-9d01-8a24374f85e5	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2068 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 22:52:17.606471
0af21261-8921-496b-a4db-297f57c3d04f	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2068 para Fabricación de Cilindros.	SOLICITUD_ENTREGADA	t	2026-06-09 12:26:10.538
6bc91e35-fae8-4321-9217-2f7bf302e877	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2068 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 12:26:10.533284
5441b5a4-ca42-49ea-9d8d-d21958266845	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2070 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 12:51:47.334411
1207f0a0-ecf3-436d-8378-689bc95e84a1	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2070 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 12:51:47.337363
21d96b42-dfde-4dbd-8a16-8d1154d61030	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2067 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 22:41:33.93431
c4ed07df-e178-4cb2-83b2-8a878bddd1d6	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2067 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:09:43.800093
ae153a8f-0243-4287-9036-f3c7b0280a6f	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2067 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 13:09:43.802898
ed9b3515-db42-4aca-8424-cd9a30314605	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Nueva solicitud pendiente	La solicitud SOL-2064 fue creada y requiere aprobación.	SOLICITUD_CREADA	t	2026-06-08 22:02:33.487466
608d65df-2092-4fb3-b21d-661e099eeb45	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2064 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:11:18.90872
cc8f2f9b-a236-4cd1-ab19-1d6c00b47de3	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2064 para Fabricación de Cilindros.	SOLICITUD_ENTREGADA	t	2026-06-09 13:11:18.912576
db3cb0c2-f7e8-4c57-b3f4-4c6192b746c1	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Nueva solicitud para despacho	La solicitud SOL-2072 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-09 13:17:19.07282
90a283d1-0ba4-432f-8e6b-ed4063a4d1ce	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Nueva solicitud para despacho	La solicitud SOL-2073 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-09 13:17:47.818475
a903b789-0f6c-447d-890a-783c1b6f0849	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2073 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:18:03.539176
6709eb8c-8629-4538-b3f8-e9b28d4dfacb	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2073 para Fabricación de Cilindros.	SOLICITUD_ENTREGADA	t	2026-06-09 13:18:03.542198
dbf74555-7737-4c62-986a-1c0ca464070a	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2071 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:09:17.519897
6198df8d-f169-4cf6-89c5-21fc7413cd3d	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2071 para Fabrica Asas.	SOLICITUD_ENTREGADA	t	2026-06-09 13:09:17.524224
9975b3f7-2137-4dd9-bbf7-0105caf6ecf7	fa059cf2-2e00-4eda-87b7-9b3df5efc607	\N	Nueva solicitud para despacho	La solicitud SOL-2074 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-09 13:25:01.212678
b0dfc3a2-3db2-4e58-a7a8-7358f7928dd8	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2074 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:25:09.693998
a78f7a82-0423-48c2-89f6-d1cc3d46a12b	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2074 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 13:25:09.697895
3f2f47e3-f34c-468e-b16a-7dc11a8c7090	83538109-2346-428c-aa25-95361ec241d0	\N	Solicitud entregada	Tu solicitud SOL-2075 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 13:26:04.389934
7c8f658a-5113-4aaa-896d-7d7c1ab5e2bd	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	\N	Despacho registrado	Bodega registró el despacho SOL-2075 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 13:26:04.400174
0db4e16d-de69-4c6e-b425-f65b3f23facb	83538109-2346-428c-aa25-95361ec241d0	42d3aae3-0983-4750-b74a-7f16cd6b03e6	Solicitud entregada	Tu solicitud SOL-2063 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 18:41:20.769639
600e8cd8-ddd2-4ec2-afb2-26543ca24d4f	77535c65-c25c-47bc-b2e2-65ab102a06e9	\N	Stock bajo	A-SEGU-008 - CARETAS DE ESMERIL quedó en 5 unidad. Umbral configurado: 5.	STOCK_BAJO	t	2026-06-09 18:41:20.781972
03ec21e2-2453-4ee1-9897-99eaba22507e	83538109-2346-428c-aa25-95361ec241d0	cc9dcb32-57e6-4000-b4e6-996831b76cc5	Solicitud entregada	Tu solicitud SOL-2064 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-09 23:15:39.899852
420088a1-7e0b-481d-8b02-a66a60164a50	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	cc9dcb32-57e6-4000-b4e6-996831b76cc5	Despacho registrado	Bodega registró el despacho SOL-2064 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 23:15:39.904478
34d24316-9b03-4fcf-a312-cea7972344ff	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	42d3aae3-0983-4750-b74a-7f16cd6b03e6	Despacho registrado	Bodega registró el despacho SOL-2063 para Fabrica Bases.	SOLICITUD_ENTREGADA	t	2026-06-09 18:41:20.780282
3d3e471a-7c2d-4639-a1cc-a870ddc25a5c	77535c65-c25c-47bc-b2e2-65ab102a06e9	\N	Stock bajo	M-MAPI-006 - CO2 quedó en 4 unidad. Umbral configurado: 5.	STOCK_BAJO	t	2026-06-10 09:48:30.127942
6d55850e-3342-4152-8d25-b1324b4a4305	77535c65-c25c-47bc-b2e2-65ab102a06e9	\N	Stock bajo	M-MAPI-006 - CO2 quedó en 5 unidad. Umbral configurado: 5.	STOCK_BAJO	t	2026-06-09 23:15:39.9061
d90dedb0-e580-481d-9865-1f1af2397ef2	fa059cf2-2e00-4eda-87b7-9b3df5efc607	4bafdc09-d60e-4eab-97b5-d64d42a884ff	Nueva solicitud para despacho	La solicitud SOL-2065 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-10 09:46:05.377484
7d98d52c-b811-4c4c-a1f7-6f1f1ab60e7e	fa059cf2-2e00-4eda-87b7-9b3df5efc607	cc9dcb32-57e6-4000-b4e6-996831b76cc5	Nueva solicitud para despacho	La solicitud SOL-2064 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-09 20:20:22.117525
65d088c6-ac4f-41a3-9e66-95913a5f881e	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	4bafdc09-d60e-4eab-97b5-d64d42a884ff	Despacho registrado	Bodega registró el despacho SOL-2065 para Fabricación de Cilindros.	SOLICITUD_ENTREGADA	t	2026-06-10 09:48:30.125363
092ab280-d5b2-4552-a3bb-af13db7b6a2d	83538109-2346-428c-aa25-95361ec241d0	4bafdc09-d60e-4eab-97b5-d64d42a884ff	Solicitud entregada	Tu solicitud SOL-2065 fue entregada por bodega.	SOLICITUD_ENTREGADA	t	2026-06-10 09:48:30.121898
f4e9b36a-163f-471c-999b-9d0ba5ca596b	fa059cf2-2e00-4eda-87b7-9b3df5efc607	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	Nueva solicitud para despacho	La solicitud SOL-2066 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	t	2026-06-10 18:30:37.220843
a946dad9-a823-486d-b751-48d39152c2ce	83538109-2346-428c-aa25-95361ec241d0	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	Solicitud entregada	Tu solicitud SOL-2066 fue entregada por bodega.	SOLICITUD_ENTREGADA	f	2026-06-10 18:33:38.060889
1415dc4f-16ec-46e6-a7a4-40915b4d83a1	88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	d33c8ef0-ee51-4889-b0de-16996b2a3a7f	Despacho registrado	Bodega registró el despacho SOL-2066 para Fabricación de Cilindros.	SOLICITUD_ENTREGADA	t	2026-06-10 18:33:38.064845
033ff308-4aa2-42c6-939b-367894150b7e	77535c65-c25c-47bc-b2e2-65ab102a06e9	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	Nueva solicitud para despacho	La solicitud SOL-2067 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	f	2026-06-10 19:03:20.510425
d9fcca82-1102-498f-931e-5d8f61fd220a	fa059cf2-2e00-4eda-87b7-9b3df5efc607	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	Nueva solicitud para despacho	La solicitud SOL-2067 fue creada y está pendiente de despacho en bodega.	SOLICITUD_CREADA	f	2026-06-10 19:03:20.51826
fd16efea-3ccb-45d3-b83a-c5505e8240d0	77535c65-c25c-47bc-b2e2-65ab102a06e9	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	Solicitud rechazada	La solicitud SOL-2067 fue rechazada. Motivo: na	SOLICITUD_RECHAZADA	f	2026-06-10 19:04:14.075524
d2d7117b-d16f-45ab-b7d2-65fca2072759	83538109-2346-428c-aa25-95361ec241d0	5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	Solicitud rechazada	Tu solicitud SOL-2067 fue rechazada. Motivo: na	SOLICITUD_RECHAZADA	f	2026-06-10 19:04:14.077958
\.


--
-- Data for Name: precios_material; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.precios_material (id, material_id, precio, fecha_vigencia, registrado_por) FROM stdin;
a86ba307-8084-4de5-ac8d-17ec161037ab	9c120e1a-f7de-4866-9f33-37af8a69443e	4.6500	2026-06-06 16:02:04.939882-05	Sistema (inicial)
4ff0cf45-72f2-492d-9b78-440a67fb905a	a6d4c7aa-3df2-46b0-a1bb-8c23bd95cef4	5.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e1d8bbf9-5eaa-4189-83e7-184e6ed5aeb0	28c662dc-c232-41b0-a40b-0d77e010d34e	6.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
1f6c41c2-c1d2-4dda-8941-166eee6353d5	f093b7bb-8e0e-43e8-ac38-16852ac8047e	1.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
288c60d0-8cc0-4070-a87e-89dd1b63ef31	d20fd6d7-1b7f-49b0-ab27-4a123132a1a0	1.3500	2026-06-06 16:02:04.939882-05	Sistema (inicial)
97f8f45d-56a1-41ac-a697-169de32f8217	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	21.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e138789d-271d-43ac-874c-0d0f34db90bd	bc66b3bc-9a95-4d7b-9183-bd151aa9710c	3.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
261e0f01-b52d-449e-b060-b3da966b33ee	1d375542-56d9-42df-851a-74af1425ec8f	4.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
8dd63dfd-d623-49b5-ad0a-00a4769d6609	02c0f97b-7439-4f07-9038-e23030d1e19a	2.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
1386a0ed-59c9-4ea2-9e7c-80d3d925eda4	bc1dd2dd-7e4e-40fc-a082-d4a6229e13ce	1.9500	2026-06-06 16:02:04.939882-05	Sistema (inicial)
47a9a731-9cba-477f-a7d5-3ba42b3b85dc	14362e48-7ade-4492-949f-fe80ed42dfde	4.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
ab40f73c-8f92-4bdf-87cf-c189da7d0cc8	f1e76c71-8f29-43c2-a161-0416264b0de0	18.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
d03db776-400b-4501-8922-cc8ae183856d	0fc385d9-81a7-4a39-a6a3-fbee835a22d5	12.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
1cd0f6a7-2355-4607-acc0-8d61a49138b0	c406c468-a7e0-4bec-9fba-353050eccd71	15.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
5155d854-6709-48c4-9c12-fc0e2fc452d0	1eaf7dda-7564-40a6-8aac-0ab412345c0c	8.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
9567daf3-407e-4de8-8e63-b2c9231026ca	f7b236c0-e0ac-4581-9250-43421fc8af7f	3.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
fc3f2eec-2416-458a-88cc-438e97f9f217	abb6b731-2df8-44f5-9835-7a7ff8354bf7	2.1000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
df6b359e-e262-407d-a60c-0e9804cdc1e2	d5a1dc92-29b3-4c33-8b98-05d0209c1b49	1.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
3afb0eee-9c83-4fe8-ba08-9a0fa58e0d97	652a95d4-7b9e-4d9e-9dd4-8af95653127d	0.8500	2026-06-06 16:02:04.939882-05	Sistema (inicial)
88e8be87-ba62-4bff-8af1-766ec959d334	975e6ef0-3de0-41d5-8f63-b5f10c2b1566	1.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e5d5ac14-1a9e-47b5-aca0-affe30c8bd18	55d67d8b-389d-49ec-a217-e08b48b2ca77	1.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
f8963740-3556-464e-8d07-13966d68f1f8	f704747c-e261-49c8-8f2d-1b06fc7fef04	8.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
a9ce194e-d3f4-42e3-9572-a0499a2623b6	63db3445-d5ae-4baa-a442-3a40e5139c8a	14.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e981c5c8-60cf-413c-80de-f43736adb0ed	6a75aecf-18ad-4c6a-b61f-0e6b3c14a9b1	2.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
8deb8310-75be-4eed-b731-4adb2c513640	33c0fe54-7f8b-47b4-8bbd-fac73a2503ea	3.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
7b874101-1141-4049-998e-4aa565e88d2a	7630dcc6-0eb0-48ea-b017-17991a569904	0.3000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
f1bc81c0-1d57-4b11-93db-519f0a29b562	0428139f-2d39-4bfd-9464-e3e1048baf9f	2.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
1f368a4a-b07f-468f-8a89-81b8750fcd65	fa8659f1-ee08-47cd-b313-ead68a9c69a0	25.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
f16a5c07-fd75-4978-959e-ecba9a8fb622	a832ba99-f4e0-44e5-b299-e70de5266fba	3.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
13a10625-f2f9-438e-b217-aa225bd8eeb0	eb93c6cf-73ee-4b76-818d-60dd884df4c4	5.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
2cc4e478-6027-49d9-8423-7748d723fca1	e2ebbe5b-0b4e-4330-89ee-6d87c730190d	0.4000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e8b1bd3c-c14c-414e-a338-88b40cafc030	690d7ab3-93c9-49c5-bbfa-088965475fde	0.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
36b3351b-e74b-464e-a178-382934562635	ab487064-d5f9-4b7b-b75d-b66f721a663b	0.6000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
1dbb3d2c-ae97-4b3f-bd2e-5bdbe81f4a16	1647111b-2f79-4796-9e09-54f98970e95b	1.1000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
79dfc291-b670-4a79-91db-c50cb7cccb55	293f8475-dafd-4626-a50c-f4466ba35d53	0.9000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
3942b992-1db7-450a-b82b-dcb515c53ec3	e5177991-6e10-4a0c-a5c8-d4c1ac060885	6.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
34485444-69ef-4a3a-9795-383d93426ff1	1a150db7-1299-41fc-99eb-ce80b7cd250e	1.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
3c068cd1-a8c2-4045-b814-4bbb4890a379	ff1862f5-2a46-4fc3-a2fa-fc0a701a39ff	18.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
198d03f2-15a1-41d8-a83a-b86e23538ae5	e54c015a-0fb9-42a5-aca1-92b267f8279b	5.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
d71a8945-6bec-4159-ab03-8608091a3d34	4d740d92-60e2-4806-9c3b-2ac3cd6cdfb6	1.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
67333e6d-357e-4eb9-b511-13ef67027964	61e4b65c-c301-479e-b93a-fae9b3b7eeaf	13.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
bed8c9fb-e9af-4900-8bd4-ea9c09959380	cc277369-9b0d-48a6-a365-35c74c5b6063	7.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
2a96b07c-eba1-4822-a878-7d4bcf937c0b	f74e3bb2-24df-48e6-87c7-4a8b38881817	7.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
6a46fd35-4385-4411-a73f-d1699963fb7d	e863acc3-fa68-4fcf-bef2-9610bf38f8e9	2.1000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
0f67970f-ed12-472a-89dd-19683b06af3a	3d02777a-3d19-465c-8ba3-aa25bf918031	1.9500	2026-06-06 16:02:04.939882-05	Sistema (inicial)
39b3abd6-9374-410e-b6a2-a4bbafebefca	fc29bad1-e8b4-4133-ab70-177845eb357a	8.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
7ee98609-f21f-48c5-bcaf-54274e1c6417	ac3af26a-20ee-4a8c-99a9-2ee80060f1a0	7.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
5597bc23-9355-4364-bf5b-36b77c89ea5a	3676bbc2-b054-45f9-9224-c7e52193ec03	12.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
481b8be3-cb14-4d47-a51f-a38cd5173698	8da8d572-404d-42b9-abc7-72312318236d	15.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
a9972634-933d-4688-91af-d9f9182d8470	d2698ef6-a310-4ba4-93ba-8e3a1b2200f9	9.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
de3c45c2-a8ce-4e2f-94f3-fc909e6d4fa8	3e7876f2-1083-4d32-9eb9-1d24605b492c	18.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
3ad9377e-bef9-4e77-ab61-5e6d3d0e33fe	c6c92514-ebbb-4edf-ac23-23fc3617e3cd	22.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
16c215b4-af84-4014-89ae-775b9d767d26	98e9cc52-96bb-40e1-afd6-69f01f8c62ba	15.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
32b1f28e-464a-41e3-8fe5-dac1d8422dd9	ec5cc9ca-406f-4f65-af35-c6c15d31162f	20.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
9f77d9d4-630d-4e61-aa16-e8acc9dfca0a	408c1629-ed6c-4ce9-9d37-173c4db6ba31	18.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
7c12ef6d-d7d7-450f-9b72-e3755fa36989	73d9c58d-e229-4f86-9d7e-d6fb3f50eac4	0.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
010c2a53-84e0-46ce-88ee-2b56846e06b9	7c5c7999-ca3c-4c11-a2b0-d50655898a60	3.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
3a5d07e1-886a-49ee-aadc-596113f40d64	510bb613-5f3b-431e-b8e8-3367950aae43	4.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
7d00f7db-7e19-4c46-b55e-b561a85ae9c3	bbb57a51-ecce-41d1-9f7e-8fedea8bda40	8.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
b88d37e7-bd75-4549-9f17-22a3a335eaa5	3d4958bf-6d76-490b-a6cd-6682487b11aa	35.0000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
60216bc5-9285-452d-8d20-3798975632c2	c36ccf4c-8acb-4eb3-bfa8-9842659db9b5	2.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
858fa7d9-7589-458a-bf98-1adebcb8b53b	b4c19ec6-3e76-430d-8705-222aaca9ce4b	1.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
e2d3e0b6-ce81-448a-b7c1-35467af87176	4ca5983f-1611-4407-befe-2675868b6fea	1.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
30af75ce-c790-4ac6-90aa-26fea93a3c75	2cf4f7e3-8c4f-4b0d-ad18-42d52beeeb77	4.8000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
79241bf6-2e1a-4ce4-b6b4-0ad59213d52d	2532e477-6397-46e0-8209-1ceb949c24ce	5.5000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
4b3fffc0-1f02-4b13-b54c-2aa32ba0a930	06105932-3a6d-4f0b-a464-cbadf502dd12	3.2000	2026-06-06 16:02:04.939882-05	Sistema (inicial)
09fc820b-e415-4831-8548-76bbecbedfda	eb93c6cf-73ee-4b76-818d-60dd884df4c4	1.5000	2026-06-06 18:58:51.153348-05	Admin TECNERO
4508f00f-8ea5-4ec9-ac3b-f0f6f68d5fa5	9c120e1a-f7de-4866-9f33-37af8a69443e	3.0000	2026-06-06 18:58:56.552782-05	Admin TECNERO
c1ff6861-64f9-4e0b-b1a9-b6b398f0f590	eb93c6cf-73ee-4b76-818d-60dd884df4c4	5.0000	2026-06-06 19:12:24.717752-05	Admin TECNERO
1d5441f7-ab92-4b21-8d8d-1d6e9fe56604	06105932-3a6d-4f0b-a464-cbadf502dd12	3.5000	2026-06-09 14:42:47.487431-05	Admin TECNERO
a37e8923-7448-444b-a134-297b48127479	0c19bf99-4c17-4079-b52b-e259337c86f6	2.0000	2026-06-09 15:15:16.268363-05	Admin TECNERO
e8c4db17-10b2-4914-9170-3e696b14c9d3	d7adb844-b7ff-4221-acb2-44a941c419ed	5.0000	2026-06-09 15:15:26.791509-05	Admin TECNERO
22ee3a4f-2f49-4376-a336-5afd02654219	3d4958bf-6d76-490b-a6cd-6682487b11aa	38.0000	2026-06-09 15:15:46.457448-05	Admin TECNERO
ec960a3f-3c2a-4717-aff5-f0c58e6bdd9e	3e7876f2-1083-4d32-9eb9-1d24605b492c	18.0000	2026-06-09 15:50:46.143606-05	Admin TECNERO
ad5b532f-24c3-420c-9ca3-76d7130d6520	3e7876f2-1083-4d32-9eb9-1d24605b492c	18.0000	2026-06-09 15:49:19.895785-05	Admin TECNERO
84f444ba-2b60-4c4d-b90a-0470f4442a23	eb93c6cf-73ee-4b76-818d-60dd884df4c4	3.5000	2026-06-09 23:07:55.67457-05	Corrección demo
95f57429-52dc-4162-8c2d-806a14c9ec85	f093b7bb-8e0e-43e8-ac38-16852ac8047e	1.5000	2026-06-10 18:31:45.449674-05	Admin TECNERO
11230f50-6ce0-45d6-974f-4af63c82fba4	2ac27d67-058e-4ffb-a3e7-b6a14e8d72d5	20.0000	2026-06-10 18:32:06.761149-05	Admin TECNERO
\.


--
-- Data for Name: produccion_diaria; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.produccion_diaria (id, fecha, linea_id, linea_nombre, cantidad, unidad, registrado_por, observaciones, created_at) FROM stdin;
0c838fd6-6c43-47b6-9349-fe5eca37beca	2026-05-18	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
7a768b25-11ec-460a-b005-6c356b56a623	2026-06-04	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
692fc8d0-a47c-4d22-a096-d6dfcd9024c2	2026-05-28	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
f021dcc3-b6a3-49ef-b069-22d63291cef4	2026-05-29	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
cbb3f89b-97aa-48c3-a8e3-f2e507a1dfb4	2026-06-09	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
f4ee9aa7-5b64-4bbf-9687-6bf91bbf292f	2026-04-16	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	40	cilindros reparados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
6025d6b8-b7e4-4452-9a38-e15729203d61	2026-06-03	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	80	asas	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
89db977b-60ac-41a3-9561-ead10c9f1878	2026-04-08	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	30	cilindros fabricados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
6fc62d2f-7761-4129-b559-71d0ffe82f6d	2026-05-05	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	80	asas	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
9d387f33-20c0-430b-a521-f15f59e09b9a	2026-05-29	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	30	cilindros fabricados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
87a6c9c7-2ea4-4914-a824-9f34e19f1c68	2026-05-28	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	30	cilindros fabricados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
242f1969-0e7c-41b5-b549-298bc7b09d50	2026-06-09	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	40	cilindros reparados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
fb813f2c-f9a4-42eb-96ed-a698c9f49730	2026-06-05	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	70	bases	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
3ebfa76f-86c5-439a-a5b4-f15d1b071642	2026-06-02	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	40	cilindros reparados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
225273a0-1e29-45b9-a03a-4d09b05c5718	2026-05-28	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	40	cilindros reparados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
69641b8f-4bcc-4691-83e9-a516aa9c977c	2026-06-01	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	30	cilindros fabricados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
f0a7e1b4-1952-4e66-b0d4-266589e51e4c	2026-05-29	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	80	asas	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
77f9bef8-3254-4d42-b45f-0e31fed512a4	2026-05-28	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	80	asas	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
0fc3f8e1-a95e-4ad6-892c-1262a1e2b787	2026-06-08	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	30	cilindros fabricados	Carga inicial TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
db9af18b-0fb5-4698-99e5-a7b82dd1981d	2026-06-10	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	50	cilindros fabricados	Admin TECNERO	Carga inicial demo para costo unitario	2026-06-10 14:50:20.180766-05
\.


--
-- Data for Name: solicitudes; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.solicitudes (id, numero, solicitante_id, solicitante_nombre, linea_id, linea_nombre, fecha, estado, costo_total, observaciones, aprobado_por, fecha_aprobacion, fecha_entrega, origen) FROM stdin;
df1b4e82-07a6-4036-9618-5b83171c36c5	DEMO-2026-04-001	83538109-2346-428c-aa25-95361ec241d0	Operario Planta	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-04-08 09:15:00-05	entregada	168.5000	Producción lote abril	Coordinador Producción	2026-04-08 10:00:00-05	2026-04-08 11:30:00-05	operario
2ff6aec1-e006-46ba-a6cc-3e8f4ea663cd	DEMO-2026-04-002	83538109-2346-428c-aa25-95361ec241d0	Operario Planta	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	2026-04-16 14:20:00-05	entregada	94.2000	Reparación cilindros devueltos	Coordinador Producción	2026-04-16 15:00:00-05	2026-04-16 16:00:00-05	operario
941b6fe0-a31c-434f-a40f-0a1de50c0c3c	DEMO-2026-05-001	83538109-2346-428c-aa25-95361ec241d0	Operario Planta	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	2026-05-05 08:45:00-05	entregada	121.8000	Fabricación de asas	Coordinador Producción	2026-05-05 09:10:00-05	2026-05-05 10:00:00-05	operario
de05a598-2e51-442d-852c-c8ae2e094c9a	DEMO-2026-05-002	83538109-2346-428c-aa25-95361ec241d0	Operario Planta	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-05-18 11:30:00-05	entregada	88.7500	Fabricación de bases	Coordinador Producción	2026-05-18 12:00:00-05	2026-05-18 13:00:00-05	operario
b77012aa-00cf-47d7-921a-2513e97d92ff	SIM-W2-20260608	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-06-08 08:10:00-05	entregada	558.0000	SIMULACION SETEADA SEMANA ACTUAL - una sola línea trabajada por día - Fabricación de Cilindros	Bodeguero TECNERO	\N	2026-06-08 14:25:00-05	solicitud_planta
90f5eeff-83ce-43cb-be79-5a7a4858d7a5	SIM-W2-20260609	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	2026-06-09 08:10:00-05	entregada	268.0000	SIMULACION SETEADA SEMANA ACTUAL - una sola línea trabajada por día - Reparación	Bodeguero TECNERO	\N	2026-06-09 15:25:00-05	solicitud_planta
4bafdc09-d60e-4eab-97b5-d64d42a884ff	SOL-2065	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-06-10 09:46:05.292559-05	entregada	71.5000	\N	Bodeguero TECNERO	2026-06-10 09:48:30.073-05	2026-06-10 09:48:30.073-05	operario
42d3aae3-0983-4750-b74a-7f16cd6b03e6	SOL-2063	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-06-09 18:41:20.556319-05	entregada	39.0000	Despacho registrado directamente en bodega por Bodeguero TECNERO	Bodeguero TECNERO	2026-06-09 18:41:20.743-05	2026-06-09 18:41:20.743-05	bodega_directo
d33c8ef0-ee51-4889-b0de-16996b2a3a7f	SOL-2066	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-06-10 18:30:37.105204-05	entregada	275.5000	nueva solicitud	Bodeguero TECNERO	2026-06-10 18:33:37.964-05	2026-06-10 18:33:37.964-05	operario
5fa6f536-1357-4929-a51b-74219dc0b39e	SOL-2056	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-05-29 10:07:00-05	entregada	82.0000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-29 10:52:00-05	2026-05-29 13:07:00-05	operario
ba8c75ec-0254-416d-b065-ca75526d86b4	SOL-2057	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	2026-05-29 12:14:00-05	entregada	5.0000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-29 12:59:00-05	2026-05-29 15:14:00-05	operario
b2b4da0c-356f-4b02-9000-573a40e7ad0a	SOL-2058	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-05-29 14:21:00-05	entregada	28.5000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-29 15:06:00-05	2026-05-29 17:21:00-05	operario
0c824fc8-2107-4932-99bd-6a0126ddbd10	SOL-2059	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-05-28 10:07:00-05	entregada	53.5000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-28 10:52:00-05	2026-05-28 13:07:00-05	operario
8eb44242-167f-43bc-ae3c-aa0fe3255a26	SOL-2060	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	2026-05-28 12:14:00-05	entregada	120.0000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-28 12:59:00-05	2026-05-28 15:14:00-05	operario
356b2609-d0a4-42d8-bded-b46a31d72b2e	SOL-2061	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-05-28 14:21:00-05	entregada	10.5000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-28 15:06:00-05	2026-05-28 17:21:00-05	operario
79c4e646-48a2-4f70-8083-18ff3f0235eb	SOL-2062	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	2026-05-28 16:28:00-05	entregada	61.0000	Material entregado durante jornada de producción	Coordinador TECNERO	2026-05-28 17:13:00-05	2026-05-28 19:28:00-05	operario
cc9dcb32-57e6-4000-b4e6-996831b76cc5	SOL-2064	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-06-09 20:20:22.019676-05	entregada	44.1000	\N	Bodeguero TECNERO	2026-06-09 23:15:39.846-05	2026-06-09 23:15:39.846-05	operario
414fe3fe-ba37-4389-b2c4-5754e749f783	SIM-20260602	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	09b35c57-bfc1-4130-a020-d97355a16f48	Reparación	2026-06-02 08:10:00-05	entregada	218.0000	SIMULACION SETEADA - una sola línea trabajada por día - Reparación	Bodeguero TECNERO	\N	2026-06-02 15:25:00-05	solicitud_planta
5ce75d79-3fb3-4395-962a-4dd9ebcd4a0e	SOL-2067	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-06-10 19:03:20.406807-05	rechazada	59.9500	na	Bodeguero TECNERO	2026-06-10 19:04:14.062-05	\N	operario
1729b21b-1e80-4775-b051-062ea9bdf13e	SIM-20260603	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	885604ed-9b04-48bd-919a-c76da573e8f6	Fabrica Asas	2026-06-03 09:10:00-05	entregada	260.0000	SIMULACION SETEADA - una sola línea trabajada por día - Fabrica Asas	Bodeguero TECNERO	\N	2026-06-03 15:25:00-05	solicitud_planta
ba366d6d-5fbf-4fa9-a2ae-61273fd10dc9	SIM-20260604	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-06-04 08:10:00-05	entregada	380.0000	SIMULACION SETEADA - una sola línea trabajada por día - Fabrica Bases	Bodeguero TECNERO	\N	2026-06-04 14:25:00-05	solicitud_planta
073297a7-ee7c-43d9-8278-1ddff45ebced	SIM-20260605	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	c3b33b01-cc5b-4fb3-b603-cae13d9ddf5b	Fabrica Bases	2026-06-05 09:10:00-05	entregada	45.0000	SIMULACION SETEADA - una sola línea trabajada por día - Fabrica Bases	Bodeguero TECNERO	\N	2026-06-05 16:25:00-05	solicitud_planta
42f84c1f-ee73-44f0-9af2-8c52ea735390	SIM-20260601	83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	b46f8786-db75-4dcd-b96f-a41e4f2b3c26	Fabricación de Cilindros	2026-06-01 08:10:00-05	entregada	420.0000	SIMULACION SETEADA - una sola línea trabajada por día - Fabricación de Cilindros	Bodeguero TECNERO	\N	2026-06-01 14:25:00-05	solicitud_planta
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: henrymarin
--

COPY public.usuarios (id, nombre, email, rol, activo, password_hash) FROM stdin;
77535c65-c25c-47bc-b2e2-65ab102a06e9	Admin TECNERO	admin@tecnero.com	admin	t	\N
88ff1e2b-0df9-4bfe-99cc-b2a51c2755fb	Coordinador TECNERO	coord@tecnero.com	coordinador	t	\N
83538109-2346-428c-aa25-95361ec241d0	Operario TECNERO	operario@tecnero.com	operario	t	\N
fa059cf2-2e00-4eda-87b7-9b3df5efc607	Bodeguero TECNERO	bodega@tecnero.com	bodeguero	t	\N
\.


--
-- Name: detalle_consumo_lotes detalle_consumo_lotes_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_consumo_lotes
    ADD CONSTRAINT detalle_consumo_lotes_pkey PRIMARY KEY (id);


--
-- Name: detalle_solicitud detalle_solicitud_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_solicitud
    ADD CONSTRAINT detalle_solicitud_pkey PRIMARY KEY (id);


--
-- Name: inventario_lotes inventario_lotes_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.inventario_lotes
    ADD CONSTRAINT inventario_lotes_pkey PRIMARY KEY (id);


--
-- Name: linea_produccion_materiales linea_produccion_materiales_linea_produccion_id_material_id_key; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.linea_produccion_materiales
    ADD CONSTRAINT linea_produccion_materiales_linea_produccion_id_material_id_key UNIQUE (linea_produccion_id, material_id);


--
-- Name: linea_produccion_materiales linea_produccion_materiales_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.linea_produccion_materiales
    ADD CONSTRAINT linea_produccion_materiales_pkey PRIMARY KEY (id);


--
-- Name: lineas_produccion lineas_produccion_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.lineas_produccion
    ADD CONSTRAINT lineas_produccion_pkey PRIMARY KEY (id);


--
-- Name: materiales materiales_codigo_key; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.materiales
    ADD CONSTRAINT materiales_codigo_key UNIQUE (codigo);


--
-- Name: materiales materiales_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.materiales
    ADD CONSTRAINT materiales_pkey PRIMARY KEY (id);


--
-- Name: movimientos_inventario movimientos_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_pkey PRIMARY KEY (id);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);


--
-- Name: precios_material precios_material_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.precios_material
    ADD CONSTRAINT precios_material_pkey PRIMARY KEY (id);


--
-- Name: produccion_diaria produccion_diaria_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT produccion_diaria_pkey PRIMARY KEY (id);


--
-- Name: solicitudes solicitudes_numero_key; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_numero_key UNIQUE (numero);


--
-- Name: solicitudes solicitudes_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_pkey PRIMARY KEY (id);


--
-- Name: produccion_diaria uq_produccion_diaria_fecha_linea; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT uq_produccion_diaria_fecha_linea UNIQUE (fecha, linea_id);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: idx_detalle_consumo_lotes_detalle; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_detalle_consumo_lotes_detalle ON public.detalle_consumo_lotes USING btree (detalle_solicitud_id);


--
-- Name: idx_detalle_consumo_lotes_lote; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_detalle_consumo_lotes_lote ON public.detalle_consumo_lotes USING btree (lote_id);


--
-- Name: idx_inventario_lotes_material_fifo; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_inventario_lotes_material_fifo ON public.inventario_lotes USING btree (material_id, fecha_entrada, id) WHERE (cantidad_disponible > (0)::numeric);


--
-- Name: idx_linea_materiales_linea; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_linea_materiales_linea ON public.linea_produccion_materiales USING btree (linea_produccion_id, activo);


--
-- Name: idx_linea_materiales_material; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_linea_materiales_material ON public.linea_produccion_materiales USING btree (material_id);


--
-- Name: idx_movimientos_inventario_fecha; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_movimientos_inventario_fecha ON public.movimientos_inventario USING btree (fecha DESC);


--
-- Name: idx_movimientos_inventario_material_fecha; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_movimientos_inventario_material_fecha ON public.movimientos_inventario USING btree (material_id, fecha DESC);


--
-- Name: idx_movimientos_inventario_tipo_fecha; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_movimientos_inventario_tipo_fecha ON public.movimientos_inventario USING btree (tipo, fecha DESC);


--
-- Name: idx_produccion_diaria_fecha; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_produccion_diaria_fecha ON public.produccion_diaria USING btree (fecha DESC);


--
-- Name: idx_produccion_diaria_linea_fecha; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_produccion_diaria_linea_fecha ON public.produccion_diaria USING btree (linea_id, fecha DESC);


--
-- Name: idx_solicitudes_origen; Type: INDEX; Schema: public; Owner: henrymarin
--

CREATE INDEX idx_solicitudes_origen ON public.solicitudes USING btree (origen);


--
-- Name: vista_solicitudes_detalle _RETURN; Type: RULE; Schema: public; Owner: henrymarin
--

CREATE OR REPLACE VIEW public.vista_solicitudes_detalle AS
 SELECT s.id,
    s.numero,
    s.solicitante_id,
    s.solicitante_nombre,
    s.linea_id,
    s.linea_nombre,
    s.fecha,
    s.estado,
    s.costo_total,
    s.observaciones,
    s.aprobado_por,
    s.fecha_aprobacion,
    s.fecha_entrega,
    COALESCE(jsonb_agg(jsonb_build_object('id', d.id, 'solicitud_id', d.solicitud_id, 'material_id', d.material_id, 'material_nombre', d.material_nombre, 'material_codigo', d.material_codigo, 'unidad_medida', d.unidad_medida, 'cantidad', d.cantidad, 'precio_unitario_momento', d.precio_unitario_momento, 'subtotal', d.subtotal) ORDER BY d.material_nombre) FILTER (WHERE (d.id IS NOT NULL)), '[]'::jsonb) AS detalles
   FROM (public.solicitudes s
     LEFT JOIN public.detalle_solicitud d ON ((d.solicitud_id = s.id)))
  GROUP BY s.id;


--
-- Name: detalle_consumo_lotes detalle_consumo_lotes_detalle_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_consumo_lotes
    ADD CONSTRAINT detalle_consumo_lotes_detalle_solicitud_id_fkey FOREIGN KEY (detalle_solicitud_id) REFERENCES public.detalle_solicitud(id) ON DELETE CASCADE;


--
-- Name: detalle_consumo_lotes detalle_consumo_lotes_lote_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_consumo_lotes
    ADD CONSTRAINT detalle_consumo_lotes_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES public.inventario_lotes(id) ON DELETE RESTRICT;


--
-- Name: detalle_solicitud detalle_solicitud_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_solicitud
    ADD CONSTRAINT detalle_solicitud_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materiales(id);


--
-- Name: detalle_solicitud detalle_solicitud_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.detalle_solicitud
    ADD CONSTRAINT detalle_solicitud_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id) ON DELETE CASCADE;


--
-- Name: notificaciones fk_notificaciones_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT fk_notificaciones_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes(id) ON DELETE SET NULL;


--
-- Name: notificaciones fk_notificaciones_usuario; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT fk_notificaciones_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: inventario_lotes inventario_lotes_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.inventario_lotes
    ADD CONSTRAINT inventario_lotes_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materiales(id) ON DELETE RESTRICT;


--
-- Name: linea_produccion_materiales linea_produccion_materiales_linea_produccion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.linea_produccion_materiales
    ADD CONSTRAINT linea_produccion_materiales_linea_produccion_id_fkey FOREIGN KEY (linea_produccion_id) REFERENCES public.lineas_produccion(id) ON DELETE CASCADE;


--
-- Name: linea_produccion_materiales linea_produccion_materiales_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.linea_produccion_materiales
    ADD CONSTRAINT linea_produccion_materiales_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materiales(id) ON DELETE CASCADE;


--
-- Name: movimientos_inventario movimientos_inventario_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materiales(id) ON DELETE RESTRICT;


--
-- Name: precios_material precios_material_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.precios_material
    ADD CONSTRAINT precios_material_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materiales(id);


--
-- Name: produccion_diaria produccion_diaria_linea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT produccion_diaria_linea_id_fkey FOREIGN KEY (linea_id) REFERENCES public.lineas_produccion(id) ON DELETE RESTRICT;


--
-- Name: solicitudes solicitudes_linea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_linea_id_fkey FOREIGN KEY (linea_id) REFERENCES public.lineas_produccion(id);


--
-- Name: solicitudes solicitudes_solicitante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: henrymarin
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES public.usuarios(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 9lKmO6uJydsEpRrdB1StclaznHTeiT4MOGXBVn5mlcJc195gVw7tGvKEbnvU7Vu

