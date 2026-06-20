class AppConfig {
  AppConfig._();

  static const String appName    = 'Scolaris';
  static const String appTagline = 'Savoir, Héritage, Avenir';
  static const String appVersion = '0.1.0';

  static const String supabaseUrl = 'https://iaxwvgqusxyhmyansawi.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlheHd2Z3F1c3h5aG15YW5zYXdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MzQwNDUsImV4cCI6MjA5MzIxMDA0NX0'
      '.1zSf0ryZlL5KZkDGJ6VHmigaxwlapeScQaSVbKkerTs';

  // La clé `service_role` ne doit JAMAIS être dans le client (elle ignore la
  // RLS). La création de comptes passe désormais par l'Edge Function
  // `create-account`, qui détient cette clé côté serveur uniquement.

  static bool get hasSupabaseConfig => true;

  static const int defaultAccentArgb = 0xFF8B1A00;
  static const int accentGoldArgb    = 0xFFC17F24;
  static const int accentGreenArgb   = 0xFF1B5E20;
  static const int accentOrangeArgb  = 0xFFD4540A;
}
