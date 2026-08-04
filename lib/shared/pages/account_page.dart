import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/locales.dart';
import '../../core/permissions/staff_permissions.dart';
import '../../core/platform/platform_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/sources/remote/supabase_db_source.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';
import '../widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

String _initialsOf(String name) => name
    .trim()
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0])
    .take(2)
    .join()
    .toUpperCase();

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  Future<void> _saveProfile(AppUser user, String name, String phone) async {
    await SupabaseDbSource.updateUser(
      id: user.id,
      fullName: name,
      phone: phone,
    );
    ref.read(authSessionProvider.notifier).setUser(
          user.copyWith(fullName: name, phone: phone),
        );
  }

  bool get _isWide =>
      PlatformUtils.isLargeFormFactor(MediaQuery.sizeOf(context).width);

  /// Bottom sheet sur mobile, dialogue centré sur desktop — même contenu.
  void _openResponsive(Widget content) {
    if (_isWide) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: content,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => content,
    );
  }

  void _openEdit(AppUser user) => _openResponsive(_EditProfileSheet(
        user: user,
        onSave: (name, phone) => _saveProfile(user, name, phone),
      ));

  void _openPasswordSheet() => _openResponsive(const _PasswordSheet());

  void _openLanguageSheet() => _openResponsive(const _LanguageSheet());

  void _openAppearanceSheet() => _openResponsive(const _AppearanceSheet());

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('profile.sign_out'.tr()),
        content: Text('profile.sign_out_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('profile.sign_out'.tr(),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(signOutUseCaseProvider)();
    }
  }

  List<Widget> _coordonneesTiles(AppUser user, bool canEdit) => [
        _InfoTile(
          icon: Icons.mail_outline_rounded, color: _terra,
          label: 'profile.email_label'.tr(),
          value: user.email.isEmpty ? '—' : user.email,
        ),
        const SizedBox(height: 6),
        _InfoTile(
          icon: Icons.phone_outlined, color: _orange,
          label: 'profile.phone'.tr(),
          value: (user.phone == null || user.phone!.isEmpty)
              ? 'profile.not_provided'.tr()
              : user.phone!,
          onEdit: canEdit ? () => _openEdit(user) : null,
        ),
      ];

  List<Widget> _etablissementTiles(AppUser user, String schoolLine, String roleLabel) => [
        _InfoTile(
          icon: Icons.badge_outlined, color: _green,
          label: 'profile.role'.tr(), value: roleLabel,
        ),
        if (schoolLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoTile(
            icon: Icons.apartment_rounded, color: Colors.blueGrey,
            label: 'profile.school'.tr(), value: schoolLine,
          ),
        ],
        if (user.createdAt != null) ...[
          const SizedBox(height: 6),
          _InfoTile(
            icon: Icons.calendar_today_outlined, color: const Color(0xFF0D47A1),
            label: 'profile.member_since'.tr(),
            value: '${'profile.month.${user.createdAt!.month}'.tr()} ${user.createdAt!.year}',
          ),
        ],
      ];

  List<Widget> _parametresTiles(BuildContext context) => [
        _ActionTile(
          icon: Icons.lock_outline_rounded, color: _orange,
          label: 'profile.password_security'.tr(),
          onTap: _openPasswordSheet,
        ),
        const SizedBox(height: 6),
        _ActionTile(
          icon: Icons.language_outlined, color: const Color(0xFF0D47A1),
          label: 'settings.lang.title'.tr(),
          value: AppLocales.label(context.locale),
          onTap: _openLanguageSheet,
        ),
        const SizedBox(height: 6),
        _ActionTile(
          icon: Icons.palette_outlined, color: _green,
          label: 'settings.appearance'.tr(),
          onTap: _openAppearanceSheet,
        ),
      ];

  Widget _signOutButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout_rounded, size: 17, color: Colors.red),
          label: Text('profile.sign_out'.tr(),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _accessWrap(BuildContext context, AppUser user) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(.3)),
        ),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final key in user.permissions)
            if (StaffPermissions.byKey(key) != null)
              _AccessChip(perm: StaffPermissions.byKey(key)!),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final user = ref.watch(authSessionProvider);
    final school = ref.watch(schoolProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final name = user.fullName.isEmpty ? 'profile.default_user'.tr() : user.fullName;
    final isStaff      = user.role == UserRole.staff;
    final isPrivileged = isStaff || user.role == UserRole.teacher;
    final showAccess   = isStaff && !user.hasFullAccess && user.permissions.isNotEmpty &&
        !user.isPlatformAdmin;
    // Élève et parent sont en lecture seule sur leur profil : seuls staff et
    // enseignant peuvent modifier nom/téléphone depuis cette page.
    final canEdit = isPrivileged;

    // Le super-admin (plateforme) n'est rattaché à aucune école — pas de
    // schoolLine, et le libellé de rôle affiché doit le refléter plutôt
    // que d'afficher "Staff" générique.
    final roleLabel = user.isPlatformAdmin
        ? 'profile.super_admin'.tr()
        : user.displayRole;

    final schoolLine = user.isPlatformAdmin ? '' : [
      if (school?.name != null && school!.name.isNotEmpty) school.name,
      if (school?.city != null && school!.city!.isNotEmpty) school.city,
    ].join(' · ');

    return LayoutBuilder(builder: (context, constraints) {
      if (PlatformUtils.isLargeFormFactor(constraints.maxWidth)) {
        return _buildDesktop(context, user, name, isPrivileged, canEdit,
            showAccess, schoolLine, roleLabel);
      }
      return _buildMobile(context, user, name, isPrivileged, canEdit,
          showAccess, schoolLine, roleLabel);
    });
  }

  Widget _buildMobile(BuildContext context, AppUser user, String name,
      bool isPrivileged, bool canEdit, bool showAccess, String schoolLine,
      String roleLabel) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(children: [
          // Barre fixe (retour + modifier) : reste accessible même en
          // scrollant, contrairement aux boutons qui étaient dessinés dans
          // le bandeau dégradé (et disparaissaient avec le scroll).
          _TopBar(canEdit: canEdit, onEdit: () => _openEdit(user)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Cover(
                  name: name,
                  roleLabel: roleLabel,
                  initials: _initialsOf(name),
                  isPrivileged: isPrivileged,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SectionTitle('profile.coordinates'.tr(), Icons.contact_mail_outlined, _terra),
                    const SizedBox(height: 8),
                    ..._coordonneesTiles(user, canEdit),
                    const SizedBox(height: 18),

                    _SectionTitle(
                        user.isPlatformAdmin
                            ? 'profile.account_info'.tr()
                            : 'profile.school_role'.tr(),
                        Icons.school_outlined, _gold),
                    const SizedBox(height: 8),
                    ..._etablissementTiles(user, schoolLine, roleLabel),

                    const SizedBox(height: 18),
                    _SectionTitle('common.settings'.tr(), Icons.tune_rounded, _orange),
                    const SizedBox(height: 8),
                    ..._parametresTiles(context),

                    if (showAccess) ...[
                      const SizedBox(height: 18),
                      _SectionTitle('profile.access'.tr(), Icons.verified_user_outlined, _terra),
                      const SizedBox(height: 8),
                      _accessWrap(context, user),
                    ],
                    const SizedBox(height: 18),
                    _signOutButton(context),
                    const SizedBox(height: 32),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, AppUser user, String name,
      bool isPrivileged, bool canEdit, bool showAccess, String schoolLine,
      String roleLabel) {
    final cs = Theme.of(context).colorScheme;
    final schoolRoleTitle = user.isPlatformAdmin
        ? 'profile.account_info'.tr()
        : 'profile.school_role'.tr();
    return PageScaffold(
      title: 'profile.title'.tr(),
      onRefresh: () async {
        ref.invalidate(schoolProvider);
        await ref.read(schoolProvider.future);
      },
      subtitle: roleLabel,
      child: LayoutBuilder(builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 1100;
        final rightColumn = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DataPanel(
                title: 'profile.coordinates'.tr(),
                child: Column(children: _coordonneesTiles(user, canEdit)),
              ),
            ),
            if (twoCols) ...[
              const SizedBox(width: 16),
              Expanded(
                child: DataPanel(
                  title: schoolRoleTitle,
                  child: Column(children: _etablissementTiles(user, schoolLine, roleLabel)),
                ),
              ),
            ],
          ]),
          if (!twoCols) ...[
            const SizedBox(height: 16),
            DataPanel(
              title: schoolRoleTitle,
              child: Column(children: _etablissementTiles(user, schoolLine, roleLabel)),
            ),
          ],
          const SizedBox(height: 16),
          DataPanel(
            title: 'common.settings'.tr(),
            child: Column(children: _parametresTiles(context)),
          ),
          if (showAccess) ...[
            const SizedBox(height: 16),
            DataPanel(
              title: 'profile.access'.tr(),
              child: _accessWrap(context, user),
            ),
          ],
          const SizedBox(height: 16),
          _signOutButton(context),
        ]);

        final profileCard = DataPanel(
          child: Column(children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, Color.lerp(cs.primary, Colors.white, .25)!],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: cs.primary.withOpacity(.3),
                    blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Center(child: Text(_initialsOf(name), style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(name,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (isPrivileged) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded, color: _gold, size: 16),
              ],
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withOpacity(.25)),
              ),
              child: Text(roleLabel.toUpperCase(), style: TextStyle(
                  color: cs.primary, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
            if (canEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'profile.edit_profile'.tr(),
                  icon: Icons.edit_outlined,
                  onTap: () => _openEdit(user),
                ),
              ),
            ],
          ]),
        );

        if (constraints.maxWidth < 760) {
          // Assez large pour le shell desktop mais étroit (panneau réduit) :
          // empile la carte profil au-dessus des sections plutôt qu'à côté.
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            profileCard,
            const SizedBox(height: 16),
            rightColumn,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 260, child: profileCard),
          const SizedBox(width: 16),
          Expanded(child: rightColumn),
        ]);
      }),
    );
  }
}

// ── Barre fixe (retour + modifier) ───────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onEdit;
  const _TopBar({required this.canEdit, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: cs.surfaceContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 20),
            ),
          ),
        ),
        const Spacer(),
        if (canEdit)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _terra.withOpacity(.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _terra.withOpacity(.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.edit_outlined, color: _terra, size: 14),
                  const SizedBox(width: 5),
                  Text('common.edit'.tr(), style: const TextStyle(
                      color: _terra, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Cover ─────────────────────────────────────────────────────────────────────
// Purement décoratif (bandeau + avatar + nom) : le retour et l'édition vivent
// dans `_TopBar`, fixe au-dessus du scroll. Le nom peut passer sur 2 lignes
// (texte long, accessibilité) : l'espace réservé sous le bandeau suit donc sa
// hauteur réelle au lieu d'une constante qui risquait de le faire chevaucher
// la section "Coordonnées".
class _Cover extends StatelessWidget {
  final String name, roleLabel, initials;
  final bool isPrivileged;
  const _Cover({
    required this.name,
    required this.roleLabel,
    required this.initials,
    required this.isPrivileged,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Padding(
      // Réserve assez d'espace sous le bandeau pour le pire cas (nom sur 2
      // lignes + badge de rôle) : évite le chevauchement avec "Coordonnées".
      padding: const EdgeInsets.only(bottom: 70),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          height: 130,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0A00), _terra],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(painter: _AfricanPatternPainter(), child: const SizedBox.expand()),
        ),

        Positioned(
          top: 78, left: 20, right: 16,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0A00), _terra, _orange],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: scaffoldBg, width: 4),
                boxShadow: [
                  BoxShadow(color: _terra.withOpacity(.35),
                      blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(child: Text(initials, style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 46),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Flexible(child: Text(name,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18, fontWeight: FontWeight.w900),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (isPrivileged) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded, color: _gold, size: 18),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _terra.withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _terra.withOpacity(.25)),
                    ),
                    child: Text(roleLabel.toUpperCase(), style: const TextStyle(
                        color: _terra, fontSize: 9.5,
                        fontWeight: FontWeight.w800, letterSpacing: 1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.text, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ]);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  const _InfoTile({
    required this.icon, required this.color,
    required this.label, required this.value, this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(.3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                color: cs.onSurface.withOpacity(.5), fontSize: 10.5)),
            const SizedBox(height: 1),
            Text(value, style: TextStyle(
                color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
        if (onEdit != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _terra.withOpacity(.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _terra.withOpacity(.2)),
              ),
              child: const Icon(Icons.edit_rounded, size: 14, color: _terra),
            ),
            ),
          ),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon, required this.color,
    required this.label, this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(.3)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(
                color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600))),
            if (value != null) ...[
              Text(value!, style: TextStyle(
                  color: cs.onSurface.withOpacity(.5), fontSize: 12)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withOpacity(.35)),
          ]),
        ),
      ),
    );
  }
}

// ── Mot de passe & Sécurité ──────────────────────────────────────────────────
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPwd = _newPwd.text.trim();
    if (newPwd.length < 8) {
      setState(() => _error = 'profile.password.too_short'.tr());
      return;
    }
    if (newPwd != _confirmPwd.text.trim()) {
      setState(() => _error = 'profile.password.mismatch'.tr());
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPwd));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('profile.password.success'.tr()),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } on AuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'profile.password.error_generic'.tr(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('profile.password.title'.tr(), style: TextStyle(
              color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close_rounded, color: cs.onSurface.withOpacity(.5), size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _newPwd,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'profile.password.new'.tr(),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPwd,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'profile.password.confirm'.tr(),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: _terra, fontSize: 12.5)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _terra, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('profile.password.submit'.tr(), style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Langue ────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('settings.lang.title'.tr(), style: TextStyle(
            color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        for (final l in AppLocales.supported)
          Builder(builder: (context) {
            final selected = context.locale == l;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await context.setLocale(l);
                  if (navigator.mounted) navigator.pop();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _terra.withOpacity(.08) : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? _terra.withOpacity(.4) : cs.outline.withOpacity(.3)),
                  ),
                  child: Row(children: [
                    Text(AppLocales.label(l), style: TextStyle(
                        color: selected ? _terra : cs.onSurface,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded, color: _terra, size: 20),
                  ]),
                ),
              ),
            );
          }),
      ]),
    );
  }
}

// ── Apparence (accent) ───────────────────────────────────────────────────────
class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  static const List<(String, Color, IconData)> _featured = [
    ('Scolaris',  Color(0xFF8B1A00), Icons.school_rounded),
    ('Océan',     Color(0xFF0E5FA3), Icons.waves_rounded),
    ('Forêt',     Color(0xFF1B5E20), Icons.park_rounded),
    ('Nuit',      Color(0xFF1A237E), Icons.nightlight_round),
    ('Améthyste', Color(0xFF6A1B9A), Icons.auto_awesome_rounded),
    ('Ambre',     Color(0xFFC17F24), Icons.wb_sunny_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final accent = ref.watch(themeControllerProvider).accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('settings.appearance'.tr(), style: TextStyle(
            color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (name, color, icon) in _featured)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref.read(themeControllerProvider.notifier).setAccent(color),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: accent.value == color.value
                            ? color
                            : color.withOpacity(.25),
                        width: accent.value == color.value ? 1.8 : 1),
                  ),
                  child: Column(children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 6),
                    Text(name, style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _AccessChip extends StatelessWidget {
  final StaffPermission perm;
  const _AccessChip({required this.perm});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _terra.withOpacity(.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(perm.icon, size: 13, color: _terra),
        const SizedBox(width: 6),
        Text(perm.label, style: const TextStyle(
            color: _terra, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(String name, String phone) onSave;
  const _EditProfileSheet({required this.user, required this.onSave});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user.fullName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.user.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'profile.edit.name_required'.tr());
      return;
    }
    setState(() { _saving = true; _error = null; });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSave(_name.text.trim(), _phone.text.trim());
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('profile.edit.update_success'.tr()),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) setState(() {
        _error = 'profile.edit.update_error'.tr(namedArgs: {'error': '$e'});
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('profile.edit.title'.tr(), style: TextStyle(
              color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close_rounded,
                color: cs.onSurface.withOpacity(.5), size: 20)),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: 'profile.edit.full_name'.tr(),
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'profile.phone'.tr(),
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'profile.edit.password_hint'.tr(),
          style: TextStyle(
              color: cs.onSurface.withOpacity(.5), fontSize: 11),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: _terra, fontSize: 12.5)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _terra, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('common.save'.tr(), style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── African pattern painter ────────────────────────────────────────────────────
class _AfricanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = Colors.white.withOpacity(.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
          Offset(size.width * 0.85, size.height * 0.5), 28.0 + i * 22, p1);
    }
    final p2 = Paint()
      ..color = ScolarisPalette.gold.withOpacity(.07)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(size.width * 0.08 + i * 38, size.height * 0.25), 7, p2);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
