
CREATE TABLE public.applications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.incidents (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','resolved')),
  failure_started_at TIMESTAMPTZ,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  response_started_at TIMESTAMPTZ,
  recovered_at TIMESTAMPTZ,
  type TEXT,
  category TEXT,
  responsible TEXT,
  cause TEXT,
  resolution TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX incidents_application_idx ON public.incidents(application_id);
CREATE INDEX incidents_detected_idx ON public.incidents(detected_at DESC);
CREATE UNIQUE INDEX incidents_one_active_per_app ON public.incidents(application_id) WHERE status = 'active';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.applications TO authenticated, anon;
GRANT ALL ON public.applications TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incidents TO authenticated, anon;
GRANT ALL ON public.incidents TO service_role;

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Aplicacoes abertas para uso interno" ON public.applications FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Incidentes abertos para uso interno" ON public.incidents FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER applications_updated_at BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER incidents_updated_at BEFORE UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.validate_incident_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.failure_started_at IS NOT NULL AND NEW.failure_started_at > NEW.detected_at THEN
    RAISE EXCEPTION 'O início da falha deve ser anterior ou igual à detecção';
  END IF;
  IF NEW.recovered_at IS NOT NULL AND NEW.recovered_at < NEW.detected_at THEN
    RAISE EXCEPTION 'A recuperação deve ser posterior ou igual à detecção';
  END IF;
  IF NEW.response_started_at IS NOT NULL THEN
    IF NEW.response_started_at < NEW.detected_at THEN
      RAISE EXCEPTION 'A atuação deve iniciar após a detecção';
    END IF;
    IF NEW.recovered_at IS NOT NULL AND NEW.response_started_at > NEW.recovered_at THEN
      RAISE EXCEPTION 'A atuação deve iniciar antes da recuperação';
    END IF;
  END IF;
  IF NEW.detected_at > now() + interval '5 minutes'
     OR COALESCE(NEW.failure_started_at, now()) > now() + interval '5 minutes'
     OR COALESCE(NEW.recovered_at, now()) > now() + interval '5 minutes'
     OR COALESCE(NEW.response_started_at, now()) > now() + interval '5 minutes' THEN
    RAISE EXCEPTION 'Datas futuras não são permitidas';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER incidents_validate BEFORE INSERT OR UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION public.validate_incident_timestamps();

INSERT INTO public.applications (name, description) VALUES
  ('XPTO', 'Plataforma XPTO'),
  ('ABC', 'Sistema ABC'),
  ('SEP', 'Serviço SEP');

DO $$
DECLARE
  app RECORD;
  i INT;
  days INT[];
  mttd INT[];
  mttr INT[];
  cats TEXT[] := ARRAY['Indisponibilidade','Lentidão','Erro de aplicação','Banco de dados','Infraestrutura','Integração','Outro'];
  resp TEXT[] := ARRAY['Ana Souza','Carlos Lima','Marina Rocha','Pedro Alves'];
  fstart TIMESTAMPTZ;
BEGIN
  FOR app IN SELECT id, name FROM public.applications LOOP
    IF app.name = 'XPTO' THEN
      days := ARRAY[28,22,15,9,3]; mttd := ARRAY[5,6,7,8,9]; mttr := ARRAY[20,25,28,31,36];
    ELSIF app.name = 'ABC' THEN
      days := ARRAY[26,18,11,4]; mttd := ARRAY[8,10,12,14]; mttr := ARRAY[30,38,44,52];
    ELSE
      days := ARRAY[24,13,5]; mttd := ARRAY[3,5,7]; mttr := ARRAY[12,19,26];
    END IF;
    FOR i IN 1..array_length(days,1) LOOP
      fstart := date_trunc('hour', now()) - (days[i] || ' days')::interval + ((i*3+7) || ' hours')::interval;
      INSERT INTO public.incidents (application_id, status, failure_started_at, detected_at, response_started_at, recovered_at, type, category, responsible, cause, resolution, notes)
      VALUES (
        app.id, 'resolved',
        fstart,
        fstart + (mttd[i] || ' minutes')::interval,
        fstart + ((mttd[i] + 2) || ' minutes')::interval,
        fstart + ((mttd[i] + mttr[i]) || ' minutes')::interval,
        cats[1 + ((i + length(app.name)) % 7)],
        cats[1 + ((i + length(app.name)) % 7)],
        resp[1 + (i % 4)],
        'Falha identificada durante operação normal do serviço.',
        'Serviço reiniciado e monitorado até a normalização.',
        'Incidente registrado para histórico de confiabilidade.'
      );
    END LOOP;
  END LOOP;
END $$;
