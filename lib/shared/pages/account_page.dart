import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/staff_permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/sources/remote/supabase_db_source.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

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

  void _openEdit(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(
        user: user,
        onSave: (name, phone) => _saveProfile(user, name, phone),
      ),
    );
  }

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

    final name = user.fullName.isEmpty ? 'Utilisateur' : user.fullName;
    final isStaff      = user.role == UserRole.staff;
    final isPrivileged = isStaff || user.role == UserRole.teacher;
    final showAccess   = isStaff && !user.hasFullAccess && user.permissions.isNotEmpty;

    final schoolLine = [
      if (school?.name != null && school!.name.isNotEmpty) school.name,
      if (school?.city != null && school!.city!.isNotEmpty) school.city,
    ].join(' · ');

    return Scaffold(
      backgroundColor: cs.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Cover(
            name: name,
            roleLabel: user.displayRole,
            initials: _initialsOf(name),
            isPrivileged: isPrivileged,
            onEdit: () => _openEdit(user),
          ),
          const SizedBox(height: 64),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Coordonnées', Icons.contact_mail_outlined, _terra),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.mail_outline_rounded, color: _terra,
                label: 'Email (identifiant de connexion)',
                value: user.email.isEmpty ? '—' : user.email,
              ),
              const SizedBox(height: 6),
              _InfoTile(
                icon: Icons.phone_outlined, color: _orange,
                label: 'Téléphone',
                value: (user.phone == null || user.phone!.isEmpty)
                    ? 'Non renseigné'
                    : user.phone!,
                onEdit: () => _openEdit(user),
              ),
              const SizedBox(height: 18),

              _SectionTitle('Établissement & rôle', Icons.school_outlined, _gold),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.badge_outlined, color: _green,
                label: 'Rôle', value: user.displayRole,
              ),
              if (schoolLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InfoTile(
                  icon: Icons.apartment_rounded, color: Colors.blueGrey,
                  label: 'École', value: schoolLine,
                ),
              ],
              if (user.createdAt != null) ...[
                const SizedBox(height: 6),
                _InfoTile(
                  icon: Icons.calendar_today_outlined, color: const Color(0xFF0D47A1),
                  label: 'Membre depuis',
                  value: '${_months[user.createdAt!.month - 1]} ${user.createdAt!.year}',
                ),
              ],

              if (showAccess) ...[
                const SizedBox(height: 18),
                _SectionTitle('Mes accès', Icons.verified_user_outlined, _terra),
                const SizedBox(height: 8),
                Container(
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
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Cover ─────────────────────────────────────────────────────────────────────
class _Cover extends StatelessWidget {
  final String name, roleLabel, initials;
  final bool isPrivileged;
  final VoidCallback onEdit;
  const _Cover({
    required this.name,
    required this.roleLabel,
    required this.initials,
    required this.isPrivileged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        height: 180,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A00), _terra],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          CustomPaint(painter: _AfricanPatternPainter(), child: const SizedBox.expand()),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text('Modifier', style: TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                ),
              ),
            ),
          ),
        ]),
      ),

      Positioned(
        bottom: -52, left: 20, right: 16,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18, fontWeight: FontWeight.w900),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
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
    ]);
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
      setState(() => _error = 'Le nom est requis.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSave(_name.text.trim(), _phone.text.trim());
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Profil mis à jour'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Échec : $e';
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
          Text('Modifier mon profil', style: TextStyle(
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
            labelText: 'Nom complet',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Téléphone',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pour changer votre email ou mot de passe, utilisez '
          '« Mot de passe & Sécurité » dans les paramètres.',
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
                : const Text('Enregistrer', style: TextStyle(
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
