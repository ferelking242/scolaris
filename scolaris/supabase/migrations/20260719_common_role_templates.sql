-- ============================================================================
--  20260719_common_role_templates.sql — Un jeu de roles UNIQUE, sans cycle
--
--  Le catalogue etait decoupe par cycle : 20 modeles (5 pour le primaire, 5 pour
--  le college, 6 pour le lycee, 5 pour l'universite). L'app n'en retenait qu'UN
--  seul cycle — le plus eleve — via cycleFromTypes().
--
--  Deux consequences :
--
--  1. Un COMPLEXE SCOLAIRE (primaire + college + lycee, le cas le plus courant au
--     Congo) etait traite comme un simple lycee : on proposait Proviseur et
--     Censeur, jamais le Directeur du primaire ni le Principal du college.
--
--  2. Le decoupage ne servait a rien. Un secretaire est un secretaire, au
--     primaire comme au lycee : memes permissions, ligne pour ligne. Verifie —
--     les jeux de grants sont IDENTIQUES d'un cycle a l'autre. Seul le nom du
--     chef changeait (Directeur / Principal / Proviseur / Recteur), et c'est du
--     vocabulaire, pas de la securite : le chef porte is_admin_role, qui donne
--     tout, quel que soit son titre.
--
--  On garde donc SIX roles, cycle = 'commun', tous renommables. Un lycee qui
--  tient a « Proviseur » renomme son chef d'etablissement en trois secondes.
--
--  Les modeles par cycle sont conserves (ecoles qui les ont deja instancies),
--  mais l'app ne les propose plus.
-- ============================================================================

insert into public.role_templates
  (id, cycle, name, description, order_num, level, color, icon_key)
values
  ('11111111-0000-4000-8000-000000000001', 'commun', 'Chef d''établissement',
   'Direction de l''école — accès total. Renommez-le selon votre établissement : Directeur, Principal, Proviseur, Recteur.',
   1, 'Direction', '#8B1A00', 'gavel'),

  ('11111111-0000-4000-8000-000000000002', 'commun', 'Adjoint',
   'Second de la direction — pédagogie, classes, notes et discipline. (Censeur, Proviseur-adjoint, Doyen…)',
   2, 'Administration', '#9B5DE0', 'shield'),

  ('11111111-0000-4000-8000-000000000003', 'commun', 'Surveillant',
   'Vie scolaire : présences, discipline, contact avec les familles.',
   3, 'Administration', '#9B5DE0', 'visibility'),

  ('11111111-0000-4000-8000-000000000004', 'commun', 'Secrétaire',
   'Élèves, inscriptions, courrier, emploi du temps.',
   4, 'Pédagogique', '#D4540A', 'folder'),

  ('11111111-0000-4000-8000-000000000005', 'commun', 'Comptable',
   'Finances : factures, paiements, rapports. (Économe, Agent comptable…)',
   5, 'Pédagogique', '#D4540A', 'payments'),

  ('11111111-0000-4000-8000-000000000006', 'commun', 'Enseignant',
   'Notes et présences de ses classes.',
   6, 'Support / Famille', '#C17F24', 'school')
on conflict (cycle, name) do update
  set description = excluded.description,
      order_num   = excluded.order_num,
      level       = excluded.level,
      color       = excluded.color,
      icon_key    = excluded.icon_key;

-- ── Permissions ─────────────────────────────────────────────────────────────
--  Reprises telles quelles des modeles existants : ce sont exactement les memes
--  d'un cycle a l'autre. Le « Chef d'etablissement » n'en a aucune : son acces
--  vient de is_admin_role, pose a la creation du role (level = 'Direction').

delete from public.role_template_permissions
 where role_template_id in (
   select id from public.role_templates where cycle = 'commun');

insert into public.role_template_permissions
  (role_template_id, permission_key, sub_permission_key)
values
  -- Adjoint (23)
  ('11111111-0000-4000-8000-000000000002', 'classes', 'assigner_prof'),
  ('11111111-0000-4000-8000-000000000002', 'classes', 'creer'),
  ('11111111-0000-4000-8000-000000000002', 'classes', 'modifier'),
  ('11111111-0000-4000-8000-000000000002', 'classes', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'eleves', 'ajouter'),
  ('11111111-0000-4000-8000-000000000002', 'eleves', 'dossier_complet'),
  ('11111111-0000-4000-8000-000000000002', 'eleves', 'modifier'),
  ('11111111-0000-4000-8000-000000000002', 'eleves', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'emploi_du_temps', 'creer'),
  ('11111111-0000-4000-8000-000000000002', 'emploi_du_temps', 'modifier'),
  ('11111111-0000-4000-8000-000000000002', 'emploi_du_temps', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'exporter'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'modifier'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'publier'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'saisir'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'presences', 'modifier'),
  ('11111111-0000-4000-8000-000000000002', 'presences', 'rapports'),
  ('11111111-0000-4000-8000-000000000002', 'presences', 'saisir'),
  ('11111111-0000-4000-8000-000000000002', 'presences', 'voir'),
  ('11111111-0000-4000-8000-000000000002', 'rapports', 'creer'),
  ('11111111-0000-4000-8000-000000000002', 'rapports', 'exporter'),
  ('11111111-0000-4000-8000-000000000002', 'rapports', 'voir'),

  -- Surveillant (8)
  ('11111111-0000-4000-8000-000000000003', 'eleves', 'dossier_complet'),
  ('11111111-0000-4000-8000-000000000003', 'eleves', 'voir'),
  ('11111111-0000-4000-8000-000000000003', 'messages', 'envoyer'),
  ('11111111-0000-4000-8000-000000000003', 'messages', 'voir'),
  ('11111111-0000-4000-8000-000000000003', 'presences', 'modifier'),
  ('11111111-0000-4000-8000-000000000003', 'presences', 'rapports'),
  ('11111111-0000-4000-8000-000000000003', 'presences', 'saisir'),
  ('11111111-0000-4000-8000-000000000003', 'presences', 'voir'),

  -- Secrétaire (12)
  ('11111111-0000-4000-8000-000000000004', 'classes', 'creer'),
  ('11111111-0000-4000-8000-000000000004', 'classes', 'modifier'),
  ('11111111-0000-4000-8000-000000000004', 'classes', 'voir'),
  ('11111111-0000-4000-8000-000000000004', 'eleves', 'ajouter'),
  ('11111111-0000-4000-8000-000000000004', 'eleves', 'dossier_complet'),
  ('11111111-0000-4000-8000-000000000004', 'eleves', 'modifier'),
  ('11111111-0000-4000-8000-000000000004', 'eleves', 'voir'),
  ('11111111-0000-4000-8000-000000000004', 'emploi_du_temps', 'creer'),
  ('11111111-0000-4000-8000-000000000004', 'emploi_du_temps', 'modifier'),
  ('11111111-0000-4000-8000-000000000004', 'emploi_du_temps', 'voir'),
  ('11111111-0000-4000-8000-000000000004', 'messages', 'envoyer'),
  ('11111111-0000-4000-8000-000000000004', 'messages', 'voir'),

  -- Comptable (7)
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'creer_facture'),
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'enregistrer_paiement'),
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'exporter'),
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'modifier_facture'),
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'rapports'),
  ('11111111-0000-4000-8000-000000000005', 'comptabilite', 'voir_paiements'),
  ('11111111-0000-4000-8000-000000000005', 'eleves', 'voir'),

  -- Enseignant (8)
  ('11111111-0000-4000-8000-000000000006', 'eleves', 'voir'),
  ('11111111-0000-4000-8000-000000000006', 'emploi_du_temps', 'voir'),
  ('11111111-0000-4000-8000-000000000006', 'notes', 'modifier'),
  ('11111111-0000-4000-8000-000000000006', 'notes', 'publier'),
  ('11111111-0000-4000-8000-000000000006', 'notes', 'saisir'),
  ('11111111-0000-4000-8000-000000000006', 'notes', 'voir'),
  ('11111111-0000-4000-8000-000000000006', 'presences', 'saisir'),
  ('11111111-0000-4000-8000-000000000006', 'presences', 'voir')
on conflict do nothing;
