import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/tuition_account.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);

/// Comptes scolarité de l'école : par élève, payé / dû à ce jour / à jour, et
/// l'encaissement d'un versement. Sous-vue de Facturation.
class TuitionAccountsPage extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  const TuitionAccountsPage({super.key, required this.onBack});
  @override
  ConsumerState<TuitionAccountsPage> createState() =>
      _TuitionAccountsPageState();
}

class _TuitionAccountsPageState extends ConsumerState<TuitionAccountsPage> {
  String _filter = 'all'; // all | uptodate | late
  String _search = '';
  String? _classId; // null = toutes les classes

  String _money(num v, String currency) =>
      '${NumberFormat.decimalPattern('fr').format(v)} $currency';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final accountsAsync = ref.watch(tuitionAccountsProvider);
    final classesAsync = ref.watch(classesProvider);
    // Encaisser écrit dans `payments` : le droit fin dédié est
    // `enregistrer_paiement`, pas `creer_facture` (qui protège la création
    // d'une facture, une action différente).
    final canCollect = ref.watch(canProvider('comptabilite.enregistrer_paiement'));

    return PageScaffold(
      title: 'Comptes scolarité',
      subtitle: 'Suivi des paiements de scolarité par élève',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour à la facturation', onTap: widget.onBack),
        const SizedBox(height: 14),
        if (studentsAsync.isLoading || accountsAsync.isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (accountsAsync.hasError)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : ${accountsAsync.error}',
                style: const TextStyle(color: _terra)),
          )
        else
          _buildBody(
            context,
            students: studentsAsync.valueOrNull ?? const [],
            accounts: accountsAsync.valueOrNull ?? const {},
            classes: classesAsync.valueOrNull ?? const [],
            canCollect: canCollect,
          ),
      ]),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<SbStudent> students,
    required Map<String, SbTuitionAccount> accounts,
    required List<SbClass> classes,
    required bool canCollect,
  }) {
    // Élèves ayant un compte (donc une grille). Ceux sans grille sont comptés à
    // part — on ne peut pas encaisser une scolarité sans grille.
    final withAccount = <({SbStudent s, SbTuitionAccount a})>[];
    for (final s in students) {
      final a = accounts[s.id];
      if (a != null) withAccount.add((s: s, a: a));
    }
    final noGrid = students.length - withAccount.length;

    // Classes ayant au moins un élève avec compte — pas la peine de proposer
    // un filtre pour une classe vide de comptes.
    final classIdsWithAccount = withAccount.map((e) => e.s.classId).toSet();
    final filterableClasses = classes
        .where((c) => classIdsWithAccount.contains(c.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final lateCount = withAccount.where((e) => !e.a.isUpToDate).length;
    final owedTotal =
        withAccount.fold<double>(0, (sum, e) => sum + e.a.owedNow);
    final currency =
        withAccount.isNotEmpty ? withAccount.first.a.currency : 'FCFA';

    // Filtre + recherche.
    final q = _search.trim().toLowerCase();
    final rows = withAccount.where((e) {
      if (_filter == 'late' && e.a.isUpToDate) return false;
      if (_filter == 'uptodate' && !e.a.isUpToDate) return false;
      if (_classId != null && e.s.classId != _classId) return false;
      if (q.isNotEmpty && !e.s.fullName.toLowerCase().contains(q)) return false;
      return true;
    }).toList()
      // En retard d'abord (les plus urgents en haut).
      ..sort((x, y) {
        if (x.a.isUpToDate != y.a.isUpToDate) return x.a.isUpToDate ? 1 : -1;
        return y.a.owedNow.compareTo(x.a.owedNow);
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Synthèse ────────────────────────────────────────────────────────
      Row(children: [
        Expanded(
            child: _StatBox(
                label: 'En retard',
                value: '$lateCount élève(s)',
                color: _terra)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                label: 'Dû aujourd\'hui',
                value: _money(owedTotal, currency),
                color: const Color(0xFFEA580C))),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                label: 'À jour',
                value: '${withAccount.length - lateCount} élève(s)',
                color: _green)),
      ]),
      if (noGrid > 0) ...[
        const SizedBox(height: 8),
        Text(
          '$noGrid élève(s) sans grille de frais — définissez-la dans « Frais de scolarité ».',
          style: TextStyle(fontSize: 11.5, color: context.cMuted),
        ),
      ],
      const SizedBox(height: 14),

      // ── Filtres ─────────────────────────────────────────────────────────
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final f in const [
          ('all', 'Tous'),
          ('late', 'En retard'),
          ('uptodate', 'À jour'),
        ])
          ChoiceChip(
            label: Text(f.$2),
            selected: _filter == f.$1,
            onSelected: (_) => setState(() => _filter = f.$1),
            selectedColor: _terra.withValues(alpha: .12),
            labelStyle: TextStyle(
              fontSize: 12,
              color: _filter == f.$1 ? _terra : context.cMuted,
              fontWeight:
                  _filter == f.$1 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        if (filterableClasses.length > 1) ...[
          Container(width: 1, height: 20, color: context.cBorder),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.cBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _classId,
                isDense: true,
                dropdownColor: context.cCard,
                style: TextStyle(fontSize: 12, color: context.cInk),
                hint: Text('Toutes les classes',
                    style: TextStyle(fontSize: 12, color: context.cMuted)),
                items: [
                  DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes les classes',
                          style: TextStyle(fontSize: 12, color: context.cMuted))),
                  for (final c in filterableClasses)
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),

      DataPanel(
        title: 'Élèves',
        headerActions: [
          SearchInput(
            hint: 'Rechercher un élève…',
            onChanged: (v) => setState(() => _search = v),
          )
        ],
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text(
                        q.isNotEmpty
                            ? 'Aucun résultat pour « ${_search.trim()} ».'
                            : 'Aucun compte à afficher.',
                        style: TextStyle(color: context.cMuted))),
              )
            : LayoutBuilder(builder: (_, constraints) {
                // Sous ~640px, la table à colonnes flex devient illisible
                // (montants tronqués) — on bascule sur des cartes empilées.
                if (constraints.maxWidth < 640) {
                  return Column(children: [
                    for (final e in rows) ...[
                      _StudentAccountCard(
                        student: e.s,
                        account: e.a,
                        money: _money,
                        canCollect: canCollect,
                        onCollect: () => showTuitionPaymentDialog(
                            context, ref, e.s.id, e.s.fullName, e.a),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ]);
                }
                return DataTablePanel(
                  columns: const [
                    'Élève',
                    'Classe',
                    'Payé',
                    'Dû à ce jour',
                    'Statut',
                    ''
                  ],
                  flex: const [3, 2, 2, 2, 3, 2],
                  rows: [
                    for (final e in rows)
                      [
                        Text(e.s.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.cInk,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        Text(
                            e.s.classGroup.isNotEmpty
                                ? e.s.classGroup
                                : '—',
                            style: TextStyle(
                                fontSize: 12, color: context.cMuted)),
                        Text(_money(e.a.paid, e.a.currency),
                            style: TextStyle(
                                fontSize: 12.5,
                                color: context.cInk,
                                fontWeight: FontWeight.w700)),
                        Text(_money(e.a.dueToDate, e.a.currency),
                            style: TextStyle(
                                fontSize: 12, color: context.cMuted)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: e.a.isUpToDate
                              ? StatusPill.success('À jour')
                              : StatusPill.danger(
                                  'Doit ${_money(e.a.owedNow, e.a.currency)}'),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: canCollect
                              ? _MiniBtn(
                                  label: 'Encaisser',
                                  onTap: () => showTuitionPaymentDialog(
                                      context, ref, e.s.id, e.s.fullName, e.a),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                  ],
                );
              }),
      ),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.cMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

/// Carte mobile d'un élève (remplace la ligne de `DataTablePanel` sous 640px) :
/// statut + montant dû en évidence, action « Encaisser » en pleine largeur.
class _StudentAccountCard extends StatelessWidget {
  final SbStudent student;
  final SbTuitionAccount account;
  final String Function(num, String) money;
  final bool canCollect;
  final VoidCallback onCollect;
  const _StudentAccountCard({
    required this.student,
    required this.account,
    required this.money,
    required this.canCollect,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.cInk,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              if (student.classGroup.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(student.classGroup,
                    style: TextStyle(fontSize: 11.5, color: context.cMuted)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          account.isUpToDate
              ? StatusPill.success('À jour')
              : StatusPill.danger('Doit ${money(account.owedNow, account.currency)}'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _MiniStat(
                label: 'Payé', value: money(account.paid, account.currency)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniStat(
                label: 'Dû à ce jour',
                value: money(account.dueToDate, account.currency)),
          ),
        ]),
        if (canCollect) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCollect,
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: BorderSide(color: _green.withValues(alpha: .35)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Encaisser',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: context.cMuted)),
          const SizedBox(height: 2),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _green.withValues(alpha: .35)),
          ),
          child: const Text('Encaisser',
              style: TextStyle(
                  fontSize: 11, color: _green, fontWeight: FontWeight.w700)),
        ),
      );
}
