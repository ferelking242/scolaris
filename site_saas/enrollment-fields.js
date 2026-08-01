// Miroir JS de lib/shared/data/enrollment_config.dart (EnrollmentFields.all).
// ⚠️ Garder synchronisé : c'est la même liste qui pilote le formulaire Flutter.
const ENROLLMENT_FIELDS = [
  { id: "photo", label: "Photo d'identité", type: "photo", defaultEnabled: true, defaultRequired: true, category: "Identité", hint: "Photo récente, fond blanc, visage visible" },
  { id: "last_name", label: "Nom de famille", placeholder: "Ex : Diallo", type: "text", defaultEnabled: true, alwaysRequired: true, category: "Identité" },
  { id: "first_name", label: "Prénom(s)", placeholder: "Ex : Mamadou", type: "text", defaultEnabled: true, alwaysRequired: true, category: "Identité" },
  { id: "birth_date", label: "Date de naissance", placeholder: "JJ/MM/AAAA", type: "date", defaultEnabled: true, defaultRequired: true, category: "Identité" },
  { id: "birth_place", label: "Lieu de naissance", placeholder: "Ville, Pays", type: "text", defaultEnabled: true, defaultRequired: true, category: "Identité" },
  { id: "gender", label: "Genre", type: "select", options: ["Masculin", "Féminin", "Autre / Non renseigné"], defaultEnabled: true, defaultRequired: false, category: "Identité" },
  { id: "nationality", label: "Nationalité", placeholder: "Ex : Sénégalaise", type: "text", defaultEnabled: true, defaultRequired: false, category: "Identité" },

  { id: "cin", label: "N° Carte d'identité nationale", placeholder: "Ex : SN-XXXXXXXXXX", type: "text", defaultEnabled: true, defaultRequired: false, category: "Documents", hint: "CIN ou numéro de passeport" },
  { id: "passport", label: "N° Passeport", placeholder: "Ex : A12345678", type: "text", defaultEnabled: false, defaultRequired: false, category: "Documents" },
  { id: "cin_file", label: "Scan CIN / Passeport", type: "file", defaultEnabled: false, defaultRequired: false, category: "Documents", hint: "PDF ou image JPG/PNG, max 5 Mo" },
  { id: "birth_certificate", label: "Acte de naissance", type: "file", defaultEnabled: true, defaultRequired: false, category: "Documents", hint: "Copie certifiée conforme" },

  { id: "level", label: "Niveau scolaire", type: "select", options: [
      "Primaire (CP)", "Primaire (CE1)", "Primaire (CE2)", "Primaire (CM1)", "Primaire (CM2)",
      "Collège (6e)", "Collège (5e)", "Collège (4e)", "Collège (3e)",
      "Lycée (2nde)", "Lycée (1ère)", "Lycée (Tle)",
      "Université (L1)", "Université (L2)", "Université (L3)", "Master (M1)", "Master (M2)", "Doctorat",
    ], defaultEnabled: true, alwaysRequired: true, category: "Académique" },
  { id: "last_diploma", label: "Dernier diplôme obtenu", placeholder: "Ex : BEPC, Baccalauréat, Licence...", type: "text", defaultEnabled: true, defaultRequired: false, category: "Académique" },
  { id: "last_diploma_file", label: "Copie du dernier diplôme", type: "file", defaultEnabled: true, defaultRequired: false, category: "Académique", hint: "PDF ou image certifiée conforme" },
  { id: "last_school", label: "Ancien établissement", placeholder: "Nom de l'école précédente", type: "text", defaultEnabled: true, defaultRequired: false, category: "Académique" },
  { id: "last_report", label: "Dernier bulletin scolaire", type: "file", defaultEnabled: false, defaultRequired: false, category: "Académique", hint: "Bulletin de l'année précédente" },
  { id: "specialty", label: "Filière / Spécialité", placeholder: "Ex : Sciences, Littérature...", type: "text", defaultEnabled: false, defaultRequired: false, category: "Académique" },

  { id: "phone", label: "Téléphone (élève/étudiant)", placeholder: "Ex : +221 77 000 00 00", type: "phone", defaultEnabled: false, defaultRequired: false, category: "Contact" },
  { id: "email", label: "Email (élève/étudiant)", placeholder: "prenom.nom@email.com", type: "email", defaultEnabled: true, defaultRequired: false, category: "Contact" },
  { id: "address", label: "Adresse résidentielle", placeholder: "Quartier, Ville", type: "textarea", defaultEnabled: true, defaultRequired: false, category: "Contact" },

  { id: "guardian_name", label: "Nom complet du tuteur / parent", placeholder: "Ex : Fatou Diallo", type: "text", defaultEnabled: true, defaultRequired: true, category: "Tuteur" },
  { id: "guardian_relation", label: "Lien de parenté", type: "select", options: ["Père", "Mère", "Tuteur légal", "Grand-parent", "Autre"], defaultEnabled: true, defaultRequired: false, category: "Tuteur" },
  { id: "guardian_phone", label: "Téléphone du tuteur", placeholder: "Ex : +221 77 000 00 00", type: "phone", defaultEnabled: true, defaultRequired: true, category: "Tuteur" },
  { id: "guardian_email", label: "Email du tuteur", placeholder: "parent@email.com", type: "email", defaultEnabled: true, defaultRequired: false, category: "Tuteur" },
  { id: "guardian_profession", label: "Profession du tuteur", placeholder: "Ex : Enseignant, Médecin...", type: "text", defaultEnabled: false, defaultRequired: false, category: "Tuteur" },
  { id: "guardian_cin", label: "CIN / Passeport du tuteur", placeholder: "N° pièce d'identité", type: "text", defaultEnabled: false, defaultRequired: false, category: "Tuteur" },

  { id: "payment_mode", label: "Mode de paiement", type: "select", options: ["Espèces", "Chèque", "Virement", "Mobile Money", "Carte bancaire"], defaultEnabled: true, defaultRequired: false, category: "Paiement" },
  { id: "scholarship", label: "Boursier", type: "toggle", defaultEnabled: false, defaultRequired: false, category: "Paiement" },
  { id: "scholarship_file", label: "Attestation de bourse", type: "file", defaultEnabled: false, defaultRequired: false, category: "Paiement" },

  { id: "medical_notes", label: "Informations médicales", placeholder: "Allergies, traitements, besoins spéciaux...", type: "textarea", defaultEnabled: false, defaultRequired: false, category: "Médical", hint: "Informations confidentielles réservées au personnel médical" },
  { id: "medical_cert", label: "Certificat médical d'aptitude", type: "file", defaultEnabled: false, defaultRequired: false, category: "Médical" },
];
