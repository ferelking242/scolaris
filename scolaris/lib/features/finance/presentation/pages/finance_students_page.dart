import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra   = Color(0xFF8B1A00);
const _gold    = Color(0xFFC17F24);
const _green   = Color(0xFF2D6A4F);
const _ink     = Color(0xFF1A0A00);
const _muted   = Color(0xFF7A5C44);

class FinanceStudentsPage extends ConsumerStatefulWidget {
  const FinanceStudentsPage({super.key});

  @override
  ConsumerState<FinanceStudentsPage> createState() =>
      _FinanceStudentsPageState();
}

class _FinanceStudentsPageState extends ConsumerState<FinanceStudentsPage> {
  String _classFilter = 'Toutes';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return studentsAsync.when(
      loading: () => const PageScaffold(
        title: 'Élèves — Finances',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Élèves — Finances',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) {
        final classes = [
          'Toutes',
          ...students.map((s) => s.classe ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort(),
        ];

        final filtered = students.where((s) {
          final matchClass =
              _classFilter == 'Toutes' || s.classe == _classFilter;
          final q = _search.toLowerCase();
          final matchSearch = q.isEmpty ||
              s.fullName.toLowerCase().contains(q) ||
              (s.matricule?.toLowerCase().contains(q) ?? false);
          return matchClass && matchSearch;
        }).toList();

        return PageScaffold(
          title: 'Élèves — Finances',
          subtitle: '${students.length} élèves inscrits',
          actions: [
            ActionButton(
                label: 'Export',
                icon: Icons.file_download_outlined,
                onTap: () {}),
            const SizedBox(width: 8),
            ActionButton(
                label: 'Nouvelle facture',
                icon: Icons.add_rounded,
                primary: true,
                onTap: () {}),
          ],
          child: Column(children: [
            _FilterBar(
              classes: classes,
              selected: _classFilter,
              search: _search,
              onClassChange: (v) => setState(() => _classFilter = v),
              onSearch: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Liste des élèves',
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun résultat.',
                              style: TextStyle(color: _muted))),
                    )
                  : DataTablePanel(
                      columns: const [
                        'Élève',
                        'Matricule',
                        'Classe',
                        'Statut paiement',
                        ''
                      ],
                      flex: const [3, 2, 2, 2, 1],
                      rows: [
                        for (final s in filtered)
                          [
                            Row(children: [
                              Avatar(name: s.fullName, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(s.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            Text(s.matricule ?? '—',
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                            Text(s.classe ?? '—',
                                style: const TextStyle(
                                    fontSize: 12, color: _ink)),
                            _PayBadge(status: 'pending'),
                            InkWell(
                              onTap: () {},
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.chevron_right_rounded,
                                    size: 18, color: _muted),
                              ),
                            ),
                          ],
                      ],
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> classes;
  final String selected;
  final String search;
  final ValueChanged<String> onClassChange;
  final ValueChanged<String> onSearch;
  const _FilterBar({
    required this.classes,
    required this.selected,
    required this.search,
    required this.onClassChange,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SearchInput(hint: 'Rechercher élève…', onChanged: onSearch),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in classes)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c),
                  selected: selected == c,
                  onSelected: (_) => onClassChange(c),
                  selectedColor: _terra.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected == c ? _terra : _muted,
                    fontWeight: selected == c ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}

class _PayBadge extends StatelessWidget {
  final String status;
  const _PayBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'paid':
        c = _green;
        label = 'Payé';
        break;
      case 'overdue':
        c = const Color(0xFFDC2626);
        label = 'En retard';
        break;
      default:
        c = _gold;
        label = 'En attente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}
