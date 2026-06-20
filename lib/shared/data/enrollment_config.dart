/// Configuration des champs du formulaire d'inscription.
/// L'admin peut activer/désactiver chaque champ et le marquer comme obligatoire.

// ── Type de champ ─────────────────────────────────────────────────────────
enum FieldType {
  text,
  date,
  phone,
  email,
  select,
  photo,
  file,
  toggle,
  textarea,
  number,
}

// ── Définition d'un champ d'inscription ──────────────────────────────────
class EnrollmentField {
  final String id;
  final String label;
  final String placeholder;
  final FieldType type;
  final List<String> options;
  final bool defaultEnabled;
  final bool defaultRequired;
  final bool alwaysRequired;
  final String category;
  final String? hint;

  const EnrollmentField({
    required this.id,
    required this.label,
    this.placeholder = '',
    required this.type,
    this.options = const [],
    this.defaultEnabled = true,
    this.defaultRequired = false,
    this.alwaysRequired = false,
    required this.category,
    this.hint,
  });
}

// ── Tous les champs disponibles ───────────────────────────────────────────
class EnrollmentFields {
  static const List<EnrollmentField> all = [

    // ── IDENTITÉ ─────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'photo',
      label: 'Photo d\'identité',
      type: FieldType.photo,
      defaultEnabled: true,
      defaultRequired: true,
      category: 'Identité',
      hint: 'Photo récente, fond blanc, visage visible',
    ),
    EnrollmentField(
      id: 'last_name',
      label: 'Nom de famille',
      placeholder: 'Ex : Diallo',
      type: FieldType.text,
      defaultEnabled: true,
      alwaysRequired: true,
      category: 'Identité',
    ),
    EnrollmentField(
      id: 'first_name',
      label: 'Prénom(s)',
      placeholder: 'Ex : Mamadou',
      type: FieldType.text,
      defaultEnabled: true,
      alwaysRequired: true,
      category: 'Identité',
    ),
    EnrollmentField(
      id: 'birth_date',
      label: 'Date de naissance',
      placeholder: 'JJ/MM/AAAA',
      type: FieldType.date,
      defaultEnabled: true,
      defaultRequired: true,
      category: 'Identité',
    ),
    EnrollmentField(
      id: 'birth_place',
      label: 'Lieu de naissance',
      placeholder: 'Ville, Pays',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: true,
      category: 'Identité',
    ),
    EnrollmentField(
      id: 'gender',
      label: 'Genre',
      type: FieldType.select,
      options: ['Masculin', 'Féminin', 'Autre / Non renseigné'],
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Identité',
    ),
    EnrollmentField(
      id: 'nationality',
      label: 'Nationalité',
      placeholder: 'Ex : Sénégalaise',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Identité',
    ),

    // ── DOCUMENTS ─────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'cin',
      label: 'N° Carte d\'identité nationale',
      placeholder: 'Ex : SN-XXXXXXXXXX',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Documents',
      hint: 'CIN ou numéro de passeport',
    ),
    EnrollmentField(
      id: 'passport',
      label: 'N° Passeport',
      placeholder: 'Ex : A12345678',
      type: FieldType.text,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Documents',
    ),
    EnrollmentField(
      id: 'cin_file',
      label: 'Scan CIN / Passeport',
      type: FieldType.file,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Documents',
      hint: 'PDF ou image JPG/PNG, max 5 Mo',
    ),
    EnrollmentField(
      id: 'birth_certificate',
      label: 'Acte de naissance',
      type: FieldType.file,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Documents',
      hint: 'Copie certifiée conforme',
    ),

    // ── ACADÉMIQUE ────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'level',
      label: 'Niveau scolaire',
      type: FieldType.select,
      options: [
        'Primaire (CP)', 'Primaire (CE1)', 'Primaire (CE2)',
        'Primaire (CM1)', 'Primaire (CM2)',
        'Collège (6e)', 'Collège (5e)', 'Collège (4e)', 'Collège (3e)',
        'Lycée (2nde)', 'Lycée (1ère)', 'Lycée (Tle)',
        'Université (L1)', 'Université (L2)', 'Université (L3)',
        'Master (M1)', 'Master (M2)', 'Doctorat',
      ],
      defaultEnabled: true,
      alwaysRequired: true,
      category: 'Académique',
    ),
    EnrollmentField(
      id: 'last_diploma',
      label: 'Dernier diplôme obtenu',
      placeholder: 'Ex : BEPC, Baccalauréat, Licence...',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Académique',
    ),
    EnrollmentField(
      id: 'last_diploma_file',
      label: 'Copie du dernier diplôme',
      type: FieldType.file,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Académique',
      hint: 'PDF ou image certifiée conforme',
    ),
    EnrollmentField(
      id: 'last_school',
      label: 'Ancien établissement',
      placeholder: 'Nom de l\'école précédente',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Académique',
    ),
    EnrollmentField(
      id: 'last_report',
      label: 'Dernier bulletin scolaire',
      type: FieldType.file,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Académique',
      hint: 'Bulletin de l\'année précédente',
    ),
    EnrollmentField(
      id: 'specialty',
      label: 'Filière / Spécialité',
      placeholder: 'Ex : Sciences, Littérature...',
      type: FieldType.text,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Académique',
    ),

    // ── CONTACT ───────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'phone',
      label: 'Téléphone (élève/étudiant)',
      placeholder: 'Ex : +221 77 000 00 00',
      type: FieldType.phone,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Contact',
    ),
    EnrollmentField(
      id: 'email',
      label: 'Email (élève/étudiant)',
      placeholder: 'prenom.nom@email.com',
      type: FieldType.email,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Contact',
    ),
    EnrollmentField(
      id: 'address',
      label: 'Adresse résidentielle',
      placeholder: 'Quartier, Ville',
      type: FieldType.textarea,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Contact',
    ),

    // ── TUTEUR / PARENT ───────────────────────────────────────────────────
    EnrollmentField(
      id: 'guardian_name',
      label: 'Nom complet du tuteur / parent',
      placeholder: 'Ex : Fatou Diallo',
      type: FieldType.text,
      defaultEnabled: true,
      defaultRequired: true,
      category: 'Tuteur',
    ),
    EnrollmentField(
      id: 'guardian_relation',
      label: 'Lien de parenté',
      type: FieldType.select,
      options: ['Père', 'Mère', 'Tuteur légal', 'Grand-parent', 'Autre'],
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Tuteur',
    ),
    EnrollmentField(
      id: 'guardian_phone',
      label: 'Téléphone du tuteur',
      placeholder: 'Ex : +221 77 000 00 00',
      type: FieldType.phone,
      defaultEnabled: true,
      defaultRequired: true,
      category: 'Tuteur',
    ),
    EnrollmentField(
      id: 'guardian_email',
      label: 'Email du tuteur',
      placeholder: 'parent@email.com',
      type: FieldType.email,
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Tuteur',
    ),
    EnrollmentField(
      id: 'guardian_profession',
      label: 'Profession du tuteur',
      placeholder: 'Ex : Enseignant, Médecin...',
      type: FieldType.text,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Tuteur',
    ),
    EnrollmentField(
      id: 'guardian_cin',
      label: 'CIN / Passeport du tuteur',
      placeholder: 'N° pièce d\'identité',
      type: FieldType.text,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Tuteur',
    ),

    // ── PAIEMENT ─────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'payment_mode',
      label: 'Mode de paiement',
      type: FieldType.select,
      options: ['Espèces', 'Chèque', 'Virement', 'Mobile Money', 'Carte bancaire'],
      defaultEnabled: true,
      defaultRequired: false,
      category: 'Paiement',
    ),
    EnrollmentField(
      id: 'scholarship',
      label: 'Boursier',
      type: FieldType.toggle,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Paiement',
    ),
    EnrollmentField(
      id: 'scholarship_file',
      label: 'Attestation de bourse',
      type: FieldType.file,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Paiement',
    ),

    // ── MÉDICAL ───────────────────────────────────────────────────────────
    EnrollmentField(
      id: 'medical_notes',
      label: 'Informations médicales',
      placeholder: 'Allergies, traitements, besoins spéciaux...',
      type: FieldType.textarea,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Médical',
      hint: 'Informations confidentielles réservées au personnel médical',
    ),
    EnrollmentField(
      id: 'medical_cert',
      label: 'Certificat médical d\'aptitude',
      type: FieldType.file,
      defaultEnabled: false,
      defaultRequired: false,
      category: 'Médical',
    ),
  ];

  static List<EnrollmentField> byCategory(String cat) =>
      all.where((f) => f.category == cat).toList();

  static List<String> get categories =>
      all.map((f) => f.category).toSet().toList();
}

// ── State mutable d'un champ (modifiable par l'admin) ─────────────────────
class EnrollmentFieldState {
  final String fieldId;
  bool enabled;
  bool required;
  String? customLabel;

  EnrollmentFieldState({
    required this.fieldId,
    required this.enabled,
    required this.required,
    this.customLabel,
  });

  factory EnrollmentFieldState.fromDefault(EnrollmentField f) =>
      EnrollmentFieldState(
        fieldId: f.id,
        enabled: f.defaultEnabled || f.alwaysRequired,
        required: f.defaultRequired || f.alwaysRequired,
      );
}

// ── Config globale (gérée par l'admin) ────────────────────────────────────
class EnrollmentConfig {
  final Map<String, EnrollmentFieldState> fields;
  final String? welcomeMessage;
  final bool allowOnlineSubmission;
  final bool requirePaymentAtRegistration;

  EnrollmentConfig({
    required this.fields,
    this.welcomeMessage,
    this.allowOnlineSubmission = true,
    this.requirePaymentAtRegistration = false,
  });

  factory EnrollmentConfig.defaults() {
    final map = <String, EnrollmentFieldState>{};
    for (final f in EnrollmentFields.all) {
      map[f.id] = EnrollmentFieldState.fromDefault(f);
    }
    return EnrollmentConfig(fields: map);
  }

  /// Sérialise pour la base (colonne `schools.enrollment_config`).
  Map<String, dynamic> toJson() => {
        'fields': {
          for (final e in fields.entries)
            e.key: {'enabled': e.value.enabled, 'required': e.value.required},
        },
        'welcomeMessage': welcomeMessage,
        'allowOnlineSubmission': allowOnlineSubmission,
        'requirePaymentAtRegistration': requirePaymentAtRegistration,
      };

  /// Reconstruit depuis la base en partant des valeurs par défaut (un champ
  /// ajouté au code plus tard apparaît même s'il n'est pas dans le JSON stocké).
  /// `alwaysRequired` reste forcé même si le JSON dit le contraire.
  factory EnrollmentConfig.fromJson(Map<String, dynamic> json) {
    final cfg = EnrollmentConfig.defaults();
    final storedFields = json['fields'];
    if (storedFields is Map) {
      for (final f in EnrollmentFields.all) {
        final s = storedFields[f.id];
        if (s is Map) {
          final st = cfg.fields[f.id]!;
          if (!f.alwaysRequired) {
            st.enabled = s['enabled'] == true;
            st.required = s['required'] == true && st.enabled;
          }
        }
      }
    }
    return EnrollmentConfig(
      fields: cfg.fields,
      welcomeMessage: json['welcomeMessage'] as String?,
      allowOnlineSubmission: json['allowOnlineSubmission'] as bool? ?? true,
      requirePaymentAtRegistration:
          json['requirePaymentAtRegistration'] as bool? ?? false,
    );
  }

  List<EnrollmentField> get enabledFields => EnrollmentFields.all
      .where((f) => fields[f.id]?.enabled == true)
      .toList();

  bool isRequired(String fieldId) =>
      EnrollmentFields.all.any((f) => f.id == fieldId && f.alwaysRequired) ||
      (fields[fieldId]?.required ?? false);
}
