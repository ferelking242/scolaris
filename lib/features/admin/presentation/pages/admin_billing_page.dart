import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';
import 'tuition_accounts_page.dart';
import 'tuition_fees_page.dart';
import 'tuition_tracking_page.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);

class AdminBillingPage extends ConsumerStatefulWidget {
  const AdminBillingPage({super.key});
  @override
  ConsumerState<AdminBillingPage> createState() => _AdminBillingPageState();
}

class _AdminBillingPageState extends ConsumerState<AdminBillingPage> {
  /// Sous-vue affichée inline : 'overview' | 'fees' | 'tracking'.
  String _view = 'overview';

  void _newInvoice(BuildContext context, WidgetRef ref) {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _InvoiceDialog(
        schoolId: schoolId,
        onSaved: () => ref.invalidate(invoicesProvider),
      ),
    );
  }

  Future<void> _collect(
      BuildContext context, WidgetRef ref, SbInvoice inv) async {
    final messenger = ScaffoldMessenger.of(context);
    // Montant à encaisser : partiel possible, défaut = solde restant.
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _CollectDialog(inv: inv),
    );
    if (amount == null) return;
    try {
      await SupabaseDbSource.recordPayment(
        invoiceId: inv.id,
        studentId: inv.studentId ?? '',
        amount: amount,
      );
      ref.invalidate(invoicesProvider);
      final remaining = inv.balance - amount;
      messenger.showSnackBar(SnackBar(
        content: Text(remaining > 0.01
            ? 'Acompte enregistré. Reste dû : ${NumberFormat.decimalPattern('fr').format(remaining)} ${inv.currency}.'
            : 'Encaissement enregistré. Facture soldée.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
      ));
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SbInvoice inv) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer la facture ?'),
        content: Text(
            'La facture « ${inv.description ?? inv.id.substring(0, 8)} » et ses '
            'encaissements éventuels seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseDbSource.deleteInvoice(inv.id);
      ref.invalidate(invoicesProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Suppression impossible : $e'),
        backgroundColor: _terra,
      ));
    }
  }

  /// La table des factures ponctuelles (encaisser / supprimer). Utilisée par la
  /// sous-vue « Factures ponctuelles ».
  Widget _invoicesPanel(
      BuildContext context, WidgetRef ref, List<SbInvoice> invoices) {
    return DataPanel(
      title: 'Factures ponctuelles',
      child: invoices.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text(
                      'Aucune facture. Cliquez « Nouvelle facture » pour commencer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.cMuted))),
            )
          : DataTablePanel(
              columns: const ['Facture', 'Élève', 'Montant', 'Statut', ''],
              flex: const [2, 3, 2, 2, 2],
              rows: [
                for (final inv in invoices)
                  [
                    Text(inv.invoiceNumber ?? inv.id.substring(0, 8),
                        style: TextStyle(
                            color: context.cInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    Text(inv.studentName ?? '—',
                        style:
                            TextStyle(fontSize: 12.5, color: context.cInk)),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${NumberFormat.decimalPattern("fr").format(inv.amount)} ${inv.currency}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.cInk,
                                  fontWeight: FontWeight.w700)),
                          if (inv.isPartiallyPaid)
                            Text(
                                'reste ${NumberFormat.decimalPattern("fr").format(inv.balance)}',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.w700)),
                        ]),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: _statusPill(inv)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!inv.isPaid)
                        _MiniBtn(
                          label: 'Encaisser',
                          color: _green,
                          onTap: () => _collect(context, ref, inv),
                        ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 16, color: context.cMuted),
                        tooltip: 'Supprimer',
                        onPressed: () => _delete(context, ref, inv),
                      ),
                    ]),
                  ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sous-vues inline (pas de route plein écran).
    if (_view == 'accounts') {
      return TuitionAccountsPage(
          onBack: () => setState(() => _view = 'overview'));
    }
    if (_view == 'fees') {
      return TuitionFeesPage(onBack: () => setState(() => _view = 'overview'));
    }
    if (_view == 'tracking') {
      return TuitionTrackingPage(
          onBack: () => setState(() => _view = 'overview'));
    }

    final invoicesAsync = ref.watch(invoicesProvider);
    return invoicesAsync.when(
      loading: () => const PageScaffold(
        title: 'Aperçu facturation',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Aperçu facturation',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (allInvoices) {
        // La SCOLARITÉ vit dans « Comptes scolarité » (compte + cascade) ; ici on
        // ne traite que les FRAIS PONCTUELS (inscription, cantine…). On exclut donc
        // la ligne-compte annuelle, qui fausserait les totaux et n'a pas d'échéance.
        final invoices =
            allInvoices.where((i) => !i.isTuition).toList();

        // « Encaissé » = argent RÉELLEMENT reçu (cumul des paiements, acomptes
        // compris). « En retard »/« En attente » = SOLDE restant dû, réparti sur
        // isLate (échéance dépassée) vs pas encore échu. Buckets exclusifs.
        final collected =
            invoices.fold(0.0, (a, b) => a + b.amountPaid);
        final overdue =
            invoices.where((i) => i.isLate).fold(0.0, (a, b) => a + b.balance);
        final pending = invoices
            .where((i) => !i.isPaid && !i.isLate && i.status != 'cancelled')
            .fold(0.0, (a, b) => a + b.balance);
        final fmt = NumberFormat.compact(locale: 'fr');

        // Sous-vue « Factures ponctuelles » : la liste sur sa propre page.
        if (_view == 'invoices') {
          return PageScaffold(
            title: 'Factures ponctuelles',
            subtitle: 'Inscription, cantine, transport, fournitures…',
            actions: [
              if (ref.watch(canProvider('comptabilite.creer_facture')))
                ActionButton(
                  label: 'Nouvelle facture',
                  icon: Icons.add_rounded,
                  primary: true,
                  onTap: () => _newInvoice(context, ref),
                ),
            ],
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BackLinkRow(
                  label: 'Retour à l\'aperçu',
                  onTap: () => setState(() => _view = 'overview')),
              const SizedBox(height: 14),
              _invoicesPanel(context, ref, invoices),
            ]),
          );
        }

        return PageScaffold(
          title: 'Aperçu facturation',
          subtitle: 'Scolarité — suivi des paiements de l\'établissement',
          actions: [
            ActionButton(
              label: 'Comptes scolarité',
              icon: Icons.account_balance_wallet_rounded,
              onTap: () => setState(() => _view = 'accounts'),
            ),
            ActionButton(
              label: 'Frais de scolarité',
              icon: Icons.event_repeat_rounded,
              onTap: () => setState(() => _view = 'fees'),
            ),
            ActionButton(
              label: 'Suivi scolarité',
              icon: Icons.grid_on_rounded,
              onTap: () => setState(() => _view = 'tracking'),
            ),
            // Créer une facture exige `comptabilite.creer_facture` : la base
            // refuse sinon.
            if (ref.watch(canProvider('comptabilite.creer_facture')))
              ActionButton(
                label: 'Nouvelle facture',
              icon: Icons.add_rounded,
              primary: true,
              onTap: () => _newInvoice(context, ref),
            ),
          ],
          child: Column(children: [
            DataPanel(
              title: 'Frais ponctuels — vue d\'ensemble',
              child: LayoutBuilder(builder: (ctx, c) {
                final boxes = [
                  _StatBox(
                      label: 'Encaissé',
                      value: fmt.format(collected),
                      color: _green),
                  _StatBox(
                      label: 'En attente',
                      value: fmt.format(pending),
                      color: const Color(0xFFEA580C)),
                  _StatBox(
                      label: 'En retard',
                      value: fmt.format(overdue),
                      color: const Color(0xFFDC2626)),
                  _StatBox(
                      label: 'Factures',
                      value: '${invoices.length}',
                      color: const Color(0xFF6D28D9)),
                ];
                if (c.maxWidth < 560) {
                  return Column(children: [
                    Row(children: [
                      Expanded(child: boxes[0]),
                      const SizedBox(width: 10),
                      Expanded(child: boxes[1]),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: boxes[2]),
                      const SizedBox(width: 10),
                      Expanded(child: boxes[3]),
                    ]),
                  ]);
                }
                return Row(children: [
                  for (var i = 0; i < boxes.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                        child: boxes[i],
                      ),
                    ),
                ]);
              }),
            ),
            const SizedBox(height: 14),
            // La liste est sur sa propre page (scolarité exclue).
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _view = 'invoices'),
              child: DataPanel(
                title: 'Factures ponctuelles',
                child: Row(children: [
                  Icon(Icons.receipt_long_rounded, color: context.cMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        invoices.isEmpty
                            ? 'Aucune facture ponctuelle pour l\'instant.'
                            : '${invoices.length} facture(s) — inscription, cantine, transport…',
                        style: TextStyle(fontSize: 13, color: context.cInk)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.cMuted),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const PlanGateBanner(
              minPlan: 'pro',
              featureLabel: 'Paiement en ligne (Mobile Money)',
              description: 'Permettez aux parents de payer directement depuis l\'app.',
              icon: Icons.phone_android_rounded,
              bullets: [
                'MTN Mobile Money, Airtel Money',
                'Confirmation automatique en temps réel',
                'Reçus envoyés par SMS',
              ],
            ),
          ]),
        );
      },
    );
  }

  static Widget _statusPill(SbInvoice inv) {
    if (inv.isPaid) return StatusPill.success('Payé');
    if (inv.status == 'cancelled') return StatusPill.neutral('Annulée');
    if (inv.isLate) {
      return StatusPill.danger(
          inv.isPartiallyPaid ? 'Retard · partiel' : 'En retard');
    }
    if (inv.isPartiallyPaid) return StatusPill.warning('Partiel');
    return StatusPill.warning('En attente');
  }
}

// ── Dialogue : nouvelle facture ──────────────────────────────────────────────
class _InvoiceDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final VoidCallback onSaved;
  const _InvoiceDialog({required this.schoolId, required this.onSaved});
  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _desc = TextEditingController(text: 'Frais d\'inscription');
  final _amount = TextEditingController();
  SbStudent? _student;
  String _category = 'Inscription';
  DateTime? _dueDate;
  bool _loading = false;
  String? _error;

  // La SCOLARITÉ ne se saisit plus ici : elle passe par le compte de scolarité
  // (Facturation → Comptes scolarité), qui gère le solde qui court et la
  // cascade des versements. Ici, seulement les frais ponctuels.
  static const _categories = [
    'Inscription',
    'Cantine',
    'Transport',
    'Fournitures',
    'Autre',
  ];

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_student == null) {
      setState(() => _error = 'Choisissez un élève.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
    try {
      await SupabaseDbSource.createInvoice(
        schoolId: widget.schoolId,
        studentId: _student!.id,
        description: _desc.text.trim(),
        amount: amount,
        category: _category,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        currency: ref.read(schoolFormatProvider).currency,
      );
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
    final studentsAsync = ref.watch(studentsProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Nouvelle facture',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            studentsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              error: (e, _) => Text('Élèves indisponibles : $e',
                  style: const TextStyle(color: _terra, fontSize: 12)),
              data: (students) => DropdownButtonFormField<SbStudent>(
                value: _student,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Élève',
                    prefixIcon: Icon(Icons.person_outline)),
                items: [
                  for (final s in students)
                    DropdownMenuItem(
                        value: s,
                        child: Text(s.fullName,
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _student = v),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined)),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'Inscription'),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'La scolarité se gère dans « Comptes scolarité », pas ici.',
                style: TextStyle(fontSize: 11.5, color: context.cMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description requise' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      'Montant (${ref.watch(schoolFormatProvider).currencySymbol})',
                  prefixIcon: const Icon(Icons.payments_outlined)),
              validator: (v) {
                final n = double.tryParse(
                    (v ?? '').trim().replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Échéance optionnelle : sans elle, la facture ne peut jamais être
            // « en retard » (isLate se base sur due_date).
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? now.add(const Duration(days: 30)),
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 2),
                  locale: const Locale('fr'),
                );
                if (d != null) setState(() => _dueDate = d);
              },
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Échéance (optionnel)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _dueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dueDate = null),
                        )
                      : null,
                ),
                child: Text(
                  _dueDate == null
                      ? 'Aucune échéance'
                      : DateFormat.yMMMMd('fr').format(_dueDate!),
                  style: TextStyle(
                      fontSize: 13,
                      color: _dueDate == null ? context.cMuted : context.cInk),
                ),
              ),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Créer la facture'),
        ),
      ],
    );
  }
}

// ── Dialogue : encaisser (montant partiel possible) ──────────────────────────
class _CollectDialog extends StatefulWidget {
  final SbInvoice inv;
  const _CollectDialog({required this.inv});
  @override
  State<_CollectDialog> createState() => _CollectDialogState();
}

class _CollectDialogState extends State<_CollectDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.inv.balance.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) {
      setState(() => _error = 'Montant invalide.');
      return;
    }
    if (v > widget.inv.balance + 0.01) {
      setState(() => _error =
          'Dépasse le reste dû (${NumberFormat.decimalPattern('fr').format(widget.inv.balance)} ${widget.inv.currency}).');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final fmt = NumberFormat.decimalPattern('fr');
    final soldeComplet = inv.amountPaid <= 0.01;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Enregistrer un encaissement'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${inv.description ?? 'Facture'}'
            '${inv.studentName != null ? ' · ${inv.studentName}' : ''}',
            style: TextStyle(fontSize: 12.5, color: context.cMuted),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            soldeComplet
                ? 'Montant dû : ${fmt.format(inv.amount)} ${inv.currency}'
                : 'Déjà réglé ${fmt.format(inv.amountPaid)} · reste ${fmt.format(inv.balance)} ${inv.currency}',
            style: TextStyle(
                fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Montant reçu (${inv.currency})',
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
                () => _amount.text = inv.balance.toStringAsFixed(0)),
            icon: const Icon(Icons.done_all_rounded, size: 15),
            label: const Text('Solde complet'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, foregroundColor: _green),
          ),
        ),
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_error!,
                style: const TextStyle(color: _terra, fontSize: 12.5)),
          ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(backgroundColor: _green),
          child: const Text('Encaisser'),
        ),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn(
      {required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
      );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
