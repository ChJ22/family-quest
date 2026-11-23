-- FAMILY QUEST MIGRATION 002 - nach Migration 001
-- Bestehende pending-Aufgaben ohne completion bleiben zur Sicherheit unverändert.
BEGIN;

-- Bereits offene Freigaben aus dem alten System uebernehmen.
INSERT INTO public.task_completions
 (family_id,task_id,task_title,member_id,period_date,status)
SELECT t.family_id,t.id,t.title,t.member_id,
 (now() AT TIME ZONE 'Europe/Berlin')::date,'pending'
FROM public.tasks t
WHERE t.status='pending' AND t.member_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.task_completions c
    WHERE c.task_id=t.id AND c.status='pending'
  );

CREATE OR REPLACE FUNCTION public.fq_task_action(p_action text,p_task_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fqtask$
DECLARE
 a public.members; t public.tasks; c public.task_completions;
 v_today date := (now() AT TIME ZONE 'Europe/Berlin')::date;
 v_period date; v_start date; v_count integer; v_limit integer; v_receiver uuid;
BEGIN
 SELECT * INTO a FROM public.fq_actor();
 IF a.id IS NULL THEN RAISE EXCEPTION 'Kein Familienprofil'; END IF;
 PERFORM 1 FROM public.families WHERE id=a.family_id FOR UPDATE;
 PERFORM public.fq_rollover(a.family_id);
 SELECT * INTO a FROM public.fq_actor();
 SELECT * INTO t FROM public.tasks WHERE id=p_task_id AND family_id=a.family_id FOR UPDATE;
 IF t.id IS NULL THEN RAISE EXCEPTION 'Aufgabe nicht gefunden'; END IF;
 IF p_action='claim' THEN
   IF a.role<>'child' OR t.assignment_mode<>'shared' OR t.status<>'open'
      OR t.claimed_by IS NOT NULL THEN RAISE EXCEPTION 'Uebernahme nicht moeglich'; END IF;
   UPDATE public.tasks SET claimed_by=a.id,claimed_at=now() WHERE id=t.id;
 ELSIF p_action='release' THEN
   IF t.assignment_mode<>'shared' OR t.status<>'open'
      OR t.claimed_by IS DISTINCT FROM a.id THEN RAISE EXCEPTION 'Rueckgabe nicht moeglich'; END IF;
   UPDATE public.tasks SET claimed_by=NULL,claimed_at=NULL WHERE id=t.id;
 ELSIF p_action='complete' THEN
   IF t.status<>'open' THEN RAISE EXCEPTION 'Aufgabe ist nicht offen'; END IF;
   v_receiver := CASE WHEN t.assignment_mode='shared' THEN t.claimed_by ELSE t.member_id END;
   IF v_receiver IS NULL THEN RAISE EXCEPTION 'Aufgabe muss zuerst uebernommen werden'; END IF;
   IF a.role<>'parent' AND a.id<>v_receiver THEN RAISE EXCEPTION 'Nicht erlaubt'; END IF;
   IF t.repeat_weekdays IS NOT NULL AND NOT
     (extract(isodow FROM v_today)::smallint = ANY(t.repeat_weekdays))
     THEN RAISE EXCEPTION 'Heute kein vorgesehener Aufgabentag'; END IF;
   IF t.repeat='once' AND EXISTS
     (SELECT 1 FROM public.task_completions WHERE task_id=t.id AND status='approved')
     THEN RAISE EXCEPTION 'Einmalige Aufgabe bereits erledigt'; END IF;
   IF EXISTS (SELECT 1 FROM public.task_completions WHERE task_id=t.id
     AND period_date=v_today AND status='approved')
     THEN RAISE EXCEPTION 'Heute bereits bestaetigt'; END IF;
   IF t.repeat='weekly' THEN
     v_start := v_today-(extract(isodow FROM v_today)::integer-1);
     v_limit := coalesce(t.repeat_target_per_week,1);
     SELECT count(*) INTO v_count FROM public.task_completions
       WHERE task_id=t.id AND status='approved'
         AND period_date BETWEEN v_start AND v_start+6;
     IF v_count>=v_limit THEN RAISE EXCEPTION 'Wochenziel erreicht'; END IF;
   END IF;
   INSERT INTO public.task_completions(family_id,task_id,task_title,member_id,period_date)
     VALUES(a.family_id,t.id,t.title,v_receiver,v_today);
   UPDATE public.tasks SET status='pending' WHERE id=t.id;
 ELSIF p_action IN ('approve','reject') THEN
   IF a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern'; END IF;
   SELECT * INTO c FROM public.task_completions WHERE task_id=t.id
     AND family_id=a.family_id AND status='pending' FOR UPDATE;
   IF c.id IS NULL OR t.status<>'pending' THEN
     RAISE EXCEPTION 'Keine neue Einreichung gefunden (Altbestand ggf. separat behandeln)';
   END IF;
   IF p_action='reject' THEN
     UPDATE public.task_completions SET status='rejected',reviewed_by=a.id,
       reviewed_at=now() WHERE id=c.id;
     UPDATE public.tasks SET status='open' WHERE id=t.id;
   ELSE
     v_period:=c.period_date;
     IF EXISTS (SELECT 1 FROM public.task_completions WHERE task_id=t.id
       AND period_date=v_period AND status='approved')
       THEN RAISE EXCEPTION 'Tagesgutschrift bereits vorhanden'; END IF;
     IF t.repeat='once' AND EXISTS (SELECT 1 FROM public.task_completions
       WHERE task_id=t.id AND status='approved')
       THEN RAISE EXCEPTION 'Einmalige Aufgabe bereits erledigt'; END IF;
     IF t.repeat='weekly' THEN
       v_start:=v_period-(extract(isodow FROM v_period)::integer-1);
       v_limit:=coalesce(t.repeat_target_per_week,1);
       SELECT count(*) INTO v_count FROM public.task_completions
         WHERE task_id=t.id AND status='approved'
           AND period_date BETWEEN v_start AND v_start+6;
       IF v_count>=v_limit THEN RAISE EXCEPTION 'Wochenziel erreicht'; END IF;
     END IF;
     UPDATE public.members SET
       xp=xp+CASE WHEN role='child' THEN t.xp ELSE 0 END,
       career_xp=career_xp+CASE WHEN role='child' THEN t.xp ELSE 0 END,
       coins=coins+t.coins
       WHERE id=c.member_id AND family_id=a.family_id;
     UPDATE public.task_completions SET status='approved',reviewed_by=a.id,
       reviewed_at=now(),
       xp_awarded=CASE WHEN (SELECT role FROM public.members WHERE id=c.member_id)='child'
         THEN t.xp ELSE 0 END,
       coins_awarded=t.coins WHERE id=c.id;
     INSERT INTO public.history(family_id,member_id,kind,task_id,xp,coins)
       VALUES(a.family_id,c.member_id,'task',t.id,
         CASE WHEN (SELECT role FROM public.members WHERE id=c.member_id)='child'
           THEN t.xp ELSE 0 END,t.coins);
     UPDATE public.tasks SET status=CASE WHEN repeat='once' THEN 'done' ELSE 'open' END,
       claimed_by=NULL,claimed_at=NULL WHERE id=t.id;
   END IF;
 ELSE
   RAISE EXCEPTION 'Unbekannte Aufgabenaktion';
 END IF;
END;
$fqtask$;
REVOKE ALL ON FUNCTION public.fq_task_action(text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fq_task_action(text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fq_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $fq002$
DECLARE a public.members; t public.tasks; r public.rewards; m public.members;
 v_mode text; v_weekdays smallint[]; v_weekly smallint; v_target uuid; v_title text; v_cost integer; v_xp integer; v_coins integer; v_repeat text; v_type text;
BEGIN
 SELECT * INTO a FROM public.fq_actor();
 IF a.id IS NULL THEN RAISE EXCEPTION 'Kein Familienprofil'; END IF;
 -- serialisiert Änderungen an Guthaben und Monatsabschluss je Familie
 PERFORM 1 FROM public.families WHERE id=a.family_id FOR UPDATE;
 PERFORM public.fq_rollover(a.family_id);
 SELECT * INTO a FROM public.fq_actor();
 IF p_action IN ('complete','approve','reject','claim','release') THEN
   PERFORM public.fq_task_action(p_action,p_id);
   RETURN;
 ELSIF p_action='create_task' THEN
   IF a.role<>'parent' AND public.fq_level(a.xp)<3 THEN RAISE EXCEPTION 'Level 3 erforderlich'; END IF;
   v_title=trim(p_data->>'title');
   IF length(coalesce(v_title,'')) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Ungültiger Titel'; END IF;
   v_mode=CASE WHEN a.role='parent' THEN coalesce(p_data->>'assignmentMode','individual') ELSE 'individual' END;
   IF v_mode NOT IN ('individual','shared') THEN RAISE EXCEPTION 'Ungueltiger Zuweisungsmodus'; END IF;
   v_target=CASE WHEN v_mode='shared' THEN NULL ELSE coalesce((p_data->>'memberId')::uuid,a.id) END;
   IF v_mode='shared' AND a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern duerfen gemeinsame Aufgaben erstellen'; END IF;
   IF v_target IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.members WHERE id=v_target AND family_id=a.family_id) THEN RAISE EXCEPTION 'Ungültiges Familienmitglied'; END IF;
   v_xp=CASE WHEN a.role='parent' THEN coalesce((p_data->>'xp')::integer,10) ELSE 10 END;
   v_coins=CASE WHEN a.role='parent' THEN coalesce((p_data->>'coins')::integer,5) ELSE 5 END;
   v_repeat=CASE WHEN a.role='parent' THEN coalesce(p_data->>'repeat','once') ELSE 'once' END;
   v_type=CASE WHEN a.role='parent' THEN coalesce(p_data->>'type','regular') ELSE 'bonus' END;
   IF v_xp NOT BETWEEN 0 AND 1000 OR v_coins NOT BETWEEN 0 AND 1000 OR v_repeat NOT IN ('once','daily','weekly') OR v_type NOT IN ('regular','bonus') THEN RAISE EXCEPTION 'Ungültige Punkte oder Aufgabenart'; END IF;
   v_weekly=CASE WHEN a.role='parent' AND p_data ? 'repeatTargetPerWeek'
     THEN (p_data->>'repeatTargetPerWeek')::smallint ELSE NULL END;
   IF a.role='parent' AND p_data ? 'repeatWeekdays' AND jsonb_typeof(p_data->'repeatWeekdays')='array' THEN
     SELECT array_agg(x::smallint) INTO v_weekdays
     FROM jsonb_array_elements_text(p_data->'repeatWeekdays') x;
   END IF;
   IF (v_weekly IS NOT NULL OR v_weekdays IS NOT NULL) AND v_repeat<>'weekly'
     THEN RAISE EXCEPTION 'Wochenoptionen erfordern woechentliche Wiederholung'; END IF;
   INSERT INTO public.tasks(family_id,member_id,created_by,title,type,repeat,xp,coins,status,
     assignment_mode,repeat_target_per_week,repeat_weekdays)
   VALUES(a.family_id,v_target,a.id,v_title,v_type,v_repeat,v_xp,v_coins,
     CASE WHEN a.role='parent' THEN 'open' ELSE 'proposed' END,
     v_mode,v_weekly,v_weekdays);
 ELSIF p_action='create_reward' THEN
   IF a.role<>'parent' AND public.fq_level(a.xp)<2 THEN RAISE EXCEPTION 'Level 2 erforderlich'; END IF;
   v_title=trim(p_data->>'title'); v_cost=(p_data->>'cost')::integer;
   IF length(coalesce(v_title,'')) NOT BETWEEN 1 AND 100 OR v_cost NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Ungültige Belohnung'; END IF;
   INSERT INTO public.rewards(family_id,created_by,title,cost,status)
   VALUES(a.family_id,a.id,v_title,v_cost,CASE WHEN a.role='parent' THEN 'active' ELSE 'proposed' END);
 ELSIF p_action IN ('acceptProposal','rejectProposal','deleteTask') THEN
   SELECT * INTO t FROM public.tasks WHERE id=p_id AND family_id=a.family_id FOR UPDATE;
   IF t.id IS NULL THEN RAISE EXCEPTION 'Aufgabe nicht gefunden'; END IF;
   IF a.role<>'parent' THEN RAISE EXCEPTION 'Nur Eltern'; END IF;
   IF p_action='acceptProposal' THEN
       IF t.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       UPDATE public.tasks SET status='open' WHERE id=t.id;
     ELSIF p_action='rejectProposal' THEN
       IF t.status<>'proposed' THEN RAISE EXCEPTION 'Ungültiger Status'; END IF;
       DELETE FROM public.tasks WHERE id=t.id;
     ELSIF p_action='deleteTask' THEN
       DELETE FROM public.tasks WHERE id=t.id;
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
END;$fq002$
;

COMMIT;
