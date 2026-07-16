-- Ajoute branch_id sur school_classes pour le multi-campus.
-- Optionnel (nullable) : les écoles sans filiales ont branch_id = null.
ALTER TABLE public.school_classes
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.school_branches(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_school_classes_branch_id ON public.school_classes (branch_id);
