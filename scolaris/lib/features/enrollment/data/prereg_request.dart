// File d'attente des **pré-inscriptions** — maquette (état en mémoire).
// En prod : table `enrollment_requests` (INSERT public anonyme, SELECT/UPDATE
// admin de l'école). Accepter → crée la fiche élève + les comptes via l'Edge
// Function `create-account`.

/// Statut du dossier.
enum PreRegStatus { pending, accepted, rejected }

/// État du paiement des frais de dossier (payés d'abord, non remboursables).
enum PreRegPay { online, cash, unpaid }

class PreRegRequest {
  final String id;
  final String firstName;
  final String lastName;
  final String level; // niveau souhaité
  final String guardianName;
  final String guardianPhone;
  final String guardianEmail;
  final String city;
  final DateTime submittedAt;
  final PreRegPay pay;
  final int feeAmount; // frais de dossier (FCFA)
  final Map<String, String> data; // champs additionnels (pour le détail)
  PreRegStatus status;

  PreRegRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.level,
    required this.guardianName,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.city,
    required this.submittedAt,
    required this.pay,
    required this.feeAmount,
    this.data = const {},
    this.status = PreRegStatus.pending,
  });

  String get fullName => '$firstName $lastName';
}

class PreRegRequests {
  PreRegRequests._();

  static final DateTime _now = DateTime(2026, 6, 30);

  static final List<PreRegRequest> items = [
    PreRegRequest(
      id: 'r1',
      firstName: 'Gloire',
      lastName: 'Makoumbou',
      level: 'Collège (6e)',
      guardianName: 'Andrée Koumba',
      guardianPhone: '+242 06 555 12 34',
      guardianEmail: 'a.koumba@gmail.com',
      city: 'Brazzaville',
      submittedAt: _now.subtract(const Duration(hours: 3)),
      pay: PreRegPay.online,
      feeAmount: 15000,
      data: {
        'Date de naissance': '14/03/2014',
        'Lieu de naissance': 'Brazzaville',
        'Genre': 'Féminin',
        'Nationalité': 'Congolaise',
        'Ancien établissement': 'École Le Savoir',
        'Lien de parenté': 'Mère',
      },
    ),
    PreRegRequest(
      id: 'r2',
      firstName: 'Junior',
      lastName: 'Ondongo',
      level: 'Primaire (CM2)',
      guardianName: 'Pascal Nzoukou',
      guardianPhone: '+242 05 444 88 21',
      guardianEmail: 'pascal.nz@gmail.com',
      city: 'Pointe-Noire',
      submittedAt: _now.subtract(const Duration(hours: 20)),
      pay: PreRegPay.cash,
      feeAmount: 15000,
      data: {
        'Date de naissance': '02/09/2015',
        'Lieu de naissance': 'Pointe-Noire',
        'Genre': 'Masculin',
        'Lien de parenté': 'Père',
      },
    ),
    PreRegRequest(
      id: 'r3',
      firstName: 'Sarah',
      lastName: 'Ibara',
      level: 'Lycée (2nde)',
      guardianName: 'Rose Okemba',
      guardianPhone: '+242 06 333 77 09',
      guardianEmail: 'rose.okemba@gmail.com',
      city: 'Brazzaville',
      submittedAt: _now.subtract(const Duration(days: 2)),
      pay: PreRegPay.unpaid,
      feeAmount: 15000,
      data: {
        'Date de naissance': '21/06/2010',
        'Genre': 'Féminin',
        'Filière / Spécialité': 'Scientifique',
        'Lien de parenté': 'Tuteur légal',
      },
    ),
    PreRegRequest(
      id: 'r4',
      firstName: 'Emmanuel',
      lastName: 'Loemba',
      level: 'Collège (4e)',
      guardianName: 'Henri Loemba',
      guardianPhone: '+243 81 234 56 78',
      guardianEmail: 'h.loemba@gmail.com',
      city: 'Kinshasa',
      submittedAt: _now.subtract(const Duration(days: 5)),
      pay: PreRegPay.online,
      feeAmount: 15000,
      status: PreRegStatus.accepted,
      data: {
        'Date de naissance': '11/11/2012',
        'Genre': 'Masculin',
      },
    ),
  ];

  // ── Agrégats ──────────────────────────────────────────────────────────────
  static int get pendingCount =>
      items.where((r) => r.status == PreRegStatus.pending).length;

  // ── Mutations (maquette) ────────────────────────────────────────────────
  static void accept(String id) => _setStatus(id, PreRegStatus.accepted);
  static void reject(String id) => _setStatus(id, PreRegStatus.rejected);

  static void _setStatus(String id, PreRegStatus s) {
    final i = items.indexWhere((r) => r.id == id);
    if (i >= 0) items[i].status = s;
  }
}
