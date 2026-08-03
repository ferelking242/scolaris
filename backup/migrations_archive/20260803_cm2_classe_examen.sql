-- ─────────────────────────────────────────────────────────────────────────────
-- Repère le CM2 comme classe d'examen (CEPE — certificat de fin d'études
-- primaires), système francophone_africa (le seul avec des écoles actives à
-- ce jour). `class_levels.metadata` (jsonb) existe déjà — pas de migration
-- de schéma nécessaire, juste une valeur de référence en plus.
--
-- ⚠️ Appliqué en direct via `supabase db query --linked` — vérifié avant
-- exécution que la ligne CM2/francophone_africa/primaire avait bien
-- metadata = null (pas d'écrasement silencieux d'une valeur existante).
-- ─────────────────────────────────────────────────────────────────────────────

update public.class_levels
set metadata = coalesce(metadata, '{}'::jsonb) || '{"exam": "CEPE"}'::jsonb
where system_type = 'francophone_africa'
  and cycle = 'primaire'
  and name = 'CM2';
