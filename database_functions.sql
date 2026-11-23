-- FAMILY QUEST: exported existing PostgreSQL function definitions.
-- REFERENCE SNAPSHOT ONLY: do not execute without review of dependencies and security.
-- Export date: 2026-11-23

CREATE OR REPLACE FUNCTION public.fq_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a public.members; t public.tasks; r public.rewards; m public.members;
 v_target uuid; v_title text; v_cost integer; v_xp integer; v_coins integer; v_repeat text; v_type text;
BEGIN
 SELECT * INTO a FROM public.fq_actor();
 IF a.id IS NULL THEN RAISE EXCEPTION 'Kein Familienprofil'; END IF;
 -- serialisiert Änderungen an Guthaben und Monatsabschluss je Familie
 PERFORM 1 FROM public.families WHERE id=a.family_id FOR UPDATE;
 PERFORM public.fq_rollover(a.family_id);
 SELECT * INTO a FROM public.fq_actor();
 IF p_action='create_task' THEN
   IF a.role<>'parent' AND public.fq_level(a.xp)<3 THEN RAISE EXCEPTION 'Level 3 erforderlich'; END IF;
   v_title=trim(p_data->>'title');
   IF length(coalesce(v_title,'')) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Ungültiger Titel'; END IF;
   v_target=coalesce((p_data->>'memberId')::uuid,a.id);
   IF NOT EXISTS(SELECT 1 FROM public.members WHERE id=v_target AND family_id=a.family_id) THEN RAISE EXCEPTION 'Ungültiges Familienmitglied'; END IF;
   v_xp=CASE WHEN a.role='parent' THEN coalesce((p_data->>'xp')::integer,10) ELSE 10 END;
   v_coins=CASE WHEN a.role='parent' THEN coalesce((p_data->>'coins')::integer,5) ELSE 5 END;
   v_repeat=CASE WHEN a.role='parent' THEN coalesce(p_data->>'repeat','once') ELSE 'once' END;
   v_type=CASE WHEN a.role='parent' THEN coalesce(p_data->>'type','regular') ELSE 'bonus' END;
   IF v_xp NOT BETWEEN 0 AND 1000 OR v_coins NOT BETWEEN 0 AND 1000 OR v_repeat NOT IN ('once','daily','weekly') OR v_type NOT IN ('regular','bonus') THEN RAISE EXCEPTION 'Ungültige Punkte oder Aufgabenart'; END IF;
   INSERT INTO public.tasks(family_id,member_id,created_by,title,type,repeat,xp,coins,status)
   VALUES(a.family_id,v_target,a.id,v_title,v_type,v_repeat,v_xp,v_coins,CASE WHEN a.role='parent' THEN 'open' ELSE 'proposed' END);
 ELSIF p_action='create_reward' THEN
   IF a.role<>'parent' AND public.fq_level(a.xp)<2 THEN RAISE EXCEPTION 'Level 2 erforderlich'; END IF;
   v_title=trim(p_data->>'title'); v_cost=(p_data->>'cost')::integer;
   IF length(coalesce(v_title,'')) NOT BETWEEN 1 AND 100 OR v_cost NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Ungültige Belohnung'; END IF;
   INSERT INTO public.rewards(family_id,created_by,title,cost,status)
   VALUES(a.family_id,a.id,v_title,v_cost,CASE WHEN a.role='parent' THEN 'active' ELSE 'proposed' END);
 ELSIF p_action IN ('complete','approve','reject','acceptProposal','rejectProposal','deleteTask') THEN
   SELECT * INTO t FROM public.tasks WHERE id=p_id AND family_id=a.family_id FOR UPDATE;
   IF t.id IS NULL THEN RAISE EXCEPTION 'Aufgabe nicht gefunden'; END IF;
   IF p_action='complete' THEN
     IF t.status<>'open' OR (a.role<>'parent' AND t.member_id<>a.id) THEN RAISE EXCEPTION 'Nicht erlaubt'; END IF;
     UPDATE public.tasks SET status='pending' WHERE id=t.id;
   ELSE
     IF a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern'; END IF;
     IF p_action='approve' THEN
       IF t.status<>'pending' THEN RAISE EXCEPTION 'Aufgabe wartet nicht auf Bestätigung'; END IF;
       UPDATE public.tasks SET status='done' WHERE id=t.id;
       UPDATE public.members SET xp=xp+CASE WHEN role='child' THEN t.xp ELSE 0 END,
         career_xp=career_xp+CASE WHEN role='child' THEN t.xp ELSE 0 END,coins=coins+t.coins WHERE id=t.member_id AND family_id=a.family_id;
       INSERT INTO public.history(family_id,member_id,kind,task_id,xp,coins) VALUES(a.family_id,t.member_id,'task',t.id,t.xp,t.coins);
     ELSIF p_action='reject' THEN
       IF t.status<>'pending' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       UPDATE public.tasks SET status='open' WHERE id=t.id;
     ELSIF p_action='acceptProposal' THEN
       IF t.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       UPDATE public.tasks SET status='open' WHERE id=t.id;
     ELSIF p_action='rejectProposal' THEN
       IF t.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       DELETE FROM public.tasks WHERE id=t.id;
     ELSIF p_action='deleteTask' THEN
       DELETE FROM public.tasks WHERE id=t.id;
     END IF;
   END IF;
 ELSIF p_action IN ('approveReward','rejectReward','deleteReward','redeem') THEN
   SELECT * INTO r FROM public.rewards WHERE id=p_id AND family_id=a.family_id FOR UPDATE;
   IF r.id IS NULL THEN RAISE EXCEPTION 'Belohnung nicht gefunden'; END IF;
   IF p_action='redeem' THEN
     IF r.status<>'active' THEN RAISE EXCEPTION 'Nicht freigegeben'; END IF;
     v_target=CASE WHEN a.role='parent' THEN coalesce((p_data->>'memberId')::uuid,a.id) ELSE a.id END;
     SELECT * INTO m FROM public.members WHERE id=v_target AND family_id=a.family_id FOR UPDATE;
     IF m.id IS NULL OR m.coins<r.cost THEN RAISE EXCEPTION 'Zu wenig Münzen oder falsches Mitglied'; END IF;
     UPDATE public.members SET coins=coins-r.cost WHERE id=m.id;
     INSERT INTO public.history(family_id,member_id,kind,reward_id,cost) VALUES(a.family_id,m.id,'reward',r.id,r.cost);
   ELSE
     IF a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern'; END IF;
     IF p_action='approveReward' THEN
       IF r.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       UPDATE public.rewards SET status='active' WHERE id=r.id;
     ELSIF p_action='rejectReward' THEN
       IF r.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       DELETE FROM public.rewards WHERE id=r.id;
     ELSIF p_action='deleteReward' THEN
       DELETE FROM public.rewards WHERE id=r.id;
     END IF;
   END IF;
 ELSE RAISE EXCEPTION 'Unbekannte Aktion'; END IF;
END;$function$
;

CREATE OR REPLACE FUNCTION public.fq_actor()
 RETURNS members
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT m FROM public.members m WHERE m.user_id = auth.uid() LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.fq_create_family(p_family_name text, p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_family uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Anmeldung erforderlich'; END IF;
 IF EXISTS(SELECT 1 FROM public.members WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'Bereits einer Familie zugeordnet'; END IF;
 IF length(trim(coalesce(p_family_name,''))) NOT BETWEEN 1 AND 80 OR length(trim(coalesce(p_name,''))) NOT BETWEEN 1 AND 40 THEN RAISE EXCEPTION 'Ungültiger Name'; END IF;
 INSERT INTO public.families(name) VALUES(trim(p_family_name)) RETURNING id INTO v_family;
 INSERT INTO public.members(family_id,user_id,name,role) VALUES(v_family,auth.uid(),trim(p_name),'parent');
 RETURN v_family;
END;$function$
;

CREATE OR REPLACE FUNCTION public.fq_join_parent(p_code text, p_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE f public.families;
BEGIN
 IF auth.uid() IS NULL OR EXISTS(SELECT 1 FROM public.members WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'Konto bereits zugeordnet oder nicht angemeldet'; END IF;
 IF length(trim(coalesce(p_name,''))) NOT BETWEEN 1 AND 40 THEN RAISE EXCEPTION 'Ungültiger Name'; END IF;
 SELECT * INTO f FROM public.families WHERE invite_code=md5(coalesce(p_code,'')) AND invite_expires_at>now() FOR UPDATE;
 IF f.id IS NULL THEN RAISE EXCEPTION 'Einladung ungültig oder abgelaufen'; END IF;
 INSERT INTO public.members(family_id,user_id,name,role) VALUES(f.id,auth.uid(),trim(p_name),'parent');
 UPDATE public.families SET invite_code=NULL,invite_expires_at=NULL WHERE id=f.id;
END;$function$
;

CREATE OR REPLACE FUNCTION public.fq_level(p_xp integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT CASE WHEN p_xp >= 200 THEN 4 WHEN p_xp >= 120 THEN 3 WHEN p_xp >= 60 THEN 2 ELSE 1 END;
$function$
;

CREATE OR REPLACE FUNCTION public.fq_parent_invite()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a public.members; v_code text;
BEGIN
 SELECT * INTO a FROM public.fq_actor();
 IF a.id IS NULL OR a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern'; END IF;
 v_code := replace(gen_random_uuid()::text,'-','');
 UPDATE public.families SET invite_code=md5(v_code),invite_expires_at=now()+interval '24 hours' WHERE id=a.family_id;
 RETURN v_code;
END;$function$
;

CREATE OR REPLACE FUNCTION public.fq_rollover(p_family uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_month text := to_char(now() at time zone 'Europe/Berlin','YYYY-MM');
BEGIN
 INSERT INTO public.monthly_archive(family_id,member_id,month,xp,level)
 SELECT family_id,id,xp_month,xp,public.fq_level(xp)
 FROM public.members WHERE family_id=p_family AND role='child' AND xp_month<>v_month
 ON CONFLICT (member_id,month) DO NOTHING;
 UPDATE public.members SET xp=0,xp_month=v_month
 WHERE family_id=p_family AND role='child' AND xp_month<>v_month;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fq_sync()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a public.members;
BEGIN
 SELECT * INTO a FROM public.fq_actor();
 IF a.id IS NULL THEN RAISE EXCEPTION 'Kein Familienprofil'; END IF;
 PERFORM 1 FROM public.families WHERE id=a.family_id FOR UPDATE;
 PERFORM public.fq_rollover(a.family_id);
END;$function$
;

CREATE OR REPLACE FUNCTION public.my_family_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select family_id
  from public.members
  where user_id = (select auth.uid());
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;
