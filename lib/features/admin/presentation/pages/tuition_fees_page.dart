import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold  = Color(0xFFC17F24);

const _moisFr = [
  'Janvier','Février','Mars','Avril','Mai','Juin',
  'Juillet','Août','Septembre','Octobre','Novembre','Décembre'
];

/// Écran admin : grille des frais de scolarité (par classe). Le compte de
/// chaque élève (payé / dû / à jour) se déduit directement de cette grille —
/// pas d'échéances à générer. Design system : `PageScaffold` + un `DataPanel`
/// par classe.
class TuitionFeesPage extends ConsumerWidget {
  /// Si fourni, la barre de retour appelle ce callback (mode inline) au lieu de
  /// `Navigator.maybePop` (mode route).
  final VoidCallback? onBack;
  const TuitionFeesPage({super.key, this.onBack});

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

    return PageScaffold(
      title: 'Frais de scolarité',
      subtitle: classesAsync.isLoading
          ? 'Chargement…'
          : 'Année $year · $configured/${classes.length} classe(s) configurée(s)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour à la facturation', onTap: onBack),
        const SizedBox(height: 14),

        // Aide.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: .25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _gold, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Définis le tarif de chaque classe (une fois par an) : le compte de '
              'chaque élève (payé / dû / à jour) est recalculé automatiquement, '
              'sans échéance à générer.',
              style: TextStyle(color: context.cMuted, fontSize: 12, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 14),

        if (classesAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: _terra)),
          )
        else if (classes.isEmpty)
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
              registrationFee: school?.registrationFees[c.id],
              onSaved: () {
                ref.invalidate(feeStructuresProvider);
                ref.invalidate(schoolProvider);
              },
            ),
            const SizedBox(height: 12),
          ],
      ]),
    );
  }
}

// ── Carte éditable d'une classe (DataPanel) ─────────────────────────────────
class _ClassFeeCard extends ConsumerStatefulWidget {
  final SbClass classe;
  final String academicYear;
  final SbFeeStructure? existing;
  final SbRegistrationFee? registrationFee;
  final VoidCallback onSaved;
  const _ClassFeeCard({
    super.key,
    required this.classe,
    required this.academicYear,
    required this.existing,
    required this.registrationFee,
    required this.onSaved,
  });

  @override
  ConsumerState<_ClassFeeCard> createState() => _ClassFeeCardState();
}

class _ClassFeeCardState extends ConsumerState<_ClassFeeCard> {
  late final TextEditingController _amount;
  late final TextEditingController _regNew;
  late final TextEditingController _regReturning;
  late String _rhythm;
  late int _periods;
  late int _startMonth;
  late int _dueDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final r = widget.registrationFee;
    _amount = TextEditingController(
        text: e != null ? e.amountPerPeriod.toStringAsFixed(0) : '');
    _regNew = TextEditingController(
        text: r?.forNew != null ? r!.forNew!.toStringAsFixed(0) : '');
    _regReturning = TextEditingController(
        text: r?.forReturning != null ? r!.forReturning!.toStringAsFixed(0) : '');
    _rhythm = e?.rhythm ?? 'monthly';
    _periods = e?.periodsCount ?? (_rhythm == 'term' ? 3 : 10);
    _startMonth = e?.startMonth ?? 9;
    _dueDay = e?.dueDay ?? 5;
  }

  @override
  void dispose() {
    _amount.dispose();
    _regNew.dispose();
    _regReturning.dispose();
    super.dispose();
  }

  bool get _canEdit => ref.watch(canProvider('comptabilite.plans_facturation'));

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
    final regNew = double.tryParse(_regNew.text.trim().replaceAll(',', '.'));
    final regReturning =
        double.tryParse(_regReturning.text.trim().replaceAll(',', '.'));
    setState(() => _saving = true);
    try {
      await SupabaseDbSource.upsertFeeStructure(
        schoolId: schoolId,
        classId: widget.classe.id,
        academicYear: widget.academicYear,
        rhythm: _rhythm,
        periodsCount: _periods,
        amountPerPeriod: amount,
        currency: ref.read(schoolFormatProvider).currency,
        startMonth: _startMonth,
        dueDay: _dueDay,
      );
      // `null` explicite si le champ est vide = pas de frais d'inscription
      // pour cette classe (efface une éventuelle valeur précédente).
      await SupabaseDbSource.updateRegistrationFee(
        schoolId: schoolId,
        classId: widget.classe.id,
        forNew: (regNew != null && regNew > 0) ? regNew : null,
        forReturning: (regReturning != null && regReturning > 0) ? regReturning : null,
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

    return DataPanel(
      title: widget.classe.name,
      headerActions: [
        if (configured)
          StatusPill.success('Configuré')
        else
          StatusPill.neutral('À définir'),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Field(label: 'Rythme', child: DropdownButton<String>(
            value: _rhythm, isDense: true, underline: const SizedBox(),
            dropdownColor: context.cCard,
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Mensualités')),
              DropdownMenuItem(value: 'term', child: Text('Tranches')),
            ],
            onChanged: (v) => setState(() {
              _rhythm = v ?? 'monthly';
              _periods = _rhythm == 'term' ? 3 : 10;
            }),
          )),
          _Field(label: 'Montant / ${isTerm ? "tranche" : "mois"}', child: SizedBox(
            width: 110,
            child: TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13, color: context.cInk),
              decoration: InputDecoration(
                isDense: true, border: InputBorder.none, hintText: '75000',
                hintStyle: TextStyle(color: context.cMuted),
                suffixText: 'XAF',
                suffixStyle: TextStyle(fontSize: 11, color: context.cMuted),
              ),
            ),
          )),
          _Field(label: isTerm ? 'Nb tranches' : 'Nb mois',
            child: DropdownButton<int>(
              value: _periods, isDense: true, underline: const SizedBox(),
              dropdownColor: context.cCard,
              items: [for (int n = 1; n <= 12; n++)
                DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (v) => setState(() => _periods = v ?? _periods),
            )),
          _Field(label: 'Début', child: DropdownButton<int>(
            value: _startMonth, isDense: true, underline: const SizedBox(),
            dropdownColor: context.cCard,
            items: [for (int m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(_moisFr[m - 1]))],
            onChanged: (v) => setState(() => _startMonth = v ?? _startMonth),
          )),
          _Field(label: 'Échéance le', child: DropdownButton<int>(
            value: _dueDay, isDense: true, underline: const SizedBox(),
            dropdownColor: context.cCard,
            items: [for (int d = 1; d <= 28; d++)
              DropdownMenuItem(value: d, child: Text('$d'))],
            onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
          )),
        ]),
        const SizedBox(height: 10),
        Text('Inscription (laisser vide = pas de frais d\'inscription)',
            style: TextStyle(color: context.cMuted, fontSize: 11)),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Field(label: 'Nouvel élève', child: SizedBox(
            width: 110,
            child: TextField(
              controller: _regNew,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 13, color: context.cInk),
              decoration: InputDecoration(
                isDense: true, border: InputBorder.none, hintText: '—',
                hintStyle: TextStyle(color: context.cMuted),
                suffixText: 'XAF',
                suffixStyle: TextStyle(fontSize: 11, color: context.cMuted),
              ),
            ),
          )),
          _Field(label: 'Réinscription', child: SizedBox(
            width: 110,
            child: TextField(
              controller: _regReturning,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 13, color: context.cInk),
              decoration: InputDecoration(
                isDense: true, border: InputBorder.none, hintText: '—',
                hintStyle: TextStyle(color: context.cMuted),
                suffixText: 'XAF',
                suffixStyle: TextStyle(fontSize: 11, color: context.cMuted),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, constraints) {
          final totalChip = total > 0
              ? Container(
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
                )
              : null;
          final saveBtn = FilledButton.icon(
            onPressed: (_saving || !_canEdit) ? null : _save,
            icon: _saving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(configured ? 'Mettre à jour' : 'Enregistrer'),
            style: FilledButton.styleFrom(
              backgroundColor: _terra,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
          // Sous ~420px, le chip de total + le bouton d'enregistrement ne
          // tiennent plus sur une ligne (le bouton se compressait).
          if (constraints.maxWidth < 420) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (totalChip != null) ...[totalChip, const SizedBox(height: 10)],
              SizedBox(width: double.infinity, child: saveBtn),
            ]);
          }
          return Row(children: [
            if (totalChip != null) totalChip,
            const Spacer(),
            saveBtn,
          ]);
        }),
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
          style: TextStyle(
              color: context.cMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.cBorder),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ]);
  }
}
