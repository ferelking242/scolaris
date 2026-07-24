-- ============================================================================
--  20260768_remove_qr_feature.sql — Retrait de la feature "qr" (Cartes QR) de
--  tous les plans
--
--  Décision produit : le QR code (carte étudiante, pointage de présence,
--  QR de pré-inscription) ne sert à rien pour l'instant côté app — tout le
--  frontend correspondant a été retiré. On retire la clé "qr" du tableau
--  `plans.features` pour que le catalogue d'offres reflète la réalité.
--
--  Idempotent. Rejouable (`-` sur un tableau sans l'élément ne fait rien).
-- ============================================================================

update public.plans
   set features = features - 'qr'
 where features @> '["qr"]'::jsonb;

-- ============================================================================
--  VERIFICATION :
--    select code, features from public.plans where features @> '["qr"]'::jsonb;
--    -- doit renvoyer 0 ligne.
-- ============================================================================
