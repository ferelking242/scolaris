// Clé publique (anon) Supabase — sûre à exposer côté client, protégée par RLS.
const SCOLARIS_CONFIG = {
  SUPABASE_URL: "https://iaxwvgqusxyhmyansawi.supabase.co",
  SUPABASE_ANON_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlheHd2Z3F1c3h5aG15YW5zYXdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MzQwNDUsImV4cCI6MjA5MzIxMDA0NX0" +
    ".1zSf0ryZlL5KZkDGJ6VHmigaxwlapeScQaSVbKkerTs",
  // App Scolaris réellement déployée (même valeur que LIEN_APP dans
  // index.html) — utilisée par ecole.html pour construire le lien
  // d'inscription. À remplacer si un domaine propre est acheté un jour.
  APP_URL: "https://ferelking242.github.io/scolaris",
};
