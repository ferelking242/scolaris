import 'package:flutter/material.dart';
import '../../domain/entities/user_entity.dart';

// ── Niveaux scolaires ────────────────────────────────────────────────────────
enum SchoolLevel {
  primaire,
  college,
  lycee,
  universite,
  master,
  doctorat;

  String get label {
    switch (this) {
      case primaire:    return 'Primaire';
      case college:     return 'Collège';
      case lycee:       return 'Lycée';
      case universite:  return 'Université';
      case master:      return 'Master';
      case doctorat:    return 'Doctorat';
    }
  }

  String get range {
    switch (this) {
      case primaire:    return 'CP — CM2';
      case college:     return '6e — 3e';
      case lycee:       return '2nde — Tle';
      case universite:  return 'L1 — L3';
      case master:      return 'M1 — M2';
      case doctorat:    return 'PhD';
    }
  }

  /// Niveau scolaire déduit d'un *type d'établissement* (`schools.metadata.types`)
  /// choisi par l'admin à l'inscription. Null si le type n'a pas d'équivalent
  /// (ex. `special`). Source de vérité du dynamisme par type d'école.
  static SchoolLevel? fromSchoolType(String type) {
    switch (type) {
      case 'garderie':
      case 'primaire':   return SchoolLevel.primaire;
      case 'college':    return SchoolLevel.college;
      case 'lycee':
      case 'technique':  return SchoolLevel.lycee;
      case 'universite':
      case 'superieur':  return SchoolLevel.universite;
      default:           return null;
    }
  }

  /// Niveau déduit du *nom de classe / niveau* de l'élève (best-effort, tolérant
  /// aux libellés francophones : CP1, 6ème, 2nde A, Terminale D, L1, M2, Thèse…).
  /// Null si indéterminable → on retombe sur le type d'école.
  static SchoolLevel? fromClassName(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return null;
    // Cycles bruts éventuels (classes.level = 'lycee', 'college'…).
    switch (s) {
      case 'prescolaire':
      case 'primaire':  return SchoolLevel.primaire;
      case 'college':   return SchoolLevel.college;
      case 'lycee':     return SchoolLevel.lycee;
      case 'universite':return SchoolLevel.universite;
    }
    // Supérieur
    if (RegExp(r'(doctorat|phd|th[èe]se)').hasMatch(s)) return SchoolLevel.doctorat;
    if (RegExp(r'(master|^m[12]\b)').hasMatch(s)) return SchoolLevel.master;
    if (RegExp(r'(licence|universit|^l[123]\b)').hasMatch(s)) return SchoolLevel.universite;
    // Lycée
    if (RegExp(r'(terminale|^tle|1[èe]re|premi[èe]re|2nde|seconde)').hasMatch(s)) {
      return SchoolLevel.lycee;
    }
    // Collège
    if (RegExp(r'(6[èe]me|5[èe]me|4[èe]me|3[èe]me|^6e\b|^5e\b|^4e\b|^3e\b)').hasMatch(s)) {
      return SchoolLevel.college;
    }
    // Primaire
    if (RegExp(r'(^cp|^ce[12]|^cm[12]|maternelle)').hasMatch(s)) {
      return SchoolLevel.primaire;
    }
    return null;
  }
}

// ── Modules choisis par l'école à l'inscription ──────────────────────────────
//
// Distinct du catalogue de features ci-dessous (qui gate par rôle/plan) : ici,
// c'est l'ÉCOLE elle-même qui choisit à l'inscription ce qu'elle veut gérer
// (ex. une école ne voulant que la facturation ne voit ni notes, ni présences,
// ni inscriptions dans son tableau de bord). Stocké dans `schools.metadata.modules`.
// Les fonctionnalités « core » (utilisateurs, classes, tableau de bord…) ne sont
// pas des modules : elles restent toujours visibles, quel que soit le choix.
class AppModule {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  /// Socle toujours actif (Académique) : ne se coche pas, ne se compte pas
  /// dans le quota d'emplacements de l'offre (`plans.max_modules`). Les
  /// modules non-core sont ceux du « catalogue » installable/désinstallable
  /// (cf. `AdminSubscriptionPage` → panneau modules).
  final bool core;
  const AppModule({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.core = false,
  });
}

/// Académique — cœur du produit, toujours actif quelle que soit l'offre.
/// Décision du 09/08/2026 : ce n'est plus « un module parmi d'autres », donc
/// il n'est plus compté dans le quota d'emplacements ni proposé au
/// décochage. Conservé ici (avec `core: true`) uniquement pour l'affichage
/// (ex. pilule « Toujours actif » dans le catalogue).
const kCoreModule = AppModule(
  id: 'academic',
  label: 'Académique',
  description: 'Notes, bulletins, emploi du temps, statistiques de classe',
  icon: Icons.grade_outlined,
  core: true,
);

/// Modules complémentaires — installables/désinstallables dans la limite du
/// quota d'emplacements de l'offre (`plans.max_modules`), cf. catalogue de
/// modules dans `AdminSubscriptionPage`.
const List<AppModule> kAppModules = [
  AppModule(
    id: 'attendance',
    label: 'Présences',
    description: 'Appel numérique, absences, retards',
    icon: Icons.how_to_reg_outlined,
  ),
  AppModule(
    id: 'finance',
    label: 'Finances',
    description: 'Facturation, paiements, comptabilité',
    icon: Icons.account_balance_wallet_outlined,
  ),
  AppModule(
    id: 'enrollment',
    label: 'Inscriptions',
    description: 'Campagnes d\'inscription, dossiers, pré-inscriptions en ligne',
    icon: Icons.how_to_reg_rounded,
  ),
];

// ── Catégories de features ────────────────────────────────────────────────────
enum FeatureCategory {
  core,
  academic,
  communication,
  finance,
  documents,
  admin,
  research;

  String get label {
    switch (this) {
      case core:          return 'Essentiel';
      case academic:      return 'Académique';
      case communication: return 'Communication';
      case finance:       return 'Finance';
      case documents:     return 'Documents';
      case admin:         return 'Administration';
      case research:      return 'Recherche';
    }
  }
}

// ── Statut d'implémentation ───────────────────────────────────────────────────
enum FeatureStatus { available, beta, planned }

// ── Modèle d'une feature ──────────────────────────────────────────────────────
class AppFeature {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final FeatureCategory category;
  final FeatureStatus status;

  /// Roles qui y ont accès
  final Set<UserRole> roles;

  /// Niveaux scolaires (pour les élèves uniquement — null = tous niveaux)
  final Set<SchoolLevel>? levels;

  /// Offre minimale requise : 'simple' (défaut) < 'pro' < 'max'.
  /// Source de vérité unique du gating par offre (cf. memory/offers-and-gating).
  final String minPlan;

  const AppFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.roles,
    this.levels,
    this.status = FeatureStatus.planned,
    this.minPlan = 'simple',
  });

  bool isAvailableFor(UserRole role, [SchoolLevel? level]) {
    if (!roles.contains(role)) return false;
    if (role == UserRole.student && levels != null && level != null) {
      return levels!.contains(level);
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Catalogue complet des features
// ─────────────────────────────────────────────────────────────────────────────

const _allStudentLevels = {
  SchoolLevel.primaire,
  SchoolLevel.college,
  SchoolLevel.lycee,
  SchoolLevel.universite,
  SchoolLevel.master,
  SchoolLevel.doctorat,
};

const _univAndUp = {
  SchoolLevel.universite,
  SchoolLevel.master,
  SchoolLevel.doctorat,
};

const _masterAndUp = {
  SchoolLevel.master,
  SchoolLevel.doctorat,
};

const _preUniv = {
  SchoolLevel.primaire,
  SchoolLevel.college,
  SchoolLevel.lycee,
};

const _allRoles = {
  UserRole.staff,
  UserRole.teacher,
  UserRole.student,
  UserRole.parent,
};

const _staffOnly = {UserRole.staff};
const _staffTeacher = {UserRole.staff, UserRole.teacher};
const _staffParent = {UserRole.staff, UserRole.parent};
const _staffTeacherParent = {UserRole.staff, UserRole.teacher, UserRole.parent};
const _noParent = {UserRole.staff, UserRole.teacher, UserRole.student};

class FeaturesCatalog {
  static const List<AppFeature> all = [

    // ── CORE — tous rôles ──────────────────────────────────────────────────

    AppFeature(
      id: 'dashboard',
      title: 'Tableau de bord',
      description: 'Vue personnalisée avec les indicateurs clés, tâches du jour et activité récente.',
      icon: Icons.dashboard_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.core,
      roles: _allRoles,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'schedule',
      title: 'Emploi du temps',
      description: 'Planning hebdomadaire interactif, vue jour/semaine, rappels de cours.',
      icon: Icons.calendar_today_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.core,
      roles: _allRoles,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'notifications',
      title: 'Notifications',
      description: 'Alertes en temps réel : absences, nouvelles notes, messages, événements.',
      icon: Icons.notifications_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.core,
      roles: _allRoles,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'profile',
      title: 'Profil & Paramètres',
      description: 'Gestion du compte, avatar, langue, thème, confidentialité.',
      icon: Icons.person_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.core,
      roles: _allRoles,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'offline',
      minPlan: 'max',
      title: 'Mode hors-ligne',
      description: 'Consultation et saisie sans connexion internet, synchronisation automatique.',
      icon: Icons.wifi_off_rounded,
      color: Color(0xFF7A5C44),
      category: FeatureCategory.core,
      roles: _allRoles,
      status: FeatureStatus.planned,
    ),

    // ── ACADÉMIQUE — Élèves ────────────────────────────────────────────────

    AppFeature(
      id: 'grades',
      title: 'Notes & Évaluations',
      description: 'Consultation des notes, moyennes, progression par matière et trimestre.',
      icon: Icons.grade_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.available,
      levels: _allStudentLevels,
    ),

    AppFeature(
      id: 'attendance_student',
      title: 'Présences & Absences',
      description: 'Historique des présences, justifications, alertes d\'absence.',
      icon: Icons.how_to_reg_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.student, UserRole.parent},
      status: FeatureStatus.available,
      levels: _allStudentLevels,
    ),

    AppFeature(
      id: 'bulletin',
      title: 'Bulletins Trimestriels',
      description: 'Consultation, téléchargement et signature électronique des bulletins.',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student, UserRole.parent},
      status: FeatureStatus.available,
      levels: {SchoolLevel.college, SchoolLevel.lycee},
    ),

    AppFeature(
      id: 'ects',
      title: 'Relevé de notes ECTS',
      description: 'Notes par unité d\'enseignement, crédits validés, semestres.',
      icon: Icons.school_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: _univAndUp,
    ),

    AppFeature(
      id: 'course_enrollment',
      title: 'Inscription aux cours / UE',
      description: 'Choix des unités d\'enseignement, confirmation d\'inscription, liste d\'attente.',
      icon: Icons.add_circle_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: _univAndUp,
    ),

    AppFeature(
      id: 'library',
      minPlan: 'pro',
      title: 'Bibliothèque',
      description: 'Catalogue de ressources, manuels, emprunts, bibliothèque numérique.',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: _allStudentLevels,
    ),

    AppFeature(
      id: 'orientation',
      title: 'Orientation Scolaire',
      description: 'Conseils d\'orientation, fiches métiers, simulateurs de parcours.',
      icon: Icons.fork_right_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.college, SchoolLevel.lycee},
    ),

    AppFeature(
      id: 'bac_prep',
      title: 'Prépa-Bac',
      description: 'Fiches de révision, annales, quiz préparatoires, planning de révision.',
      icon: Icons.psychology_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.lycee},
    ),

    AppFeature(
      id: 'post_bac',
      title: 'Candidatures Post-Bac',
      description: 'Suivi des candidatures, dossiers, lettres de motivation, résultats.',
      icon: Icons.send_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.lycee},
    ),

    AppFeature(
      id: 'clubs',
      title: 'Clubs & Activités',
      description: 'Clubs sportifs, culturels, parascolaires, inscriptions et événements.',
      icon: Icons.groups_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.college, SchoolLevel.lycee, SchoolLevel.universite},
    ),

    AppFeature(
      id: 'student_forum',
      title: 'Forum Étudiant',
      description: 'Espaces de discussion par promo, matière ou projet, Q&A communautaire.',
      icon: Icons.forum_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.communication,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: _univAndUp,
    ),

    AppFeature(
      id: 'internship',
      title: 'Offres de Stage & Emploi',
      description: 'Annonces de stage/emploi, candidatures, suivi entreprise.',
      icon: Icons.work_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.lycee, SchoolLevel.universite, SchoolLevel.master},
    ),

    AppFeature(
      id: 'alumni',
      title: 'Réseau Alumni',
      description: 'Annuaire des anciens élèves, mentorat, opportunités professionnelles.',
      icon: Icons.connect_without_contact_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.communication,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: _masterAndUp,
    ),

    AppFeature(
      id: 'thesis',
      title: 'Suivi de Thèse',
      description: 'Journal de thèse, jalons, interactions avec le directeur, soutenances.',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.research,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.doctorat},
    ),

    AppFeature(
      id: 'publications',
      title: 'Publications Scientifiques',
      description: 'Dépôt d\'articles, peer-review, citations, suivi des soumissions.',
      icon: Icons.science_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.research,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: {SchoolLevel.master, SchoolLevel.doctorat},
    ),

    AppFeature(
      id: 'conferences',
      title: 'Conférences & Colloques',
      description: 'Agenda des conférences, soumissions de communications, accès aux actes.',
      icon: Icons.mic_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.research,
      roles: {UserRole.staff, UserRole.teacher, UserRole.student},
      status: FeatureStatus.planned,
      levels: _masterAndUp,
    ),

    // ── ACADÉMIQUE — Enseignants ───────────────────────────────────────────

    AppFeature(
      id: 'attendance_teacher',
      title: 'Appel Numérique',
      description: 'Appel en classe, gestion des retards et absences, sync instantanée.',
      icon: Icons.checklist_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'gradebook',
      title: 'Carnet de Notes',
      description: 'Saisie des notes, calcul des moyennes, pondération par coefficients.',
      icon: Icons.edit_note_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'textbook',
      title: 'Cahier de Textes',
      description: 'Contenu de cours, objectifs pédagogiques, ressources partagées aux élèves.',
      icon: Icons.book_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'quiz',
      minPlan: 'pro',
      title: 'Évaluations en ligne',
      description: 'Création de QCM, devoirs numériques, correction automatique, statistiques.',
      icon: Icons.quiz_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'class_stats',
      title: 'Statistiques de Classe',
      description: 'Courbes de progression, taux de présence, comparatif entre classes.',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'class_council',
      title: 'Conseil de Classe',
      description: 'Comptes-rendus numériques, appréciations globales, délibérations.',
      icon: Icons.groups_2_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'pedagogy',
      title: 'Ressources Pédagogiques',
      description: 'Partage de documents, vidéos, liens; bibliothèque partagée entre collègues.',
      icon: Icons.folder_special_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.academic,
      roles: _staffTeacher,
      status: FeatureStatus.planned,
    ),

    // ── COMMUNICATION ──────────────────────────────────────────────────────

    AppFeature(
      id: 'messaging',
      minPlan: 'pro',
      title: 'Messagerie',
      description: 'Chat interne sécurisé entre élèves, enseignants, parents et administration.',
      icon: Icons.chat_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.communication,
      roles: _allRoles,
      // L'écran existant était une maquette (conversations codées en dur, aucun
      // accès à la base) : il a été retiré. La messagerie reste à construire —
      // schéma conversations/participants + RLS + temps réel.
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'liaison',
      minPlan: 'pro',
      title: 'Carnet de Liaison',
      description: 'Messages officiels école → parents, signature électronique, archivage.',
      icon: Icons.mail_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.communication,
      roles: {UserRole.staff, UserRole.teacher, UserRole.parent},
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'parent_meetings',
      minPlan: 'pro',
      title: 'Réunions Parents-Profs',
      description: 'Planification, créneaux de disponibilité, réservation en ligne, rappels.',
      icon: Icons.event_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.communication,
      roles: _staffTeacherParent,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'announcements',
      minPlan: 'pro',
      title: 'Annonces & Événements',
      description: 'Tableau d\'affichage numérique, sorties scolaires, examens, jours fériés.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.communication,
      roles: _allRoles,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'broadcast',
      minPlan: 'pro',
      title: 'Notification Globale',
      description: 'Envoi de messages à tous les utilisateurs ou par groupe/classe.',
      icon: Icons.wifi_tethering_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.communication,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    // ── FINANCE ────────────────────────────────────────────────────────────

    AppFeature(
      id: 'fees_parent',
      minPlan: 'pro',
      title: 'Paiement Frais Scolaires',
      description: 'Paiement en ligne sécurisé, historique des versements, reçus PDF.',
      icon: Icons.payment_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.finance,
      roles: _staffParent,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'fees_student',
      minPlan: 'pro',
      title: 'Paiement (Université)',
      description: 'Frais d\'inscription, de bibliothèque, d\'examens. Paiement en ligne.',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.finance,
      roles: {UserRole.staff, UserRole.student},
      status: FeatureStatus.planned,
      levels: _univAndUp,
    ),

    AppFeature(
      id: 'billing_admin',
      minPlan: 'pro',
      title: 'Gestion Financière',
      description: 'Suivi des paiements, relances, budget, rapports comptables.',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.finance,
      roles: _staffOnly,
      status: FeatureStatus.available,
    ),

    // ── DOCUMENTS ─────────────────────────────────────────────────────────

    AppFeature(
      id: 'certificates',
      minPlan: 'pro',
      title: 'Documents Officiels',
      description: 'Certificats de scolarité, attestations, diplômes, en un clic.',
      icon: Icons.description_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.documents,
      roles: {UserRole.staff, UserRole.student, UserRole.parent},
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'archives',
      minPlan: 'pro',
      title: 'Archives Scolaires',
      description: 'Historique complet des années précédentes, dossiers élèves archivés.',
      icon: Icons.archive_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.documents,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'reports',
      minPlan: 'pro',
      title: 'Rapports & Exports',
      description: 'Génération de rapports PDF/Excel, statistiques d\'établissement.',
      icon: Icons.summarize_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.documents,
      roles: _staffTeacher,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'reports_premium',
      minPlan: 'max',
      title: 'Rapport Premium',
      description: 'Tendance de recouvrement période par période, au-delà du rapport standard.',
      icon: Icons.insights_rounded,
      color: Color(0xFF7C3AED),
      category: FeatureCategory.documents,
      roles: _staffOnly,
      status: FeatureStatus.available,
    ),

    // ── ADMIN EXCLUSIF ─────────────────────────────────────────────────────

    AppFeature(
      id: 'users_mgmt',
      title: 'Gestion Utilisateurs',
      description: 'Créer, modifier, désactiver les comptes de tous les rôles.',
      icon: Icons.manage_accounts_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'classes_mgmt',
      title: 'Gestion des Classes',
      description: 'Création de classes, affectation élèves/profs, niveaux et filières.',
      icon: Icons.class_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'timetable_mgmt',
      title: 'Gestion des Emplois du Temps',
      description: 'Création et publication des emplois du temps pour tout l\'établissement.',
      icon: Icons.table_chart_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.available,
    ),

    AppFeature(
      id: 'discipline',
      minPlan: 'pro',
      title: 'Surveillance & Discipline',
      description: 'Registre incidents, sanctions, convocations, conseils de discipline.',
      icon: Icons.security_rounded,
      color: Color(0xFFC17F24),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'inscriptions',
      title: 'Gestion des Inscriptions',
      description: 'Dossiers d\'inscription, validation, liste d\'attente, campagnes.',
      icon: Icons.how_to_reg_rounded,
      color: Color(0xFF8B1A00),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'school_config',
      title: 'Configuration Établissement',
      description: 'Informations, logo, palette de couleurs, multi-sites, domaines.',
      icon: Icons.settings_rounded,
      color: Color(0xFFD4540A),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'impersonate',
      title: 'Vue par Rôle',
      description: 'Simuler l\'interface d\'un élève, enseignant ou parent pour déboguer.',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF2D6A4F),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    // ── EXCLUSIF MAX (à venir) ─────────────────────────────────────────────
    // Ces 4 features composent le catalogue `plans.features` de l'offre Max
    // côté base (20260617_subscriptions.sql) mais n'ont encore aucune UI —
    // listées ici pour que l'offre Max ait un contenu visible dans la vitrine
    // plutôt que de sembler ne rien apporter de plus que Pro.

    AppFeature(
      id: 'multi_etablissements',
      minPlan: 'max',
      title: 'Multi-établissements',
      description: 'Gérez plusieurs écoles d\'un même groupe depuis un seul compte.',
      icon: Icons.corporate_fare_rounded,
      color: Color(0xFF7C3AED),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'marque_blanche',
      minPlan: 'max',
      title: 'Marque Blanche',
      description: 'Logo, couleurs et domaine personnalisés aux couleurs de votre établissement.',
      icon: Icons.palette_rounded,
      color: Color(0xFF7C3AED),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'support_dedie',
      minPlan: 'max',
      title: 'Support Dédié',
      description: 'Un interlocuteur attitré, priorité sur les demandes d\'assistance.',
      icon: Icons.support_agent_rounded,
      color: Color(0xFF7C3AED),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),

    AppFeature(
      id: 'export_api',
      minPlan: 'max',
      title: 'Export API',
      description: 'Accès API pour connecter Scolaris à vos propres outils.',
      icon: Icons.api_rounded,
      color: Color(0xFF7C3AED),
      category: FeatureCategory.admin,
      roles: _staffOnly,
      status: FeatureStatus.planned,
    ),
  ];

  /// Features filtrées par rôle (et optionnellement par niveau)
  static List<AppFeature> forRole(UserRole role, [SchoolLevel? level]) {
    return all.where((f) => f.isAvailableFor(role, level)).toList();
  }

  /// Features filtrées par catégorie
  static List<AppFeature> forCategory(FeatureCategory cat) {
    return all.where((f) => f.category == cat).toList();
  }

  /// Toutes les catégories présentes dans un ensemble de features
  static List<FeatureCategory> categoriesIn(List<AppFeature> features) {
    final cats = features.map((f) => f.category).toSet().toList();
    cats.sort((a, b) => a.index.compareTo(b.index));
    return cats;
  }
}
