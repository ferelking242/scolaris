import 'package:flutter/material.dart';

/// Modèle par capacités du personnel (staff). Source de vérité UNIQUE des
/// permissions assignables : utilisée par l'écran de gestion du personnel, le
/// menu dynamique et les gardes de pages.
///
/// La clé spéciale [kAllPermission] (« * ») = accès total (Direction / fondateur).

const String kAllPermission = '*';

/// Une permission assignable à un membre du personnel.
class StaffPermission {
  /// Clé canonique stockée en base (jsonb `users.permissions`).
  final String key;
  final String label;
  final String description;
  final IconData icon;

  /// Réservé à la Direction (ne pas proposer dans les presets restreints).
  final bool sensitive;

  const StaffPermission({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    this.sensitive = false,
  });
}

class StaffPermissions {
  StaffPermissions._();

  // ── Clés canoniques ────────────────────────────────────────────────────────
  static const students = 'students';
  static const classes = 'classes';
  static const grades = 'grades';
  static const attendance = 'attendance';
  static const discipline = 'discipline';
  static const finance = 'finance';
  static const reports = 'reports';
  static const timetable = 'timetable';
  // `communication` a été retiré : la messagerie et les annonces n'existent
  // plus (cf. 20260732_drop_messaging.sql). Une case à cocher qui ne commande
  // rien est pire qu'absente : elle promet une sécurité inexistante.
  static const staffManage = 'staff_manage';
  static const schoolConfig = 'school_config';

  /// Catalogue complet (ordre d'affichage dans l'écran de gestion).
  static const List<StaffPermission> all = [
    StaffPermission(
      key: students,
      label: 'Élèves & inscriptions',
      description: 'Créer/modifier les élèves, gérer les inscriptions',
      icon: Icons.group_outlined,
    ),
    StaffPermission(
      key: classes,
      label: 'Classes & matières',
      description: 'Gérer les classes, niveaux et matières',
      icon: Icons.class_outlined,
    ),
    StaffPermission(
      key: grades,
      label: 'Notes & bulletins',
      description: 'Consulter/saisir les notes, générer les bulletins',
      icon: Icons.grade_outlined,
    ),
    StaffPermission(
      key: attendance,
      label: 'Présences',
      description: 'Appel, absences et retards',
      icon: Icons.how_to_reg_outlined,
    ),
    StaffPermission(
      key: discipline,
      label: 'Discipline',
      description: 'Incidents, sanctions, vie scolaire',
      icon: Icons.gavel_outlined,
    ),
    StaffPermission(
      key: finance,
      label: 'Finances',
      description: 'Factures, encaissements, paiements',
      icon: Icons.payments_outlined,
    ),
    StaffPermission(
      key: reports,
      label: 'Rapports',
      description: 'Statistiques et exports',
      icon: Icons.summarize_outlined,
    ),
    StaffPermission(
      key: timetable,
      label: 'Emploi du temps',
      description: 'Créer et publier les horaires',
      icon: Icons.table_chart_outlined,
    ),
    StaffPermission(
      key: staffManage,
      label: 'Gérer le personnel',
      description: 'Inviter et modifier d\'autres membres',
      icon: Icons.manage_accounts_outlined,
      sensitive: true,
    ),
    StaffPermission(
      key: schoolConfig,
      label: 'Configuration école',
      description: 'Infos école, abonnement, paramètres',
      icon: Icons.settings_outlined,
      sensitive: true,
    ),
  ];

  static StaffPermission? byKey(String key) {
    for (final p in all) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// Modèles de départ (presets). L'admin part de l'un d'eux puis ajuste les
  /// cases librement. « Co-Directeur » = accès total via [kAllPermission].
  static const Map<String, List<String>> presets = {
    'Secrétaire': [students, classes, timetable],
    'Comptable': [finance, reports],
    'Surveillant': [attendance, discipline],
    'Co-Directeur': [kAllPermission],
    'Personnalisé': [],
  };
}
