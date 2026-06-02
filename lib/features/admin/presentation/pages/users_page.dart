import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _filter = 'All';

  void _openEnrollment() {
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
            onSubmit: (data) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Élève inscrit avec succès'),
                  ]),
                  backgroundColor: _green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
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
        return PageScaffold(
          title: 'Utilisateurs',
          subtitle: '${allUsers.length} comptes tous rôles',
          actions: [
            ActionButton(
                label: 'Inviter', icon: Icons.send_outlined, onTap: () {}),
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
                              _IconBtn(
                                  icon: Icons.edit_outlined, onTap: () {}),
                              const SizedBox(width: 6),
                              _IconBtn(
                                  icon: Icons.more_horiz_rounded, onTap: () {}),
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
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: muted),
        ),
      );
}
