import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/rbac_mapping.dart';
import '../../../../core/permissions/staff_permissions.dart';
import '../../../../data/sources/remote/staff_roles_source.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';
import '../../roles/workspace/role_workspace_models.dart' show colorFromHex;

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _filter = 'All';

  // Inscription inline (au lieu d'une route plein écran).
  bool _enrolling = false;
  EnrollmentConfig? _enrollConfig;
  List<SbClass> _enrollClasses = const [];
  String? _enrollSchoolId;

  // Fiche élève inline (id de l'utilisateur consulté).
  String? _viewId;

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

    // Ouverture inline (dans le shell), pas de route plein écran.
    setState(() {
      _enrollConfig = config;
      _enrollClasses = classes;
      _enrollSchoolId = schoolId;
      _enrolling = true;
    });
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

    final subParts = <String>[
      if (st?.matricule != null) 'N° ${st!.matricule}',
      if (classLabel != null) classLabel,
    ];
    final sub = subParts.isEmpty ? 'Fiche élève' : subParts.join(' · ');

    return PageScaffold(
      title: u.fullName,
      subtitle: sub,
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
          ActionButton(
              label: 'Modifier', icon: Icons.edit_outlined,
              onTap: () => _editUser(u)),
          if (canEnable)
            ActionButton(
                label: 'Activer l\'accès', icon: Icons.vpn_key_outlined,
                onTap: () => _enableAccess(u)),
          ActionButton(
            label: u.isActive ? 'Bloquer' : 'Réactiver',
            icon: u.isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            onTap: () => _toggleActive(u),
          ),
        ]),
        const SizedBox(height: 16),

        // Identité.
        DataPanel(
          title: 'Identité',
          child: Column(children: [
            _ProfileKV(label: 'Matricule', value: st?.matricule ?? '—'),
            _ProfileKV(label: 'Niveau', value: st?.niveau ?? '—'),
            _ProfileKV(label: 'Classe', value: classLabel ?? 'Sans classe'),
            _ProfileKV(label: 'Email', value: u.email.isEmpty ? '—' : u.email),
          ]),
        ),
        const SizedBox(height: 14),

        // Compte & accès.
        DataPanel(
          title: 'Compte & accès',
          child: Column(children: [
            const _ProfileKV(label: 'Rôle', value: 'Élève'),
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
        onCreated: () => ref.invalidate(usersProvider),
      ),
    );
  }

  void _editUser(SbUser u) {
    showDialog(
      context: context,
      builder: (_) => _EditUserDialog(
        user: u,
        onSaved: () => ref.invalidate(usersProvider),
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
      ref.invalidate(usersProvider);
      ref.invalidate(studentsProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Compte "${u.fullName}" supprimé.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Suppression impossible : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    }
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

  @override
  Widget build(BuildContext context) {
    // Inscription inline : remplace la liste par le formulaire (shell conservé).
    if (_enrolling && _enrollConfig != null && _enrollSchoolId != null) {
      return _InlineEnroll(
        config: _enrollConfig!,
        classes: _enrollClasses,
        onBack: () => setState(() => _enrolling = false),
        onSubmit: (data) => _saveStudent(_enrollSchoolId!, data),
      );
    }

    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      loading: () => const PageScaffold(
        title: 'Utilisateurs',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Utilisateurs',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (allUsers) {
        // Fiche élève inline : remplace la liste par le profil.
        if (_viewId != null) {
          final match = allUsers.where((u) => u.id == _viewId).toList();
          if (match.isNotEmpty) {
            return _studentProfileView(match.first);
          }
          // Utilisateur disparu (supprimé) → on referme la fiche.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _viewId = null);
          });
        }
        final users = allUsers
            .where((u) =>
                _filter == 'All' || u.role == _filter.toLowerCase())
            .toList();
        final familiesEnabled =
            ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
        return PageScaffold(
          title: 'Utilisateurs',
          subtitle: '${allUsers.length} comptes tous rôles',
          actions: [
            ActionButton(
                label: 'Inviter', icon: Icons.send_outlined, onTap: _openInvite),
            const SizedBox(width: 8),
            ActionButton(
                label: 'Inscrire un élève',
                icon: Icons.person_add_alt_1_rounded,
                primary: true,
                onTap: _openEnrollment),
          ],
          child: Column(children: [
            _FilterRow(
              current: _filter,
              options: const [
                'All',
                'admin',
                'teacher',
                'finance',
                'surveillance',
                'parent',
                'student',
              ],
              onChange: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Comptes',
              headerActions: const [
                SearchInput(hint: 'Rechercher un utilisateur…')
              ],
              child: users.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun utilisateur.',
                              style: TextStyle(color: context.cMuted))),
                    )
                  : DataTablePanel(
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
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: u.role == 'student'
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
                                if (u.role == 'student') ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 15,
                                      color: context.cMuted.withValues(alpha: .5)),
                                ],
                              ]),
                            ),
                            Text(u.email,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 12, color: context.cMuted)),
                            _RoleBadge(user: u),
                            _StatusDot(active: u.isActive),
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
                              const SizedBox(width: 6),
                              _IconBtn(
                                  icon: Icons.edit_outlined,
                                  onTap: () => _editUser(u)),
                              const SizedBox(width: 6),
                              _IconBtn(
                                  icon: u.isActive
                                      ? Icons.block_rounded
                                      : Icons.check_circle_outline_rounded,
                                  onTap: () => _toggleActive(u)),
                              const SizedBox(width: 6),
                              _IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: _terra,
                                  onTap: () => _deleteUser(u)),
                            ]),
                          ],
                      ],
                    ),
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
class _InlineEnroll extends StatelessWidget {
  final EnrollmentConfig config;
  final List<SbClass> classes;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onSubmit;
  const _InlineEnroll({
    required this.config,
    required this.classes,
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
class _ProfileKV extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileKV({required this.label, required this.value});
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
                  color: context.cInk,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String current;
  final List<String> options;
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
                  label: Text(o),
                  selected: current == o,
                  onSelected: (_) => onChange(o),
                  selectedColor: const Color(0xFF8B1A00).withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: current == o ? const Color(0xFF8B1A00) : context.cMuted,
                    fontWeight: current == o ? FontWeight.w700 : FontWeight.w500,
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
class _RoleBadge extends ConsumerWidget {
  final SbUser user;
  const _RoleBadge({required this.user});

  static const _staffRoles = {'staff_custom', 'finance', 'surveillance'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = _staffRoles.contains(user.role.toLowerCase());

    if (isStaff && user.staffRoleId == null) {
      return _pill(context, 'Sans rôle', const Color(0xFFDC2626));
    }

    var label = user.role;
    var color = _color(user.role) ?? context.cMuted;

    if (isStaff) {
      final roles = ref.watch(staffRolesProvider).asData?.value;
      final r = roles?.where((r) => r.id == user.staffRoleId).firstOrNull;
      if (r != null) {
        label = r.name;
        color = colorFromHex(r.color); // la couleur choisie pour le rôle
      } else {
        label = user.roleTitle ?? user.role;
      }
    }

    return _pill(context, label, color);
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

  static Color? _color(String r) {
    switch (r) {
      case 'admin':
        return const Color(0xFF8B1A00);
      case 'teacher':
        return const Color(0xFF0891B2);
      case 'student':
        return const Color(0xFF16A34A);
      case 'parent':
        return const Color(0xFF7C3AED);
      case 'finance':
        return const Color(0xFFC17F24);
      default:
        return null; // ← neutre résolu depuis le thème dans build()
    }
  }
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
  late final Set<String> _perms = _initPerms();
  bool _loading = false;
  String? _error;

  // Même mécanique que l'invitation : le droit est porté par le RÔLE.
  SbRoleTemplate? _template;
  SbStaffRole? _existingRole;
  bool _custom = false;
  bool _roleResolved = false;

  // Personnel dont on peut ajuster les accès (pas le fondateur 'admin', ni
  // teacher/student/parent dont l'accès est défini par le rôle).
  static const _restrictable = {'staff_custom', 'finance', 'surveillance'};
  bool get _isStaff => _restrictable.contains(widget.user.role.toLowerCase());

  Set<String> _initPerms() {
    final p = widget.user.permissions;
    if (p.contains(kAllPermission)) {
      return StaffPermissions.all.map((e) => e.key).toSet();
    }
    return p.toSet();
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
      if (_title.text.trim().isEmpty) _title.text = role.name;
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
      if (_title.text.trim().isEmpty) _title.text = t.name;
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
      if (_isStaff) {
        final schoolId = ref.read(currentSchoolIdProvider);
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
                  for (final p in StaffPermissions.all)
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

/// Choix du rôle à l'invitation.
///
/// Affiche d'abord les rôles **déjà créés** dans l'école (les réutiliser est le
/// cas normal : deux comptables partagent un rôle), puis les **modèles** du
/// catalogue adaptés au cycle de l'établissement (Proviseur/Censeur pour un
/// lycée, Recteur/Doyen pour une université…), qui seront créés à la volée.
/// En dernier, une échappatoire « Accès personnalisé » pour les cas hors moule.
class _RolePicker extends ConsumerWidget {
  final String? selectedRoleId;
  final String? selectedTemplateId;
  final bool custom;
  final ValueChanged<SbStaffRole> onRole;
  final ValueChanged<SbRoleTemplate> onTemplate;
  final VoidCallback onCustom;

  const _RolePicker({
    required this.selectedRoleId,
    required this.selectedTemplateId,
    required this.custom,
    required this.onRole,
    required this.onTemplate,
    required this.onCustom,
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
      ChoiceChip(
        label: const Text('Accès personnalisé', style: TextStyle(fontSize: 12)),
        avatar: Icon(Icons.tune,
            size: 15, color: custom ? _terra : context.cMuted),
        selected: custom,
        onSelected: (_) => onCustom(),
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
  final Set<String> _perms = {};
  bool _loading = false;
  String? _error;

  /// Rôle choisi. Le droit est porté par le RÔLE, pas par la personne : deux
  /// comptables partagent le même rôle, et le modifier plus tard les met à jour
  /// tous les deux. Null = « Accès personnalisé » (rôle dédié à cette personne).
  SbRoleTemplate? _template; // modèle du catalogue (rôle pas encore créé)
  SbStaffRole? _existingRole; // rôle déjà créé dans l'école
  bool _custom = false;

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
    super.dispose();
  }

  /// Sélection d'un rôle existant de l'école.
  void _pickRole(SbStaffRole role) {
    setState(() {
      _existingRole = role;
      _template = null;
      _custom = false;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(role.grants,
            isAdminRole: role.isAdminRole));
      if (_title.text.trim().isEmpty) _title.text = role.name;
    });
  }

  /// Sélection d'un modèle du catalogue : le rôle sera créé à la volée.
  void _pickTemplate(SbRoleTemplate t) {
    setState(() {
      _template = t;
      _existingRole = null;
      _custom = false;
      _perms
        ..clear()
        ..addAll(RbacMapping.toLegacyPermissions(t.grants,
            isAdminRole: t.level == 'Direction'));
      if (_title.text.trim().isEmpty) _title.text = t.name;
    });
  }

  void _pickCustom() {
    setState(() {
      _custom = true;
      _template = null;
      _existingRole = null;
      _perms.clear();
    });
  }

  /// Traduit les modules cochés en grants `module.action` (toutes les actions du
  /// module). La finesse action par action n'est pas exposée tant que les
  /// policies RLS ne l'appliquent pas — cf. RbacMapping.
  Set<String> _grantsFromModules(List<SbPermissionModule> catalog) {
    final grants = <String>{};
    for (final key in _perms) {
      final module = RbacMapping.permissionToModule[key];
      if (module == null) continue; // 'discipline' : dérivé, pas de module
      final mod = catalog.where((m) => m.key == module).firstOrNull;
      if (mod == null) continue;
      for (final sub in mod.subPermissions) {
        grants.add('$module.${sub.key}');
      }
    }
    return grants;
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
          // Accès personnalisé → rôle dédié, nommé d'après le titre saisi.
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
            id: roleId,
            schoolId: schoolId,
            name: name,
            isAdminRole: false,
            grants: grants,
          );
        }

        staffRoleId = role.id;
        permissions = RbacMapping.toLegacyPermissions(role.grants,
            isAdminRole: role.isAdminRole);
      }

      await SupabaseDbSource.createMemberAccount(
        email: _email.text.trim(),
        password: _pass.text,
        fullName: _name.text.trim(),
        role: _isStaff ? 'staff_custom' : 'teacher',
        permissions: permissions,
        title: _isStaff ? _title.text.trim() : null,
        staffRoleId: staffRoleId,
      );
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
                  custom: _custom,
                  onRole: _pickRole,
                  onTemplate: _pickTemplate,
                  onCustom: _pickCustom,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _custom ? 'Accès accordés' : 'Accès de ce rôle',
                      style: TextStyle(
                          fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                // Hors mode personnalisé, les accès sont ceux du rôle : on les
                // affiche sans les rendre modifiables ici. Les changer pour une
                // seule personne casserait le modèle (le droit suit le rôle) ;
                // ça se fait dans « Rôles & permissions », et ça s'applique à
                // tous ceux qui portent ce rôle.
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in StaffPermissions.all)
                    FilterChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(p.icon,
                          size: 15,
                          color: _perms.contains(p.key) ? _terra : context.cMuted),
                      selected: _perms.contains(p.key),
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
                if (!_custom && _perms.isNotEmpty) ...[
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
  Widget build(BuildContext context) => GestureDetector(
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
