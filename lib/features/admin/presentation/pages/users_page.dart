import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/permissions/rbac_mapping.dart';
import '../../../../core/permissions/staff_permissions.dart';
import '../../../../data/sources/remote/staff_roles_source.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/pdf/student_card_pdf.dart';
import '../../../../shared/pdf/users_list_pdf.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';
import '../../roles/workspace/role_workspace_models.dart' show colorFromHex;
import '../widgets/tuition_account.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

/// Deux populations, deux métiers, deux écrans.
///
/// Le PERSONNEL se recrute, porte un rôle, reçoit des droits. Les ÉLÈVES et
/// leurs FAMILLES s'inscrivent, appartiennent à une classe, n'ont aucun droit
/// d'administration. Les mélanger dans une liste « Utilisateurs » obligeait à
/// filtrer pour retrouver la personne cherchée, et affichait à l'admin des
/// colonnes qui n'ont de sens que pour la moitié des lignes.
enum UsersScope {
  /// Direction, secrétariat, comptabilité, surveillance, enseignants.
  staff,

  /// Élèves et parents.
  families,
}

class UsersPage extends ConsumerStatefulWidget {
  final UsersScope scope;
  const UsersPage({super.key, this.scope = UsersScope.staff});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _filter = 'all';
  String _search = '';
  // Un élève sorti (transféré/diplômé/radié) reste dans la base — juste hors
  // de la vue par défaut, comme une classe active ne montre pas ses anciens.
  bool _showExited = false;

  bool get _isFamilies => widget.scope == UsersScope.families;

  /// Les rôles de cet écran. Tout ce qui n'est ni élève ni parent est du
  /// personnel — y compris les rôles historiques (`finance`, `surveillance`),
  /// qu'on ne veut pas voir disparaître de la liste parce qu'on aurait oublié de
  /// les énumérer.
  bool _inScope(String role) {
    final isFamily = role == 'student' || role == 'parent';
    return _isFamilies ? isFamily : !isFamily;
  }

  // Inscription inline (au lieu d'une route plein écran).
  bool _enrolling = false;
  EnrollmentConfig? _enrollConfig;
  List<SbClass> _enrollClasses = const [];
  String? _enrollSchoolId;

  // Fiche élève inline (id de l'utilisateur consulté).
  String? _viewId;
  String _profileSearch = '';
  String _profileTab = 'infos'; // infos | finances | presence | documents

  static const _kStudentDocuments = [
    (key: 'birth_certificate', label: 'Acte de naissance'),
    (key: 'vaccination_record', label: 'Carnet de vaccination'),
    (key: 'medical_certificate', label: 'Certificat médical'),
  ];

  // ── Droits fins « Élèves & familles » ─────────────────────────────────────
  //  La base accepte `eleves.X` OU `utilisateurs.X` (cf. policies users_insert/
  //  update/delete) pour une fiche élève/parent — le personnel peut recevoir le
  //  droit via l'un ou l'autre module. L'écran ne testait jusqu'ici QUE
  //  `utilisateurs.X` : un rôle avec seulement `eleves.ajouter` par ex. voyait
  //  la base accepter l'action mais l'écran cachait le bouton. On reflète donc
  //  ici la même règle OR que le serveur applique déjà.
  bool _canAddStudent() =>
      ref.watch(canProvider('eleves.ajouter')) ||
      ref.watch(canProvider('utilisateurs.creer'));

  bool _canEditUser(SbUser u) =>
      ref.watch(canProvider('utilisateurs.modifier')) ||
      ((u.role == 'student' || u.role == 'parent') &&
          ref.watch(canProvider('eleves.modifier')));

  bool _canDeleteUser(SbUser u) =>
      ref.watch(canProvider('utilisateurs.supprimer')) ||
      ((u.role == 'student' || u.role == 'parent') &&
          ref.watch(canProvider('eleves.supprimer')));

  /// Ouvrir la fiche détaillée (dossier complet) d'un élève/parent.
  bool _canOpenDossier(SbUser u) {
    if (u.role != 'student' && u.role != 'parent') return false;
    return ref.watch(canProvider('eleves.dossier_complet')) ||
        ref.watch(canProvider('utilisateurs.modifier'));
  }

  /// « eleves.voir » — sans ce droit fin, la liste des élèves/parents ne
  /// doit PAS s'afficher, même si le rôle a accès à la page (coarse
  /// `students`, cf. legacy_permissions_of_role qui l'active dès qu'UNE
  /// sous-permission « eleves.* » est cochée, `.voir` ou une autre).
  ///
  /// Repli : une école qui n'utilise pas encore le système de rôles fins
  /// (aucun `staff_role_id`, uniquement l'ancien `permissions` plat) n'a
  /// AUCUN grain fin du tout — `myGrantsProvider` renvoie alors un ensemble
  /// vide. Bloquer sur ce cas casserait l'accès de toutes ces écoles. On ne
  /// bloque donc que si le rôle EST sur le système fin (au moins un grain,
  /// peu importe lequel) mais n'a explicitement pas `eleves.voir`.
  bool _canSeeStudents() {
    final grants = ref.watch(myGrantsProvider).valueOrNull;
    if (grants == null) return false; // droits pas encore chargés
    if (grants.contains('*') || grants.contains('eleves.voir')) return true;
    final onFineRbac = grants.isNotEmpty;
    return !onFineRbac;
  }

  Future<void> _openEnrollment() async {
    final schoolId = ref.read(authSessionProvider)?.schoolId;
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
      ));
      return;
    }
    // Restriction de plan : on vérifie la limite d'élèves AVANT d'ouvrir.
    final canAdd = await SupabaseDbSource.canAddStudent(schoolId);
    if (!mounted) return;
    if (!canAdd) {
      _showLimitReached();
      return;
    }

    // Charger la config admin + la liste des classes en parallèle.
    final results = await Future.wait([
      ref.read(enrollmentConfigProvider.future),
      ref.read(classesProvider.future),
    ]);
    if (!mounted) return;

    final configJson = results[0] as Map<String, dynamic>?;
    final classes = results[1] as List<SbClass>;
    final config = configJson != null
        ? EnrollmentConfig.fromJson(configJson)
        : EnrollmentConfig.defaults();

    setState(() {
      _enrollConfig = config;
      _enrollClasses = classes;
      _enrollSchoolId = schoolId;
    });

    // Inscription RAPIDE par défaut (nom, sexe, naissance, classe — 4 champs) :
    // le dossier complet (documents, tuteur, médical…) reste disponible via
    // le lien « Dossier complet » du dialogue, mais la plupart des
    // inscriptions faites par le secrétariat n'ont besoin que de l'essentiel.
    if (!mounted) return;
    final useFullForm = await showDialog<bool>(
      context: context,
      builder: (_) => _QuickEnrollDialog(
        classes: classes,
        classCounts: _classCounts(),
        onSubmit: (data) => _saveStudent(schoolId, data),
      ),
    );
    if (useFullForm == true && mounted) {
      setState(() => _enrolling = true);
    }
  }

  /// Enregistre réellement la fiche élève (users + student_profiles).
  Future<void> _saveStudent(String schoolId, Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    String s(String k) => (data[k]?.toString() ?? '').trim();
    final fullName = '${s('first_name')} ${s('last_name')}'.trim();
    try {
      // Re-vérification au moment de l'enregistrement : la limite a pu être
      // atteinte entre l'ouverture du formulaire et la validation (autre
      // appareil, autre onglet…). Évite de dépasser le quota de l'offre.
      final stillOk = await SupabaseDbSource.canAddStudent(schoolId);
      if (!stillOk) {
        if (!mounted) return;
        _showLimitReached();
        return;
      }
      final classId = data['class_id'] as String?;
      final studentId = await SupabaseDbSource.createStudent(
        schoolId: schoolId,
        fullName: fullName.isEmpty ? 'Élève' : fullName,
        email: s('email').isEmpty ? null : s('email'),
        phone: s('phone').isEmpty ? null : s('phone'),
        classId: classId,
        matricule: s('matricule').isEmpty ? null : s('matricule'),
        birthDate: s('birth_date').isEmpty ? null : s('birth_date'),
        gender: s('gender').isEmpty ? null : s('gender'),
        nationality: s('nationality').isEmpty ? null : s('nationality'),
      );
      // Parent/tuteur saisi → on crée (ou réutilise) sa fiche et on la relie.
      // Réservé Pro/Max : en Simple, aucun compte parent (cf. gating par offre).
      final familiesEnabled =
          await ref.read(familyAccountsEnabledProvider.future);
      final guardianName = s('guardian_name');
      if (familiesEnabled && guardianName.isNotEmpty) {
        await SupabaseDbSource.createOrLinkGuardian(
          schoolId: schoolId,
          studentId: studentId,
          guardianName: guardianName,
          phone: s('guardian_phone').isEmpty ? null : s('guardian_phone'),
          email: s('guardian_email').isEmpty ? null : s('guardian_email'),
          relationship:
              s('guardian_relation').isEmpty ? 'Parent' : s('guardian_relation'),
        );
      }
      ref.invalidate(usersProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(studentCountProvider);
      if (!mounted) return;
      setState(() => _enrolling = false); // referme l'inscription inline
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('${fullName.isEmpty ? "Élève" : fullName} inscrit·e'
              '${familiesEnabled && guardianName.isNotEmpty ? " + parent lié" : ""}'),
        ]),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      // Le garde-fou base (trigger) renvoie ce message si la limite est atteinte
      // entre la pré-vérif et l'écriture → on affiche le dialogue d'upsell propre.
      if (e.toString().contains('Limite d\'élèves')) {
        _showLimitReached();
        return;
      }
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de l\'inscription : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Imprime/exporte EXACTEMENT la liste affichée (filtres rôle/recherche/
  /// sortis déjà appliqués en amont dans `build`) — pas « tout », comme le
  /// fait EduNet avec ses boutons Imprimer/Exporter.
  Future<void> _printUsers(List<SbUser> users) async {
    await printUsersListPdf(
      title: _isFamilies ? 'Élèves & familles' : 'Personnel',
      users: users,
    );
  }

  Future<void> _exportUsers(List<SbUser> users) async {
    await exportUsersListPdf(
      title: _isFamilies ? 'Élèves & familles' : 'Personnel',
      users: users,
    );
  }

  Future<void> _toggleStudentDocument(String studentId, String key, bool provided) async {
    try {
      await SupabaseDbSource.setStudentDocumentStatus(
          studentId: studentId, documentKey: key, provided: provided);
      ref.invalidate(studentsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<(String, String)> _primaryGuardianContact(String studentId) async {
    final guardians = await ref.read(guardiansForStudentProvider(studentId).future);
    if (guardians.isEmpty) return ('', '');
    final primary = guardians.firstWhere((g) => g.isPrimary, orElse: () => guardians.first);
    return (primary.fullName, primary.phone ?? '');
  }

  Future<void> _downloadStudentCard(SbUser u, SbStudent? st) async {
    final school = ref.read(schoolProvider).valueOrNull;
    final (guardianName, guardianPhone) = await _primaryGuardianContact(u.id);
    await downloadStudentCardPdf(
        user: u, student: st, school: school,
        guardianName: guardianName, guardianPhone: guardianPhone);
  }

  Future<void> _printStudentCard(SbUser u, SbStudent? st) async {
    final school = ref.read(schoolProvider).valueOrNull;
    final (guardianName, guardianPhone) = await _primaryGuardianContact(u.id);
    await printStudentCardPdf(
        user: u, student: st, school: school,
        guardianName: guardianName, guardianPhone: guardianPhone);
  }

  Future<void> _editMedicalInfo(String studentId, SbStudent? st) async {
    final bloodCtrl = TextEditingController(text: st?.bloodGroup ?? '');
    final allergiesCtrl = TextEditingController(text: st?.allergies ?? '');
    final vulnerabilityCtrl = TextEditingController(text: st?.vulnerability ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Informations médicales'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: bloodCtrl,
              decoration: const InputDecoration(labelText: 'Groupe sanguin', hintText: 'Ex : O+'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: allergiesCtrl,
              decoration: const InputDecoration(labelText: 'Allergies'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vulnerabilityCtrl,
              decoration: const InputDecoration(
                  labelText: 'Vulnérabilité',
                  hintText: 'Ex : orphelin, handicap — laisser vide si aucune'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _terra),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await SupabaseDbSource.updateStudentMedical(
        studentId: studentId,
        bloodGroup: bloodCtrl.text,
        allergies: allergiesCtrl.text,
        vulnerability: vulnerabilityCtrl.text,
      );
      ref.invalidate(studentsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showLimitReached() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Limite d\'élèves atteinte'),
        content: const Text(
          'Vous avez atteint le nombre d\'élèves inclus dans votre offre. '
          'Passez à l\'offre supérieure pour inscrire davantage d\'élèves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _terra),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(navIntentProvider.notifier).state = 'nav.subscription';
            },
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  // ── Fiche élève (profil inline) ─────────────────────────────────────────
  /// Filtre les paires (label, valeur) d'un panneau selon `_profileSearch` —
  /// recherche live sur la fiche élève, sur le modèle vu chez EduNet (chercher
  /// une info précise sans naviguer entre les sections).
  List<(String, String)> _filterKv(List<(String, String)> pairs) {
    final q = _profileSearch.trim().toLowerCase();
    if (q.isEmpty) return pairs;
    return pairs
        .where((p) => p.$1.toLowerCase().contains(q) || p.$2.toLowerCase().contains(q))
        .toList();
  }

  Widget _kvPanel(String title, List<(String, String)> pairs) {
    final filtered = _filterKv(pairs);
    return DataPanel(
      title: title,
      child: filtered.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucune correspondance.',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            )
          : Column(children: [
              for (final p in filtered) _ProfileKV(label: p.$1, value: p.$2),
            ]),
    );
  }

  Widget _studentProfileView(SbUser u) {
    final students = ref.watch(studentsProvider).valueOrNull ?? const <SbStudent>[];
    SbStudent? st;
    for (final s in students) {
      if (s.id == u.id) { st = s; break; }
    }
    final familiesEnabled =
        ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
    final canEnable = familiesEnabled && u.authUid == null;
    final classLabel = st?.classGroup.isNotEmpty == true ? st!.classGroup : null;

    // Titulaire — l'enseignant responsable de la classe, résolu depuis la
    // liste des comptes de l'école (déjà chargée) plutôt qu'un aller-retour DB.
    String titulaireLabel = 'Non assigné';
    if (st?.mainTeacherId != null) {
      final everyone = ref.watch(usersProvider).valueOrNull ?? const <SbUser>[];
      for (final t in everyone) {
        if (t.id == st!.mainTeacherId) { titulaireLabel = t.fullName; break; }
      }
    }

    final subParts = <String>[
      if (st?.matricule != null) 'N° ${st!.matricule}',
      if (classLabel != null) classLabel,
    ];
    final sub = subParts.isEmpty ? 'Fiche élève' : subParts.join(' · ');

    // Onglets façon EduNet (Infos / Finances / Présence / Documents), avec la
    // carte élève « toujours visible » dans une colonne latérale sur grand
    // écran (empilée en bas sur mobile).
    final tabs = <(String, String, IconData)>[
      ('infos', 'Infos', Icons.person_outline_rounded),
      ('finances', 'Finances', Icons.account_balance_wallet_outlined),
      ('presence', 'Présence', Icons.fact_check_outlined),
      ('documents', 'Documents', Icons.folder_outlined),
    ];

    return PageScaffold(
      title: u.fullName,
      subtitle: sub,
      actions: [
        ActionButton(
            label: 'Imprimer', icon: Icons.print_outlined,
            onTap: () => _printStudentCard(u, st)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(
          label: 'Tous les utilisateurs',
          onTap: () => setState(() { _viewId = null; _profileSearch = ''; }),
        ),
        const SizedBox(height: 14),

        // En-tête.
        Row(children: [
          Avatar(name: u.fullName, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName,
                  style: TextStyle(
                      color: context.cInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                if (classLabel != null) ...[
                  _MiniChip(icon: Icons.class_rounded, label: classLabel),
                  const SizedBox(width: 6),
                ],
                u.isActive
                    ? StatusPill.success('Actif')
                    : StatusPill.neutral('Bloqué'),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Actions.
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_canEditUser(u))
            ActionButton(
                label: 'Modifier', icon: Icons.edit_outlined,
                onTap: () => _editUser(u)),
          if (canEnable && _canEditUser(u))
            ActionButton(
                label: 'Activer l\'accès', icon: Icons.vpn_key_outlined,
                onTap: () => _enableAccess(u)),
          // Suspendre un compte touche `users.status` : la base exige
          // `utilisateurs.gerer_roles` (cf. guard_user_privileges).
          if (ref.watch(canProvider('utilisateurs.gerer_roles')))
            ActionButton(
              label: u.isActive ? 'Bloquer' : 'Réactiver',
              icon: u.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              onTap: () => _toggleActive(u),
            ),
        ]),
        const SizedBox(height: 16),

        TextField(
          onChanged: (v) => setState(() => _profileSearch = v),
          style: TextStyle(fontSize: 13, color: context.cInk),
          decoration: InputDecoration(
            hintText: 'Rechercher dans la fiche…',
            hintStyle: TextStyle(fontSize: 13, color: context.cMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.cMuted),
            isDense: true,
            filled: true,
            fillColor: context.cSubtle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.cBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _terra, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Onglets.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final t in tabs) ...[
              ChoiceChip(
                avatar: Icon(t.$3, size: 15,
                    color: _profileTab == t.$1 ? _terra : context.cMuted),
                label: Text(t.$2),
                selected: _profileTab == t.$1,
                onSelected: (_) => setState(() => _profileTab = t.$1),
                selectedColor: _terra.withValues(alpha: .12),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  color: _profileTab == t.$1 ? _terra : context.cMuted,
                  fontWeight: _profileTab == t.$1 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Contenu de l'onglet + carte élève toujours visible à côté (grand
        // écran) ou en dessous (mobile) — comme chez EduNet.
        LayoutBuilder(builder: (_, constraints) {
          final cardPreview = _StudentCardSidebar(
            user: u, student: st,
            onDownload: () => _downloadStudentCard(u, st),
            onPrint: () => _printStudentCard(u, st),
          );
          final tabContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _profileTabContent(
                u, st, classLabel, titulaireLabel),
          );
          if (constraints.maxWidth < 860) {
            return Column(children: [
              tabContent,
              const SizedBox(height: 14),
              cardPreview,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: tabContent),
            const SizedBox(width: 16),
            SizedBox(width: 240, child: cardPreview),
          ]);
        }),
      ]),
    );
  }

  List<Widget> _profileTabContent(
      SbUser u, SbStudent? st, String? classLabel, String titulaireLabel) {
    switch (_profileTab) {
      case 'finances':
        return [
          TuitionAccountCard(
            studentId: u.id,
            studentName: u.fullName,
            canCollect: ref.watch(canProvider('comptabilite.enregistrer_paiement')),
            title: 'Scolarité & paiements',
          ),
        ];

      case 'presence':
        return [
          Builder(builder: (_) {
            final absences = ref.watch(absencesForStudentProvider(u.id));
            final list = absences.valueOrNull ?? const <SbAbsence>[];
            final since30 = DateTime.now().subtract(const Duration(days: 30));
            final recent = list.where((a) =>
                (a.absenceDate ?? DateTime(2000)).isAfter(since30));
            final present = recent.where((a) => a.status == 'present').length;
            final absent = recent.where((a) => a.status == 'absent').length;
            final late = recent.where((a) => a.status == 'late').length;
            final total = present + absent + late;
            final rate = total == 0 ? 0 : (present * 100 / total).round();
            final unjustified = list.where((a) => a.status == 'absent' && !a.justified).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _StatMiniCard(icon: Icons.check_circle_outline_rounded,
                    label: 'Présences (30j)', value: '$present', color: _green)),
                const SizedBox(width: 8),
                Expanded(child: _StatMiniCard(icon: Icons.cancel_outlined,
                    label: 'Absences (30j)', value: '$absent', color: _terra)),
                const SizedBox(width: 8),
                Expanded(child: _StatMiniCard(icon: Icons.schedule_rounded,
                    label: 'Retards (30j)', value: '$late', color: _gold)),
                const SizedBox(width: 8),
                Expanded(child: _StatMiniCard(icon: Icons.pie_chart_outline_rounded,
                    label: 'Taux présence', value: '$rate%', color: _terra)),
              ]),
              const SizedBox(height: 14),
              DataPanel(
                title: 'Registre de présence',
                child: absences.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()))
                    : Column(children: [
                        _ProfileKV(label: 'Total absences', value: '${list.length}'),
                        _ProfileKV(
                            label: 'Non justifiées',
                            value: '$unjustified',
                            highlight: unjustified > 0),
                        if (list.isNotEmpty)
                          _ProfileKV(
                              label: 'Dernière',
                              value: _relativeTime(
                                  list.map((a) => a.absenceDate ?? DateTime(2000))
                                      .reduce((a, b) => a.isAfter(b) ? a : b))),
                      ]),
              ),
            ]);
          }),
        ];

      case 'documents':
        return [
          DataPanel(
            title: 'Documents officiels',
            child: Column(children: [
              for (final doc in _kStudentDocuments)
                _DocumentRow(
                  label: doc.label,
                  provided: st?.documents[doc.key] ?? false,
                  onToggle: (v) => _toggleStudentDocument(u.id, doc.key, v),
                ),
            ]),
          ),
        ];

      case 'infos':
      default:
        return [
          LayoutBuilder(builder: (_, c) {
            final twoCol = c.maxWidth > 700;
            final cards = <Widget>[
              _kvPanel('Identité', [
                ('Matricule', st?.matricule ?? '—'),
                ('Niveau', st?.niveau ?? '—'),
                ('Classe', classLabel ?? 'Sans classe'),
                ('Titulaire', titulaireLabel),
                ('Email', u.email.isEmpty ? '—' : u.email),
              ]),
              _kvPanel('Compte & accès', [
                ('Rôle', 'Élève'),
                ('Statut', u.isActive ? 'Actif' : 'Bloqué'),
                ('Connexion', u.authUid != null ? 'Compte activé' : 'Fiche sans connexion'),
                ('Dernière connexion', u.lastSeenAt != null ? _relativeTime(u.lastSeenAt!) : 'Jamais'),
              ]),
              DataPanel(
                title: 'Informations médicales',
                headerActions: [
                  TextButton.icon(
                    onPressed: () => _editMedicalInfo(u.id, st),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                  ),
                ],
                child: Builder(builder: (_) {
                  final pairs = _filterKv([
                    ('Groupe sanguin', st?.bloodGroup ?? '—'),
                    ('Allergies', st?.allergies ?? 'Aucune'),
                    ('Vulnérabilité', st?.vulnerability ?? 'Aucune'),
                  ]);
                  return pairs.isEmpty
                      ? Text('Aucune correspondance.', style: TextStyle(fontSize: 12, color: context.cMuted))
                      : Column(children: [for (final p in pairs) _ProfileKV(label: p.$1, value: p.$2)]);
                }),
              ),
              Builder(builder: (_) {
                final guardians = ref.watch(guardiansForStudentProvider(u.id));
                return DataPanel(
                  title: 'Parent / Tuteur',
                  child: guardians.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                    error: (e, _) => Text('Contacts indisponibles.',
                        style: TextStyle(fontSize: 12, color: context.cMuted)),
                    data: (list) => list.isEmpty
                        ? Text(
                            'Aucun parent lié. Ajoutez-en un à l\'inscription de l\'élève.',
                            style: TextStyle(fontSize: 12.5, color: context.cMuted))
                        : Column(
                            children: [
                              for (final g in list)
                                _GuardianRow(
                                  g: g,
                                  onTap: () => setState(() => _viewId = g.parentId),
                                ),
                            ],
                          ),
                  ),
                );
              }),
            ];
            if (!twoCol) {
              return Column(children: [
                for (final c in cards) ...[c, const SizedBox(height: 14)],
              ]);
            }
            return Column(children: [
              for (var i = 0; i < cards.length; i += 2) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 14),
                  Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
                ]),
                const SizedBox(height: 14),
              ],
            ]);
          }),
        ];
    }
  }

  // ── Fiche parent (profil inline) ────────────────────────────────────────
  Widget _parentProfileView(SbUser u) {
    final familiesEnabled =
        ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
    final canEnable = familiesEnabled && u.authUid == null;
    final email = _displayEmail(u.email);

    return PageScaffold(
      title: u.fullName,
      subtitle: 'Fiche parent',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(
          label: 'Tous les utilisateurs',
          onTap: () => setState(() => _viewId = null),
        ),
        const SizedBox(height: 14),

        // En-tête.
        Row(children: [
          Avatar(name: u.fullName, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName,
                  style: TextStyle(
                      color: context.cInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                const _MiniChip(icon: Icons.family_restroom_rounded, label: 'Parent'),
                const SizedBox(width: 6),
                u.isActive
                    ? StatusPill.success('Actif')
                    : StatusPill.neutral('Bloqué'),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Actions (mêmes droits fins que la fiche élève).
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_canEditUser(u))
            ActionButton(
                label: 'Modifier', icon: Icons.edit_outlined,
                onTap: () => _editUser(u)),
          if (canEnable && _canEditUser(u))
            ActionButton(
                label: 'Activer l\'accès', icon: Icons.vpn_key_outlined,
                onTap: () => _enableAccess(u)),
          if (ref.watch(canProvider('utilisateurs.gerer_roles')))
            ActionButton(
              label: u.isActive ? 'Bloquer' : 'Réactiver',
              icon: u.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              onTap: () => _toggleActive(u),
            ),
        ]),
        const SizedBox(height: 16),

        // Contact.
        DataPanel(
          title: 'Contact',
          child: Column(children: [
            _ProfileKV(label: 'Email', value: email ?? '—'),
            _ProfileKV(
                label: 'Téléphone',
                value: (u.phone?.trim().isNotEmpty ?? false) ? u.phone! : '—'),
          ]),
        ),
        const SizedBox(height: 14),

        // Compte & accès.
        DataPanel(
          title: 'Compte & accès',
          child: Column(children: [
            const _ProfileKV(label: 'Rôle', value: 'Parent'),
            _ProfileKV(
                label: 'Statut', value: u.isActive ? 'Actif' : 'Bloqué'),
            _ProfileKV(
                label: 'Connexion',
                value: u.authUid != null
                    ? 'Compte activé'
                    : 'Fiche sans connexion'),
            _ProfileKV(
                label: 'Dernière connexion',
                value: u.lastSeenAt != null
                    ? _relativeTime(u.lastSeenAt!)
                    : 'Jamais'),
          ]),
        ),
        const SizedBox(height: 14),

        // Enfants liés — chacun ouvre sa fiche élève.
        Builder(builder: (_) {
          final children = ref.watch(childrenOfParentProvider(u.id));
          return DataPanel(
            title: 'Enfants',
            child: children.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                    child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (e, _) => Text('Liste indisponible.',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
              data: (list) => list.isEmpty
                  ? Text('Aucun enfant rattaché à ce parent.',
                      style: TextStyle(fontSize: 12.5, color: context.cMuted))
                  : Column(
                      children: [
                        for (final s in list)
                          _ChildRow(
                            student: s,
                            onTap: () => setState(() => _viewId = s.id),
                          ),
                      ],
                    ),
            ),
          );
        }),
      ]),
    );
  }

  void _openInvite() {
    final schoolId = ref.read(authSessionProvider)?.schoolId;
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _InviteMemberDialog(
        schoolId: schoolId,
        onCreated: () {
          ref.invalidate(usersProvider);
          ref.invalidate(teachersProvider);
        },
      ),
    );
  }

  void _editUser(SbUser u) {
    showDialog(
      context: context,
      builder: (_) => _EditUserDialog(
        user: u,
        onSaved: () {
          ref.invalidate(usersProvider);
          ref.invalidate(teachersProvider);
        },
      ),
    );
  }

  void _enableAccess(SbUser u) {
    showDialog(
      context: context,
      builder: (_) => _EnableAccessDialog(
        user: u,
        onDone: () {
          ref.invalidate(usersProvider);
          ref.invalidate(studentsProvider);
        },
      ),
    );
  }

  Future<void> _deleteUser(SbUser u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le compte ?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'Le compte de "${u.fullName}" sera supprimé définitivement. '
          'Cette action est irréversible.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.deleteUser(u.id);
    } on PostgrestException catch (e) {
      // Notes gelées sur une période validée : le motif est obligatoire.
      // On le redemande plutôt que d'échouer silencieusement (cf. guard_grade_period).
      if (e.code == '42501' && e.message.contains('motif')) {
        if (!mounted) return;
        final reason = await _askDeleteReason(u.fullName);
        if (reason == null) return;
        try {
          await SupabaseDbSource.deleteUser(u.id, reason: reason);
        } catch (e2) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(
            content: Text('Suppression impossible : $e2'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _terra,
          ));
          return;
        }
      } else {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text('Suppression impossible : $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _terra,
        ));
        return;
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Suppression impossible : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
      return;
    }
    ref.invalidate(usersProvider);
    ref.invalidate(studentsProvider);
    ref.invalidate(teachersProvider);
    ref.invalidate(coursesForSchoolProvider);
    ref.invalidate(coursesForClassProvider);
    ref.invalidate(teachersWithoutClassProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('Compte "${u.fullName}" supprimé.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _terra,
    ));
  }

  /// Certaines notes de [fullName] appartiennent à une période validée : la
  /// suppression du compte les efface aussi, ce qui exige un motif tracé.
  Future<String?> _askDeleteReason(String fullName) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Motif requis',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$fullName" a des notes sur une période validée. '
              'Indiquez pourquoi ce compte est supprimé (ce sera tracé).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex. : doublon créé par erreur',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return reason;
  }

  /// Sortie d'élève : transfert, diplôme, ou radiation/abandon — au choix de
  /// l'admin, avec un motif libre. Garde le dossier intact (cf. [SbStudent]).
  Future<void> _withdrawStudent(SbUser u) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    final result = await showDialog<({String decision, String reason})>(
      context: context,
      builder: (_) => _WithdrawDialog(studentName: u.fullName),
    );
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.withdrawStudent(
        schoolId: schoolId,
        studentId: u.id,
        decision: result.decision,
        reason: result.reason.isEmpty ? null : result.reason,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
      return;
    }
    ref.invalidate(usersProvider);
    ref.invalidate(studentsProvider);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('"${u.fullName}" marqué(e) comme sorti(e).'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _green,
    ));
  }

  /// Annule une sortie décidée par erreur — redevient un élève actif, sans
  /// classe (l'admin doit lui en réaffecter une).
  Future<void> _reactivateStudent(SbUser u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Réactiver cet élève ?'),
        content: Text(
            '"${u.fullName}" redeviendra actif. Il faudra lui réaffecter une '
            'classe depuis sa fiche.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Réactiver')),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.reactivateStudent(studentId: u.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
      return;
    }
    ref.invalidate(usersProvider);
    ref.invalidate(studentsProvider);
  }

  Future<void> _toggleActive(SbUser u) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.setUserActive(u.id, !u.isActive);
      ref.invalidate(usersProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${u.fullName} ${u.isActive ? "désactivé·e" : "réactivé·e"}'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Effectif actuel par classe (élèves actifs, non sortis) — même calcul que
  /// `admin_classes_page.dart`, pour afficher la capacité dans le sélecteur
  /// de classe de l'inscription (rapide et complète).
  Map<String, int> _classCounts() {
    final students = ref.watch(studentsProvider).valueOrNull ?? const <SbStudent>[];
    final counts = <String, int>{};
    for (final s in students) {
      if (s.classId == null || s.hasExited) continue;
      counts[s.classId!] = (counts[s.classId!] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    // Inscription inline : remplace la liste par le formulaire (shell conservé).
    if (_enrolling && _enrollConfig != null && _enrollSchoolId != null) {
      return _InlineEnroll(
        config: _enrollConfig!,
        classes: _enrollClasses,
        classCounts: _classCounts(),
        schoolId: _enrollSchoolId!,
        onBack: () => setState(() => _enrolling = false),
        onSubmit: (data) => _saveStudent(_enrollSchoolId!, data),
      );
    }

    final pageTitle = _isFamilies ? 'Élèves & familles' : 'Personnel';

    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      loading: () => PageScaffold(
        title: pageTitle,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: pageTitle,
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (everyone) {
        if (_isFamilies && !_canSeeStudents()) {
          return PageScaffold(
            title: pageTitle,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded, color: context.cMuted, size: 40),
                const SizedBox(height: 12),
                Text('Accès non autorisé',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: context.cInk)),
                const SizedBox(height: 6),
                Text(
                  'Votre rôle n\'a pas le droit « Voir les élèves ». '
                  'Contactez la direction de votre établissement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: context.cMuted),
                ),
              ]),
            ),
          );
        }
        // Le super-admin plateforme n'est membre de l'école que pour que la
        // RLS le laisse lire son propre profil (cf.
        // 20260803_fix_admin_school_members.sql) — ce n'est pas du personnel
        // à gérer, il ne doit donc pas apparaître ici. Idem pour son propre
        // compte : on ne se gère pas soi-même dans sa propre liste de
        // personnel.
        final platformAdminIds =
            ref.watch(platformAdminUserIdsProvider).valueOrNull ?? const <String>{};
        final selfId = ref.watch(authSessionProvider)?.id;
        final allUsers = everyone.where((u) {
          if (_inScope(u.role) == false) return false;
          if (_isFamilies) return true;
          if (platformAdminIds.contains(u.id)) return false;
          if (u.id == selfId) return false;
          return true;
        }).toList();
        // Fiche inline : remplace la liste par le profil (élève OU parent).
        if (_viewId != null) {
          final match = allUsers.where((u) => u.id == _viewId).toList();
          if (match.isNotEmpty) {
            final target = match.first;
            return target.role == 'parent'
                ? _parentProfileView(target)
                : _studentProfileView(target);
          }
          // Utilisateur disparu (supprimé) → on referme la fiche.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _viewId = null);
          });
        }
        // ── Filtres ────────────────────────────────────────────────────────
        //  Côté PERSONNEL, on filtre par RÔLE réel de l'école (Secrétaire,
        //  Comptable, et tous ceux que l'admin a créés) — pas par le rôle
        //  technique du compte. C'est le rôle qui porte les droits, c'est donc
        //  lui que le directeur cherche.
        final schoolRoles =
            ref.watch(staffRolesProvider).valueOrNull ?? const <SbStaffRole>[];

        final options = <_FilterOption>[
          (key: 'all', label: 'Tous'),
          if (_isFamilies) ...[
            (key: 'student', label: 'Élèves'),
            (key: 'parent', label: 'Parents'),
          ] else ...[
            for (final r in schoolRoles) (key: r.id, label: r.name),
            (key: 'none', label: 'Sans rôle'),
          ],
        ];

        const founders = {'admin', 'direction', 'directeur', 'dg'};

        final users = allUsers.where((u) {
          if (_filter == 'all') return true;
          if (_isFamilies) return u.role == _filter;
          // « Sans rôle » signale les comptes à configurer. Le FONDATEUR n'en
          // fait pas partie : il n'a pas de rôle du personnel, et c'est normal —
          // son accès vient de son `users.role`.
          if (_filter == 'none') {
            return u.staffRoleId == null &&
                !founders.contains(u.role.toLowerCase());
          }
          return u.staffRoleId == _filter;
        }).where((u) {
          // Recherche libre : nom ou email, insensible à la casse.
          final q = _search.trim().toLowerCase();
          if (q.isEmpty) return true;
          return u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q);
        }).where((u) => _showExited || !u.hasExited).toList();
        final familiesEnabled =
            ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
        return PageScaffold(
          title: pageTitle,
          subtitle: _isFamilies
              ? '${allUsers.length} élèves et parents'
              : '${allUsers.length} membres du personnel',
          actions: [
            if (_isFamilies) ...[
              ActionButton(
                  label: 'Imprimer',
                  icon: Icons.print_outlined,
                  onTap: () => _printUsers(users)),
              ActionButton(
                  label: 'Exporter',
                  icon: Icons.ios_share_rounded,
                  onTap: () => _exportUsers(users)),
            ],
            // Chaque écran n'offre que le geste qui lui correspond : on
            // n'INVITE pas un élève, on l'INSCRIT.
            if (_isFamilies && _canAddStudent())
              ActionButton(
                  label: 'Inscrire un élève',
                  icon: Icons.person_add_alt_1_rounded,
                  primary: true,
                  onTap: _openEnrollment)
            else if (!_isFamilies && ref.watch(canProvider('utilisateurs.creer')))
              ActionButton(
                  label: 'Inviter',
                  icon: Icons.send_outlined,
                  primary: true,
                  onTap: _openInvite),
          ],
          child: Column(children: [
            if (_isFamilies) ...[
              _FamilyStatsRow(
                total: allUsers.length,
                students: allUsers.where((u) => u.role == 'student').length,
                parents: allUsers.where((u) => u.role == 'parent').length,
                exited: allUsers.where((u) => u.hasExited).length,
                onTapTotal: () => setState(() => _filter = 'all'),
                onTapStudents: () => setState(() => _filter = 'student'),
                onTapParents: () => setState(() => _filter = 'parent'),
                onTapExited: () => setState(() {
                  _filter = 'all';
                  _showExited = true;
                }),
              ),
              const SizedBox(height: 12),
            ],
            _FilterRow(
              current: _filter,
              options: options,
              onChange: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Comptes',
              headerActions: [
                if (_isFamilies) ...[
                  FilterChip(
                    label: const Text('Élèves sortis'),
                    selected: _showExited,
                    onSelected: (v) => setState(() => _showExited = v),
                    labelStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                ],
                SearchInput(
                  hint: 'Rechercher un utilisateur…',
                  onChanged: (v) => setState(() => _search = v),
                )
              ],
              child: users.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              _search.trim().isEmpty
                                  ? 'Aucun utilisateur.'
                                  : 'Aucun résultat pour « ${_search.trim()} ».',
                              style: TextStyle(color: context.cMuted))),
                    )
                  : LayoutBuilder(builder: (_, constraints) {
                      // Le tableau à 6 colonnes fixes devient illisible sous
                      // 640px (email/date tronqués) : cartes empilées à la place.
                      if (constraints.maxWidth < 640) {
                        return Column(children: [
                          for (final u in users)
                            _UserCard(
                              user: u,
                              familiesEnabled: familiesEnabled,
                              onOpen: _canOpenDossier(u)
                                  ? () => setState(() => _viewId = u.id)
                                  : null,
                              onEnableAccess: () => _enableAccess(u),
                              onEdit: () => _editUser(u),
                              onToggleActive: () => _toggleActive(u),
                              onWithdraw: () => _withdrawStudent(u),
                              onReactivate: () => _reactivateStudent(u),
                              onDelete: () => _deleteUser(u),
                            ),
                        ]);
                      }
                      return DataTablePanel(
                      columns: const [
                        'Nom',
                        'Email',
                        'Rôle',
                        'Statut',
                        'Dernière connexion',
                        ''
                      ],
                      flex: const [3, 3, 2, 2, 2, 2],
                      rows: [
                        for (final u in users)
                          [
                            Builder(builder: (_) {
                              // Élèves ET parents ouvrent une fiche détaillée,
                              // si le rôle a le droit `eleves.dossier_complet`
                              // (ou `utilisateurs.modifier`, en repli).
                              final openable = _canOpenDossier(u);
                              return MouseRegion(
                                cursor: openable
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: openable
                                    ? () => setState(() => _viewId = u.id)
                                    : null,
                                child: Row(children: [
                                  Avatar(name: u.fullName, size: 24),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(u.fullName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: context.cInk,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (openable) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 15,
                                        color:
                                            context.cMuted.withValues(alpha: .5)),
                                  ],
                                ]),
                                ),
                              );
                            }),
                            Text(u.email,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 12, color: context.cMuted)),
                            _RoleCell(user: u),
                            u.hasExited
                                ? _ExitedPill(reason: u.exitReason)
                                : _StatusDot(active: u.isActive),
                            Text(
                              u.lastSeenAt != null
                                  ? _relativeTime(u.lastSeenAt!)
                                  : '—',
                              style:
                                  TextStyle(fontSize: 12, color: context.cMuted),
                            ),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              // Accès : login déjà actif, ou activable (Pro/Max,
                              // élève/parent encore en fiche sans connexion).
                              if (u.authUid != null)
                                const Tooltip(
                                  message: 'Connexion active',
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.lock_open_rounded,
                                        size: 16, color: Color(0xFF15803D)),
                                  ),
                                )
                              else if (familiesEnabled &&
                                  (u.role == 'student' || u.role == 'parent'))
                                _IconBtn(
                                    icon: Icons.vpn_key_outlined,
                                    onTap: () => _enableAccess(u)),
                              // Les boutons suivent les droits FINS du rôle :
                              // `eleves.X` OU `utilisateurs.X` pour un élève/
                              // parent (même règle OR que la base) ; suspendre
                              // un compte ou changer son rôle exige toujours
                              // `utilisateurs.gerer_roles` (cf. guard_user_privileges).
                              if (_canEditUser(u)) ...[
                                const SizedBox(width: 6),
                                _IconBtn(
                                    icon: Icons.edit_outlined,
                                    onTap: () => _editUser(u)),
                              ],
                              if (ref.watch(canProvider('utilisateurs.gerer_roles'))) ...[
                                const SizedBox(width: 6),
                                _IconBtn(
                                    icon: u.isActive
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline_rounded,
                                    onTap: () => _toggleActive(u)),
                              ],
                              // Sortie d'élève : PAS une suppression — l'élève
                              // garde son dossier (notes, bulletins), juste
                              // hors effectifs actifs. C'est le chemin normal
                              // pour un transfert, un diplôme ou un abandon.
                              if (u.role == 'student' && _canEditUser(u)) ...[
                                const SizedBox(width: 6),
                                _IconBtn(
                                    icon: u.hasExited
                                        ? Icons.replay_rounded
                                        : Icons.logout_rounded,
                                    color: u.hasExited ? _green : _gold,
                                    onTap: () => u.hasExited
                                        ? _reactivateStudent(u)
                                        : _withdrawStudent(u)),
                              ],
                              if (_canDeleteUser(u)) ...[
                                const SizedBox(width: 6),
                                _IconBtn(
                                    icon: Icons.delete_outline_rounded,
                                    color: _terra,
                                    onTap: () => _deleteUser(u)),
                              ],
                            ]),
                          ],
                      ],
                      );
                    }),
            ),
          ]),
        );
      },
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }
}

/// Vue d'inscription **inline** : barre de retour + formulaire, dans le shell.
/// Inscription RAPIDE : nom, sexe, naissance, classe — pensée pour le
/// secrétariat qui inscrit vite un élève déjà connu (contrairement au
/// formulaire public de pré-inscription, complet mais lent). Le lien
/// « Dossier complet » ferme ce dialogue et bascule vers `_InlineEnroll`
/// (l'`EnrollmentPage` à catégories multiples) pour qui veut tout saisir
/// d'un coup (documents, tuteur, médical…).
class _QuickEnrollDialog extends StatefulWidget {
  final List<SbClass> classes;
  final Map<String, int> classCounts;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;
  const _QuickEnrollDialog({
    required this.classes,
    required this.classCounts,
    required this.onSubmit,
  });

  @override
  State<_QuickEnrollDialog> createState() => _QuickEnrollDialogState();
}

const _boyBlue = Color(0xFF2563EB);
const _girlPink = Color(0xFFDB2777);

class _QuickEnrollDialogState extends State<_QuickEnrollDialog> {
  final _nameCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _guardianNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  String _gender = 'M';
  DateTime? _birthDate;
  String? _classId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _matriculeCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom complet est requis.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final iso = _birthDate == null
        ? ''
        : '${_birthDate!.year.toString().padLeft(4, '0')}-'
          '${_birthDate!.month.toString().padLeft(2, '0')}-'
          '${_birthDate!.day.toString().padLeft(2, '0')}';
    await widget.onSubmit({
      'first_name': name,
      'last_name': '',
      'gender': _gender == 'M' ? 'Masculin' : 'Féminin',
      'birth_date': iso,
      'class_id': _classId,
      'matricule': _matriculeCtrl.text.trim(),
      'guardian_name': _guardianNameCtrl.text.trim(),
      'guardian_phone': _guardianPhoneCtrl.text.trim(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _decor(BuildContext context, String hint, {String? label}) => InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: context.cMuted),
        labelStyle: TextStyle(fontSize: 12.5, color: context.cMuted),
        isDense: true,
        filled: true,
        fillColor: context.cSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.cBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _terra, width: 1.5),
        ),
      );

  Widget _sectionTitle(BuildContext context, IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 14, color: context.cMuted),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: .4,
                  fontWeight: FontWeight.w700,
                  color: context.cMuted)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final genderColor = _gender == 'M' ? _boyBlue : _girlPink;
    final initials = _nameCtrl.text.trim().isEmpty
        ? '?'
        : _nameCtrl.text
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase();

    return Dialog(
      backgroundColor: context.cCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── En-tête : avatar en direct + titre ──────────────────────
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: genderColor.withValues(alpha: .14), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: genderColor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Inscription rapide',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.cInk)),
                    Text('L\'essentiel pour créer la fiche tout de suite',
                        style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                  ]),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: context.cMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                ),
              ]),
              const SizedBox(height: 18),

              _sectionTitle(context, Icons.badge_outlined, 'Identité'),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13.5, color: context.cInk),
                decoration: _decor(context, 'Ex : Fatou Mbemba', label: 'Nom complet *'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: context.cSubtle,
                      selectedBackgroundColor: genderColor.withValues(alpha: .12),
                      selectedForegroundColor: genderColor,
                      side: BorderSide(color: context.cBorder),
                    ),
                    segments: const [
                      ButtonSegment(value: 'M', label: Text('Garçon'), icon: Icon(Icons.male_rounded, size: 15)),
                      ButtonSegment(value: 'F', label: Text('Fille'), icon: Icon(Icons.female_rounded, size: 15)),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) => setState(() => _gender = s.first),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickBirthDate,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.cSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: Row(children: [
                    Icon(Icons.cake_outlined, size: 16, color: context.cMuted),
                    const SizedBox(width: 10),
                    Text(
                      _birthDate == null
                          ? 'Date de naissance'
                          : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                            '${_birthDate!.month.toString().padLeft(2, '0')}/'
                            '${_birthDate!.year}',
                      style: TextStyle(
                          fontSize: 13,
                          color: _birthDate == null ? context.cMuted : context.cInk),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 18),
              _sectionTitle(context, Icons.school_outlined, 'Scolarité'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.cSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.cBorder),
                ),
                child: DropdownButton<String>(
                  value: _classId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.cCard,
                  hint: Text('Classe (optionnel)', style: TextStyle(fontSize: 13, color: context.cMuted)),
                  style: TextStyle(fontSize: 13, color: context.cInk),
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Aucune classe —',
                            style: TextStyle(color: context.cMuted, fontStyle: FontStyle.italic))),
                    for (final c in widget.classes)
                      DropdownMenuItem(
                        value: c.id,
                        child: Builder(builder: (_) {
                          final count = widget.classCounts[c.id] ?? 0;
                          final full = count >= c.maxStudents;
                          return Text(
                            '${c.name} ($count/${c.maxStudents})${full ? ' — complet' : ''}',
                            style: TextStyle(
                                color: full ? _terra : context.cInk,
                                fontWeight: full ? FontWeight.w700 : FontWeight.normal),
                          );
                        }),
                      ),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _matriculeCtrl,
                style: TextStyle(fontSize: 13.5, color: context.cInk),
                decoration: _decor(context, 'Auto-généré si vide', label: 'Matricule (optionnel)'),
              ),

              const SizedBox(height: 18),
              _sectionTitle(context, Icons.family_restroom_rounded, 'Tuteur (optionnel, à compléter plus tard sinon)'),
              TextField(
                controller: _guardianNameCtrl,
                style: TextStyle(fontSize: 13.5, color: context.cInk),
                decoration: _decor(context, 'Nom du parent/tuteur', label: 'Nom du tuteur'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _guardianPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 13.5, color: context.cInk),
                decoration: _decor(context, '+242 06 000 00 00', label: 'Téléphone du tuteur'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: _terra, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(true),
                  child: const Text('Dossier complet →'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _terra),
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(_saving ? 'Inscription…' : 'Inscrire'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InlineEnroll extends StatelessWidget {
  final EnrollmentConfig config;
  final List<SbClass> classes;
  final Map<String, int> classCounts;
  final String schoolId;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _InlineEnroll({
    required this.config,
    required this.classes,
    required this.classCounts,
    required this.schoolId,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cPage,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Barre de retour (reste dans la page Utilisateurs).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onBack,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_rounded,
                        size: 15, color: context.cMuted),
                    const SizedBox(width: 6),
                    Text('Retour aux utilisateurs',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.cMuted,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: EnrollmentPage(
            isAdminMode: true,
            config: config,
            adminClasses: classes,
            classStudentCounts: classCounts,
            schoolId: schoolId,
            onSubmit: onSubmit,
          ),
        ),
      ]),
    );
  }
}

/// Puce compacte (icône + texte) — ex. classe dans l'en-tête de la fiche élève.
class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: context.cMuted),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: context.cInk, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Ligne clé/valeur des panneaux de la fiche élève.
/// Ligne de la checklist « Documents » — suivi de conformité post-inscription,
/// indépendant de l'upload fait à la pré-inscription.
class _DocumentRow extends StatelessWidget {
  final String label;
  final bool provided;
  final ValueChanged<bool> onToggle;
  const _DocumentRow({required this.label, required this.provided, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onToggle(!provided),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(
            provided ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: provided ? const Color(0xFF15803D) : context.cMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: provided ? const Color(0xFF15803D).withValues(alpha: .1) : context.cSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              provided ? 'Fourni' : 'Non fourni',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: provided ? const Color(0xFF15803D) : context.cMuted),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileKV extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ProfileKV({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: context.cMuted)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  color: highlight ? _terra : context.cInk,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Petite carte statistique (onglet Présence), façon `stat-card` d'EduNet.
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatMiniCard(
      {required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
            color: context.cInk, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.cMuted, fontSize: 10)),
      ]),
    );
  }
}

/// Carte élève « toujours visible » — sidebar façon EduNet (contenu latéral
/// sur grand écran, empilé sous les onglets sur mobile). Réutilise le rendu
/// visuel du PDF (dégradé terracotta/or, initiales) plutôt qu'un panneau texte.
class _StudentCardSidebar extends StatelessWidget {
  final SbUser user;
  final SbStudent? student;
  final VoidCallback onDownload;
  final VoidCallback onPrint;
  const _StudentCardSidebar(
      {required this.user, required this.student, required this.onDownload, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
    return DataPanel(
      title: 'Carte élève',
      headerActions: [
        IconButton(
          onPressed: onDownload,
          icon: const Icon(Icons.download_rounded, size: 17),
          tooltip: 'Télécharger',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onPrint,
          icon: const Icon(Icons.print_outlined, size: 17),
          tooltip: 'Imprimer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_terra, _gold, _terra],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CARTE ÉLÈVE',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 58,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: Center(child: Text(initials,
                    style: const TextStyle(color: _terra, fontSize: 17, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(student?.matricule ?? '—',
                      style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                  Text(student?.classGroup.isNotEmpty == true ? student!.classGroup : '—',
                      style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Les fiches parent créées à l'inscription reçoivent un email de substitution
/// `parent.xxxx@parent.scolaris.local` (aucun email fourni). Ne pas l'afficher :
/// ce n'est pas un vrai contact.
String? _displayEmail(String? email) {
  final e = email?.trim();
  if (e == null || e.isEmpty) return null;
  if (e.endsWith('@parent.scolaris.local')) return null;
  return e;
}

/// Ligne « parent/tuteur » de la fiche élève. Ouvre la fiche du parent.
class _GuardianRow extends StatelessWidget {
  final SbGuardianLink g;
  final VoidCallback onTap;
  const _GuardianRow({required this.g, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final email = _displayEmail(g.email);
    final phone = (g.phone?.trim().isNotEmpty ?? false) ? g.phone!.trim() : null;
    final contact = [phone, email].whereType<String>().join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Avatar(name: g.fullName, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(g.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: context.cInk,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                _TinyTag(label: g.relationship),
                if (g.isPrimary) ...[
                  const SizedBox(width: 4),
                  const _TinyTag(label: 'Principal', accent: true),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                contact.isEmpty ? 'Aucun contact renseigné' : contact,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.cMuted),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Icon(
            g.hasAccount ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 15,
            color: g.hasAccount ? const Color(0xFF15803D) : context.cMuted,
          ),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: context.cMuted.withValues(alpha: .5)),
        ]),
      ),
    );
  }
}

/// Ligne « enfant » de la fiche parent. Ouvre la fiche de l'élève.
class _ChildRow extends StatelessWidget {
  final SbStudent student;
  final VoidCallback onTap;
  const _ChildRow({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final classe = student.classGroup.isNotEmpty ? student.classGroup : 'Sans classe';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Avatar(name: student.fullName, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: context.cInk,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(classe,
                  style: TextStyle(fontSize: 11.5, color: context.cMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: context.cMuted.withValues(alpha: .5)),
        ]),
      ),
    );
  }
}

/// Micro-étiquette (relation, « Principal »).
class _TinyTag extends StatelessWidget {
  final String label;
  final bool accent;
  const _TinyTag({required this.label, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final color = accent ? _terra : context.cMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Cartes stats cliquables (Total/Élèves/Parents/Sortis) — cliquer applique
/// directement le filtre correspondant, sur le modèle vu chez EduNet
/// (cliquer « Filles » filtre la liste sans passer par le menu déroulant).
class _FamilyStatsRow extends StatelessWidget {
  final int total;
  final int students;
  final int parents;
  final int exited;
  final VoidCallback onTapTotal;
  final VoidCallback onTapStudents;
  final VoidCallback onTapParents;
  final VoidCallback onTapExited;
  const _FamilyStatsRow({
    required this.total,
    required this.students,
    required this.parents,
    required this.exited,
    required this.onTapTotal,
    required this.onTapStudents,
    required this.onTapParents,
    required this.onTapExited,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final stats = <Widget>[
        _StatChip(icon: Icons.groups_rounded, label: 'Total', value: total,
            color: _terra, onTap: onTapTotal),
        _StatChip(icon: Icons.school_rounded, label: 'Élèves', value: students,
            color: _green, onTap: onTapStudents),
        _StatChip(icon: Icons.family_restroom_rounded, label: 'Parents',
            value: parents, color: _gold, onTap: onTapParents),
        _StatChip(icon: Icons.logout_rounded, label: 'Sortis', value: exited,
            color: context.cMuted, onTap: onTapExited),
      ];
      final narrow = c.maxWidth < 560;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final s in stats)
            SizedBox(width: narrow ? (c.maxWidth - 10) / 2 : (c.maxWidth - 30) / 4, child: s),
        ],
      );
    });
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('$value', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.cInk)),
                Text(label, style: TextStyle(fontSize: 10.5, color: context.cMuted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Une option de filtre : une clé technique, un libellé lisible.
///
/// Les filtres affichaient les rôles TECHNIQUES bruts (`teacher`, `finance`,
/// `surveillance`) — de l'anglais de base de données, montré tel quel à un
/// directeur congolais. Et ils ignoraient les rôles réels de l'école : pas de
/// Secrétaire, pas de Comptable, et aucun des rôles que l'admin crée lui-même.
typedef _FilterOption = ({String key, String label});

class _FilterRow extends StatelessWidget {
  final String current;
  final List<_FilterOption> options;
  final ValueChanged<String> onChange;
  const _FilterRow(
      {required this.current, required this.options, required this.onChange});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(o.label),
                  selected: current == o.key,
                  onSelected: (_) => onChange(o.key),
                  selectedColor: const Color(0xFF8B1A00).withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: current == o.key
                        ? const Color(0xFF8B1A00)
                        : context.cMuted,
                    fontWeight:
                        current == o.key ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Pastille de rôle.
///
/// Affiche le rôle RÉEL de la personne (« Secrétaire », « Comptable »), et non
/// la clé technique (`staff_custom`), qui ne dit rien à personne. Pour le
/// personnel sans rôle attribué — les comptes d'avant la bascule RBAC —, elle
/// le dit franchement : sans rôle, ces gens n'ont AUCUN accès, et c'est
/// exactement ce qu'un admin doit pouvoir repérer d'un coup d'œil.
/// Le rôle affiché est le RÔLE DU PERSONNEL — celui que l'école a nommé, et qui
/// porte les droits. Jamais le rôle technique du compte.
///
/// Ce badge ne cherchait le vrai rôle que pour trois valeurs (`staff_custom`,
/// `finance`, `surveillance`). `teacher` n'en faisait pas partie : à l'époque,
/// les enseignants n'avaient aucun rôle. Depuis 20260721 ils en portent un — le
/// badge ne l'avait jamais appris, et continuait d'afficher « teacher ».
///
/// Les autres cas affichaient l'anglais de la base tel quel : « student »,
/// « parent », « admin ».
/// Le rôle, plus l'alerte « Sans classe » pour un enseignant qui n'enseigne
/// nulle part.
///
/// On pouvait inviter un professeur et l'oublier : il se connectait, n'avait ni
/// carnet ni appel, et c'était à lui de venir s'en plaindre. Le même oubli
/// silencieux que « Sans rôle » — désormais visible d'un coup d'œil.
class _RoleCell extends ConsumerWidget {
  final SbUser user;
  const _RoleCell({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orphans =
        ref.watch(teachersWithoutClassProvider).valueOrNull ?? const <String>{};
    final idle = user.role == 'teacher' && orphans.contains(user.id);

    if (!idle) return _RoleBadge(user: user);

    return Wrap(spacing: 4, runSpacing: 2, children: [
      _RoleBadge(user: user),
      Tooltip(
        message: 'Ni titulaire d’une classe, ni enseignant d’un cours : '
            'il ne peut ni noter ni faire l’appel.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEA580C).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFFEA580C).withValues(alpha: .3)),
          ),
          child: const Text('Sans classe',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C))),
        ),
      ),
    ]);
  }
}

class _RoleBadge extends ConsumerWidget {
  final SbUser user;
  const _RoleBadge({required this.user});

  /// Le FONDATEUR n'a pas de rôle du personnel : il est reconnu à son
  /// `users.role`. Même liste qu'en base (has_permission) et que
  /// supabase_auth_source.dart.
  static const _founders = {'admin', 'direction', 'directeur', 'dg'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = user.role.toLowerCase();

    // Les familles n'ont pas de rôle du personnel : un libellé, en français.
    if (role == 'student') {
      return _pill(context, 'Élève', const Color(0xFF15803D));
    }
    if (role == 'parent') {
      return _pill(context, 'Parent', const Color(0xFF7C3AED));
    }

    // Le rôle du personnel, avec le nom et la couleur choisis par l'école.
    if (user.staffRoleId != null) {
      final roles = ref.watch(staffRolesProvider).asData?.value;
      final r = roles?.where((r) => r.id == user.staffRoleId).firstOrNull;
      if (r != null) return _pill(context, r.name, colorFromHex(r.color));
    }

    if (_founders.contains(role)) {
      return _pill(context, 'Administrateur', const Color(0xFF8B1A00));
    }

    // Un membre du personnel sans rôle ne peut RIEN faire : la base lui refuse
    // tout. On le signale en rouge plutôt que de le laisser passer inaperçu.
    return _pill(context, 'Sans rôle', const Color(0xFFDC2626));
  }

  Widget _pill(BuildContext context, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );

  // Plus de palette par rôle TECHNIQUE : la couleur d'un membre du personnel est
  // celle de son rôle, choisie par l'école dans la page des rôles.
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF16A34A) : context.cMuted,
          ),
        ),
        const SizedBox(width: 6),
        Text(active ? 'Actif' : 'Inactif',
            style: TextStyle(
                fontSize: 12,
                color: active ? const Color(0xFF16A34A) : context.cMuted)),
      ]);
}

/// Pastille « Sorti » à la place du statut actif/inactif habituel — le motif
/// (transfert, diplôme…) en tooltip plutôt que d'allonger la colonne.
class _ExitedPill extends StatelessWidget {
  final String? reason;
  const _ExitedPill({this.reason});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: reason?.isNotEmpty == true ? reason! : 'Sans motif renseigné',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.logout_rounded, size: 13, color: _gold),
          const SizedBox(width: 5),
          const Text('Sorti', style: TextStyle(fontSize: 12, color: _gold)),
        ]),
      );
}

/// Choix du motif de sortie d'un élève : transfert (vers une autre école),
/// diplôme/fin de scolarité, ou radiation/abandon — avec un motif libre.
class _WithdrawDialog extends StatefulWidget {
  final String studentName;
  const _WithdrawDialog({required this.studentName});
  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  String _decision = 'transferred';
  final _reasonCtrl = TextEditingController();

  static const _options = [
    ('transferred', 'Transféré(e)', Icons.moving_rounded),
    ('graduated', 'Diplômé(e) / fin de scolarité', Icons.school_rounded),
    ('withdrawn', 'Radiation / abandon', Icons.person_off_rounded),
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('${widget.studentName} quitte l\'école',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Son dossier (notes, bulletins) est conservé — il n\'est '
                'jamais supprimé, juste retiré des effectifs actifs.',
                style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 14),
            for (final (value, label, icon) in _options)
              RadioListTile<String>(
                value: value,
                groupValue: _decision,
                onChanged: (v) => setState(() => _decision = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Row(children: [
                  Icon(icon, size: 17, color: _terra),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ]),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Motif (optionnel)',
                hintText: 'Ex. : déménagement à Pointe-Noire',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, (decision: _decision, reason: _reasonCtrl.text.trim())),
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: const Text('Confirmer la sortie'),
        ),
      ],
    );
  }
}

/// Carte compacte pour un utilisateur — remplace la ligne du tableau sous
/// 640px, où 6 colonnes à largeur fixe rendaient email/date illisibles.
/// Les actions se replient dans un menu `⋮` plutôt qu'une rangée d'icônes.
class _UserCard extends ConsumerWidget {
  final SbUser user;
  final bool familiesEnabled;
  final VoidCallback? onOpen;
  final VoidCallback onEnableAccess;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onWithdraw;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;
  const _UserCard({
    required this.user,
    required this.familiesEnabled,
    required this.onOpen,
    required this.onEnableAccess,
    required this.onEdit,
    required this.onToggleActive,
    required this.onWithdraw,
    required this.onReactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    final isFamily = u.role == 'student' || u.role == 'parent';
    // `eleves.X` OU `utilisateurs.X` pour un élève/parent — même règle OR que
    // les policies RLS de `users` (cf. 20260724_lock_users.sql).
    final canModify = ref.watch(canProvider('utilisateurs.modifier')) ||
        (isFamily && ref.watch(canProvider('eleves.modifier')));
    final canManageRoles = ref.watch(canProvider('utilisateurs.gerer_roles'));
    final canDelete = ref.watch(canProvider('utilisateurs.supprimer')) ||
        (isFamily && ref.watch(canProvider('eleves.supprimer')));
    final canEnable = familiesEnabled &&
        u.authUid == null &&
        (u.role == 'student' || u.role == 'parent');

    final menuEntries = <PopupMenuEntry<String>>[
      if (canEnable)
        const PopupMenuItem(value: 'enable', child: Text('Activer l\'accès')),
      if (canModify)
        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
      if (canManageRoles)
        PopupMenuItem(
            value: 'toggle',
            child: Text(u.isActive ? 'Bloquer' : 'Réactiver')),
      if (u.role == 'student' && canModify)
        PopupMenuItem(
            value: 'withdraw',
            child: Text(u.hasExited ? 'Réactiver l\'élève' : 'Marquer sorti')),
      if (canDelete)
        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(name: u.fullName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(u.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.cInk,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (u.authUid != null)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.lock_open_rounded,
                              size: 14, color: Color(0xFF15803D)),
                        )
                      else if (onOpen != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 15, color: context.cMuted.withValues(alpha: .5)),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(u.email.isEmpty ? '—' : u.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RoleCell(user: u),
                        u.hasExited
                            ? _ExitedPill(reason: u.exitReason)
                            : _StatusDot(active: u.isActive),
                        Text(
                          u.lastSeenAt != null
                              ? '· ${_UsersPageState._relativeTime(u.lastSeenAt!)}'
                              : '· jamais connecté',
                          style: TextStyle(fontSize: 11, color: context.cMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (menuEntries.isNotEmpty)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: context.cMuted),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => menuEntries,
                  onSelected: (v) {
                    switch (v) {
                      case 'enable':
                        onEnableAccess();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle':
                        onToggleActive();
                        break;
                      case 'withdraw':
                        u.hasExited ? onReactivate() : onWithdraw();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color ?? context.cMuted),
        ),
      );
}

// ── Formulaire « Modifier un utilisateur » ───────────────────────────────────
class _EditUserDialog extends ConsumerStatefulWidget {
  final SbUser user;
  final VoidCallback onSaved;
  const _EditUserDialog({required this.user, required this.onSaved});
  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.user.fullName);
  late final TextEditingController _email =
      TextEditingController(text: widget.user.email);
  late final TextEditingController _title =
      TextEditingController(text: widget.user.roleTitle ?? '');
  // Dernier titre posé automatiquement par une sélection de rôle : permet de
  // distinguer "l'utilisateur a tapé son propre titre" (on ne l'écrase plus)
  // de "le titre vient encore du rôle précédent" (on peut le remplacer).
  String? _lastAutoTitle;
  late final Set<String> _perms = _initPerms();
  bool _loading = false;
  String? _error;

  // Même mécanique que l'invitation : le droit est porté par le RÔLE.
  SbRoleTemplate? _template;
  SbStaffRole? _existingRole;
  bool _custom = false;
  bool _roleResolved = false;

  final _staffInfo = _StaffInfo();
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _staffInfo.phone.text = widget.user.phone ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Un élève/parent n'a pas de fiche `staff_profiles` : ne rien charger, sinon
    // on afficherait (et créerait) des champs employé qui ne les concernent pas.
    if (_isFamily) {
      setState(() => _profileLoaded = true);
      return;
    }
    final p = await SupabaseDbSource.getStaffProfile(widget.user.id);
    if (!mounted) return;
    setState(() {
      if (p != null) _staffInfo.loadFrom(p);
      _profileLoaded = true;
    });
  }

  // Personnel dont on peut ajuster les accès (pas le fondateur 'admin', ni
  // teacher/student/parent dont l'accès est défini par le rôle).
  static const _restrictable = {'staff_custom', 'finance', 'surveillance'};
  bool get _isStaff => _restrictable.contains(widget.user.role.toLowerCase());

  // Élève ou parent : pas de fiche employé, pas de rôle du personnel.
  bool get _isFamily =>
      widget.user.role == 'student' || widget.user.role == 'parent';

  Set<String> _initPerms() {
    final p = widget.user.permissions;
    if (p.contains(kAllPermission)) {
      return StaffPermissions.all.map((e) => e.key).toSet();
    }
    return p.toSet();
  }

  /// Modules actifs de l'école — décide quelles permissions proposer
  /// (cf. `StaffPermissions.availableFor`).
  Set<String>? get _enabledModules {
    final school = ref.watch(schoolProvider).valueOrNull;
    return school != null && school.modules.isNotEmpty ? school.modules.toSet() : null;
  }

  /// Présélectionne le rôle que l'employé porte déjà. Les comptes créés avant la
  /// bascule RBAC n'en ont aucun (staffRoleId null) : ils restent en « accès
  /// personnalisé » jusqu'à ce qu'on leur en attribue un.
  void _resolveCurrentRole(List<SbStaffRole> roles) {
    if (_roleResolved) return;
    _roleResolved = true;
    final id = widget.user.staffRoleId;
    if (id == null) {
      _custom = true;
      return;
    }
    _existingRole = roles.where((r) => r.id == id).firstOrNull;
    if (_existingRole == null) _custom = true;
  }

  void _pickRole(SbStaffRole role) {
    setState(() {
      _existingRole = role;
      _template = null;
      _custom = false;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(role.grants,
            isAdminRole: role.isAdminRole));
      final text = _title.text.trim();
      if (text.isEmpty || text == _lastAutoTitle) _title.text = role.name;
      _lastAutoTitle = role.name;
    });
  }

  void _pickTemplate(SbRoleTemplate t) {
    setState(() {
      _template = t;
      _existingRole = null;
      _custom = false;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(t.grants,
            isAdminRole: t.level == 'Direction'));
      final text = _title.text.trim();
      if (text.isEmpty || text == _lastAutoTitle) _title.text = t.name;
      _lastAutoTitle = t.name;
    });
  }

  void _pickCustom() => setState(() {
        _custom = true;
        _template = null;
        _existingRole = null;
      });

  Set<String> _grantsFromModules(List<SbPermissionModule> catalog) {
    final grants = <String>{};
    for (final key in _perms) {
      final module = RbacMapping.permissionToModule[key];
      if (module == null) continue; // 'discipline' : dérivé
      final mod = catalog.where((m) => m.key == module).firstOrNull;
      if (mod == null) continue;
      for (final sub in mod.subPermissions) {
        grants.add('$module.${sub.key}');
      }
    }
    return grants;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _title.dispose();
    _staffInfo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isStaff && _perms.isEmpty) {
      setState(() => _error = 'Choisissez un rôle pour ce membre.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final navigator = Navigator.of(context);
    try {
      await SupabaseDbSource.updateUser(
        id: widget.user.id,
        fullName: _name.text.trim(),
        email: _email.text.trim(),
      );

      final schoolId = ref.read(currentSchoolIdProvider);
      if (_isFamily) {
        // Élève/parent : seul le téléphone (colonne `users`) est commun. Pas de
        // fiche `staff_profiles` — l'y écrire créerait un employé fantôme.
        await SupabaseDbSource.updateUserPhone(
            id: widget.user.id, phone: _staffInfo.phone.text);
      } else if (schoolId != null && _profileLoaded) {
        await SupabaseDbSource.updateUserPhone(
            id: widget.user.id, phone: _staffInfo.phone.text);
        await SupabaseDbSource.upsertStaffProfile(
          userId: widget.user.id,
          schoolId: schoolId,
          employeeId: _staffInfo.matricule.text,
          gender: _staffInfo.gender,
          dateOfBirth: _staffInfo.dateOfBirth,
          joinDate: _staffInfo.joinDate,
          contractType: _staffInfo.contractType,
        );
      }

      if (_isStaff) {
        if (schoolId == null) throw Exception('École introuvable.');

        SbStaffRole role;
        if (_existingRole != null) {
          role = _existingRole!;
        } else if (_template != null) {
          role = await StaffRolesSource.ensureRoleFromTemplate(
            schoolId: schoolId, template: _template!);
        } else {
          final catalog = await ref.read(permissionCatalogProvider.future);
          final grants = _grantsFromModules(catalog);
          final name = _title.text.trim().isEmpty
              ? _name.text.trim()
              : _title.text.trim();
          final roleId = await StaffRolesSource.createStaffRole(
            schoolId: schoolId,
            name: name,
            description: 'Rôle personnalisé',
            grants: grants,
          );
          role = SbStaffRole(
            id: roleId, schoolId: schoolId, name: name,
            isAdminRole: false, grants: grants,
          );
        }

        await SupabaseDbSource.updateStaffAccess(
          id: widget.user.id,
          permissions: RbacMapping.toLegacyPermissions(role.grants,
              isAdminRole: role.isAdminRole),
          title: _title.text.trim(),
          staffRoleId: role.id,
        );
        ref.invalidate(staffRolesProvider);
      }
      widget.onSaved();
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Présélectionne le rôle déjà porté, dès que la liste des rôles est arrivée.
    final roles = ref.watch(staffRolesProvider).asData?.value;
    if (_isStaff && roles != null) _resolveCurrentRole(roles);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Modifier l\'utilisateur',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              // Élève/parent : seul le téléphone. Le personnel a la fiche
              // complète (matricule, sexe, naissance, embauche, contrat).
              if (_isFamily)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: _staffInfo.phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                )
              else if (_profileLoaded)
                _StaffInfoFields(info: _staffInfo)
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),

              if (_isStaff) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                      labelText: 'Titre (ex. Secrétaire)',
                      prefixIcon: Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Rôle',
                      style: TextStyle(
                          fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                _RolePicker(
                  selectedRoleId: _existingRole?.id,
                  selectedTemplateId: _template?.id,
                  custom: _custom,
                  onRole: _pickRole,
                  onTemplate: _pickTemplate,
                  onCustom: _pickCustom,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_custom ? 'Accès accordés' : 'Accès de ce rôle',
                      style: TextStyle(
                          fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in StaffPermissions.availableFor(_enabledModules))
                    FilterChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(p.icon,
                          size: 15,
                          color: _perms.contains(p.key) ? _terra : context.cMuted),
                      selected: _perms.contains(p.key),
                      // Hors « accès personnalisé », les accès sont ceux du rôle :
                      // les modifier pour une seule personne romprait le modèle.
                      onSelected: _custom
                          ? (v) => setState(() {
                                if (v) {
                                  _perms.add(p.key);
                                } else {
                                  _perms.remove(p.key);
                                }
                              })
                          : null,
                      selectedColor: _terra.withValues(alpha: .12),
                      checkmarkColor: _terra,
                      backgroundColor: context.cCard,
                      side: BorderSide(color: context.cBorder),
                    ),
                ]),
                if (!_custom && _existingRole != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ces accès viennent du rôle « ${_existingRole!.name} ». Les '
                    'modifier dans « Rôles & permissions » les changera pour tous '
                    'les membres qui le portent.',
                    style: TextStyle(fontSize: 11, color: context.cMuted),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: _terra, fontSize: 12.5)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ── Fiche du personnel : champs partagés invitation / modification ───────────
//
// Un seul formulaire pour les deux fenêtres. Deux copies auraient divergé à la
// première évolution.

class _StaffInfo {
  final phone = TextEditingController();
  final matricule = TextEditingController();
  String? gender; // 'M' | 'F'
  DateTime? dateOfBirth;
  DateTime? joinDate;
  String contractType = 'permanent';

  void dispose() {
    phone.dispose();
    matricule.dispose();
  }

  void loadFrom(SbStaffProfile p) {
    matricule.text = p.employeeId ?? '';
    gender = p.gender;
    dateOfBirth = p.dateOfBirth;
    joinDate = p.joinDate;
    contractType = p.contractType;
  }
}

class _StaffInfoFields extends StatefulWidget {
  final _StaffInfo info;
  const _StaffInfoFields({required this.info});
  @override
  State<_StaffInfoFields> createState() => _StaffInfoFieldsState();
}

class _StaffInfoFieldsState extends State<_StaffInfoFields> {
  static const _contracts = {
    'permanent': 'Permanent',
    'vacataire': 'Vacataire',
    'prestataire': 'Prestataire',
  };

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? (last.isBefore(DateTime.now()) ? last : DateTime.now()),
      firstDate: first,
      lastDate: last,
      locale: const Locale('fr'),
    );
    if (d != null) setState(() => onPicked(d));
  }

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    final now = DateTime.now();

    return Column(children: [
      const SizedBox(height: 12),
      TextFormField(
        controller: i.phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: i.matricule,
            decoration: const InputDecoration(
                labelText: 'Matricule',
                prefixIcon: Icon(Icons.badge_outlined)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: i.gender,
            decoration: const InputDecoration(
                labelText: 'Sexe', prefixIcon: Icon(Icons.wc_outlined)),
            items: const [
              DropdownMenuItem(value: 'M', child: Text('Masculin')),
              DropdownMenuItem(value: 'F', child: Text('Féminin')),
            ],
            onChanged: (v) => setState(() => i.gender = v),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _DateField(
            label: 'Date de naissance',
            value: _fmt(i.dateOfBirth),
            onTap: () => _pickDate(
              current: i.dateOfBirth,
              first: DateTime(1940),
              last: DateTime(now.year - 16, now.month, now.day),
              onPicked: (d) => i.dateOfBirth = d,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DateField(
            label: "Date d'embauche",
            value: _fmt(i.joinDate),
            onTap: () => _pickDate(
              current: i.joinDate,
              first: DateTime(1990),
              last: DateTime(now.year + 1),
              onPicked: (d) => i.joinDate = d,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: i.contractType,
        decoration: const InputDecoration(
            labelText: 'Type de contrat',
            prefixIcon: Icon(Icons.description_outlined)),
        items: [
          for (final e in _contracts.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => i.contractType = v ?? 'permanent'),
      ),
    ]);
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          child: Text(value,
              style: TextStyle(fontSize: 13, color: context.cInk)),
        ),
      );
}

/// Choix du rôle à l'invitation.
///
/// Affiche d'abord les rôles **déjà créés** dans l'école (les réutiliser est le
/// cas normal : deux comptables partagent un rôle), puis les **modèles** du
/// catalogue adaptés au cycle de l'établissement (Proviseur/Censeur pour un
/// lycée, Recteur/Doyen pour une université…), qui seront créés à la volée.
///
/// Pas de « sur-mesure » ici : un rôle taillé à la main se crée dans
/// « Rôles & permissions » (nommé, partagé, réutilisable), puis apparaît
/// ci-dessus comme un rôle sélectionnable. Bricoler des droits pour une seule
/// personne à l'invitation romprait le modèle « le droit suit le rôle ».
class _RolePicker extends ConsumerWidget {
  final String? selectedRoleId;
  final String? selectedTemplateId;
  final bool custom;
  final ValueChanged<SbStaffRole> onRole;
  final ValueChanged<SbRoleTemplate> onTemplate;

  /// Null → pas d'option « Accès personnalisé » (cas de l'invitation : un rôle
  /// sur-mesure se crée dans « Rôles & permissions », pas ici).
  final VoidCallback? onCustom;

  const _RolePicker({
    required this.selectedRoleId,
    required this.selectedTemplateId,
    this.custom = false,
    required this.onRole,
    required this.onTemplate,
    this.onCustom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(staffRolesProvider);
    final templates = ref.watch(roleTemplatesProvider);

    if (roles.isLoading || templates.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final existing = roles.asData?.value ?? const <SbStaffRole>[];
    final existingNames = existing.map((r) => r.name).toSet();
    // Un modèle déjà instancié dans l'école est proposé comme rôle, pas en double.
    final proposals = (templates.asData?.value ?? const <SbRoleTemplate>[])
        .where((t) => !existingNames.contains(t.name))
        .toList();

    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final r in existing)
        ChoiceChip(
          label: Text(r.name, style: const TextStyle(fontSize: 12)),
          avatar: Icon(Icons.badge_outlined,
              size: 15, color: selectedRoleId == r.id ? _terra : context.cMuted),
          selected: selectedRoleId == r.id,
          onSelected: (_) => onRole(r),
          selectedColor: _terra.withValues(alpha: .12),
          backgroundColor: context.cCard,
          side: BorderSide(color: context.cBorder),
        ),
      for (final t in proposals)
        ChoiceChip(
          label: Text(t.name, style: const TextStyle(fontSize: 12)),
          avatar: Icon(Icons.add_circle_outline,
              size: 15,
              color: selectedTemplateId == t.id ? _terra : context.cMuted),
          selected: selectedTemplateId == t.id,
          onSelected: (_) => onTemplate(t),
          selectedColor: _terra.withValues(alpha: .12),
          backgroundColor: context.cCard,
          side: BorderSide(color: context.cBorder),
        ),
      if (onCustom != null)
        ChoiceChip(
          label: const Text('Accès personnalisé', style: TextStyle(fontSize: 12)),
          avatar: Icon(Icons.tune,
              size: 15, color: custom ? _terra : context.cMuted),
          selected: custom,
          onSelected: (_) => onCustom!(),
          selectedColor: _terra.withValues(alpha: .12),
          backgroundColor: context.cCard,
          side: BorderSide(color: context.cBorder),
        ),
    ]);
  }
}

// ── Formulaire « Inviter un membre » ──────────────────────────────────────────
class _InviteMemberDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final VoidCallback onCreated;
  const _InviteMemberDialog({required this.schoolId, required this.onCreated});
  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _title = TextEditingController();
  late final TextEditingController _pass =
      TextEditingController(text: _generatePassword());

  bool _isStaff = false; // false = Enseignant, true = Personnel
  // Dernier titre posé automatiquement par une sélection de rôle : permet de
  // distinguer "l'utilisateur a tapé son propre titre" (on ne l'écrase plus)
  // de "le titre vient encore du rôle précédent" (on peut le remplacer).
  String? _lastAutoTitle;
  final Set<String> _perms = {};
  bool _loading = false;
  String? _error;

  /// Modules actifs de l'école — décide quelles permissions proposer
  /// (cf. `StaffPermissions.availableFor`).
  Set<String>? get _enabledModules {
    final school = ref.watch(schoolProvider).valueOrNull;
    return school != null && school.modules.isNotEmpty ? school.modules.toSet() : null;
  }

  /// Rôle choisi. Le droit est porté par le RÔLE, pas par la personne : deux
  /// comptables partagent le même rôle, et le modifier plus tard les met à jour
  /// tous les deux. Un rôle sur-mesure se crée dans « Rôles & permissions ».
  SbRoleTemplate? _template; // modèle du catalogue (rôle pas encore créé)
  SbStaffRole? _existingRole; // rôle déjà créé dans l'école

  final _staffInfo = _StaffInfo();

  static String _generatePassword() {
    final n = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'Scolaris-${n.toString().padLeft(4, '0')}';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _title.dispose();
    _pass.dispose();
    _staffInfo.dispose();
    super.dispose();
  }

  /// Sélection d'un rôle existant de l'école.
  void _pickRole(SbStaffRole role) {
    setState(() {
      _existingRole = role;
      _template = null;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(role.grants,
            isAdminRole: role.isAdminRole));
      final text = _title.text.trim();
      if (text.isEmpty || text == _lastAutoTitle) _title.text = role.name;
      _lastAutoTitle = role.name;
    });
  }

  /// Sélection d'un modèle du catalogue : le rôle sera créé à la volée.
  void _pickTemplate(SbRoleTemplate t) {
    setState(() {
      _template = t;
      _existingRole = null;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(t.grants,
            isAdminRole: t.level == 'Direction'));
      final text = _title.text.trim();
      if (text.isEmpty || text == _lastAutoTitle) _title.text = t.name;
      _lastAutoTitle = t.name;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isStaff && _perms.isEmpty) {
      setState(() => _error = 'Choisissez un rôle pour ce membre.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? staffRoleId;
      var permissions = const <String>[];

      if (!_isStaff) {
        // Un ENSEIGNANT porte lui aussi un rôle, comme le reste du personnel.
        // Sans rôle, il n'a aucune permission — et depuis que les notes sont
        // verrouillées en base (20260722), il ne pourrait plus en saisir une
        // seule. Cf. 20260721_teachers_get_a_role.sql.
        final schoolId = ref.read(currentSchoolIdProvider);
        final templates = await ref.read(roleTemplatesProvider.future);
        final t = templates.where((t) => t.name == 'Enseignant').firstOrNull;
        if (schoolId != null && t != null) {
          final role = await StaffRolesSource.ensureRoleFromTemplate(
            schoolId: schoolId,
            template: t,
          );
          staffRoleId = role.id;
          permissions = RbacMapping.toLegacyPermissions(role.grants);
        }
      }

      if (_isStaff) {
        final schoolId = ref.read(currentSchoolIdProvider);
        if (schoolId == null) throw Exception('École introuvable.');

        SbStaffRole role;
        if (_existingRole != null) {
          role = _existingRole!;
        } else if (_template != null) {
          // Création paresseuse : le rôle n'existe dans l'école qu'à la première
          // embauche qui en a besoin. La suivante le réutilise.
          role = await StaffRolesSource.ensureRoleFromTemplate(
            schoolId: schoolId,
            template: _template!,
          );
        } else {
          // Aucun rôle choisi : on n'invente plus de rôle « sur-mesure » ici. Un
          // rôle taillé à la main se crée dans « Rôles & permissions ».
          throw Exception('Choisissez un rôle pour ce membre.');
        }

        staffRoleId = role.id;
        permissions = RbacMapping.toLegacyPermissions(role.grants,
            isAdminRole: role.isAdminRole);
      }

      final userId = await SupabaseDbSource.createMemberAccount(
        email: _email.text.trim(),
        password: _pass.text,
        fullName: _name.text.trim(),
        role: _isStaff ? 'staff_custom' : 'teacher',
        permissions: permissions,
        title: _isStaff ? _title.text.trim() : null,
        staffRoleId: staffRoleId,
        phone: _staffInfo.phone.text,
      );

      // Fiche du personnel (matricule, sexe, naissance, embauche, contrat).
      final schoolId = ref.read(currentSchoolIdProvider);
      if (userId != null && schoolId != null) {
        await SupabaseDbSource.upsertStaffProfile(
          userId: userId,
          schoolId: schoolId,
          employeeId: _staffInfo.matricule.text,
          gender: _staffInfo.gender,
          dateOfBirth: _staffInfo.dateOfBirth,
          joinDate: _staffInfo.joinDate,
          contractType: _staffInfo.contractType,
        );
      }

      ref.invalidate(staffRolesProvider);
      widget.onCreated();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(
            '${_name.text.trim()} créé(e). Mot de passe : ${_pass.text}'),
        backgroundColor: _green,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiesEnabled =
        ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
    // En offre Simple, le personnel personnalisé est verrouillé → seul Enseignant.
    if (_isStaff && !familiesEnabled) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _isStaff = false));
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Inviter un membre',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Type : Enseignant vs Personnel ─────────────────────────
              Row(children: [
                Expanded(
                  child: _TypeChoice(
                    label: 'Enseignant',
                    icon: Icons.co_present_outlined,
                    selected: !_isStaff,
                    onTap: () => setState(() => _isStaff = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeChoice(
                    label: 'Personnel',
                    icon: Icons.badge_outlined,
                    selected: _isStaff,
                    onTap: () => setState(() => _isStaff = true),
                  ),
                ),
              ]),

              // ── Offre Simple : personnel verrouillé ────────────────────
              if (!familiesEnabled) ...[
                const SizedBox(height: 12),
                const PlanGateBanner(
                  minPlan: 'pro',
                  featureLabel: 'Personnel avec accès personnalisés',
                  description:
                      'Créez secrétaire, comptable, surveillant… avec des droits précis.',
                  icon: Icons.badge_outlined,
                  bullets: [
                    'Choisir ce que chaque membre peut gérer',
                    'Secrétaire, Comptable, Surveillant…',
                    'Accès séparés et sécurisés',
                  ],
                ),
              ],

              // ── Fiche : téléphone, matricule, sexe, naissance, embauche,
              //    contrat. Vaut aussi pour un enseignant : lui non plus n'avait
              //    ni téléphone ni date d'embauche.
              _StaffInfoFields(info: _staffInfo),

              // ── Personnel : rôle + titre + aperçu des accès ────────────
              if (_isStaff && familiesEnabled) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                      labelText: 'Titre (ex. Secrétaire)',
                      prefixIcon: Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Rôle',
                      style: TextStyle(
                          fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                _RolePicker(
                  selectedRoleId: _existingRole?.id,
                  selectedTemplateId: _template?.id,
                  onRole: _pickRole,
                  onTemplate: _pickTemplate,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Accès de ce rôle',
                      style: TextStyle(
                          fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                // Les accès sont ceux du rôle : on les affiche en lecture seule.
                // Les changer pour une seule personne casserait le modèle (le
                // droit suit le rôle) ; ça se fait dans « Rôles & permissions »,
                // et ça s'applique à tous ceux qui portent ce rôle.
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in StaffPermissions.availableFor(_enabledModules))
                    FilterChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(p.icon,
                          size: 15,
                          color: _perms.contains(p.key) ? _terra : context.cMuted),
                      selected: _perms.contains(p.key),
                      onSelected: null,
                      selectedColor: _terra.withValues(alpha: .12),
                      checkmarkColor: _terra,
                      backgroundColor: context.cCard,
                      side: BorderSide(color: context.cBorder),
                    ),
                ]),
                if (_perms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pour changer ces accès, modifiez le rôle dans '
                    '« Rôles & permissions » — la modification s\'appliquera à '
                    'tous les membres qui le portent.',
                    style: TextStyle(fontSize: 11, color: context.cMuted),
                  ),
                ],
              ],

              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                decoration: InputDecoration(
                  labelText: 'Mot de passe temporaire',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Régénérer',
                    onPressed: () =>
                        setState(() => _pass.text = _generatePassword()),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? '6 caractères minimum' : null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E7490).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.verified_user_outlined,
                      size: 16, color: Color(0xFF0E7490)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le compte est créé immédiatement (sans email à confirmer). '
                      'Communiquez le mot de passe ci-dessus au membre.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF0E7490)),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: _terra, fontSize: 12.5)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Créer le compte'),
        ),
      ],
    );
  }
}

// ── Choix de type (Enseignant / Personnel) ───────────────────────────────────
class _TypeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChoice(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? _terra.withValues(alpha: .08) : context.cCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? _terra : context.cBorder, width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Icon(icon, size: 20, color: selected ? _terra : context.cMuted),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? _terra : context.cInk,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      );
}

// ── Activer l'accès (donner un login à une fiche élève/parent) ───────────────
class _EnableAccessDialog extends StatefulWidget {
  final SbUser user;
  final VoidCallback onDone;
  const _EnableAccessDialog({required this.user, required this.onDone});
  @override
  State<_EnableAccessDialog> createState() => _EnableAccessDialogState();
}

class _EnableAccessDialogState extends State<_EnableAccessDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
      text: _isRealEmail(widget.user.email) ? widget.user.email : '');
  late final TextEditingController _pass =
      TextEditingController(text: 'Scolaris-${DateTime.now().microsecondsSinceEpoch % 10000}');
  bool _loading = false;
  String? _error;

  // Les fiches sans email réel ont un email synthétique @*.scolaris.local.
  static bool _isRealEmail(String e) =>
      e.contains('@') && !e.endsWith('.scolaris.local');

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await SupabaseDbSource.enableUserLogin(
        userId: widget.user.id,
        email: _email.text.trim(),
        password: _pass.text,
        fullName: widget.user.fullName,
      );
      widget.onDone();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Accès activé pour ${widget.user.fullName}. '
            'Identifiants : ${_email.text.trim()} / ${_pass.text}'),
        backgroundColor: _green,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.user.role == 'student';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Activer la connexion',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Donne un identifiant de connexion à ${widget.user.fullName}'
                  '${isStudent ? " (élève)" : " (parent)"}.',
                  style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email de connexion',
                  prefixIcon: Icon(Icons.mail_outline)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() => _pass.text =
                      'Scolaris-${DateTime.now().microsecondsSinceEpoch % 10000}'),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? '6 caractères minimum' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: _terra, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Activer'),
        ),
      ],
    );
  }
}
