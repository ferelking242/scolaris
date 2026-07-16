-- ============================================================================
--  20260713_staff_rbac.sql — Systeme de roles & permissions du personnel
--
--  RECONSTRUIT depuis la base live (projet iaxwvgqusxyhmyansawi) le 13/07/2026.
--  Ces tables avaient ete creees directement sur le serveur, sans migration :
--  ce fichier retablit la reproductibilite du schema. Ne pas supprimer.
--
--  Contenu : 6 tables + fonction has_permission() + RLS + catalogue de reference
--            (10 modules, 45 sous-permissions, 20 modeles de roles).
-- ============================================================================

-- 1. Catalogue de reference (global, sans school_id) -------------------------

create table if not exists public.permission_catalog (
  key       text primary key,
  label     text not null,
  order_num integer not null default 0
);

create table if not exists public.sub_permission_catalog (
  permission_key text not null references public.permission_catalog(key) on delete cascade,
  key            text not null,
  label          text not null,
  order_num      integer not null default 0,
  primary key (permission_key, key)
);

create table if not exists public.role_templates (
  id                 uuid primary key default gen_random_uuid(),
  cycle              text not null,
  name               text not null,
  description        text,
  order_num          integer not null default 0,
  level              text not null default 'Pédagogique',
  color              text not null default '#8B1A00',
  icon_key           text not null default 'badge',
  parent_template_id uuid references public.role_templates(id) on delete set null,
  unique (cycle, name)
);

create table if not exists public.role_template_permissions (
  role_template_id   uuid not null references public.role_templates(id) on delete cascade,
  permission_key     text not null,
  sub_permission_key text not null,
  primary key (role_template_id, permission_key, sub_permission_key)
);

-- 2. Roles reels d'une ecole -------------------------------------------------

create table if not exists public.staff_roles (
  id                   uuid primary key default gen_random_uuid(),
  school_id            uuid not null references public.schools(id) on delete cascade,
  name                 text not null,
  description          text,
  is_admin_role        boolean not null default false,
  based_on_template_id uuid references public.role_templates(id) on delete set null,
  created_at           timestamptz default now(),
  level                text not null default 'Pédagogique',
  color                text not null default '#8B1A00',
  icon_key             text not null default 'badge',
  parent_role_id       uuid references public.staff_roles(id) on delete set null,
  unique (school_id, name)
);

create index if not exists idx_staff_roles_school on public.staff_roles (school_id);

create table if not exists public.staff_role_permissions (
  staff_role_id      uuid not null references public.staff_roles(id) on delete cascade,
  permission_key     text not null,
  sub_permission_key text not null,
  primary key (staff_role_id, permission_key, sub_permission_key)
);

-- Rattachement d'un employe a son role.
alter table public.users add column if not exists staff_role_id uuid
  references public.staff_roles(id) on delete set null;

-- 3. Fonction d'autorisation (appelee par les policies RLS) ------------------
--    SECURITY DEFINER : contourne la RLS pour lire users/staff_roles sans boucle.

create or replace function public.has_permission(uid uuid, p_key text, p_sub text)
returns boolean
language sql
stable
security definer
as $fn$
  select exists (
    select 1
    from public.users u
    join public.staff_roles r on r.id = u.staff_role_id
    where u.auth_uid = uid
      and (
        r.is_admin_role
        or exists (
          select 1 from public.staff_role_permissions srp
          where srp.staff_role_id      = r.id
            and srp.permission_key     = p_key
            and srp.sub_permission_key = p_sub
        )
      )
  );
$fn$;

-- 4. Securite (RLS) ----------------------------------------------------------

alter table public.permission_catalog        enable row level security;
alter table public.sub_permission_catalog    enable row level security;
alter table public.role_templates            enable row level security;
alter table public.role_template_permissions enable row level security;
alter table public.staff_roles               enable row level security;
alter table public.staff_role_permissions    enable row level security;

-- Catalogue de reference : lecture ouverte (aucune donnee sensible).
drop policy if exists "Lecture publique" on public.permission_catalog;
create policy "Lecture publique" on public.permission_catalog        for select using (true);
drop policy if exists "Lecture publique" on public.sub_permission_catalog;
create policy "Lecture publique" on public.sub_permission_catalog    for select using (true);
drop policy if exists "Lecture publique" on public.role_templates;
create policy "Lecture publique" on public.role_templates            for select using (true);
drop policy if exists "Lecture publique" on public.role_template_permissions;
create policy "Lecture publique" on public.role_template_permissions for select using (true);

-- Roles d'une ecole : lecture par ses membres, ecriture par qui detient
-- la sous-permission utilisateurs.gerer_roles (ou un role admin).
drop policy if exists "Voir les roles de son ecole" on public.staff_roles;
create policy "Voir les roles de son ecole" on public.staff_roles
  for select using (school_id = public.user_school_id(auth.uid()));

drop policy if exists "Gerer les roles (admin/permission dediee)" on public.staff_roles;
create policy "Gerer les roles (admin/permission dediee)" on public.staff_roles
  for all
  using      (school_id = public.user_school_id(auth.uid())
              and public.has_permission(auth.uid(), 'utilisateurs', 'gerer_roles'))
  with check (school_id = public.user_school_id(auth.uid())
              and public.has_permission(auth.uid(), 'utilisateurs', 'gerer_roles'));

drop policy if exists "Voir permissions des roles de son ecole" on public.staff_role_permissions;
create policy "Voir permissions des roles de son ecole" on public.staff_role_permissions
  for select using (staff_role_id in (
    select id from public.staff_roles where school_id = public.user_school_id(auth.uid())));

drop policy if exists "Gerer permissions des roles (admin/permission dediee)" on public.staff_role_permissions;
create policy "Gerer permissions des roles (admin/permission dediee)" on public.staff_role_permissions
  for all
  using      (staff_role_id in (select id from public.staff_roles
                where school_id = public.user_school_id(auth.uid()))
              and public.has_permission(auth.uid(), 'utilisateurs', 'gerer_roles'))
  with check (staff_role_id in (select id from public.staff_roles
                where school_id = public.user_school_id(auth.uid()))
              and public.has_permission(auth.uid(), 'utilisateurs', 'gerer_roles'));

-- 5. Catalogue de reference (seed) -------------------------------------------

insert into public.permission_catalog (key, label, order_num) values
  ('eleves', 'Élèves', 1),
  ('comptabilite', 'Comptabilité', 2),
  ('notes', 'Notes', 3),
  ('presences', 'Présences', 4),
  ('classes', 'Classes', 5),
  ('emploi_du_temps', 'Emploi du temps', 6),
  ('utilisateurs', 'Utilisateurs & rôles', 7),
  ('rapports', 'Rapports', 8),
  ('messages', 'Messages', 9),
  ('parametres', 'Paramètres école', 10)
on conflict (key) do update set label = excluded.label, order_num = excluded.order_num;

insert into public.sub_permission_catalog (permission_key, key, label, order_num) values
  ('classes', 'voir', 'Voir', 1),
  ('classes', 'creer', 'Créer', 2),
  ('classes', 'modifier', 'Modifier', 3),
  ('classes', 'supprimer', 'Supprimer', 4),
  ('classes', 'assigner_prof', 'Assigner professeur', 5),
  ('comptabilite', 'voir_paiements', 'Voir paiements', 1),
  ('comptabilite', 'enregistrer_paiement', 'Enregistrer paiement', 2),
  ('comptabilite', 'creer_facture', 'Créer facture', 3),
  ('comptabilite', 'modifier_facture', 'Modifier facture', 4),
  ('comptabilite', 'supprimer_facture', 'Supprimer facture', 5),
  ('comptabilite', 'rapports', 'Rapports', 6),
  ('comptabilite', 'exporter', 'Exporter', 7),
  ('comptabilite', 'plans_facturation', 'Plans de facturation', 8),
  ('eleves', 'voir', 'Voir', 1),
  ('eleves', 'ajouter', 'Ajouter', 2),
  ('eleves', 'modifier', 'Modifier', 3),
  ('eleves', 'supprimer', 'Supprimer', 4),
  ('eleves', 'dossier_complet', 'Dossier complet', 5),
  ('emploi_du_temps', 'voir', 'Voir', 1),
  ('emploi_du_temps', 'creer', 'Créer', 2),
  ('emploi_du_temps', 'modifier', 'Modifier', 3),
  ('messages', 'voir', 'Voir', 1),
  ('messages', 'envoyer', 'Envoyer', 2),
  ('messages', 'diffusion', 'Diffusion', 3),
  ('notes', 'voir', 'Voir', 1),
  ('notes', 'saisir', 'Saisir', 2),
  ('notes', 'modifier', 'Modifier', 3),
  ('notes', 'supprimer', 'Supprimer', 4),
  ('notes', 'publier', 'Publier', 5),
  ('notes', 'exporter', 'Exporter', 6),
  ('parametres', 'voir', 'Voir', 1),
  ('parametres', 'modifier', 'Modifier', 2),
  ('parametres', 'ecole', 'École', 3),
  ('presences', 'voir', 'Voir', 1),
  ('presences', 'saisir', 'Saisir', 2),
  ('presences', 'modifier', 'Modifier', 3),
  ('presences', 'rapports', 'Rapports', 4),
  ('rapports', 'voir', 'Voir', 1),
  ('rapports', 'creer', 'Créer', 2),
  ('rapports', 'exporter', 'Exporter', 3),
  ('utilisateurs', 'voir', 'Voir', 1),
  ('utilisateurs', 'creer', 'Créer', 2),
  ('utilisateurs', 'modifier', 'Modifier', 3),
  ('utilisateurs', 'supprimer', 'Supprimer', 4),
  ('utilisateurs', 'gerer_roles', 'Gérer les rôles', 5)
on conflict (permission_key, key) do update set label = excluded.label, order_num = excluded.order_num;

insert into public.role_templates (id, cycle, name, description, order_num, level, color, icon_key) values
  ('4e5ebeb3-1b45-4e04-ba9f-31136ac3ac90', 'college', 'Principal', 'Chef d''établissement — accès total', 1, 'Direction', '#8B1A00', 'gavel'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'college', 'Surveillant Général', 'Discipline, présences, vie scolaire', 2, 'Administration', '#9B5DE0', 'visibility'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'college', 'Secrétaire', 'Élèves, courrier, emploi du temps', 3, 'Pédagogique', '#D4540A', 'folder'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'college', 'Comptable / Économe', 'Finances, factures, paiements', 4, 'Pédagogique', '#D4540A', 'payments'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'college', 'Enseignant', 'Notes, présences de ses classes', 5, 'Support / Famille', '#C17F24', 'school'),
  ('faa21357-8b41-4510-b6ba-9b908e56f3d1', 'lycee', 'Proviseur', 'Chef d''établissement — accès total', 1, 'Direction', '#8B1A00', 'gavel'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'lycee', 'Censeur / Proviseur-adjoint', 'Second du proviseur — pédagogie & discipline', 2, 'Administration', '#9B5DE0', 'shield'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'lycee', 'Surveillant Général', 'Discipline, présences, vie scolaire', 3, 'Administration', '#9B5DE0', 'visibility'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'lycee', 'Secrétaire', 'Élèves, courrier, emploi du temps', 4, 'Pédagogique', '#D4540A', 'folder'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'lycee', 'Comptable / Économe', 'Finances, factures, paiements', 5, 'Pédagogique', '#D4540A', 'payments'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'lycee', 'Enseignant', 'Notes, présences de ses classes', 6, 'Support / Famille', '#C17F24', 'school'),
  ('a5a04fce-c183-4163-9960-eba6ed18eddf', 'primaire', 'Directeur', 'Chef d''établissement — accès total', 1, 'Direction', '#8B1A00', 'gavel'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'primaire', 'Secrétaire', 'Élèves, courrier, emploi du temps', 2, 'Pédagogique', '#D4540A', 'folder'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'primaire', 'Comptable', 'Finances, factures, paiements', 3, 'Pédagogique', '#D4540A', 'payments'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'primaire', 'Enseignant', 'Notes, présences de sa classe', 4, 'Support / Famille', '#C17F24', 'school'),
  ('d8245092-c5d0-4dd0-9cd7-2042858065d4', 'universite', 'Recteur', 'Chef d''établissement — accès total', 1, 'Direction', '#8B1A00', 'gavel'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'universite', 'Doyen', 'Responsable de faculté — pédagogie', 2, 'Administration', '#9B5DE0', 'shield'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'universite', 'Secrétaire Académique', 'Élèves, emploi du temps, dossiers', 3, 'Pédagogique', '#D4540A', 'folder'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'universite', 'Agent Comptable', 'Finances, factures, paiements', 4, 'Pédagogique', '#D4540A', 'payments'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'universite', 'Enseignant-Chercheur', 'Notes, présences de ses cours', 5, 'Support / Famille', '#C17F24', 'school')
on conflict (cycle, name) do nothing;

insert into public.role_template_permissions (role_template_id, permission_key, sub_permission_key) values
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'classes', 'creer'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'classes', 'modifier'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'classes', 'voir'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'eleves', 'ajouter'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'eleves', 'dossier_complet'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'eleves', 'modifier'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'eleves', 'voir'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'emploi_du_temps', 'creer'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'emploi_du_temps', 'modifier'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'emploi_du_temps', 'voir'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'messages', 'envoyer'),
  ('0cf8e223-217c-4e9e-958a-ff26605cb3a1', 'messages', 'voir'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'creer_facture'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'enregistrer_paiement'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'exporter'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'modifier_facture'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'rapports'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'comptabilite', 'voir_paiements'),
  ('16b815be-a642-4b6d-a289-00e3d4c616e2', 'eleves', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'classes', 'assigner_prof'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'classes', 'creer'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'classes', 'modifier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'classes', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'eleves', 'ajouter'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'eleves', 'dossier_complet'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'eleves', 'modifier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'eleves', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'emploi_du_temps', 'creer'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'emploi_du_temps', 'modifier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'emploi_du_temps', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'notes', 'exporter'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'notes', 'modifier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'notes', 'publier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'notes', 'saisir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'notes', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'presences', 'modifier'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'presences', 'rapports'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'presences', 'saisir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'presences', 'voir'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'rapports', 'creer'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'rapports', 'exporter'),
  ('1cb6e6e3-f3a7-4ad0-9e09-e1ff88789c56', 'rapports', 'voir'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'creer_facture'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'enregistrer_paiement'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'exporter'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'modifier_facture'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'rapports'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'comptabilite', 'voir_paiements'),
  ('286c63d1-a51a-4f74-a7f0-56e2da997cab', 'eleves', 'voir'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'classes', 'creer'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'classes', 'modifier'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'classes', 'voir'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'eleves', 'ajouter'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'eleves', 'dossier_complet'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'eleves', 'modifier'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'eleves', 'voir'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'emploi_du_temps', 'creer'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'emploi_du_temps', 'modifier'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'emploi_du_temps', 'voir'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'messages', 'envoyer'),
  ('2d36ec4f-a40a-491e-a1a7-3f28c0daee0c', 'messages', 'voir'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'creer_facture'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'enregistrer_paiement'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'exporter'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'modifier_facture'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'rapports'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'comptabilite', 'voir_paiements'),
  ('634b0ebd-281f-4bee-a95e-2839f37f692e', 'eleves', 'voir'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'classes', 'creer'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'classes', 'modifier'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'classes', 'voir'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'eleves', 'ajouter'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'eleves', 'dossier_complet'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'eleves', 'modifier'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'eleves', 'voir'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'emploi_du_temps', 'creer'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'emploi_du_temps', 'modifier'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'emploi_du_temps', 'voir'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'messages', 'envoyer'),
  ('7489c47f-28e5-46ce-8596-1ca47ca17239', 'messages', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'classes', 'assigner_prof'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'classes', 'creer'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'classes', 'modifier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'classes', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'eleves', 'ajouter'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'eleves', 'dossier_complet'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'eleves', 'modifier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'eleves', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'emploi_du_temps', 'creer'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'emploi_du_temps', 'modifier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'emploi_du_temps', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'notes', 'exporter'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'notes', 'modifier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'notes', 'publier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'notes', 'saisir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'notes', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'presences', 'modifier'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'presences', 'rapports'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'presences', 'saisir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'presences', 'voir'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'rapports', 'creer'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'rapports', 'exporter'),
  ('7f3897d2-20d8-4fc3-8465-c49af6ac07de', 'rapports', 'voir'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'eleves', 'dossier_complet'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'eleves', 'voir'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'messages', 'envoyer'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'messages', 'voir'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'presences', 'modifier'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'presences', 'rapports'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'presences', 'saisir'),
  ('9daa6d96-5213-4a9e-8d1e-9d16ca1f2b66', 'presences', 'voir'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'classes', 'creer'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'classes', 'modifier'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'classes', 'voir'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'eleves', 'ajouter'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'eleves', 'dossier_complet'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'eleves', 'modifier'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'eleves', 'voir'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'emploi_du_temps', 'creer'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'emploi_du_temps', 'modifier'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'emploi_du_temps', 'voir'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'messages', 'envoyer'),
  ('9e0355e4-8583-4d6c-a5d7-7a1819c8ce2f', 'messages', 'voir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'eleves', 'voir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'emploi_du_temps', 'voir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'notes', 'modifier'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'notes', 'publier'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'notes', 'saisir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'notes', 'voir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'presences', 'saisir'),
  ('c20390bf-7f3e-4f71-9546-1abb4771404d', 'presences', 'voir'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'eleves', 'dossier_complet'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'eleves', 'voir'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'messages', 'envoyer'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'messages', 'voir'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'presences', 'modifier'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'presences', 'rapports'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'presences', 'saisir'),
  ('c9571ee1-263d-47c8-822a-c8f3a5d9e6db', 'presences', 'voir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'eleves', 'voir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'emploi_du_temps', 'voir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'notes', 'modifier'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'notes', 'publier'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'notes', 'saisir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'notes', 'voir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'presences', 'saisir'),
  ('e29bf605-61b7-4b94-816e-deba43a19283', 'presences', 'voir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'eleves', 'voir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'emploi_du_temps', 'voir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'notes', 'modifier'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'notes', 'publier'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'notes', 'saisir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'notes', 'voir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'presences', 'saisir'),
  ('e588d932-7684-4f7f-a59c-01a215f97f9f', 'presences', 'voir'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'creer_facture'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'enregistrer_paiement'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'exporter'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'modifier_facture'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'rapports'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'comptabilite', 'voir_paiements'),
  ('e851d837-9594-4e01-a5c6-86f06a37ff70', 'eleves', 'voir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'eleves', 'voir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'emploi_du_temps', 'voir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'notes', 'modifier'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'notes', 'publier'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'notes', 'saisir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'notes', 'voir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'presences', 'saisir'),
  ('fe662a6b-b4f0-4787-9ff5-b6109a8280b6', 'presences', 'voir')
on conflict do nothing;
