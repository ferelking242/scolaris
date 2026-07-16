-- ============================================================
  -- Migration: Congo University Filières + EAD Test School
  -- Date: 2026-06-03
  -- Inserted via: Supabase REST API (service_role)
  -- ============================================================

  -- This migration documents what was inserted programmatically.
  -- The class_levels rows were inserted for the following system_types:
  --   lmd_congo_ensp: ENSP filières (EMI, GLAR, GC, GE, TELE) L1-M2
  --   lmd_congo_enam: ENAM filières (RH, ADM, DIP, MAG) L1-M2
  --   lmd_congo_fseg: FSEG filières (ECO, GES, CPT) L1-M2
  --   lmd_congo_flsh: FLSH filières (LM, HIST, ANGL) L1-M2
  --   lmd_congo_fdd:  FDD filières (DP, DPU) L1-M2
  --   lmd_congo_fst:  FST filières (MATH, PHYS, INFO) L1-M2
  --   lmd_congo_fssa: FSSA filières (MED PCEM1-D4, PHARM L1-M2)
  -- Total: 111 rows added to class_levels
  --
  -- EAD Test School (created 2026-06-03):
  --   EAD Brazzaville (EAD-BZV): id = de3764d3-f0e6-4191-ba89-ab4c73cf37a1
  --   EAD Pointe-Noire (EAD-PNR): id = 2688d21a-fc84-4400-ad52-93df4efa8796
  --   22 filières per school (44 total)
  --   100 classes per school (L1-M2 for 10 key filières)
  --   17 users: 7 students, 4 teachers, 6 admin
  --   Password for all EAD users: EadCongo2025!
  --
  -- EAD Users (email → role):
  --   ondongo.ferel@ead.cg    → student (GLAR L2, BZV)
  --   mabika.gloire@ead.cg    → student (EMI L1, BZV)
  --   mouanda.prisca@ead.cg   → student (GES M1, BZV)
  --   loemba.ryan@ead.cg      → student (FDD-DP L3, BZV)
  --   ngakosso.nina@ead.cg    → student (FLSH-LM L1, BZV)
  --   batchi.kevin@ead.cg     → student (GLAR L2, PNR)
  --   moukala.grace@ead.cg    → student (ECO L3, PNR)
  --   prof.djemba@ead.cg      → teacher (Réseaux, BZV)
  --   prof.makaya@ead.cg      → teacher (Maths, BZV)
  --   prof.milandou@ead.cg    → teacher (Droit, BZV)
  --   prof.nguila@ead.cg      → teacher (Économie, PNR)
  --   secretariat.bzv@ead.cg  → admin/secretaire (BZV)
  --   direction.bzv@ead.cg    → admin/directeur (BZV)
  --   finance.bzv@ead.cg      → admin/finance (BZV)
  --   secretariat.pnr@ead.cg  → admin/secretaire (PNR)
  --   direction.pnr@ead.cg    → admin/directeur (PNR)
  --   dg@ead.cg               → admin/dg (Direction Générale)
  -- ============================================================

  -- Verify counts:
  SELECT system_type, COUNT(*) AS nb
  FROM public.class_levels
  WHERE system_type LIKE 'lmd_congo%'
  GROUP BY system_type
  ORDER BY system_type;

  SELECT name, code, city FROM public.schools WHERE code LIKE 'EAD%';
  SELECT role, COUNT(*) FROM public.users WHERE school_id IN (
    'de3764d3-f0e6-4191-ba89-ab4c73cf37a1',
    '2688d21a-fc84-4400-ad52-93df4efa8796'
  ) GROUP BY role;
  