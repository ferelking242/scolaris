-- ============================================================================
--  20260720_school_currency_grading.sql — Devise et bareme de l'ecole
--
--  Deux choses etaient codees en dur dans l'app, et elles interdisent tout
--  deploiement hors zone franc CFA :
--
--  • « FCFA » apparait en dur dans 11 fichiers. Une ecole nigeriane verrait ses
--    frais de scolarite libelles en FCFA au lieu de nairas.
--
--  • Le bareme « /20 » est fige. Or le Nigeria, le Ghana et le Kenya notent en
--    lettres (A–F) ou sur 100. Un bulletin nigerian affichant « 14/20 » ne veut
--    rien dire la-bas.
--
--  Ces deux reglages appartiennent a l'ECOLE, pas au code.
--
--  Ne concerne PAS les prix de la plateforme (plans Simple/Pro/Max) : ceux-la
--  sont les prix du vendeur, deja declinables par pays via plan_prices.country.
-- ============================================================================

-- Code ISO 4217. XAF = franc CFA d'Afrique centrale (Congo, Cameroun, Gabon…).
alter table public.schools
  add column if not exists currency text not null default 'XAF';

-- Bareme de notation :
--   'numeric_20'  → note sur 20   (francophone)
--   'numeric_100' → note sur 100  (anglophone : Nigeria, Ghana…)
--   'letter'      → lettres A–F   (anglophone : Kenya, Afrique du Sud…)
alter table public.schools
  add column if not exists grading_scale text not null default 'numeric_20'
  check (grading_scale in ('numeric_20', 'numeric_100', 'letter'));

comment on column public.schools.currency is
  'Code ISO 4217 (XAF, XOF, NGN, GHS, KES, MAD, EUR, USD…). Affichage des frais,
   factures, paiements et recus. Ne concerne pas les prix de la plateforme.';

comment on column public.schools.grading_scale is
  'Bareme des notes : numeric_20 | numeric_100 | letter.';

-- ── Reprise de l'existant ───────────────────────────────────────────────────
--  Toutes les ecoles actuelles sont en zone CFA et notent sur 20 : les valeurs
--  par defaut sont deja les bonnes. On aligne quand meme la devise sur le pays,
--  pour les ecoles hors zone centrale.

-- ── Incoherence de defauts ──────────────────────────────────────────────────
--  fee_structures.currency avait pour defaut 'XAF' (franc CFA), mais
--  invoices.currency avait 'CDF' (franc congolais, RDC). Deux monnaies
--  differentes : une facture ecrite sans devise explicite ne parlait pas la meme
--  langue que la grille de frais dont elle decoule.
--
--  Le code Dart passait toujours 'XAF' explicitement, donc le defaut ne se
--  declenchait jamais — mais c'etait une mine : toute ecriture passant a cote
--  (script, console, futur Edge Function) produisait une facture en CDF.
--
--  Les deux colonnes n'ont plus de defaut du tout : la devise vient de l'ecole,
--  et l'appelant DOIT la fournir. Un oubli echoue franchement au lieu de
--  produire une facture dans la mauvaise monnaie.

alter table public.invoices       alter column currency drop default;
alter table public.fee_structures alter column currency drop default;

update public.schools
   set currency = case country
     when 'CD' then 'CDF'   -- RD Congo : franc congolais
     when 'CI' then 'XOF'   -- zone UEMOA (Afrique de l'Ouest)
     when 'SN' then 'XOF'
     when 'BF' then 'XOF'
     when 'ML' then 'XOF'
     when 'BJ' then 'XOF'
     when 'TG' then 'XOF'
     when 'NE' then 'XOF'
     when 'GN' then 'GNF'
     when 'NG' then 'NGN'
     when 'GH' then 'GHS'
     when 'KE' then 'KES'
     when 'ZA' then 'ZAR'
     when 'MA' then 'MAD'
     when 'DZ' then 'DZD'
     when 'TN' then 'TND'
     when 'FR' then 'EUR'
     else 'XAF'             -- CG, CM, GA, TD, CF, GQ : franc CFA central
   end
 where currency = 'XAF';
