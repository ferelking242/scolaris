import 'package:flutter/material.dart';

import '../../../../shared/data/mock_data.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = Color(0xFF8B1A00);
const _green  = Color(0xFF2D6A4F);

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
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
              // TODO: save to Supabase
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: const [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
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
    final users = MockData.users
        .where((u) => _filter == 'All' || u.role == _filter.toLowerCase())
        .toList();
    return PageScaffold(
      title: 'Utilisateurs',
      subtitle: '${MockData.users.length} comptes tous rôles',
      actions: [
        ActionButton(label: 'Inviter', icon: Icons.send_outlined, onTap: () {}),
        const SizedBox(width: 8),
        ActionButton(
            label: 'Inscrire un élève',
            icon: Icons.person_add_alt_1_rounded,
            primary: true,
            onTap: _openEnrollment),
      ],
      child: Column(
        children: [
          _FilterRow(
            current: _filter,
            options: const ['All', 'Admin', 'Teacher', 'Finance', 'Surveillance', 'Parent', 'Student'],
            onChange: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
          DataPanel(
            title: 'Comptes',
            headerActions: const [SearchInput(hint: 'Rechercher un utilisateur…')],
            child: DataTablePanel(
              columns: const ['Nom', 'Email', 'Rôle', 'Statut', 'Dernière connexion', ''],
              flex: const [3, 3, 2, 2, 2, 2],
              rows: [
                for (final u in users)
                  [
                    Row(children: [
                      Avatar(name: u.name, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(u.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    Text(u.email,
                        style: const TextStyle(fontSize: 12, color: muted)),
                    Align(alignment: Alignment.centerLeft, child: StatusPill.neutral(u.role)),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: u.active
                            ? StatusPill.success('Actif')
                            : StatusPill.danger('Inactif')),
                    Text(u.lastSeen,
                        style: const TextStyle(fontSize: 12, color: muted)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionButton(label: 'Gérer', onTap: () {}),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String current;
  final List<String> options;
  final ValueChanged<String> onChange;
  const _FilterRow({
    required this.current,
    required this.options,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final o in options) ...[
              GestureDetector(
                onTap: () => onChange(o),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == current ? ink : cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: o == current ? ink : border),
                  ),
                  child: Text(o,
                      style: TextStyle(
                          fontSize: 12,
                          color: o == current ? Colors.white : ink,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}
