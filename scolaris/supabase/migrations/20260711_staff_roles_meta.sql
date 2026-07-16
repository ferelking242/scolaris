-- ============================================================
-- SCOLARIS — Métadonnées visuelles des rôles (niveau hiérarchique,
-- couleur, icône) pour l'organigramme de la page Rôles & permissions.
-- Additif uniquement, ne casse rien de l'existant.
-- ============================================================

ALTER TABLE public.role_templates ADD COLUMN IF NOT EXISTS level text NOT NULL DEFAULT 'Pédagogique';
ALTER TABLE public.role_templates ADD COLUMN IF NOT EXISTS color text NOT NULL DEFAULT '#8B1A00';
ALTER TABLE public.role_templates ADD COLUMN IF NOT EXISTS icon_key text NOT NULL DEFAULT 'badge';
ALTER TABLE public.role_templates ADD COLUMN IF NOT EXISTS parent_template_id uuid REFERENCES public.role_templates(id) ON DELETE SET NULL;

ALTER TABLE public.staff_roles ADD COLUMN IF NOT EXISTS level text NOT NULL DEFAULT 'Pédagogique';
ALTER TABLE public.staff_roles ADD COLUMN IF NOT EXISTS color text NOT NULL DEFAULT '#8B1A00';
ALTER TABLE public.staff_roles ADD COLUMN IF NOT EXISTS icon_key text NOT NULL DEFAULT 'badge';
ALTER TABLE public.staff_roles ADD COLUMN IF NOT EXISTS parent_role_id uuid REFERENCES public.staff_roles(id) ON DELETE SET NULL;

-- Niveaux : 'Direction' | 'Administration' | 'Pédagogique' | 'Support / Famille'
UPDATE public.role_templates SET level = 'Direction', color = '#8B1A00', icon_key = 'gavel'
  WHERE name IN ('Proviseur','Principal','Directeur','Recteur');
UPDATE public.role_templates SET level = 'Administration', color = '#9B5DE0', icon_key = 'shield'
  WHERE name IN ('Censeur / Proviseur-adjoint','Doyen');
UPDATE public.role_templates SET level = 'Administration', color = '#9B5DE0', icon_key = 'visibility'
  WHERE name = 'Surveillant Général';
UPDATE public.role_templates SET level = 'Pédagogique', color = '#D4540A', icon_key = 'folder'
  WHERE name IN ('Secrétaire','Secrétaire Académique');
UPDATE public.role_templates SET level = 'Pédagogique', color = '#D4540A', icon_key = 'payments'
  WHERE name IN ('Comptable / Économe','Comptable','Agent Comptable');
UPDATE public.role_templates SET level = 'Support / Famille', color = '#C17F24', icon_key = 'school'
  WHERE name IN ('Enseignant','Enseignant-Chercheur');
