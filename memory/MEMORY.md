# Memory Index

- [Business model](business-model.md) — SaaS B2B, 3 offres Simple/Pro/Max, école paie, FCFA puis multi-pays, prix forfait par palier
- [Backend state](backend-state.md) — Supabase: comptes test (demo1234), RLS, trigger inscription, quirk users/profiles, inscription 100% OK
- [Offers & gating](offers-and-gating.md) — contenu exact Simple/Pro/Max, mécanisme de verrouillage (minPlan×maturité), Simple=staff strict, essai=Simple
- [Accounts & access](accounts-and-access.md) — fiche vs accès, login par rôle, élève+parent en 1 fois, Edge Function ; **RBAC personnel par capacités** (permissions jsonb + presets + menu dynamique + gardes) implémenté
- [Distribution & white-label](distribution-and-whitelabel.md) — 1 app Flutter multi-cible, web d'abord puis PWA/stores, white-label = thème dynamique par école
- [Admin build roadmap](admin-build-roadmap.md) — étapes 0→10 + **ÉTAT au 19 juin 2026** (ce qui est fait, ⚠️ migrations SQL à exécuter, et la suite) — LIRE EN PREMIER pour reprendre
