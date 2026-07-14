-- ============================================================================
--  20260737_seed_class_levels.sql — REMPLIR le catalogue des niveaux
--
--  Constate en base : `class_levels` existe et est VIDE. Le menu deroulant
--  « Niveau » de la creation de classe n'avait donc rien a proposer — ce n'etait
--  ni l'ecole, ni le code.
--
--  Le seed d'origine (20260603) n'a jamais ete applique. Refrain connu : le
--  depot n'est pas la source de verite de la base.
--
--  ⚠ Pourquoi ce fichier plutot que 20260603 : celui-ci commence par un
--    TRUNCATE, qui ECHOUE — `classes` porte une cle etrangere vers
--    `class_levels` (posee en direct, absente du depot). Et un TRUNCATE CASCADE
--    aurait EFFACE LES CLASSES DE TOUTES LES ECOLES.
--
--  Ici : aucune suppression, insertion idempotente. 191 niveaux.
-- ============================================================================


  -- ============================================================
  -- SCOLARIS — Migration : Table de référence class_levels
  -- À appliquer via : Supabase Dashboard > SQL Editor
  -- ============================================================

  -- 1. Création de la table catalogue
  -- ============================================================
  CREATE TABLE IF NOT EXISTS public.class_levels (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_type  text NOT NULL,
    -- 'francophone_africa' | 'francophone_france' | 'anglophone_nigeria'
    -- 'anglophone_ghana' | 'anglophone_kenya' | 'anglophone_cameroon'
    -- 'arabophone' | 'lmd' | 'grande_ecole'

    cycle        text NOT NULL,
    -- 'prescolaire' | 'primaire' | 'college' | 'lycee'
    -- 'universite_l' | 'universite_m' | 'universite_d' | 'prepa'

    cycle_label  text NOT NULL,    -- "Primaire", "Collège", "Lycée", etc.
    name         text NOT NULL,    -- "CP1", "CE1", "6ème", "Form 1", "L1"
    short_name   text NOT NULL,    -- version courte/abrégée
    order_num    integer NOT NULL, -- tri dans le système
    series       text,             -- filière lycée: 'A','C','D','S','ES','STMG'...
    country_hint text[],           -- codes ISO pays où ce niveau est courant
    metadata     jsonb DEFAULT '{}',
    created_at   timestamptz DEFAULT now()
  );

  COMMENT ON TABLE public.class_levels IS
    'Catalogue de référence des niveaux scolaires — toutes filières, tous pays. '
    'Les écoles sélectionnent les niveaux qui leur correspondent lors de l inscription.';

  CREATE INDEX IF NOT EXISTS idx_cl_system ON public.class_levels (system_type);
  CREATE INDEX IF NOT EXISTS idx_cl_cycle  ON public.class_levels (cycle);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_cl_uniq ON public.class_levels (system_type, name, COALESCE(series, ''));

  ALTER TABLE public.class_levels ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS "Lecture publique" ON public.class_levels;
  CREATE POLICY "Lecture publique" ON public.class_levels FOR SELECT USING (true);


  -- 2. PAS de TRUNCATE.
  -- ============================================================
  --  `classes` porte une cle etrangere vers `class_levels` (posee en direct sur
  --  le serveur, absente du depot). Un TRUNCATE echoue, et un TRUNCATE CASCADE
  --  EFFACERAIT LES CLASSES DE TOUTES LES ECOLES.
  --
  --  L'insertion ci-dessous est idempotente : elle s'appuie sur l'index unique
  --  (system_type, name, coalesce(series,'')). Rejouable sans rien detruire.


  -- 3. Insertion du catalogue complet
  -- ============================================================
  INSERT INTO public.class_levels
    (system_type, cycle, cycle_label, name, short_name, order_num, series, country_hint, metadata)
  VALUES

  -- ================================================================
  -- A. SYSTÈME FRANCOPHONE AFRICAIN (Congo, DRC, Cameroun, Sénégal,
  --    Côte d'Ivoire, Gabon, Burkina, Mali, Bénin, Togo, RCA, Tchad…)
  -- ================================================================

  -- Préscolaire
  ('francophone_africa','prescolaire','Préscolaire','Petite Section','PS',1,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD'],  '{"age":"3-4 ans"}'),
  ('francophone_africa','prescolaire','Préscolaire','Moyenne Section','MS',2,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD'],  '{"age":"4-5 ans"}'),
  ('francophone_africa','prescolaire','Préscolaire','Grande Section','GS',3,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD'],   '{"age":"5-6 ans"}'),

  -- Primaire
  ('francophone_africa','primaire','Primaire','CP1','CP1',10,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),
  ('francophone_africa','primaire','Primaire','CP2','CP2',11,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),
  ('francophone_africa','primaire','Primaire','CE1','CE1',12,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),
  ('francophone_africa','primaire','Primaire','CE2','CE2',13,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),
  ('francophone_africa','primaire','Primaire','CM1','CM1',14,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),
  ('francophone_africa','primaire','Primaire','CM2','CM2',15,NULL,ARRAY['CG','CD','CM','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],NULL),

  -- Sénégal a CP, CE1, CE2, CM1, CM2 (pas de CP1/CP2)
  ('francophone_africa','primaire','Primaire','CP','CP',16,NULL,ARRAY['SN','MR'],  '{"note":"utilisé au Sénégal, Mauritanie"}'),
  ('francophone_africa','primaire','Primaire','CI','CI',17,NULL,ARRAY['MG'],       '{"note":"Cours Inférieur — Madagascar"}'),
  ('francophone_africa','primaire','Primaire','CE','CE',18,NULL,ARRAY['MG'],       '{"note":"Cours Élémentaire — Madagascar"}'),
  ('francophone_africa','primaire','Primaire','CM','CM',19,NULL,ARRAY['MG'],       '{"note":"Cours Moyen — Madagascar"}'),

  -- Collège (1er cycle secondaire)
  ('francophone_africa','college','Collège','6ème','6e',20,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE','MG'],NULL),
  ('francophone_africa','college','Collège','5ème','5e',21,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE','MG'],NULL),
  ('francophone_africa','college','Collège','4ème','4e',22,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE','MG'],NULL),
  ('francophone_africa','college','Collège','3ème','3e',23,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE','MG'],NULL),

  -- Lycée Série A — Lettres & Philosophie
  ('francophone_africa','lycee','Lycée','2nde A','2A',30,'A',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Lettres & Philosophie"}'),
  ('francophone_africa','lycee','Lycée','1ère A','1A',31,'A',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Lettres & Philosophie"}'),
  ('francophone_africa','lycee','Lycée','Terminale A','TleA',32,'A',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],'{"label":"Lettres & Philosophie"}'),

  -- Lycée Série B — Économie & Sciences Sociales (Sénégal, Mali…)
  ('francophone_africa','lycee','Lycée','2nde B','2B',33,'B',ARRAY['SN','ML','BF','BJ'], '{"label":"Économie & Sciences Sociales"}'),
  ('francophone_africa','lycee','Lycée','1ère B','1B',34,'B',ARRAY['SN','ML','BF','BJ'], '{"label":"Économie & Sciences Sociales"}'),
  ('francophone_africa','lycee','Lycée','Terminale B','TleB',35,'B',ARRAY['SN','ML','BF','BJ'],'{"label":"Économie & Sciences Sociales"}'),

  -- Lycée Série C — Maths & Physique
  ('francophone_africa','lycee','Lycée','2nde C','2C',36,'C',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Maths & Physique"}'),
  ('francophone_africa','lycee','Lycée','1ère C','1C',37,'C',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Maths & Physique"}'),
  ('francophone_africa','lycee','Lycée','Terminale C','TleC',38,'C',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],'{"label":"Maths & Physique"}'),

  -- Lycée Série D — Sciences de la Nature & de la Vie
  ('francophone_africa','lycee','Lycée','2nde D','2D',39,'D',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Sciences Nat. & Vie"}'),
  ('francophone_africa','lycee','Lycée','1ère D','1D',40,'D',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'], '{"label":"Sciences Nat. & Vie"}'),
  ('francophone_africa','lycee','Lycée','Terminale D','TleD',41,'D',ARRAY['CG','CD','CI','GA','BF','ML','BJ','TG','CF','TD','GN','NE'],'{"label":"Sciences Nat. & Vie"}'),

  -- Lycée Série E — Maths & Technique (Cameroun, Sénégal, Côte d'Ivoire)
  ('francophone_africa','lycee','Lycée','2nde E','2E',42,'E',ARRAY['CM','SN','CI'], '{"label":"Maths & Technique"}'),
  ('francophone_africa','lycee','Lycée','1ère E','1E',43,'E',ARRAY['CM','SN','CI'], '{"label":"Maths & Technique"}'),
  ('francophone_africa','lycee','Lycée','Terminale E','TleE',44,'E',ARRAY['CM','SN','CI'],'{"label":"Maths & Technique"}'),

  -- Lycée Série F — Technique Industrielle (Congo, Cameroun…)
  ('francophone_africa','lycee','Lycée','2nde F','2F',45,'F',ARRAY['CG','CD','CM'], '{"label":"Technique Industrielle"}'),
  ('francophone_africa','lycee','Lycée','1ère F','1F',46,'F',ARRAY['CG','CD','CM'], '{"label":"Technique Industrielle"}'),
  ('francophone_africa','lycee','Lycée','Terminale F','TleF',47,'F',ARRAY['CG','CD','CM'],'{"label":"Technique Industrielle"}'),

  -- Lycée Série G — Gestion & Commerce (Cameroun, Sénégal, Congo…)
  ('francophone_africa','lycee','Lycée','2nde G','2G',48,'G',ARRAY['CG','CD','CM','SN'], '{"label":"Gestion & Commerce"}'),
  ('francophone_africa','lycee','Lycée','1ère G','1G',49,'G',ARRAY['CG','CD','CM','SN'], '{"label":"Gestion & Commerce"}'),
  ('francophone_africa','lycee','Lycée','Terminale G','TleG',50,'G',ARRAY['CG','CD','CM','SN'],'{"label":"Gestion & Commerce"}'),

  -- Lycée Série H — Informatique (Sénégal, Cameroun)
  ('francophone_africa','lycee','Lycée','2nde H','2H',51,'H',ARRAY['SN','CM'], '{"label":"Informatique"}'),
  ('francophone_africa','lycee','Lycée','1ère H','1H',52,'H',ARRAY['SN','CM'], '{"label":"Informatique"}'),
  ('francophone_africa','lycee','Lycée','Terminale H','TleH',53,'H',ARRAY['SN','CM'],'{"label":"Informatique"}'),

  -- Lycée Tronc commun (2nde générale avant orientation)
  ('francophone_africa','lycee','Lycée','2nde (Tronc Commun)','2TC',29,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','BJ','TG'],'{"note":"Avant spécialisation série"}'),

  -- ================================================================
  -- B. SYSTÈME FRANÇAIS MÉTROPOLITAIN (France, DROM-COM, Écoles françaises à l'étranger)
  -- ================================================================

  -- Préscolaire (Maternelle)
  ('francophone_france','prescolaire','Maternelle','Petite Section (MS)','PS',1,NULL,ARRAY['FR'],  '{"age":"3-4 ans"}'),
  ('francophone_france','prescolaire','Maternelle','Moyenne Section (MS)','MS',2,NULL,ARRAY['FR'], '{"age":"4-5 ans"}'),
  ('francophone_france','prescolaire','Maternelle','Grande Section (GS)','GS',3,NULL,ARRAY['FR'],  '{"age":"5-6 ans"}'),

  -- Primaire (Élémentaire)
  ('francophone_france','primaire','Primaire','CP','CP',10,NULL,ARRAY['FR'],  '{"cycle":"Cycle 2"}'),
  ('francophone_france','primaire','Primaire','CE1','CE1',11,NULL,ARRAY['FR'],'{"cycle":"Cycle 2"}'),
  ('francophone_france','primaire','Primaire','CE2','CE2',12,NULL,ARRAY['FR'],'{"cycle":"Cycle 2"}'),
  ('francophone_france','primaire','Primaire','CM1','CM1',13,NULL,ARRAY['FR'],'{"cycle":"Cycle 3"}'),
  ('francophone_france','primaire','Primaire','CM2','CM2',14,NULL,ARRAY['FR'],'{"cycle":"Cycle 3"}'),

  -- Collège
  ('francophone_france','college','Collège','6ème','6e',20,NULL,ARRAY['FR'],NULL),
  ('francophone_france','college','Collège','5ème','5e',21,NULL,ARRAY['FR'],NULL),
  ('francophone_france','college','Collège','4ème','4e',22,NULL,ARRAY['FR'],NULL),
  ('francophone_france','college','Collège','3ème','3e',23,NULL,ARRAY['FR'],NULL),

  -- Lycée Général (réforme Blanquer 2019)
  ('francophone_france','lycee','Lycée Général','2nde Générale','2de',30,NULL,ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Général','1ère Générale','1ère',31,NULL,ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Général','Terminale Générale','Tle',32,NULL,ARRAY['FR'],NULL),

  -- Lycée Technologique
  ('francophone_france','lycee','Lycée Techno','2nde Technologique','2de T',33,'TECHNO',ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Techno','1ère STMG','1STMG',34,'STMG',ARRAY['FR'],'{"label":"Sciences & Technologies Mgt Gestion"}'),
  ('francophone_france','lycee','Lycée Techno','Terminale STMG','TleSTMG',35,'STMG',ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Techno','1ère STI2D','1STI2D',36,'STI2D',ARRAY['FR'],'{"label":"Sciences & Tech. Industrie Dev. Durable"}'),
  ('francophone_france','lycee','Lycée Techno','Terminale STI2D','TleSTI2D',37,'STI2D',ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Techno','1ère ST2S','1ST2S',38,'ST2S',ARRAY['FR'],'{"label":"Sciences & Technologies Santé & Social"}'),
  ('francophone_france','lycee','Lycée Techno','Terminale ST2S','TleST2S',39,'ST2S',ARRAY['FR'],NULL),

  -- Lycée Professionnel
  ('francophone_france','lycee','Lycée Pro','2nde Pro','2de Pro',40,'PRO',ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Pro','1ère Pro','1ère Pro',41,'PRO',ARRAY['FR'],NULL),
  ('francophone_france','lycee','Lycée Pro','Terminale Pro','Tle Pro',42,'PRO',ARRAY['FR'],NULL),

  -- ================================================================
  -- C. SYSTÈME ANGLOPHONE — NIGERIA
  -- ================================================================
  ('anglophone_nigeria','prescolaire','Pre-Primary','Nursery 1','N1',1,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','prescolaire','Pre-Primary','Nursery 2','N2',2,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','prescolaire','Pre-Primary','Kindergarten','KG',3,NULL,ARRAY['NG'],NULL),

  ('anglophone_nigeria','primaire','Primary','Primary 1','P1',10,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','primaire','Primary','Primary 2','P2',11,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','primaire','Primary','Primary 3','P3',12,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','primaire','Primary','Primary 4','P4',13,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','primaire','Primary','Primary 5','P5',14,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','primaire','Primary','Primary 6','P6',15,NULL,ARRAY['NG'],NULL),

  ('anglophone_nigeria','college','Junior Secondary','JSS 1','JSS1',20,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','college','Junior Secondary','JSS 2','JSS2',21,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','college','Junior Secondary','JSS 3','JSS3',22,NULL,ARRAY['NG'],NULL),

  ('anglophone_nigeria','lycee','Senior Secondary','SSS 1','SSS1',30,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','lycee','Senior Secondary','SSS 2','SSS2',31,NULL,ARRAY['NG'],NULL),
  ('anglophone_nigeria','lycee','Senior Secondary','SSS 3','SSS3',32,NULL,ARRAY['NG'],NULL),

  -- ================================================================
  -- D. SYSTÈME ANGLOPHONE — GHANA
  -- ================================================================
  ('anglophone_ghana','prescolaire','Kindergarten','KG 1','KG1',1,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','prescolaire','Kindergarten','KG 2','KG2',2,NULL,ARRAY['GH'],NULL),

  ('anglophone_ghana','primaire','Primary','Primary 1','P1',10,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','primaire','Primary','Primary 2','P2',11,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','primaire','Primary','Primary 3','P3',12,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','primaire','Primary','Primary 4','P4',13,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','primaire','Primary','Primary 5','P5',14,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','primaire','Primary','Primary 6','P6',15,NULL,ARRAY['GH'],NULL),

  ('anglophone_ghana','college','JHS','JHS 1','JHS1',20,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','college','JHS','JHS 2','JHS2',21,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','college','JHS','JHS 3','JHS3',22,NULL,ARRAY['GH'],NULL),

  ('anglophone_ghana','lycee','SHS','SHS 1','SHS1',30,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','lycee','SHS','SHS 2','SHS2',31,NULL,ARRAY['GH'],NULL),
  ('anglophone_ghana','lycee','SHS','SHS 3','SHS3',32,NULL,ARRAY['GH'],NULL),

  -- ================================================================
  -- E. SYSTÈME ANGLOPHONE — KENYA (Nouveau système CBC 2017)
  -- ================================================================
  ('anglophone_kenya','prescolaire','Pre-Primary','PP 1','PP1',1,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','prescolaire','Pre-Primary','PP 2','PP2',2,NULL,ARRAY['KE'],NULL),

  ('anglophone_kenya','primaire','Primary','Grade 1','G1',10,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','primaire','Primary','Grade 2','G2',11,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','primaire','Primary','Grade 3','G3',12,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','primaire','Primary','Grade 4','G4',13,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','primaire','Primary','Grade 5','G5',14,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','primaire','Primary','Grade 6','G6',15,NULL,ARRAY['KE'],NULL),

  ('anglophone_kenya','college','Junior Secondary','Grade 7','G7',20,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','college','Junior Secondary','Grade 8','G8',21,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','college','Junior Secondary','Grade 9','G9',22,NULL,ARRAY['KE'],NULL),

  ('anglophone_kenya','lycee','Senior Secondary','Grade 10','G10',30,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','lycee','Senior Secondary','Grade 11','G11',31,NULL,ARRAY['KE'],NULL),
  ('anglophone_kenya','lycee','Senior Secondary','Grade 12','G12',32,NULL,ARRAY['KE'],NULL),

  -- ================================================================
  -- F. SYSTÈME ANGLOPHONE — CAMEROUN (Anglophone, O/A Levels)
  -- ================================================================
  ('anglophone_cameroon','prescolaire','Nursery','Nursery 1','N1',1,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','prescolaire','Nursery','Nursery 2','N2',2,NULL,ARRAY['CM'],NULL),

  ('anglophone_cameroon','primaire','Primary','Class 1','C1',10,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','primaire','Primary','Class 2','C2',11,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','primaire','Primary','Class 3','C3',12,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','primaire','Primary','Class 4','C4',13,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','primaire','Primary','Class 5','C5',14,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','primaire','Primary','Class 6','C6',15,NULL,ARRAY['CM'],NULL),

  ('anglophone_cameroon','college','O-Levels','Form 1','F1',20,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','college','O-Levels','Form 2','F2',21,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','college','O-Levels','Form 3','F3',22,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','college','O-Levels','Form 4','F4',23,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','college','O-Levels','Form 5','F5',24,NULL,ARRAY['CM'],NULL),

  ('anglophone_cameroon','lycee','A-Levels','Lower Sixth','LS',30,NULL,ARRAY['CM'],NULL),
  ('anglophone_cameroon','lycee','A-Levels','Upper Sixth','US',31,NULL,ARRAY['CM'],NULL),

  -- ================================================================
  -- G. SYSTÈME ANGLOPHONE — AFRIQUE DU SUD (South Africa)
  -- ================================================================
  ('anglophone_southafrica','prescolaire','Grade R','Grade R','GrR',1,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Foundation Phase','Grade 1','G1',10,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Foundation Phase','Grade 2','G2',11,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Foundation Phase','Grade 3','G3',12,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Intermediate Phase','Grade 4','G4',13,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Intermediate Phase','Grade 5','G5',14,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','primaire','Intermediate Phase','Grade 6','G6',15,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','college','Senior Phase','Grade 7','G7',20,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','college','Senior Phase','Grade 8','G8',21,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','college','Senior Phase','Grade 9','G9',22,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','lycee','FET Phase','Grade 10','G10',30,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','lycee','FET Phase','Grade 11','G11',31,NULL,ARRAY['ZA'],NULL),
  ('anglophone_southafrica','lycee','FET Phase','Grade 12 (Matric)','Matric',32,NULL,ARRAY['ZA'],NULL),

  -- ================================================================
  -- H. SYSTÈME ARABOPHONE — Maghreb (Maroc, Algérie, Tunisie)
  -- ================================================================
  ('arabophone','prescolaire','Préscolaire','1ère année Maternelle','M1',1,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','prescolaire','Préscolaire','2ème année Maternelle','M2',2,NULL,ARRAY['MA','DZ','TN'],NULL),

  ('arabophone','primaire','Primaire','1ère Année Primaire','1AP',10,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','primaire','Primaire','2ème Année Primaire','2AP',11,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','primaire','Primaire','3ème Année Primaire','3AP',12,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','primaire','Primaire','4ème Année Primaire','4AP',13,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','primaire','Primaire','5ème Année Primaire','5AP',14,NULL,ARRAY['MA','DZ','TN'],NULL),
  ('arabophone','primaire','Primaire','6ème Année Primaire','6AP',15,NULL,ARRAY['MA','DZ','TN'],NULL),

  ('arabophone','college','Collège','1ère Année Collège','1AC',20,NULL,ARRAY['MA'],NULL),
  ('arabophone','college','Collège','2ème Année Collège','2AC',21,NULL,ARRAY['MA'],NULL),
  ('arabophone','college','Collège','3ème Année Collège','3AC',22,NULL,ARRAY['MA'],NULL),
  ('arabophone','college','Collège','1ère Année Moyenne','1AM',23,NULL,ARRAY['DZ'],NULL),
  ('arabophone','college','Collège','2ème Année Moyenne','2AM',24,NULL,ARRAY['DZ'],NULL),
  ('arabophone','college','Collège','3ème Année Moyenne','3AM',25,NULL,ARRAY['DZ'],NULL),
  ('arabophone','college','Collège','4ème Année Moyenne','4AM',26,NULL,ARRAY['DZ'],NULL),

  ('arabophone','lycee','Lycée','1ère Année Bac','1Bac',30,NULL,ARRAY['MA'],NULL),
  ('arabophone','lycee','Lycée','2ème Année Bac','2Bac',31,NULL,ARRAY['MA'],NULL),
  ('arabophone','lycee','Lycée','1ère Année Secondaire','1AS',32,NULL,ARRAY['DZ'],NULL),
  ('arabophone','lycee','Lycée','2ème Année Secondaire','2AS',33,NULL,ARRAY['DZ'],NULL),
  ('arabophone','lycee','Lycée','3ème Année Secondaire','3AS',34,NULL,ARRAY['DZ'],NULL),

  -- ================================================================
  -- I. UNIVERSITÉ — Système LMD (Licence-Master-Doctorat)
  --    Utilisé dans toute l'Afrique francophone + Europe francophone
  -- ================================================================
  ('lmd','universite_l','Licence','Licence 1 (L1)','L1',10,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN','GN','NE','BJ','TG'],NULL),
  ('lmd','universite_l','Licence','Licence 2 (L2)','L2',11,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN','GN','NE','BJ','TG'],NULL),
  ('lmd','universite_l','Licence','Licence 3 (L3)','L3',12,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN','GN','NE','BJ','TG'],NULL),

  ('lmd','universite_m','Master','Master 1 (M1)','M1',20,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN','GN','NE','BJ','TG'],NULL),
  ('lmd','universite_m','Master','Master 2 (M2)','M2',21,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN','GN','NE','BJ','TG'],NULL),

  ('lmd','universite_d','Doctorat','Doctorat 1ère année (D1)','D1',30,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN'],NULL),
  ('lmd','universite_d','Doctorat','Doctorat 2ème année (D2)','D2',31,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN'],NULL),
  ('lmd','universite_d','Doctorat','Doctorat 3ème année (D3)','D3',32,NULL,ARRAY['CG','CD','CM','SN','CI','GA','BF','ML','FR','MA','DZ','TN'],NULL),

  -- ================================================================
  -- J. UNIVERSITÉ — Ancien système pré-LMD (DEUG, Licence, Maîtrise)
  --    Encore utilisé dans certains pays
  -- ================================================================
  ('ancien_systeme_univ','universite_l','DEUG','DEUG 1','DEUG1',10,NULL,ARRAY['CG','CD','CI','GA'],'{"note":"Diplôme Études Universitaires Générales — avant réforme LMD"}'),
  ('ancien_systeme_univ','universite_l','DEUG','DEUG 2','DEUG2',11,NULL,ARRAY['CG','CD','CI','GA'],NULL),
  ('ancien_systeme_univ','universite_l','Licence','Licence','LIC',12,NULL,ARRAY['CG','CD','CI','GA'],NULL),
  ('ancien_systeme_univ','universite_m','Maîtrise','Maîtrise','MAI',20,NULL,ARRAY['CG','CD','CI','GA'],NULL),
  ('ancien_systeme_univ','universite_m','DEA/DESS','DEA','DEA',21,NULL,ARRAY['CG','CD','CI','GA'],'{"note":"Diplôme Études Approfondies"}'),
  ('ancien_systeme_univ','universite_d','Doctorat','Doctorat d''État','DOC',30,NULL,ARRAY['CG','CD','CI','GA'],NULL),

  -- ================================================================
  -- K. GRANDE ÉCOLE / CLASSES PRÉPARATOIRES (France + Afrique)
  -- ================================================================
  ('grande_ecole','prepa','Prépa','Maths Sup (MPSI/PCSI/BCPST)','Sup',10,NULL,ARRAY['FR','MA','DZ','TN','SN','CI'],NULL),
  ('grande_ecole','prepa','Prépa','Maths Spé (MP/PC/PSI/PT/TB)','Spé',11,NULL,ARRAY['FR','MA','DZ','TN','SN','CI'],NULL),
  ('grande_ecole','prepa','Prépa','Prépa ECS (éco voie scientifique)','ECS',12,'ECS',ARRAY['FR','MA'],NULL),
  ('grande_ecole','prepa','Prépa','Prépa ECE (éco & commercial)','ECE',13,'ECE',ARRAY['FR','MA'],NULL),
  ('grande_ecole','prepa','Prépa','Prépa Lettres (hypokhâgne)','HK',14,'L',ARRAY['FR','MA'],NULL),
  ('grande_ecole','prepa','Prépa','Prépa Lettres (khâgne)','K',15,'L',ARRAY['FR','MA'],NULL),

  ('grande_ecole','universite_l','Grande École','1ère année ingénieur','GE1',20,NULL,ARRAY['FR','MA','DZ','TN','SN','CM'],NULL),
  ('grande_ecole','universite_l','Grande École','2ème année ingénieur','GE2',21,NULL,ARRAY['FR','MA','DZ','TN','SN','CM'],NULL),
  ('grande_ecole','universite_m','Grande École','3ème année ingénieur (diplôme)','GE3',22,NULL,ARRAY['FR','MA','DZ','TN','SN','CM'],NULL),

  -- ================================================================
  -- L. UNIVERSITÉ — Système Anglophone (NG, GH, KE, ZA, CM Anglophone)
  -- ================================================================
  ('anglophone_university','universite_l','Undergraduate','Year 1 / 100 Level','Y1',10,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_l','Undergraduate','Year 2 / 200 Level','Y2',11,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_l','Undergraduate','Year 3 / 300 Level','Y3',12,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_l','Undergraduate','Year 4 / 400 Level','Y4',13,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_l','Undergraduate','Year 5 / 500 Level (Medicine/Law)','Y5',14,NULL,ARRAY['NG','GH','KE'],NULL),
  ('anglophone_university','universite_m','Postgraduate','Masters Year 1','MYR1',20,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_m','Postgraduate','Masters Year 2','MYR2',21,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_d','Postgraduate','PhD Year 1','PHD1',30,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_d','Postgraduate','PhD Year 2','PHD2',31,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL),
  ('anglophone_university','universite_d','Postgraduate','PhD Year 3','PHD3',32,NULL,ARRAY['NG','GH','KE','ZA','CM'],NULL)
  ON CONFLICT (system_type, name, COALESCE(series, '')) DO NOTHING;


  -- 4. Vérification
  -- ============================================================
  SELECT system_type, cycle, COUNT(*) AS nb_niveaux
  FROM public.class_levels
  GROUP BY system_type, cycle
  ORDER BY system_type, cycle;
  