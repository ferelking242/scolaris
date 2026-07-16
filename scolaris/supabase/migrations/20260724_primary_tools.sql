-- ============================================================================
--  20260724_primary_tools.sql — Les trois outils du PRIMAIRE, pour de vrai
--
--  Etat avant (verifie en direct sur l'instance, pas dans le depot) :
--  les ecrans « Cahier de liaison », « Menu de la cantine » et « Carnet de
--  recompenses » existent dans l'app depuis le debut… et affichent des listes
--  ecrites en dur dans les fichiers Dart. Aucune table ne les adosse :
--
--      cahier_liaison / liaison_entries / liaison_messages  → 404
--      canteen_menus  / menu_cantine    / cantine_menus     → 404
--      rewards / bons_points / student_rewards              → 404
--
--  Ce sont pourtant les trois choses qu'une ecole primaire vient chercher, et
--  celles que le PARENT consulte (en primaire, c'est lui qui a le compte).
--
--  Cette migration cree les tables, la RLS, et les droits qui vont avec.
--
--  CONVENTIONS REPRISES DE L'EXISTANT (rien n'est reinvente) :
--    • cloisonnement par ecole  : public.is_member_of(school_id)
--    • droits du personnel      : public.has_permission(auth.uid(), cle, sous_cle)
--                                 (reconnait deja le fondateur — cf. 20260716)
--    • perimetre du prof        : public.teaches_class(auth.uid(), class_id)
--    • lien parent-enfant       : public.is_my_child(auth.uid(), student_id)
--                                 ⚠ version a DEUX arguments (cf. 20260722).
--    • identite                 : public.my_user_id()
--
--  Idempotent (create if not exists / drop policy if exists). Rejouable.
--  ROLLBACK complet en fin de fichier.
-- ============================================================================

-- ── 0) Helpers manquants ────────────────────────────────────────────────────
--  Le cahier de liaison et la cantine s'adressent souvent a une CLASSE entiere,
--  pas a un eleve nommement. Il faut donc pouvoir repondre a « cette classe est
--  celle de mon enfant ? » et « cette classe est la mienne ? ».

-- La classe de l'ELEVE connecte (null s'il n'est pas eleve).
-- NB : la cle de `student_profiles` vers `users` est `user_id` (verifie en
-- direct — il n'y a ni `student_id` ni `id` sur cette table).
create or replace function public.my_class_id()
returns uuid
language sql stable security definer
set search_path = public
as $fn$
  select sp.class_id
    from public.student_profiles sp
    join public.users u on u.id = sp.user_id
   where u.auth_uid = auth.uid()
   limit 1;
$fn$;

-- Le PARENT connecte a-t-il un enfant dans cette classe ?
create or replace function public.has_child_in_class(uid uuid, p_class_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1
      from public.parent_student ps
      join public.users p  on p.id = ps.parent_id
      join public.student_profiles sp on sp.user_id = ps.student_id
     where p.auth_uid = uid
       and sp.class_id = p_class_id
  );
$fn$;

grant execute on function public.my_class_id()                      to authenticated;
grant execute on function public.has_child_in_class(uuid, uuid)     to authenticated;

-- ── 1) Nouveaux modules de permission ───────────────────────────────────────
--  Le catalogue RBAC (20260713_staff_rbac) n'avait pas de module pour ces
--  outils. On les ajoute plutot que de detourner « messages » : l'admin doit
--  pouvoir cocher « Cantine » sans donner acces a la communication.

insert into public.permission_catalog (key, label, order_num) values
  ('liaison',      'Cahier de liaison', 11),
  ('cantine',      'Cantine',           12),
  ('recompenses',  'Récompenses',       13)
on conflict (key) do update
  set label = excluded.label, order_num = excluded.order_num;

insert into public.sub_permission_catalog (permission_key, key, label, order_num) values
  ('liaison',     'voir',      'Voir',      1),
  ('liaison',     'ecrire',    'Écrire',    2),
  ('liaison',     'supprimer', 'Supprimer', 3),
  ('cantine',     'voir',      'Voir',      1),
  ('cantine',     'gerer',     'Gérer',     2),
  ('recompenses', 'voir',      'Voir',      1),
  ('recompenses', 'attribuer', 'Attribuer', 2),
  ('recompenses', 'retirer',   'Retirer',   3)
on conflict (permission_key, key) do update
  set label = excluded.label, order_num = excluded.order_num;

--  Qui recoit quoi, dans les modeles de roles existants :
--    • Enseignant  → ecrit dans le cahier de liaison, attribue les recompenses.
--                    (C'est l'instituteur : sans lui, le cahier reste vide.)
--    • Adjoint     → tout, y compris la cantine.
--    • Secretaire  → gere la cantine (c'est un acte administratif).
--    • Surveillant → voit, n'ecrit pas.
--  Le Chef d'etablissement n'a besoin de rien : son acces vient de
--  is_admin_role (cf. 20260719).
insert into public.role_template_permissions
  (role_template_id, permission_key, sub_permission_key)
values
  -- Enseignant
  ('11111111-0000-4000-8000-000000000006', 'liaison',     'voir'),
  ('11111111-0000-4000-8000-000000000006', 'liaison',     'ecrire'),
  ('11111111-0000-4000-8000-000000000006', 'recompenses', 'voir'),
  ('11111111-0000-4000-8000-000000000006', 'recompenses', 'attribuer'),
  ('11111111-0000-4000-8000-000000000006', 'cantine',     'voir'),
  -- Adjoint
  ('11111111-0000-4000-8000-000000000002', 'liaison',     'voir'),
  ('11111111-0000-4000-8000-000000000002', 'liaison',     'ecrire'),
  ('11111111-0000-4000-8000-000000000002', 'liaison',     'supprimer'),
  ('11111111-0000-4000-8000-000000000002', 'cantine',     'voir'),
  ('11111111-0000-4000-8000-000000000002', 'cantine',     'gerer'),
  ('11111111-0000-4000-8000-000000000002', 'recompenses', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'recompenses', 'attribuer'),
  -- Secretaire
  ('11111111-0000-4000-8000-000000000004', 'cantine',     'voir'),
  ('11111111-0000-4000-8000-000000000004', 'cantine',     'gerer'),
  ('11111111-0000-4000-8000-000000000004', 'liaison',     'voir'),
  -- Surveillant
  ('11111111-0000-4000-8000-000000000003', 'liaison',     'voir'),
  ('11111111-0000-4000-8000-000000000003', 'recompenses', 'voir')
on conflict do nothing;

-- ============================================================================
--  2) CAHIER DE LIAISON
--  Un mot de l'ecole a la famille. Deux portees :
--    • toute une classe  (class_id renseigne, student_id null) — le cas courant
--    • un eleve en particulier (student_id renseigne)
--  `requires_ack` = le parent doit accuser reception (la « signature » du
--  cahier papier). L'accuse vit dans une table a part : un mot adresse a la
--  classe recoit UN accuse PAR parent.
-- ============================================================================
create table if not exists public.liaison_entries (
  id           uuid primary key default gen_random_uuid(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  class_id     uuid     references public.classes(id) on delete cascade,
  student_id   uuid     references public.users(id)   on delete cascade,
  author_id    uuid not null references public.users(id),
  -- Vocabulaire repris de l'ecran existant (c'est celui d'un vrai cahier de
  -- liaison) : mot d'information, sortie scolaire, medicament a administrer,
  -- demande de permission, felicitation, avertissement. 'devoir' en plus.
  category     text not null default 'info'
               check (category in ('info','devoir','sortie','medicament',
                                   'permission','felicitation','avertissement')),
  title        text not null,
  body         text not null,
  requires_ack boolean not null default false,
  created_at   timestamptz not null default now(),
  -- Un mot s'adresse a une classe OU a un eleve : jamais a personne.
  constraint liaison_target_ck check (class_id is not null or student_id is not null)
);
create index if not exists liaison_entries_school_idx  on public.liaison_entries(school_id);
create index if not exists liaison_entries_class_idx   on public.liaison_entries(class_id);
create index if not exists liaison_entries_student_idx on public.liaison_entries(student_id);
create index if not exists liaison_entries_created_idx on public.liaison_entries(created_at desc);

create table if not exists public.liaison_acks (
  id        uuid primary key default gen_random_uuid(),
  entry_id  uuid not null references public.liaison_entries(id) on delete cascade,
  parent_id uuid not null references public.users(id) on delete cascade,
  acked_at  timestamptz not null default now(),
  unique (entry_id, parent_id)
);
create index if not exists liaison_acks_parent_idx on public.liaison_acks(parent_id);

alter table public.liaison_entries enable row level security;
alter table public.liaison_acks    enable row level security;

--  LECTURE : la famille concernee (parent de l'eleve / de la classe, ou l'eleve
--  lui-meme), le prof de la classe, le personnel autorise.
drop policy if exists liaison_read on public.liaison_entries;
create policy liaison_read on public.liaison_entries
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or (class_id is not null and class_id = public.my_class_id())
      or public.is_my_child(auth.uid(), student_id)
      or (class_id is not null and public.has_child_in_class(auth.uid(), class_id))
      or (public.get_my_role()::text = 'teacher'
          and class_id is not null
          and public.teaches_class(auth.uid(), class_id))
      or (public.get_my_role()::text <> 'teacher'
          and public.has_permission(auth.uid(), 'liaison', 'voir'))
    )
  );

--  ECRITURE : le prof, dans SES classes seulement. Le personnel autorise,
--  partout dans l'ecole. La famille n'ecrit jamais dans le cahier (elle accuse
--  reception — voir liaison_acks).
drop policy if exists liaison_insert on public.liaison_entries;
create policy liaison_insert on public.liaison_entries
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'liaison', 'ecrire')
    and author_id = public.my_user_id()
    and (
      public.get_my_role()::text <> 'teacher'
      or (class_id is not null and public.teaches_class(auth.uid(), class_id))
    )
  );

drop policy if exists liaison_update on public.liaison_entries;
create policy liaison_update on public.liaison_entries
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'liaison', 'ecrire')
    and (author_id = public.my_user_id()
         or public.has_permission(auth.uid(), 'liaison', 'supprimer'))
  )
  with check (public.is_member_of(school_id));

drop policy if exists liaison_delete on public.liaison_entries;
create policy liaison_delete on public.liaison_entries
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'liaison', 'supprimer')
  );

--  ACCUSES : le parent signe POUR LUI (parent_id = lui), et pour un mot qu'il a
--  le droit de lire (la policy de lecture ci-dessus s'applique au sous-select).
--  L'ecole lit les accuses pour savoir qui a signe.
drop policy if exists liaison_ack_read on public.liaison_acks;
create policy liaison_ack_read on public.liaison_acks
  for select to authenticated
  using (
    parent_id = public.my_user_id()
    or exists (select 1 from public.liaison_entries e
                where e.id = entry_id
                  and public.is_member_of(e.school_id)
                  and public.has_permission(auth.uid(), 'liaison', 'voir'))
  );

drop policy if exists liaison_ack_write on public.liaison_acks;
create policy liaison_ack_write on public.liaison_acks
  for insert to authenticated
  with check (
    parent_id = public.my_user_id()
    and exists (select 1 from public.liaison_entries e where e.id = entry_id)
  );

-- ============================================================================
--  3) CANTINE
--  Un menu par jour et par ecole ; des plats rattaches au menu.
--  Lecture ouverte a toute l'ecole (le menu n'est pas confidentiel) ; ecriture
--  reservee a qui a la permission « cantine.gerer ».
-- ============================================================================
create table if not exists public.canteen_menus (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools(id) on delete cascade,
  menu_date  date not null,
  note       text,                       -- ex. allergenes, service exceptionnel
  created_at timestamptz not null default now(),
  unique (school_id, menu_date)          -- un seul menu par jour et par ecole
);
create index if not exists canteen_menus_school_date_idx
  on public.canteen_menus(school_id, menu_date);

create table if not exists public.canteen_dishes (
  id          uuid primary key default gen_random_uuid(),
  menu_id     uuid not null references public.canteen_menus(id) on delete cascade,
  course      text not null default 'plat'
              check (course in ('entree','plat','dessert')),
  name        text not null,
  description text,
  emoji       text,
  allergens   text[] not null default '{}',
  order_num   int not null default 0
);
create index if not exists canteen_dishes_menu_idx on public.canteen_dishes(menu_id);

alter table public.canteen_menus  enable row level security;
alter table public.canteen_dishes enable row level security;

drop policy if exists canteen_menu_read on public.canteen_menus;
create policy canteen_menu_read on public.canteen_menus
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists canteen_menu_write on public.canteen_menus;
create policy canteen_menu_write on public.canteen_menus
  for all to authenticated
  using (public.is_member_of(school_id)
         and public.has_permission(auth.uid(), 'cantine', 'gerer'))
  with check (public.is_member_of(school_id)
         and public.has_permission(auth.uid(), 'cantine', 'gerer'));

--  Les plats heritent des droits de leur menu (pas de school_id duplique).
drop policy if exists canteen_dish_read on public.canteen_dishes;
create policy canteen_dish_read on public.canteen_dishes
  for select to authenticated
  using (exists (select 1 from public.canteen_menus m
                  where m.id = menu_id and public.is_member_of(m.school_id)));

drop policy if exists canteen_dish_write on public.canteen_dishes;
create policy canteen_dish_write on public.canteen_dishes
  for all to authenticated
  using (exists (select 1 from public.canteen_menus m
                  where m.id = menu_id
                    and public.is_member_of(m.school_id)
                    and public.has_permission(auth.uid(), 'cantine', 'gerer')))
  with check (exists (select 1 from public.canteen_menus m
                  where m.id = menu_id
                    and public.is_member_of(m.school_id)
                    and public.has_permission(auth.uid(), 'cantine', 'gerer')));

-- ============================================================================
--  4) RECOMPENSES — bons points et badges
--  Le bon point est nominatif et date ; le badge est un palier obtenu.
--  Le catalogue de badges appartient a l'ECOLE (chacune a ses traditions).
-- ============================================================================
create table if not exists public.merit_points (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  student_id  uuid not null references public.users(id) on delete cascade,
  awarded_by  uuid not null references public.users(id),
  subject     text,                      -- matiere / contexte (libre)
  reason      text not null,             -- « A aide un camarade », …
  stars       int  not null default 1 check (stars between 1 and 3),
  awarded_at  timestamptz not null default now()
);
create index if not exists merit_points_student_idx on public.merit_points(student_id);
create index if not exists merit_points_school_idx  on public.merit_points(school_id);

create table if not exists public.badge_catalog (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  key         text not null,
  title       text not null,
  description text,
  emoji       text,
  order_num   int not null default 0,
  unique (school_id, key)
);

create table if not exists public.student_badges (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.users(id) on delete cascade,
  badge_id   uuid not null references public.badge_catalog(id) on delete cascade,
  awarded_by uuid references public.users(id),
  awarded_at timestamptz not null default now(),
  unique (student_id, badge_id)          -- un badge ne s'obtient qu'une fois
);
create index if not exists student_badges_student_idx on public.student_badges(student_id);

alter table public.merit_points   enable row level security;
alter table public.badge_catalog  enable row level security;
alter table public.student_badges enable row level security;

--  LECTURE : l'eleve voit les siens, le parent ceux de ses enfants, le prof
--  ceux de ses classes n'est pas exprimable ici (merit_points n'a pas de
--  class_id) → on retombe sur la permission du personnel, ce qui est correct :
--  un prof qui attribue des bons points a la permission « recompenses.voir ».
drop policy if exists merit_read on public.merit_points;
create policy merit_read on public.merit_points
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
      or public.has_permission(auth.uid(), 'recompenses', 'voir')
    )
  );

drop policy if exists merit_insert on public.merit_points;
create policy merit_insert on public.merit_points
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'recompenses', 'attribuer')
    and awarded_by = public.my_user_id()
  );

drop policy if exists merit_delete on public.merit_points;
create policy merit_delete on public.merit_points
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'recompenses', 'retirer')
  );

--  Le catalogue de badges : lisible par toute l'ecole, modifiable par qui
--  attribue les recompenses.
drop policy if exists badge_catalog_read on public.badge_catalog;
create policy badge_catalog_read on public.badge_catalog
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists badge_catalog_write on public.badge_catalog;
create policy badge_catalog_write on public.badge_catalog
  for all to authenticated
  using (public.is_member_of(school_id)
         and public.has_permission(auth.uid(), 'recompenses', 'attribuer'))
  with check (public.is_member_of(school_id)
         and public.has_permission(auth.uid(), 'recompenses', 'attribuer'));

drop policy if exists student_badge_read on public.student_badges;
create policy student_badge_read on public.student_badges
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
      or public.has_permission(auth.uid(), 'recompenses', 'voir')
    )
  );

drop policy if exists student_badge_write on public.student_badges;
create policy student_badge_write on public.student_badges
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'recompenses', 'attribuer')
  );

drop policy if exists student_badge_delete on public.student_badges;
create policy student_badge_delete on public.student_badges
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'recompenses', 'retirer')
  );

-- ============================================================================
--  VERIFICATION (a lancer apres) :
--
--    -- les 7 tables existent :
--    select table_name from information_schema.tables
--     where table_schema = 'public'
--       and table_name in ('liaison_entries','liaison_acks','canteen_menus',
--                          'canteen_dishes','merit_points','badge_catalog',
--                          'student_badges');    -- attendu : 7 lignes
--
--    -- l'enseignant peut ecrire dans le cahier :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'teacher' limit 1),
--      'liaison', 'ecrire');                     -- attendu : true
--
--    -- un parent ne le peut pas :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'parent' limit 1),
--      'liaison', 'ecrire');                     -- attendu : false
--
--  ⚠ Les profs deja crees ont un staff_role (cf. 20260721). Les nouvelles
--    permissions sont accordees au MODELE : les roles deja instancies dans les
--    ecoles ne les recoivent PAS automatiquement. Si un prof existant ne peut
--    pas ecrire, c'est cela — il faut propager les grants du modele vers les
--    staff_roles existants (a faire une fois le comportement constate).
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    drop table if exists public.student_badges  cascade;
--    drop table if exists public.badge_catalog   cascade;
--    drop table if exists public.merit_points    cascade;
--    drop table if exists public.canteen_dishes  cascade;
--    drop table if exists public.canteen_menus   cascade;
--    drop table if exists public.liaison_acks    cascade;
--    drop table if exists public.liaison_entries cascade;
--    delete from public.role_template_permissions
--     where permission_key in ('liaison','cantine','recompenses');
--    delete from public.sub_permission_catalog
--     where permission_key in ('liaison','cantine','recompenses');
--    delete from public.permission_catalog
--     where key in ('liaison','cantine','recompenses');
--    drop function if exists public.has_child_in_class(uuid, uuid);
--    drop function if exists public.my_class_id();
-- ============================================================================
