import 'package:supabase_flutter/supabase_flutter.dart';

import 'platform_mock_data.dart';

/// Les vraies données plateforme (remplace [PlatformMock] pas à pas). Vit à
/// part de `supabase_db_source.dart` — c'est un besoin propre à la console
/// super-admin (lecture cross-écoles), pas au reste de l'app (scopée à UNE
/// école). Nécessite les policies `platform_admin_read_*` (cf.
/// 20260757_platform_dashboard_read.sql) : sans elles, un admin plateforme ne
/// verrait que ses propres écoles via `tenant_isolation`.
class PlatformRepository {
  PlatformRepository._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Toutes les écoles, avec leur abonnement fusionné dans la MÊME forme que
  /// [PlatformSchool] (déjà utilisée par tout l'écran) — une école sans ligne
  /// `subscriptions` retombe sur les valeurs par défaut d'un essai qui vient
  /// de démarrer, cohérent avec ce que `createStudent`/l'inscription posent.
  static Future<List<PlatformSchool>> getSchools() async {
    final schoolsData = await _db
        .from('schools')
        .select('id, name, city, country, metadata, created_at, contact_email, '
            'contact_phone')
        .order('created_at', ascending: false);
    final subsData = await _db
        .from('subscriptions')
        .select('school_id, plan_code, status, price, current_period_end, trial_end');

    final subsBySchool = <String, Map<String, dynamic>>{
      for (final s in subsData as List)
        if ((s as Map<String, dynamic>)['school_id'] != null)
          s['school_id'] as String: s,
    };

    return (schoolsData as List).map((j) {
      final row = j as Map<String, dynamic>;
      final id = row['id'] as String;
      final createdAt =
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
      final sub = subsBySchool[id];

      final plan = _planFromCode(sub?['plan_code'] as String?);
      final status = _statusFromCode(sub?['status'] as String?);
      final periodEnd = _parseDate(sub?['current_period_end']) ??
          _parseDate(sub?['trial_end']) ??
          createdAt.add(const Duration(days: 30));

      final metadata = row['metadata'];
      final rawTypes = metadata is Map ? metadata['types'] : null;
      final types = rawTypes is List
          ? rawTypes.map((e) => e.toString()).toList()
          : const <String>['primaire'];

      return PlatformSchool(
        id: id,
        name: row['name'] as String? ?? '—',
        city: row['city'] as String? ?? '—',
        country: row['country'] as String? ?? '—',
        types: types,
        createdAt: createdAt,
        plan: plan,
        status: status,
        // Effectifs : pas encore branchés (pas nécessaires au Dashboard —
        // ni _RecentSchools ni _AttentionList ne les affichent). 0 en
        // attendant, pour ne pas laisser un mock trompeur.
        studentCount: 0,
        teacherCount: 0,
        classCount: 0,
        periodEnd: periodEnd,
        director: '—',
        email: row['contact_email'] as String? ?? '',
        phone: row['contact_phone'] as String? ?? '',
      );
    }).toList();
  }

  /// Nombre total d'élèves, toutes écoles confondues — via la fonction
  /// `platform_total_students()` (pas d'accès direct à `users`, qui
  /// exposerait noms/emails/téléphones de tout le monde).
  static Future<int> getTotalStudents() async {
    final res = await _db.rpc('platform_total_students');
    return (res as num?)?.toInt() ?? 0;
  }

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static PlatformPlan _planFromCode(String? code) => switch (code) {
        'pro' => PlatformPlan.pro,
        'max' => PlatformPlan.max,
        _ => PlatformPlan.simple,
      };

  static SubStatus _statusFromCode(String? code) => switch (code) {
        'active' => SubStatus.active,
        'past_due' => SubStatus.pastDue,
        'expired' => SubStatus.expired,
        'canceled' => SubStatus.canceled,
        _ => SubStatus.trial,
      };
}
