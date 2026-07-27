-- ============================================================================
--  20260776_deploy_classes_rls.sql — Déployer POUR DE VRAI le modèle
--  `classes.*` sur classes / subjects / courses / schedules
--
--  ── Ce qu'on a découvert (audit du 27/07/2026) ──────────────────────────────
--  Comme pour `comptabilite.*` (cf. 20260774), le catalogue fin `classes.*`
--  (voir/creer/modifier/supprimer/assigner_prof) existe dans « Rôles &
--  permissions » et l'écran Flutter le vérifie bien (`admin_classes_page.dart`,
--  `admin_subjects_page.dart`, `admin_courses_page.dart`) — mais la migration
--  qui devait le faire respecter en base (`20260731_lock_structure.sql`) n'a
--  JAMAIS été appliquée en production. `classes`, `subjects`, `courses` et
--  `schedules` étaient encore sur `tenant_isolation` (ALL, is_member_of) :
--  n'importe quel membre de l'école, y compris un ÉLÈVE, pouvait créer,
--  modifier ou supprimer une classe, une matière, un cours ou l'emploi du
--  temps via un appel API direct.
--
--  `classes.assigner_prof` reste décoratif : l'affectation d'un prof à un
--  cours (`course_teachers`) utilise déjà `classes.modifier` (cf. 20260739),
--  et ça reste ainsi — pas de nouvelle sous-permission introduite ici.
-- ============================================================================

-- ── 1) CLASSES, MATIERES, COURS ──────────────────────────────────────────────
--  Lecture ouverte à l'école (un élève doit voir sa classe et ses matières) ;
--  écriture réservée à `classes.creer/modifier/supprimer`.
do $$
declare t text;
begin
  foreach t in array array['classes', 'subjects', 'courses'] loop
    execute format('drop policy if exists tenant_isolation on public.%I', t);

    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using (public.is_member_of(school_id))', t || '_read', t);

    execute format('drop policy if exists %I on public.%I', t || '_insert', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      'with check (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''creer''))',
      t || '_insert', t);

    execute format('drop policy if exists %I on public.%I', t || '_update', t);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      'using (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''modifier'')) '
      'with check (public.is_member_of(school_id))',
      t || '_update', t);

    execute format('drop policy if exists %I on public.%I', t || '_delete', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      'using (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''supprimer''))',
      t || '_delete', t);
  end loop;
end $$;

-- ── 2) EMPLOI DU TEMPS ───────────────────────────────────────────────────────
--  L'élève le consulte, l'administration le construit.
drop policy if exists tenant_isolation on public.schedules;

drop policy if exists schedules_read on public.schedules;
create policy schedules_read on public.schedules
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists schedules_write on public.schedules;
create policy schedules_write on public.schedules
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'emploi_du_temps', 'modifier')
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'emploi_du_temps', 'modifier')
  );

-- ── 3) Backfill : ne retirer aucun accès explicitement voulu ────────────────
--  Un rôle créé DEPUIS un modèle (`based_on_template_id`) qui prévoit des
--  droits `classes.*`, mais qui n'en a AUCUN aujourd'hui, ne les a pas perdus
--  par choix : la case n'avait jamais eu d'effet réel avant cette migration,
--  donc rien ne l'a jamais poussé à vérifier qu'elle était bien cochée. On
--  restaure ce que son modèle d'origine prévoyait — mais seulement s'il n'a
--  RIEN dans le module (un rôle qui a DÉJÀ fait un choix explicite, même
--  partiel, dans `classes.*` n'est pas touché).
insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sr.id, 'classes', rtp.sub_permission_key
  from public.staff_roles sr
  join public.role_template_permissions rtp
    on rtp.role_template_id = sr.based_on_template_id
   and rtp.permission_key = 'classes'
 where not exists (
   select 1 from public.staff_role_permissions x
    where x.staff_role_id = sr.id and x.permission_key = 'classes'
 )
on conflict do nothing;

-- ============================================================================
--  VERIFICATION :
--    select count(*) from pg_policies
--     where qual ilike '%''classes''%' or with_check ilike '%''classes''%';
--
--    -- Un élève ne doit RIEN pouvoir sur la structure :
--    select has_permission(u.auth_uid,'classes','creer')
--      from users u where u.role::text = 'student' limit 1;
--    -- attendu : false
--
--    -- Le Secrétaire d'École Lumière du Congo a récupéré son accès classes :
--    select sub_permission_key from staff_role_permissions
--     where permission_key = 'classes'
--       and staff_role_id = (select id from staff_roles
--             where school_id = '597bf04f-1e94-40a6-9eaa-93d16868e4fc'
--               and name = 'Secrétaire')
--     order by 1;
--    -- attendu : creer, modifier, voir
-- ============================================================================
