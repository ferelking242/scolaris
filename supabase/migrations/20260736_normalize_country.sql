-- ============================================================================
--  20260736_normalize_country.sql — Le pays est un CODE, pas une phrase
--
--  Constate en base :
--
--      name                              country
--      Collège Saint-François de Sales   Congo
--      Université Denis Sassou Nguesso   Congo
--      Lumière du savoir                 congo      ← minuscule
--      Lycée Savorgnan de Brazza         Congo
--      École Lumière du Congo            Congo
--
--  `schools.country` contient du TEXTE LIBRE, pas le code ISO 3166 attendu.
--  Trois choses s'appuient pourtant dessus, et toutes les trois echouent en
--  silence :
--
--   1. LA DEVISE. `20260720` faisait `case country when 'CD' then 'CDF' ...`.
--      Aucune ligne n'a jamais matche : toutes les ecoles sont restees en XAF.
--      Par chance, c'est la bonne valeur pour le Congo-Brazzaville. Une ecole
--      kinoise aurait facture en francs CFA au lieu de francs congolais.
--
--   2. LE SYSTEME EDUCATIF. « francophone » designe le programme francais en
--      France et le programme africain au Congo : la distinction se fait sur
--      'FR'. « Congo » n'etant pas « FR », on retombe sur l'africain — juste,
--      mais par accident.
--
--   3. LE CATALOGUE DES NIVEAUX, qui en decoule.
--
--  Un defaut qui ne se voit pas parce qu'il donne la bonne reponse pour la
--  mauvaise raison est le plus dangereux de tous : il attend le premier client
--  etranger pour se manifester.
-- ============================================================================

-- ── 1. Normaliser l'existant ────────────────────────────────────────────────
--  On ne devine pas : on traduit les noms effectivement rencontres, et on laisse
--  intact ce qu'on ne reconnait pas (mieux vaut une valeur suspecte qu'une
--  valeur fausse).

update public.schools
   set country = case lower(trim(country))
     when 'congo'                then 'CG'
     when 'congo-brazzaville'    then 'CG'
     when 'republique du congo'  then 'CG'
     when 'rdc'                  then 'CD'
     when 'congo-kinshasa'       then 'CD'
     when 'rd congo'             then 'CD'
     when 'cameroun'             then 'CM'
     when 'gabon'                then 'GA'
     when 'tchad'                then 'TD'
     when 'senegal'              then 'SN'
     when 'sénégal'              then 'SN'
     when 'cote d''ivoire'       then 'CI'
     when 'côte d''ivoire'       then 'CI'
     when 'mali'                 then 'ML'
     when 'benin'                then 'BJ'
     when 'bénin'                then 'BJ'
     when 'togo'                 then 'TG'
     when 'burkina faso'         then 'BF'
     when 'niger'                then 'NE'
     when 'guinee'               then 'GN'
     when 'guinée'               then 'GN'
     when 'nigeria'              then 'NG'
     when 'ghana'                then 'GH'
     when 'kenya'                then 'KE'
     when 'afrique du sud'       then 'ZA'
     when 'maroc'                then 'MA'
     when 'algerie'              then 'DZ'
     when 'algérie'              then 'DZ'
     when 'tunisie'              then 'TN'
     when 'france'               then 'FR'
     else country               -- deja un code, ou inconnu : on n'invente pas
   end
 where country is not null
   and length(trim(country)) <> 2;   -- un code ISO fait 2 lettres

-- ── 2. Empecher que ca recommence ───────────────────────────────────────────
--  Le formulaire d'inscription ecrivait le nom du pays. Une contrainte le dira
--  franchement au lieu de laisser passer une valeur qui cassera trois calculs
--  plus tard.
alter table public.schools drop constraint if exists schools_country_iso;
alter table public.schools
  add constraint schools_country_iso
  check (country is null or country ~ '^[A-Z]{2}$');

comment on column public.schools.country is
  'Code ISO 3166-1 alpha-2 (CG, CD, CM, NG, FR...). PAS le nom du pays :
   la devise, le systeme educatif et le catalogue des niveaux en dependent.';

-- ── 3. Rejouer le rattrapage des devises, qui n'avait rien rattrape ─────────
update public.schools
   set currency = case country
     when 'CD' then 'CDF'
     when 'CI' then 'XOF' when 'SN' then 'XOF' when 'BF' then 'XOF'
     when 'ML' then 'XOF' when 'BJ' then 'XOF' when 'TG' then 'XOF'
     when 'NE' then 'XOF'
     when 'GN' then 'GNF' when 'NG' then 'NGN' when 'GH' then 'GHS'
     when 'KE' then 'KES' when 'ZA' then 'ZAR' when 'MA' then 'MAD'
     when 'DZ' then 'DZD' when 'TN' then 'TND' when 'FR' then 'EUR'
     else 'XAF'   -- CG, CM, GA, TD, CF, GQ : franc CFA central
   end;

-- ============================================================================
--  VERIFICATION :
--
--    select name, country, currency,
--           metadata->'types' as types,
--           metadata->>'educational_system' as systeme
--      from public.schools;
--
--    -- Attendu : country = 'CG' partout, currency = 'XAF'.
--
--  ⚠ TROIS ECOLES SUR CINQ n'ont ni type ni systeme educatif (null / []). Le
--    formulaire d'inscription ne les enregistre pas toujours. Sans type, une
--    ecole se voit proposer les niveaux du primaire au lycee — ce qui est faux
--    pour l'Universite Denis Sassou Nguesso. A renseigner dans
--    « Paramètres école > Cycles & système éducatif ».
-- ============================================================================
