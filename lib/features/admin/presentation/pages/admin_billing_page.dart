import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';
import 'tuition_fees_page.dart';
import 'tuition_tracking_page.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);

class AdminBillingPage extends ConsumerWidget {
  const AdminBillingPage({super.key});

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
    final fmt = NumberFormat.decimalPattern('fr');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enregistrer l\'encaissement'),
        content: Text(
            'Confirmer la réception de ${fmt.format(inv.amount)} ${inv.currency} '
            'pour « ${inv.description ?? 'facture'} »'
            '${inv.studentName != null ? ' (${inv.studentName})' : ''} ?\n\n'
            'Paiement en espèces — la facture passera à « Payé ».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: const Text('Encaisser'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseDbSource.recordPayment(
        invoiceId: inv.id,
        studentId: inv.studentId ?? '',
        amount: inv.amount,
      );
      ref.invalidate(invoicesProvider);
      messenger.showSnackBar(const SnackBar(
        content: Text('Encaissement enregistré.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      data: (invoices) {
        final collected =
            invoices.where((i) => i.isPaid).fold(0.0, (a, b) => a + b.amount);
        final pending =
            invoices.where((i) => i.isPending).fold(0.0, (a, b) => a + b.amount);
        final overdue =
            invoices.where((i) => i.isOverdue).fold(0.0, (a, b) => a + b.amount);
        final fmt = NumberFormat.compact(locale: 'fr');

        return PageScaffold(
          title: 'Aperçu facturation',
          subtitle: 'Scolarité — suivi des paiements de l\'établissement',
          actions: [
            ActionButton(
              label: 'Frais de scolarité',
              icon: Icons.event_repeat_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TuitionFeesPage())),
            ),
            ActionButton(
              label: 'Suivi scolarité',
              icon: Icons.grid_on_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TuitionTrackingPage())),
            ),
            ActionButton(
              label: 'Nouvelle facture',
              icon: Icons.add_rounded,
              primary: true,
              onTap: () => _newInvoice(context, ref),
            ),
          ],
          child: Column(children: [
            DataPanel(
              title: 'Ce mois',
              child: LayoutBuilder(builder: (ctx, c) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
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
                  ],
                );
              }),
            ),
            const SizedBox(height: 14),
            DataPanel(
              title: 'Toutes les factures',
              child: invoices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              'Aucune facture. Cliquez « Nouvelle facture » pour commencer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted))),
                    )
                  : DataTablePanel(
                      columns: const [
                        'Facture',
                        'Élève',
                        'Montant',
                        'Statut',
                        ''
                      ],
                      flex: const [2, 3, 2, 2, 2],
                      rows: [
                        for (final inv in invoices)
                          [
                            Text(inv.invoiceNumber ?? inv.id.substring(0, 8),
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text(inv.studentName ?? '—',
                                style: const TextStyle(
                                    fontSize: 12.5, color: ink)),
                            Text(
                                '${NumberFormat.decimalPattern("fr").format(inv.amount)} ${inv.currency}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: ink,
                                    fontWeight: FontWeight.w700)),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: _statusPill(inv.status)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              if (!inv.isPaid)
                                _MiniBtn(
                                  label: 'Encaisser',
                                  color: _green,
                                  onTap: () => _collect(context, ref, inv),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: muted),
                                tooltip: 'Supprimer',
                                onPressed: () => _delete(context, ref, inv),
                              ),
                            ]),
                          ],
                      ],
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

  static Widget _statusPill(String s) {
    Color c;
    String label;
    switch (s) {
      case 'paid':
        c = _green;
        label = 'Payé';
        break;
      case 'overdue':
        c = const Color(0xFFDC2626);
        label = 'En retard';
        break;
      default:
        c = const Color(0xFFEA580C);
        label = 'En attente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
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
  final _desc = TextEditingController(text: 'Frais de scolarité');
  final _amount = TextEditingController();
  SbStudent? _student;
  String _category = 'Scolarité';
  bool _loading = false;
  String? _error;

  static const _categories = [
    'Scolarité',
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
              onChanged: (v) => setState(() => _category = v ?? 'Scolarité'),
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
              decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.payments_outlined)),
              validator: (v) {
                final n = double.tryParse(
                    (v ?? '').trim().replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                return null;
              },
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
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
