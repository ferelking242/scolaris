import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold  = Color(0xFFC17F24);

const _moisFr = [
  'Janvier','Février','Mars','Avril','Mai','Juin',
  'Juillet','Août','Septembre','Octobre','Novembre','Décembre'
];

/// Écran admin : grille des frais de scolarité (par classe) + génération de
/// l'échéancier annuel de tous les élèves en un clic.
class TuitionFeesPage extends ConsumerWidget {
  const TuitionFeesPage({super.key});

  Future<void> _generate(BuildContext context, WidgetRef ref, String year) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Générer l\'échéancier'),
        content: Text(
            'Créer les échéances de scolarité $year pour tous les élèves des '
            'classes ayant une grille.\n\nLes échéances déjà créées sont '
            'conservées (aucun doublon). Tu peux relancer sans risque.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final created = await SupabaseDbSource.generateTuitionSchedule(
        schoolId: schoolId,
        academicYear: year,
        createdBy: ref.read(authSessionProvider)?.id,
      );
      ref.invalidate(invoicesProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(created == 0
            ? 'Échéancier déjà à jour — aucune nouvelle échéance.'
            : '$created échéance(s) créée(s).'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final feesAsync    = ref.watch(feeStructuresProvider);
    final school       = ref.watch(schoolProvider).valueOrNull;
    final year         = school?.academicYear ?? '—';

    final classes = classesAsync.valueOrNull ?? const <SbClass>[];
    final fees = {
      for (final f in feesAsync.valueOrNull ?? const <SbFeeStructure>[])
        f.classId: f
    };
    final configured = fees.length;

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Frais de scolarité',
            subtitle: classesAsync.isLoading
                ? 'Chargement…'
                : 'Année $year · $configured/${classes.length} classe(s) configurée(s)',
            icon: Icons.payments_rounded,
            actions: [
              HeaderActionButton(
                label: 'Générer l\'échéancier',
                icon: Icons.event_repeat_rounded,
                filled: true,
                onTap: configured == 0
                    ? null
                    : () => _generate(context, ref, year),
              ),
            ],
          ),
          Expanded(
            child: classesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _terra)),
              error: (e, _) => Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : $e',
                          style: const TextStyle(color: muted)))),
              data: (classes) =>
                  _list(context, ref, classes, fees, year, configured),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<SbClass> classes,
    Map<String, SbFeeStructure> fees,
    String year,
    int configured,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        // Aide
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: .25)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: _gold, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Définis le tarif de chaque classe (une fois par an), puis clique '
              '« Générer l\'échéancier » : chaque élève reçoit ses échéances. '
              'Re-générable à tout moment (rattrape les nouveaux élèves).',
              style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        if (classes.isEmpty)
          const EmptyState(
            icon: Icons.class_outlined,
            title: 'Aucune classe',
            description:
                'Crée d\'abord des classes pour définir leurs frais de scolarité.',
          )
        else
          for (final c in classes) ...[
            _ClassFeeCard(
              key: ValueKey(c.id),
              classe: c,
              academicYear: year,
              existing: fees[c.id],
              onSaved: () => ref.invalidate(feeStructuresProvider),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// ── Carte éditable d'une classe ─────────────────────────────────────────────
class _ClassFeeCard extends ConsumerStatefulWidget {
  final SbClass classe;
  final String academicYear;
  final SbFeeStructure? existing;
  final VoidCallback onSaved;
  const _ClassFeeCard({
    super.key,
    required this.classe,
    required this.academicYear,
    required this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_ClassFeeCard> createState() => _ClassFeeCardState();
}

class _ClassFeeCardState extends ConsumerState<_ClassFeeCard> {
  late final TextEditingController _amount;
  late String _rhythm;
  late int _periods;
  late int _startMonth;
  late int _dueDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e != null ? e.amountPerPeriod.toStringAsFixed(0) : '');
    _rhythm = e?.rhythm ?? 'monthly';
    _periods = e?.periodsCount ?? (_rhythm == 'term' ? 3 : 10);
    _startMonth = e?.startMonth ?? 9;
    _dueDay = e?.dueDay ?? 5;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final messenger = ScaffoldMessenger.of(context);
    if (schoolId == null || amount == null || amount <= 0) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Saisis un montant valide.'),
        backgroundColor: _terra, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseDbSource.upsertFeeStructure(
        schoolId: schoolId,
        classId: widget.classe.id,
        academicYear: widget.academicYear,
        rhythm: _rhythm,
        periodsCount: _periods,
        amountPerPeriod: amount,
        startMonth: _startMonth,
        dueDay: _dueDay,
      );
      widget.onSaved();
      messenger.showSnackBar(SnackBar(
        content: Text('Frais de ${widget.classe.name} enregistrés.'),
        backgroundColor: _green, behavior: SnackBarBehavior.floating));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTerm = _rhythm == 'term';
    final configured = widget.existing != null;
    final total = (double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0) * _periods;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: configured ? _green.withValues(alpha: .35) : border),
        boxShadow: const [BoxShadow(
          color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête de carte
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: configured
                ? _green.withValues(alpha: .05)
                : const Color(0xFFFBF7F0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: border.withValues(alpha: .6))),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _terra.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.class_rounded, color: _terra, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.classe.name,
                style: const TextStyle(
                    color: ink, fontSize: 15.5, fontWeight: FontWeight.w800))),
            if (configured)
              StatusPill.success('Configuré')
            else
              StatusPill.neutral('À définir'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              // Rythme
              _Field(label: 'Rythme', child: DropdownButton<String>(
                value: _rhythm, isDense: true, underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Mensualités')),
                  DropdownMenuItem(value: 'term', child: Text('Tranches')),
                ],
                onChanged: (v) => setState(() {
                  _rhythm = v ?? 'monthly';
                  _periods = _rhythm == 'term' ? 3 : 10; // défaut cohérent
                }),
              )),
              // Montant
              _Field(label: 'Montant / ${isTerm ? "tranche" : "mois"}', child: SizedBox(
                width: 110,
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true, border: InputBorder.none, hintText: '75000',
                    suffixText: 'XAF', suffixStyle: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              )),
              // Nb périodes
              _Field(label: isTerm ? 'Nb tranches' : 'Nb mois',
                child: DropdownButton<int>(
                  value: _periods, isDense: true, underline: const SizedBox(),
                  items: [for (int n = 1; n <= 12; n++)
                    DropdownMenuItem(value: n, child: Text('$n'))],
                  onChanged: (v) => setState(() => _periods = v ?? _periods),
                )),
              // Mois de début
              _Field(label: 'Début', child: DropdownButton<int>(
                value: _startMonth, isDense: true, underline: const SizedBox(),
                items: [for (int m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(_moisFr[m - 1]))],
                onChanged: (v) => setState(() => _startMonth = v ?? _startMonth),
              )),
              // Jour d'échéance
              _Field(label: 'Échéance le', child: DropdownButton<int>(
                value: _dueDay, isDense: true, underline: const SizedBox(),
                items: [for (int d = 1; d <= 28; d++)
                  DropdownMenuItem(value: d, child: Text('$d'))],
                onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
              )),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _terra.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.functions_rounded, size: 14, color: _terra),
                    const SizedBox(width: 6),
                    Text('Total année : ${NumberFormat.decimalPattern("fr").format(total)} XAF',
                        style: const TextStyle(
                            color: _terra, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(configured ? 'Mettre à jour' : 'Enregistrer'),
                style: FilledButton.styleFrom(
                  backgroundColor: _terra,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              color: muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1E8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        // Material requis par DropdownButton / TextField (transparent).
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ]);
  }
}
