-- ============================================================================
--  20260749_report_cards_generated_at.sql — horodater le snapshot cote SERVEUR
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  L'ecran de cloture doit savoir si une note corrigee DEPUIS la generation est
--  deja reportee dans le bulletin officiel. Il compare pour cela deux dates :
--
--    grades.updated_at    -- horodatee par le SERVEUR (now())
--    report_cards.generated_at
--
--  Or `generated_at` etait pose par le CLIENT (DateTime.now() cote Dart). Deux
--  horloges differentes : un poste en retard sur le serveur laisserait le bouton
--  « Appliquer les corrections » actif a tort (ou l'inverse). Pour comparer deux
--  instants, il faut une seule horloge — celle du serveur.
--
--  ── Ce que fait cette etape ─────────────────────────────────────────────────
--
--  Un trigger BEFORE INSERT OR UPDATE pose `generated_at = now()` a chaque
--  ecriture du snapshot. Le client n'a plus a l'envoyer ; meme s'il l'envoie, le
--  serveur ecrase. Les deux dates comparees sont desormais sur la meme horloge.
-- ============================================================================

create or replace function public.stamp_report_card_generated_at()
returns trigger
language plpgsql
as $fn$
begin
  new.generated_at := now();
  return new;
end;
$fn$;

drop trigger if exists trg_stamp_report_card_generated_at on public.report_cards;
create trigger trg_stamp_report_card_generated_at
  before insert or update on public.report_cards
  for each row execute function public.stamp_report_card_generated_at();

-- ============================================================================
--  VERIFICATION :
--    -- Regenerez un bulletin, puis :
--    select student_name, generated_at from public.report_cards
--     order by generated_at desc limit 5;   -- generated_at ~ maintenant (serveur)
-- ============================================================================
