-- SAFRA-C00 — hardening de grants e RLS das tabelas legadas de confiabilidade.
-- Escopo: public.applications e public.incidents.
--
-- IMPORTANTE:
-- 1) Esta é uma política de contenção anterior ao RBAC completo do SAFRA-C04.
-- 2) Antes de aplicar em ambiente live, usuários autorizados devem possuir
--    app_metadata.safra_access = true e o produto deve possuir fluxo de autenticação.
-- 3) Sem essa condição, o acesso via publishable key será negado por desenho.
-- 4) Não reabrir anon como forma de corrigir falha de autenticação.

-- ---------------------------------------------------------------------------
-- 1. Grants: remover acesso anônimo e reduzir privilégios de authenticated.
-- ---------------------------------------------------------------------------

REVOKE ALL PRIVILEGES ON TABLE public.applications FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.incidents FROM anon;

REVOKE ALL PRIVILEGES ON TABLE public.applications FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.incidents FROM authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.applications FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.incidents FROM PUBLIC;

-- Catálogo de aplicações: leitura apenas.
GRANT SELECT ON TABLE public.applications TO authenticated;

-- Incidentes: leitura + abertura + atualização operacional.
GRANT SELECT ON TABLE public.incidents TO authenticated;

GRANT INSERT (
  application_id,
  status,
  detected_at,
  type,
  category
) ON TABLE public.incidents TO authenticated;

GRANT UPDATE (
  failure_started_at,
  response_started_at,
  recovered_at,
  status,
  type,
  category,
  responsible,
  cause,
  resolution,
  notes
) ON TABLE public.incidents TO authenticated;

-- O papel de serviço continua reservado a operações confiáveis server-side.
GRANT ALL PRIVILEGES ON TABLE public.applications TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.incidents TO service_role;

-- ---------------------------------------------------------------------------
-- 2. Garantir RLS habilitada.
-- ---------------------------------------------------------------------------

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3. Remover policies permissivas da baseline.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Aplicacoes abertas para uso interno" ON public.applications;
DROP POLICY IF EXISTS "Incidentes abertos para uso interno" ON public.incidents;

-- Torna a migration idempotente em caso de reaplicação controlada.
DROP POLICY IF EXISTS "safra_c00_applications_select" ON public.applications;
DROP POLICY IF EXISTS "safra_c00_incidents_select" ON public.incidents;
DROP POLICY IF EXISTS "safra_c00_incidents_insert" ON public.incidents;
DROP POLICY IF EXISTS "safra_c00_incidents_update" ON public.incidents;

-- ---------------------------------------------------------------------------
-- 4. RLS transitória real: acesso somente a usuário autenticado, não anônimo,
--    explicitamente autorizado em app_metadata.
--
-- app_metadata é administrado pelo backend/admin e não pode ser alterado pelo
-- próprio usuário, ao contrário de user_metadata.
-- ---------------------------------------------------------------------------

CREATE POLICY "safra_c00_applications_select"
ON public.applications
FOR SELECT
TO authenticated
USING (
  (SELECT auth.uid()) IS NOT NULL
  AND COALESCE((SELECT auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
  AND COALESCE((SELECT auth.jwt() -> 'app_metadata' ->> 'safra_access'), 'false') = 'true'
);

CREATE POLICY "safra_c00_incidents_select"
ON public.incidents
FOR SELECT
TO authenticated
USING (
  (SELECT auth.uid()) IS NOT NULL
  AND COALESCE((SELECT auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
  AND COALESCE((SELECT auth.jwt() -> 'app_metadata' ->> 'safra_access'), 'false') = 'true'
);

CREATE POLICY "safra_c00_incidents_insert"
ON public.incidents
FOR INSERT
TO authenticated
WITH CHECK (
  (SELECT auth.uid()) IS NOT NULL
  AND COALESCE((SELECT auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
  AND COALESCE((SELECT auth.jwt() -> 'app_metadata' ->> 'safra_access'), 'false') = 'true'
);

CREATE POLICY "safra_c00_incidents_update"
ON public.incidents
FOR UPDATE
TO authenticated
USING (
  (SELECT auth.uid()) IS NOT NULL
  AND COALESCE((SELECT auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
  AND COALESCE((SELECT auth.jwt() -> 'app_metadata' ->> 'safra_access'), 'false') = 'true'
)
WITH CHECK (
  (SELECT auth.uid()) IS NOT NULL
  AND COALESCE((SELECT auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
  AND COALESCE((SELECT auth.jwt() -> 'app_metadata' ->> 'safra_access'), 'false') = 'true'
);

-- Não existe policy DELETE para authenticated: exclusão via Data API fica negada.
-- Não existe policy INSERT/UPDATE/DELETE em applications: catálogo fica read-only.
