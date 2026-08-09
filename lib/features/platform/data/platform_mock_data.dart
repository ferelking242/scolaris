import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Offres commerciales (cf. business-model).
enum PlatformPlan { simple, pro, max }

extension PlatformPlanX on PlatformPlan {
  // Alignées sur `plans.name` (cf. 20260801_offer_tiers.sql — offres par
  // modules, pas par taille). Ce sont des VALEURS PAR DÉFAUT : si les prix
  // changent dans Réglages (`plan_prices`), penser à les remettre à jour ici
  // aussi — `platform_subscriptions_page.dart` (MRR, revenu par offre)
  // utilise CES constantes, pas la vraie table `plan_prices`.
  String get label => switch (this) {
        PlatformPlan.simple => 'Essentiel',
        PlatformPlan.pro => 'Croissance',
        PlatformPlan.max => 'Complet',
      };

  /// Prix mensuel par défaut (FCFA, Congo) — cf. `plan_prices`, vérifié en
  /// direct le 03/08/2026.
  int get monthlyPrice => switch (this) {
        PlatformPlan.simple => 8900,
        PlatformPlan.pro => 17900,
        PlatformPlan.max => 29900,
      };

  /// `plans.max_students` (plafond dur) est `null` pour les 3 offres depuis
  /// le passage aux offres par modules — mais il y a bien une franchise
  /// (`plans.included_students`) au-delà de laquelle un supplément de taille
  /// s'applique. Affiché comme la vraie limite d'usage : pas un plafond qui
  /// bloque, mais pas « illimité » non plus (sinon toutes les écoles
  /// affichent la même chose, plus aucun signal utile). Vérifié en direct
  /// le 03/08/2026.
  int? get studentLimit => switch (this) {
        PlatformPlan.simple => 200,
        PlatformPlan.pro => 500,
        PlatformPlan.max => 1500,
      };

  Color get color => switch (this) {
        PlatformPlan.simple => ScolarisPalette.forestGreen,
        PlatformPlan.pro => ScolarisAccents.sapphire,
        PlatformPlan.max => ScolarisAccents.violet,
      };
}

/// Cycle de vie de l'abonnement d'une école (cf. table `subscriptions`).
enum SubStatus { trial, active, pastDue, expired, canceled }

extension SubStatusX on SubStatus {
  String get label => switch (this) {
        SubStatus.trial => 'Essai',
        SubStatus.active => 'Actif',
        SubStatus.pastDue => 'Impayé',
        SubStatus.expired => 'Expiré',
        SubStatus.canceled => 'Résilié',
      };
}

/// Un versement d'abonnement (mock — futur `subscription_payments`).
class PlatformPayment {
  final DateTime date;
  final int amount;
  final String method; // 'MTN MoMo', 'Airtel Money', 'Virement'…
  final String period; // ex. « Mars 2026 »
  final bool success;
  const PlatformPayment({
    required this.date,
    required this.amount,
    required this.method,
    required this.period,
    this.success = true,
  });
}

/// Un versement d'abonnement en attente de vérification (référence Mobile
/// Money saisie par l'école, pas encore confirmée) — cf.
/// `PlatformRepository.getPendingSubscriptionPayments`.
class PlatformPendingPayment {
  final String id;
  final String schoolName;
  final String planCode;
  final String period; // 'monthly' | 'annual'
  final double amount;
  final String currency;
  final String? provider; // 'mtn' | 'airtel'
  final String? reference;
  final DateTime createdAt;

  /// 'plan_change' (défaut, active une offre à la confirmation) ou
  /// 'addon_slot' (achat à la carte d'un emplacement de module — la
  /// confirmation n'active AUCUNE offre, cf.
  /// `platform_confirm_subscription_payment` / 20260809_module_slot_addon.sql).
  final String paymentType;
  final int quantity;

  bool get isAddonSlot => paymentType == 'addon_slot';

  const PlatformPendingPayment({
    required this.id,
    required this.schoolName,
    required this.planCode,
    required this.period,
    required this.amount,
    required this.currency,
    this.provider,
    this.reference,
    required this.createdAt,
    this.paymentType = 'plan_change',
    this.quantity = 1,
  });
}

/// Un évènement du cycle de vie de l'abonnement (timeline).
class SubEvent {
  final DateTime date;
  final String title;
  final IconData icon;
  final Color color;
  const SubEvent({
    required this.date,
    required this.title,
    required this.icon,
    required this.color,
  });
}

/// Ligne d'élève (mock) pour l'onglet Élèves de la fiche.
class PlatformStudentRow {
  final String name;
  final String className;
  final String matricule;
  final bool active;
  const PlatformStudentRow({
    required this.name,
    required this.className,
    required this.matricule,
    required this.active,
  });
}

/// Élément du flux d'activité d'une école (onglet Activité).
class ActivityItem {
  final IconData icon;
  final Color color;
  final String text;
  final String ago;
  const ActivityItem(this.icon, this.color, this.text, this.ago);
}

/// Représentation « plateforme » d'une école (agrège école + abonnement +
/// effectif + contact). En prod, viendra de l'Edge Function `platform-admin`.
class PlatformSchool {
  final String id;
  final String name;
  final String city;
  final String country;
  final List<String> types;
  final DateTime createdAt;
  final PlatformPlan plan;
  final SubStatus status;
  final int studentCount;
  final int teacherCount;
  final int classCount;

  /// Fin d'essai (si en essai) ou fin de période payée.
  final DateTime periodEnd;

  // Contact du responsable.
  final String director;
  final String email;
  final String phone;

  /// `false` tant qu'une école auto-inscrite (self-signup depuis le site
  /// vitrine) n'a pas été validée par l'équipe Scolaris — son responsable a
  /// un compte mais ne peut pas encore se connecter (cf. `SupabaseAuthSource`).
  final bool isActive;

  const PlatformSchool({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.types,
    required this.createdAt,
    required this.plan,
    required this.status,
    required this.studentCount,
    required this.teacherCount,
    required this.classCount,
    required this.periodEnd,
    required this.director,
    required this.email,
    required this.phone,
    this.isActive = true,
  });

  PlatformSchool copyWith({
    PlatformPlan? plan,
    SubStatus? status,
    DateTime? periodEnd,
    bool? isActive,
  }) =>
      PlatformSchool(
        id: id,
        name: name,
        city: city,
        country: country,
        types: types,
        createdAt: createdAt,
        plan: plan ?? this.plan,
        status: status ?? this.status,
        studentCount: studentCount,
        teacherCount: teacherCount,
        classCount: classCount,
        periodEnd: periodEnd ?? this.periodEnd,
        director: director,
        email: email,
        phone: phone,
        isActive: isActive ?? this.isActive,
      );

  int? get studentLimit => plan.studentLimit;

  /// Ratio d'usage d'élèves (0..1) ; 0 si illimité.
  double get usageRatio {
    final lim = studentLimit;
    if (lim == null || lim == 0) return 0;
    return (studentCount / lim).clamp(0, 1);
  }

  /// Compte-t-elle dans le revenu récurrent (payante et à jour) ?
  bool get isPaying => status == SubStatus.active || status == SubStatus.pastDue;

  /// Jours restants avant la fin de période/essai (négatif = dépassé). La
  /// vraie date du jour — PAS `PlatformMock.now` (figée pour la maquette) —
  /// sinon une vraie école aurait un compte à rebours faux.
  int get daysLeft => periodEnd.difference(DateTime.now()).inDays;

  String get typesLabel {
    const fr = {
      'primaire': 'Primaire',
      'college': 'Collège',
      'lycee': 'Lycée',
      'univ': 'Université',
    };
    return types.map((t) => fr[t] ?? t).join(' · ');
  }
}

/// Données de démonstration — remplacées à terme par l'Edge Function.
class PlatformMock {
  PlatformMock._();

  static final DateTime now = DateTime(2026, 6, 30);

  static final List<PlatformSchool> schools = [
    PlatformSchool(
      id: 's1',
      name: 'EAD Brazzaville',
      city: 'Brazzaville',
      country: 'Congo',
      types: ['college', 'lycee'],
      createdAt: now.subtract(const Duration(days: 96)),
      plan: PlatformPlan.pro,
      status: SubStatus.active,
      studentCount: 742,
      teacherCount: 38,
      classCount: 24,
      periodEnd: now.add(const Duration(days: 19)),
      director: 'Serge Bouya',
      email: 'direction@ead-bzv.cg',
      phone: '+242 06 555 12 34',
    ),
    PlatformSchool(
      id: 's2',
      name: 'Collège Les Rapides',
      city: 'Pointe-Noire',
      country: 'Congo',
      types: ['college'],
      createdAt: now.subtract(const Duration(days: 61)),
      plan: PlatformPlan.simple,
      status: SubStatus.active,
      studentCount: 168,
      teacherCount: 12,
      classCount: 8,
      periodEnd: now.add(const Duration(days: 8)),
      director: 'Andrée Koumba',
      email: 'contact@lesrapides.cg',
      phone: '+242 05 444 88 21',
    ),
    PlatformSchool(
      id: 's3',
      name: 'Institut Sainte-Marie',
      city: 'Brazzaville',
      country: 'Congo',
      types: ['primaire', 'college'],
      createdAt: now.subtract(const Duration(days: 14)),
      plan: PlatformPlan.simple,
      status: SubStatus.trial,
      studentCount: 54,
      teacherCount: 6,
      classCount: 5,
      periodEnd: now.add(const Duration(days: 16)),
      director: 'Sœur Béatrice',
      email: 'secretariat@sainte-marie.cg',
      phone: '+242 06 333 77 09',
    ),
    PlatformSchool(
      id: 's4',
      name: 'Groupe Scolaire Horizon',
      city: 'Dolisie',
      country: 'Congo',
      types: ['primaire', 'college', 'lycee'],
      createdAt: now.subtract(const Duration(days: 205)),
      plan: PlatformPlan.max,
      status: SubStatus.active,
      studentCount: 1340,
      teacherCount: 74,
      classCount: 46,
      periodEnd: now.add(const Duration(days: 168)),
      director: 'Pascal Nzoukou',
      email: 'admin@gs-horizon.cg',
      phone: '+242 06 222 45 67',
    ),
    PlatformSchool(
      id: 's5',
      name: 'École Le Savoir',
      city: 'Owando',
      country: 'Congo',
      types: ['primaire'],
      createdAt: now.subtract(const Duration(days: 33)),
      plan: PlatformPlan.pro,
      status: SubStatus.pastDue,
      studentCount: 410,
      teacherCount: 21,
      classCount: 14,
      periodEnd: now.subtract(const Duration(days: 3)),
      director: 'Rose Okemba',
      email: 'direction@lesavoir.cg',
      phone: '+242 05 111 90 42',
    ),
    PlatformSchool(
      id: 's6',
      name: 'Lycée de l\'Étoile',
      city: 'Kinshasa',
      country: 'RD Congo',
      types: ['lycee'],
      createdAt: now.subtract(const Duration(days: 7)),
      plan: PlatformPlan.simple,
      status: SubStatus.trial,
      studentCount: 21,
      teacherCount: 4,
      classCount: 3,
      periodEnd: now.add(const Duration(days: 23)),
      director: 'Henri Loemba',
      email: 'contact@lycee-etoile.cd',
      phone: '+243 81 234 56 78',
    ),
    PlatformSchool(
      id: 's7',
      name: 'Complexe Scolaire Bilingue',
      city: 'Libreville',
      country: 'Gabon',
      types: ['college', 'lycee'],
      createdAt: now.subtract(const Duration(days: 128)),
      plan: PlatformPlan.pro,
      status: SubStatus.active,
      studentCount: 655,
      teacherCount: 33,
      classCount: 21,
      periodEnd: now.add(const Duration(days: 41)),
      director: 'Alain Nzoussi',
      email: 'direction@csb-gabon.ga',
      phone: '+241 06 78 90 12',
    ),
    PlatformSchool(
      id: 's8',
      name: 'École Primaire Kimbondo',
      city: 'Brazzaville',
      country: 'Congo',
      types: ['primaire'],
      createdAt: now.subtract(const Duration(days: 240)),
      plan: PlatformPlan.simple,
      status: SubStatus.expired,
      studentCount: 96,
      teacherCount: 7,
      classCount: 6,
      periodEnd: now.subtract(const Duration(days: 27)),
      director: 'Christelle Niangou',
      email: 'ecole.kimbondo@gmail.com',
      phone: '+242 06 909 11 22',
    ),
  ];

  static PlatformSchool byId(String id) =>
      schools.firstWhere((s) => s.id == id);

  // ── Création (maquette : ajoute en mémoire ; en prod → Edge Function
  //    `create-account` qui crée l'école + le compte admin). ─────────────────
  static int _seq = 100;
  static PlatformSchool add({
    required String name,
    required String city,
    required String country,
    required List<String> types,
    required PlatformPlan plan,
    required String director,
    required String email,
    required String phone,
  }) {
    final s = PlatformSchool(
      id: 's${++_seq}',
      name: name.trim(),
      city: city.trim(),
      country: country.trim(),
      types: types.isEmpty ? const ['primaire'] : types,
      createdAt: now,
      plan: plan,
      status: SubStatus.trial, // toute nouvelle école démarre en essai
      studentCount: 0,
      teacherCount: 0,
      classCount: 0,
      periodEnd: now.add(const Duration(days: 30)),
      director: director.trim(),
      email: email.trim(),
      phone: phone.trim(),
    );
    schools.add(s);
    return s;
  }

  // ── Mutations (maquette : effet en mémoire, remplacées par l'API en prod) ──
  static PlatformSchool _replace(String id, PlatformSchool ns) {
    final i = schools.indexWhere((s) => s.id == id);
    if (i >= 0) schools[i] = ns;
    return ns;
  }

  static PlatformSchool setStatus(String id, SubStatus status) =>
      _replace(id, byId(id).copyWith(status: status));

  static PlatformSchool setPlan(String id, PlatformPlan plan) =>
      _replace(id, byId(id).copyWith(plan: plan));

  static PlatformSchool extendTrial(String id, int days) {
    final s = byId(id);
    return _replace(id, s.copyWith(periodEnd: s.periodEnd.add(Duration(days: days))));
  }

  // ── Séries temporelles (mock) pour les graphiques ─────────────────────────
  /// 6 derniers mois (finissant au mois courant).
  static const trendMonths = ['jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin'];

  /// Écoles cumulées sur la plateforme, mois par mois.
  static const schoolsTrend = <double>[2, 3, 5, 6, 7, 8];

  /// Revenu mensuel récurrent (FCFA) mois par mois.
  static const mrrTrend =
      <double>[45000, 75000, 105000, 120000, 150000, 164500];

  // ── Agrégats plateforme (KPIs) ──────────────────────────────────────────
  static int get total => schools.length;
  static int get paying => schools.where((s) => s.isPaying).length;
  static int get trials => schools.where((s) => s.status == SubStatus.trial).length;
  static int get churned =>
      schools.where((s) => s.status == SubStatus.expired || s.status == SubStatus.canceled).length;

  /// Revenu mensuel récurrent estimé (somme des offres des écoles payantes).
  static int get mrr => schools
      .where((s) => s.isPaying)
      .fold(0, (sum, s) => sum + s.plan.monthlyPrice);

  static int get totalStudents =>
      schools.fold(0, (sum, s) => sum + s.studentCount);

  /// Répartition par offre (toutes écoles confondues).
  static Map<PlatformPlan, int> get planBreakdown {
    final m = {for (final p in PlatformPlan.values) p: 0};
    for (final s in schools) {
      m[s.plan] = (m[s.plan] ?? 0) + 1;
    }
    return m;
  }

  /// Écoles triées par date d'inscription (plus récentes d'abord).
  static List<PlatformSchool> get recent =>
      [...schools]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Écoles nécessitant une attention (impayé / expiré / essai bientôt fini).
  static List<PlatformSchool> get needsAttention => schools
      .where((s) =>
          s.status == SubStatus.pastDue ||
          s.status == SubStatus.expired ||
          (s.status == SubStatus.trial && s.daysLeft <= 20))
      .toList();

  // ── Détail par école (mock généré) ───────────────────────────────────────
  static const _months = [
    'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
  ];

  /// Historique de paiements (déduit de l'offre + ancienneté).
  static List<PlatformPayment> paymentsFor(PlatformSchool s) {
    if (s.status == SubStatus.trial) return const [];
    final methods = ['MTN MoMo', 'Airtel Money', 'Virement'];
    final count = s.status == SubStatus.expired ? 3 : 5;
    final out = <PlatformPayment>[];
    for (var i = 0; i < count; i++) {
      final d = DateTime(now.year, now.month - i, 5);
      // L'impayé courant : le dernier versement a échoué.
      final failed = s.status == SubStatus.pastDue && i == 0;
      out.add(PlatformPayment(
        date: d,
        amount: s.plan.monthlyPrice,
        method: methods[(s.id.hashCode + i).abs() % methods.length],
        period: '${_months[d.month - 1]} ${d.year}',
        success: !failed,
      ));
    }
    return out;
  }

  // ── Élèves (mock déterministe pour la fiche) ──────────────────────────────
  static const _firstNames = [
    'Bienvenu', 'Alice', 'Ferel', 'Gloire', 'Céleste', 'Rémy', 'Patricia',
    'Henri', 'Rose', 'Thomas', 'Andrée', 'Serge', 'Christelle', 'Pascal',
    'Nadia', 'Emmanuel', 'Divine', 'Grâce', 'Junior', 'Sarah',
  ];
  static const _lastNames = [
    'Makoumbou', 'Moukoko', 'Ondongo', 'Mouamba', 'Ibara', 'Makosso',
    'Etsiona', 'Loemba', 'Okemba', 'Mouyabi', 'Koumba', 'Bouya', 'Niangou',
    'Nzoukou', 'Bantsimba', 'Massamba', 'Kimbembe', 'Goma',
  ];

  static const _classCatalog = {
    'primaire': ['CP', 'CE1', 'CE2', 'CM1', 'CM2'],
    'college': ['6ème', '5ème', '4ème', '3ème'],
    'lycee': ['2nde', '1ère', 'Terminale'],
    'univ': ['L1', 'L2', 'L3'],
  };

  static List<String> classesFor(PlatformSchool s) {
    final out = <String>[];
    for (final t in s.types) {
      out.addAll(_classCatalog[t] ?? const []);
    }
    return out.isEmpty ? const ['—'] : out;
  }

  /// Échantillon d'élèves (max 12) pour l'onglet Élèves de la fiche.
  static List<PlatformStudentRow> studentsFor(PlatformSchool s) {
    final n = s.studentCount.clamp(0, 12);
    final classes = classesFor(s);
    final out = <PlatformStudentRow>[];
    for (var i = 0; i < n; i++) {
      final seed = (s.id.hashCode + i * 31).abs();
      final fn = _firstNames[seed % _firstNames.length];
      final ln = _lastNames[(seed ~/ 5) % _lastNames.length];
      out.add(PlatformStudentRow(
        name: '$fn $ln',
        className: classes[i % classes.length],
        matricule: 'MAT-${now.year}-${(101 + i)}',
        active: i % 9 != 0,
      ));
    }
    return out;
  }

  /// Flux d'activité récent de l'école (onglet Activité).
  static List<ActivityItem> activityFor(PlatformSchool s) {
    final items = <ActivityItem>[
      const ActivityItem(Icons.person_add_rounded, ScolarisPalette.terracotta,
          'Nouvel élève inscrit', 'il y a 2 h'),
      const ActivityItem(Icons.grade_rounded, ScolarisPalette.gold,
          'Notes du 2ᵉ trimestre saisies', 'il y a 5 h'),
      const ActivityItem(Icons.campaign_rounded, ScolarisPalette.forestGreen,
          'Annonce publiée aux parents', 'hier'),
      const ActivityItem(Icons.event_available_rounded, ScolarisAccents.sapphire,
          'Emploi du temps mis à jour', 'il y a 2 j'),
      const ActivityItem(Icons.login_rounded, ScolarisAccents.slate,
          'Connexion de la direction', 'il y a 3 j'),
    ];
    if (s.isPaying) {
      items.insert(
          3,
          const ActivityItem(Icons.payments_rounded, ScolarisPalette.forestGreen,
              'Paiement de scolarité encaissé', 'hier'));
    }
    if (s.status == SubStatus.pastDue) {
      items.insert(
          0,
          const ActivityItem(Icons.error_outline_rounded, ScolarisPalette.orange,
              'Échec de prélèvement de l\'abonnement', 'il y a 3 j'));
    }
    return items;
  }

  /// Timeline du cycle de vie de l'abonnement.
  static List<SubEvent> timelineFor(PlatformSchool s) {
    final events = <SubEvent>[
      SubEvent(
        date: s.createdAt,
        title: 'École inscrite sur Scolaris',
        icon: Icons.rocket_launch_rounded,
        color: ScolarisPalette.terracotta,
      ),
      SubEvent(
        date: s.createdAt,
        title: 'Essai gratuit démarré (offre Simple)',
        icon: Icons.hourglass_top_rounded,
        color: ScolarisPalette.gold,
      ),
    ];
    if (s.status != SubStatus.trial) {
      events.add(SubEvent(
        date: s.createdAt.add(const Duration(days: 25)),
        title: 'Abonnement ${s.plan.label} activé',
        icon: Icons.workspace_premium_rounded,
        color: s.plan.color,
      ));
    }
    if (s.status == SubStatus.pastDue) {
      events.add(SubEvent(
        date: s.periodEnd,
        title: 'Paiement en retard détecté',
        icon: Icons.error_outline_rounded,
        color: ScolarisPalette.orange,
      ));
    }
    if (s.status == SubStatus.expired) {
      events.add(SubEvent(
        date: s.periodEnd,
        title: 'Abonnement expiré — accès en lecture seule',
        icon: Icons.block_rounded,
        color: ScolarisPalette.terracotta,
      ));
    }
    return events.reversed.toList(); // plus récent en haut
  }
}
