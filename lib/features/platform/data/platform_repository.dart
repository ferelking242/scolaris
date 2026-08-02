import 'package:supabase_flutter/supabase_flutter.dart';

import 'platform_announcement.dart';
import 'platform_mock_data.dart';

/// Un événement réel du cycle de vie d'une école (table `platform_events`,
/// écrite par des triggers DB — jamais par le client). `metadata` porte les
/// détails bruts (montants, anciens/nouveaux statuts…) ; l'UI en dérive le
/// libellé, l'icône et la couleur (cf. `platform_school_detail.dart`).
class PlatformEvent {
  final String type;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  const PlatformEvent({
    required this.type,
    required this.metadata,
    required this.createdAt,
  });
}

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
            'contact_phone, is_active')
        .order('created_at', ascending: false);
    final subsData = await _db
        .from('subscriptions')
        .select('school_id, plan_code, status, price, current_period_end, trial_end');
    // Effectifs par école (RPC dédiée : pas d'accès direct à `users`, cf.
    // 20260759_platform_school_stats.sql). Best-effort — si la migration
    // n'est pas encore appliquée, on retombe sur 0 plutôt que de planter.
    Map<String, ({int students, int teachers, int classes})> stats = {};
    try {
      final statsData = await _db.rpc('platform_school_stats');
      stats = {
        for (final s in statsData as List)
          (s as Map<String, dynamic>)['school_id'] as String: (
            students: (s['student_count'] as num?)?.toInt() ?? 0,
            teachers: (s['teacher_count'] as num?)?.toInt() ?? 0,
            classes: (s['class_count'] as num?)?.toInt() ?? 0,
          ),
      };
    } catch (_) {
      // Migration pas encore appliquée — la liste reste utilisable sans.
    }

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
      final stat = stats[id];

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
        studentCount: stat?.students ?? 0,
        teacherCount: stat?.teachers ?? 0,
        classCount: stat?.classes ?? 0,
        periodEnd: periodEnd,
        director: '—',
        email: row['contact_email'] as String? ?? '',
        phone: row['contact_phone'] as String? ?? '',
        isActive: row['is_active'] as bool? ?? true,
      );
    }).toList();
  }

  /// Active/désactive une école — utilisé pour valider une inscription
  /// self-service (créée avec `is_active: false`, cf.
  /// `SchoolRegistrationScreen`) avant que son responsable ne puisse se
  /// connecter (cf. `SupabaseAuthSource._fetchProfile`).
  static Future<void> setSchoolActive(String schoolId, bool active) async {
    await _db.from('schools').update({'is_active': active}).eq('id', schoolId);
  }

  /// Crée une nouvelle école + son compte admin via l'Edge Function
  /// `platform-create-school` (service_role — ne peut pas se faire en client,
  /// et surtout pas via `auth.signUp`, qui remplacerait la session du
  /// super-admin par celle du nouveau compte). Renvoie l'id de l'école créée.
  static Future<String> createSchool({
    required String name,
    required String city,
    required String country,
    required List<String> types,
    required PlatformPlan plan,
    required String directorName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _db.functions.invoke('platform-create-school', body: {
      'name': name,
      'city': city,
      'country': country,
      'types': types,
      'planCode': plan.name,
      'directorName': directorName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    if (res.status >= 400) {
      final data = res.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Erreur serveur (${res.status})';
      throw Exception(msg);
    }
    final data = res.data;
    final schoolId = (data is Map) ? data['schoolId'] as String? : null;
    if (schoolId == null) throw Exception('Réponse serveur invalide.');
    return schoolId;
  }

  /// Nombre total d'élèves, toutes écoles confondues — via la fonction
  /// `platform_total_students()` (pas d'accès direct à `users`, qui
  /// exposerait noms/emails/téléphones de tout le monde).
  static Future<int> getTotalStudents() async {
    final res = await _db.rpc('platform_total_students');
    return (res as num?)?.toInt() ?? 0;
  }

  /// Suspend (accès limité) ou réactive une école. Pas de statut « suspended »
  /// dédié dans `subscriptions` (contrainte : trial/active/past_due/canceled/
  /// expired) — on réutilise `canceled` pour représenter la suspension admin,
  /// comme le faisait déjà la maquette. Nécessite la policy UPDATE de
  /// 20260760_platform_school_write.sql.
  static Future<void> setSchoolSuspended(String schoolId, bool suspended) async {
    await _db.from('subscriptions').update({
      'status': suspended ? 'canceled' : 'active',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('school_id', schoolId);
  }

  /// Prolonge l'essai/la période en cours de [days] jours. Lit d'abord la
  /// ligne pour partir de la vraie échéance actuelle (pas de `now()` qui
  /// raccourcirait une période déjà en avance).
  static Future<void> extendSchoolTrial(String schoolId, int days) async {
    final row = await _db
        .from('subscriptions')
        .select('trial_end, current_period_end')
        .eq('school_id', schoolId)
        .maybeSingle();
    final extra = Duration(days: days);
    final newTrialEnd = _parseDate(row?['trial_end'])?.add(extra);
    final newPeriodEnd = _parseDate(row?['current_period_end'])?.add(extra) ??
        DateTime.now().add(extra);
    await _db.from('subscriptions').update({
      if (newTrialEnd != null) 'trial_end': newTrialEnd.toIso8601String(),
      'current_period_end': newPeriodEnd.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('school_id', schoolId);
  }

  /// Change l'offre (Simple/Pro/Max) d'une école.
  static Future<void> setSchoolPlan(String schoolId, PlatformPlan plan) async {
    await _db.from('subscriptions').update({
      'plan_code': plan.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('school_id', schoolId);
  }

  /// Tarifs réels des 3 offres (Congo/XAF/mensuel — seul marché servi
  /// aujourd'hui, cf. `plan_prices`) + limite d'élèves (`plans.max_students`).
  static Future<Map<PlatformPlan, ({int price, int? limit})>> getPlanSettings() async {
    final plansData = await _db.from('plans').select('code, max_students');
    final pricesData = await _db
        .from('plan_prices')
        .select('plan_code, price')
        .eq('country', 'CG')
        .eq('period', 'monthly');

    final limitByCode = <String, int?>{
      for (final p in plansData as List)
        (p as Map<String, dynamic>)['code'] as String: (p['max_students'] as num?)?.toInt(),
    };
    final priceByCode = <String, int>{
      for (final p in pricesData as List)
        (p as Map<String, dynamic>)['plan_code'] as String: (p['price'] as num?)?.toInt() ?? 0,
    };

    return {
      for (final p in PlatformPlan.values)
        p: (
          price: priceByCode[p.name] ?? p.monthlyPrice,
          limit: limitByCode.containsKey(p.name) ? limitByCode[p.name] : p.studentLimit,
        ),
    };
  }

  /// Modifie le tarif + la limite d'une offre (Congo, mensuel).
  static Future<void> setPlanSettings(PlatformPlan plan,
      {required int price, required int? limit}) async {
    await _db.from('plans').update({'max_students': limit}).eq('code', plan.name);
    await _db.from('plan_prices').upsert({
      'plan_code': plan.name,
      'country': 'CG',
      'currency': 'XAF',
      'period': 'monthly',
      'price': price,
    }, onConflict: 'plan_code,country,period');
  }

  /// Roster réel des élèves d'une école (nom, classe, matricule, actif) — via
  /// `platform_school_students()`, qui ne remonte QUE ces 4 champs (pas
  /// d'email/téléphone), même logique de vie privée que `platform_school_stats()`.
  static Future<List<PlatformStudentRow>> getSchoolStudents(String schoolId) async {
    final data = await _db.rpc('platform_school_students', params: {'p_school_id': schoolId});
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      return PlatformStudentRow(
        name: row['full_name'] as String? ?? '—',
        className: row['class_name'] as String? ?? '—',
        matricule: row['matricule'] as String? ?? '—',
        active: row['active'] as bool? ?? true,
      );
    }).toList();
  }

  /// Historique réel des paiements d'abonnement (école → Scolaris) — table
  /// `subscription_payments`, déjà en place, seule la lecture manquait.
  static Future<List<PlatformPayment>> getSchoolPayments(String schoolId) async {
    final data = await _db
        .from('subscription_payments')
        .select('amount, method, provider, status, paid_at, created_at')
        .eq('school_id', schoolId)
        .order('created_at', ascending: false);
    const months = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
    ];
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      final date = _parseDate(row['paid_at']) ?? _parseDate(row['created_at']) ?? DateTime.now();
      return PlatformPayment(
        date: date,
        amount: (row['amount'] as num?)?.toInt() ?? 0,
        method: (row['provider'] as String?) ?? (row['method'] as String?) ?? '—',
        period: '${months[date.month - 1]} ${date.year}',
        success: row['status'] == 'success',
      );
    }).toList();
  }

  /// Versements d'abonnement en attente de vérification, TOUTES écoles
  /// confondues — l'école a envoyé l'argent elle-même (USSD, hors app) vers
  /// le numéro marchand Scolaris et saisi la référence reçue par SMS ; rien
  /// n'est encore activé (cf. 20260804_platform_subscription_payments.sql).
  static Future<List<PlatformPendingPayment>> getPendingSubscriptionPayments() async {
    final data = await _db
        .from('subscription_payments')
        .select('id, school_id, plan_code, period, amount, currency, provider, '
            'reference, created_at, schools(name)')
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      final school = row['schools'];
      return PlatformPendingPayment(
        id: row['id'] as String,
        schoolName: (school is Map ? school['name'] as String? : null) ?? '—',
        planCode: row['plan_code'] as String? ?? '—',
        period: row['period'] as String? ?? 'monthly',
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        currency: row['currency'] as String? ?? 'XAF',
        provider: row['provider'] as String?,
        reference: row['reference'] as String?,
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  /// Vérifié sur le relevé marchand : active l'offre ET solde le versement,
  /// via la fonction dédiée (jamais une écriture directe — cf. migration).
  static Future<void> confirmSubscriptionPayment(String paymentId) async {
    await _db.rpc('platform_confirm_subscription_payment',
        params: {'p_payment_id': paymentId});
  }

  /// Référence invalide/introuvable — reste tracée, n'active rien.
  static Future<void> rejectSubscriptionPayment(String paymentId) async {
    await _db.rpc('platform_reject_subscription_payment',
        params: {'p_payment_id': paymentId});
  }

  /// Historique réel des événements d'une école (création, changement de
  /// statut/offre, prolongation d'essai, paiement) — alimenté par des
  /// triggers DB (cf. 20260764_platform_events.sql), jamais par le client.
  static Future<List<PlatformEvent>> getSchoolEvents(String schoolId) async {
    final data = await _db
        .from('platform_events')
        .select('event_type, metadata, created_at')
        .eq('school_id', schoolId)
        .order('created_at', ascending: false);
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      return PlatformEvent(
        type: row['event_type'] as String? ?? '',
        metadata: (row['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  /// Historique réel des annonces publiées (toutes, tri antéchronologique).
  static Future<List<PlatformAnnouncement>> getAnnouncements() async {
    final data = await _db
        .from('platform_announcements')
        .select('id, title, body, kind, audience, reach, created_at, '
            'expires_at, archived_at')
        .order('created_at', ascending: false);
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      return PlatformAnnouncement(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        body: row['body'] as String? ?? '',
        kind: kindFromCode(row['kind'] as String?),
        audience: audienceFromCode(row['audience'] as String?),
        reach: (row['reach'] as num?)?.toInt() ?? 0,
        date: _parseDate(row['created_at']) ?? DateTime.now(),
        expiresAt: _parseDate(row['expires_at']),
        archivedAt: _parseDate(row['archived_at']),
      );
    }).toList();
  }

  /// Publie une vraie annonce (visible par les écoles concernées via
  /// `my_platform_announcements()`). `reach` est figé au moment de la
  /// diffusion (nombre d'écoles réellement ciblées à cet instant).
  /// `expiresAt` optionnel : passé cette date, l'annonce arrête d'être
  /// distribuée sans intervention manuelle.
  static Future<void> publishAnnouncement({
    required String title,
    required String body,
    required AnnouncementKind kind,
    required AnnouncementAudience audience,
    required int reach,
    DateTime? expiresAt,
  }) async {
    await _db.from('platform_announcements').insert({
      'title': title.trim(),
      'body': body.trim(),
      'kind': kind.code,
      'audience': audience.code,
      'reach': reach,
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  /// Dépublie une annonce immédiatement (erreur de saisie, info périmée…) —
  /// elle arrête d'être distribuée aux écoles dès le prochain appel de
  /// `my_platform_announcements()`, sans attendre son expiration.
  static Future<void> unpublishAnnouncement(String id) async {
    await _db
        .from('platform_announcements')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Équipe super-admin réelle (lecture seule — l'ajout/retrait se fait par
  /// SQL direct sur `platform_admins`, volontairement, cf. commentaire dans
  /// `platform_admins` : pas de policy insert/update/delete côté client).
  static Future<List<({String email, String fullName})>> getPlatformAdmins() async {
    final data = await _db.rpc('platform_admin_list');
    return (data as List).map((r) {
      final row = r as Map<String, dynamic>;
      return (
        email: row['email'] as String? ?? '—',
        fullName: row['full_name'] as String? ?? '—',
      );
    }).toList();
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
