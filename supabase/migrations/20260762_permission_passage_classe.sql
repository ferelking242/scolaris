-- ============================================================================
--  20260762_permission_passage_classe.sql — Permission dédiée : Passage de
--  classe & sortie d'élève
--
--  Jusqu'ici, la page « Passage de classe » (décision de fin d'année : classe
--  supérieure / redoublement / sortie) était protégée par la permission
--  générale `students` ("Élèves & inscriptions") — tout membre du personnel
--  pouvant gérer les fiches élèves au quotidien pouvait aussi prendre cette
--  décision annuelle, sans distinction. Un comptable (preset "Comptable" :
--  finance+reports) n'y avait PAS accès, un enseignant non plus (rôle
--  `teacher`, aucun accès à l'espace admin) — mais un secrétaire (preset
--  students+classes+timetable) si, sans que ce soit un choix explicite.
--
--  On ajoute donc une sous-permission dédiée dans le catalogue fin
--  (`eleves.passage_classe`), pour que l'admin puisse la donner/retirer
--  indépendamment depuis « Rôles & permissions ». Backfill : tout membre qui
--  avait déjà `students` (coarse) garde l'accès (cf. StaffPermissions côté
--  Dart, clé `promotion`) — sinon on retirerait silencieusement un accès déjà
--  utilisé.
--
--  Idempotent. Rejouable.
-- ============================================================================

insert into public.sub_permission_catalog (permission_key, key, label, order_num) values
  ('eleves', 'passage_classe', 'Passage de classe & sortie', 6)
on conflict (permission_key, key) do update set label = excluded.label, order_num = excluded.order_num;

-- Backfill : quiconque a déjà la permission plate `students` reçoit aussi la
-- nouvelle clé plate `promotion` — sans ça, ce changement retirerait
-- silencieusement l'accès à des membres qui l'utilisaient déjà.
update public.users
   set permissions = permissions || '["promotion"]'::jsonb
 where permissions @> '["students"]'::jsonb
   and not permissions @> '["promotion"]'::jsonb
   and not permissions @> '["*"]'::jsonb;

-- ============================================================================
--  VERIFICATION :
--    select key, label from public.sub_permission_catalog where permission_key = 'eleves';
--    select id, full_name, permissions from public.users where permissions @> '["promotion"]'::jsonb;
-- ============================================================================
