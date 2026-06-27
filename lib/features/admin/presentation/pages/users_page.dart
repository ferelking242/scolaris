import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/staff_permissions.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _filter = 'All';

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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: _terra,
            foregroundColor: Colors.white,
            title: const Text('Inscrire un élève',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            elevation: 0,
          ),
          body: EnrollmentPage(
            isAdminMode: true,
            config: config,
            adminClasses: classes,
            onSubmit: (data) => _saveStudent(schoolId, data),
          ),
        ),
      ),
    );
  }

  /// Enregistre réellement la fiche élève (users + student_profiles).
  Future<void> _saveStudent(String schoolId, Map<String, dynamic> data) async {
    final navigator = Navigator.of(context);
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
      navigator.pop();
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
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun utilisateur.',
                              style: TextStyle(color: muted))),
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
                            Row(children: [
                              Avatar(name: u.fullName, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(u.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: ink,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            Text(u.email,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontSize: 12, color: muted)),
                            _RoleBadge(role: u.role),
                            _StatusDot(active: u.isActive),
                            Text(
                              u.lastSeenAt != null
                                  ? _relativeTime(u.lastSeenAt!)
                                  : '—',
                              style:
                                  const TextStyle(fontSize: 12, color: muted),
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
                    color: current == o ? const Color(0xFF8B1A00) : muted,
                    fontWeight: current == o ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) {
    final color = _color(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(role,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }

  static Color _color(String r) {
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
        return muted;
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
            color: active ? const Color(0xFF16A34A) : muted,
          ),
        ),
        const SizedBox(width: 6),
        Text(active ? 'Actif' : 'Inactif',
            style: TextStyle(
                fontSize: 12,
                color: active ? const Color(0xFF16A34A) : muted)),
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
          child: Icon(icon, size: 16, color: color ?? muted),
        ),
      );
}

// ── Formulaire « Modifier un utilisateur » ───────────────────────────────────
class _EditUserDialog extends StatefulWidget {
  final SbUser user;
  final VoidCallback onSaved;
  const _EditUserDialog({required this.user, required this.onSaved});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
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
      setState(() => _error = 'Cochez au moins un accès.');
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
        final allChecked = _perms.length == StaffPermissions.all.length;
        await SupabaseDbSource.updateStaffAccess(
          id: widget.user.id,
          permissions: allChecked ? [kAllPermission] : _perms.toList(),
          title: _title.text.trim(),
        );
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Accès accordés',
                      style: TextStyle(
                          fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in StaffPermissions.all)
                    FilterChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(p.icon,
                          size: 15,
                          color: _perms.contains(p.key) ? _terra : muted),
                      selected: _perms.contains(p.key),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _perms.add(p.key);
                        } else {
                          _perms.remove(p.key);
                        }
                      }),
                      selectedColor: _terra.withValues(alpha: .12),
                      checkmarkColor: _terra,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: border),
                    ),
                ]),
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

  void _applyPreset(String name) {
    final keys = StaffPermissions.presets[name] ?? const [];
    setState(() {
      _perms.clear();
      if (keys.contains(kAllPermission)) {
        _perms.addAll(StaffPermissions.all.map((p) => p.key)); // tout coché
      } else {
        _perms.addAll(keys);
      }
      if (_title.text.trim().isEmpty && name != 'Personnalisé') {
        _title.text = name;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isStaff && _perms.isEmpty) {
      setState(() => _error = 'Cochez au moins un accès pour ce membre.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Enseignant = rôle dédié. Personnel = staff_custom + permissions.
      // Tout coché → accès total ('*') pour englober les futurs modules.
      final allChecked = _perms.length == StaffPermissions.all.length;
      final permissions = !_isStaff
          ? const <String>[]
          : (allChecked ? [kAllPermission] : _perms.toList());

      await SupabaseDbSource.createMemberAccount(
        email: _email.text.trim(),
        password: _pass.text,
        fullName: _name.text.trim(),
        role: _isStaff ? 'staff_custom' : 'teacher',
        permissions: permissions,
        title: _isStaff ? _title.text.trim() : null,
      );
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

              // ── Personnel : titre + presets + permissions ──────────────
              if (_isStaff && familiesEnabled) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                      labelText: 'Titre (ex. Secrétaire)',
                      prefixIcon: Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Modèle de départ',
                      style: TextStyle(
                          fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final preset in StaffPermissions.presets.keys)
                    ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _applyPreset(preset),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: border),
                    ),
                ]),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Accès accordés',
                      style: TextStyle(
                          fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in StaffPermissions.all)
                    FilterChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(p.icon,
                          size: 15,
                          color: _perms.contains(p.key) ? _terra : muted),
                      selected: _perms.contains(p.key),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _perms.add(p.key);
                        } else {
                          _perms.remove(p.key);
                        }
                      }),
                      selectedColor: _terra.withValues(alpha: .12),
                      checkmarkColor: _terra,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: border),
                    ),
                ]),
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
            color: selected ? _terra.withValues(alpha: .08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? _terra : border, width: selected ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 20, color: selected ? _terra : muted),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: selected ? _terra : ink,
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
                  style: const TextStyle(fontSize: 12.5, color: muted)),
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
