
CREATE OR REPLACE FUNCTION public.validate_incident_timestamps()
RETURNS TRIGGER AS $$
DECLARE tol interval := interval '60 seconds';
BEGIN
  IF NEW.failure_started_at IS NOT NULL AND NEW.failure_started_at > NEW.detected_at + tol THEN
    RAISE EXCEPTION 'O início da falha deve ser anterior ou igual à detecção';
  END IF;
  IF NEW.recovered_at IS NOT NULL AND NEW.recovered_at < NEW.detected_at - tol THEN
    RAISE EXCEPTION 'A recuperação deve ser posterior ou igual à detecção';
  END IF;
  IF NEW.response_started_at IS NOT NULL THEN
    IF NEW.response_started_at < NEW.detected_at - tol THEN
      RAISE EXCEPTION 'A atuação deve iniciar após a detecção';
    END IF;
    IF NEW.recovered_at IS NOT NULL AND NEW.response_started_at > NEW.recovered_at + tol THEN
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
