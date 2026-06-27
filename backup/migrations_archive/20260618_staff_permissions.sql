-- Permissions granulaires du personnel (modèle par capacités).
-- Chaque membre du staff porte une liste de clés de permissions (jsonb), ex :
--   ["students","classes","communication"]
-- La clé spéciale "*" = accès total (Direction / fondateur).
-- Les rôles teacher/student/parent n'utilisent PAS ce champ (accès par rôle).

alter table public.users
  add column if not exists permissions jsonb not null default '[]'::jsonb;

-- Titre affiché du membre (ex. « Secrétaire », « Comptable ») — distinct du
-- rôle technique (enum). Permet un libellé propre sans dépendre de l'enum.
alter table public.users
  add column if not exists role_title text;

-- Rétro-compatibilité : aujourd'hui TOUT le personnel a un accès total. On le
-- préserve en donnant "*" au personnel existant (seules les lignes encore au
-- défaut '[]' sont touchées → idempotent). L'admin pourra ensuite restreindre.
update public.users
set permissions = '["*"]'::jsonb
where permissions = '[]'::jsonb
  and lower(role::text) in (
    'staff','staff_custom','admin','secretaire','secretariat',
    'dg','directeur','direction','surveillance','surveillant',
    'finance','comptable'
  );
