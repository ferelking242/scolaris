import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../platform_providers.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Réglages de la plateforme : offres & tarifs (réels) + équipe super-admin
/// (lecture seule — l'ajout/retrait se fait par SQL direct, volontairement :
/// cf. le commentaire sur `platform_admins`, pas de policy insert/update côté
/// client pour éviter l'auto-attribution de ce statut).
class PlatformSettingsPage extends ConsumerWidget {
  const PlatformSettingsPage({super.key});

  Future<void> _editPlan(BuildContext context, WidgetRef ref, PlatformPlan p,
      ({int price, int? limit}) current) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await showDialog<(int, int?)>(
      context: context,
      builder: (_) => _EditPlanDialog(
        plan: p,
        price: current.price,
        limit: current.limit,
      ),
    );
    if (res == null) return;
    try {
      await PlatformRepository.setPlanSettings(p, price: res.$1, limit: res.$2);
      ref.invalidate(platformPlanSettingsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Offre ${p.label} mise à jour.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.color,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.terracotta,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planSettingsAsync = ref.watch(platformPlanSettingsProvider);
    final adminsAsync = ref.watch(platformAdminsProvider);

    return PageScaffold(
      title: 'Réglages',
      subtitle: 'Offres, tarifs & équipe de la plateforme',
      actions: const [PlatformSearchLauncher()],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Offres & tarifs ──────────────────────────────────────────────
        DataPanel(
          title: 'Offres & tarifs',
          child: planSettingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
            ),
            data: (settings) => Column(children: [
              for (final p in PlatformPlan.values) ...[
                _PlanRow(
                  plan: p,
                  price: settings[p]?.price ?? p.monthlyPrice,
                  limit: settings[p]?.limit ?? p.studentLimit,
                  onEdit: () => _editPlan(context, ref, p,
                      settings[p] ?? (price: p.monthlyPrice, limit: p.studentLimit)),
                ),
                if (p != PlatformPlan.values.last)
                  Divider(height: 18, color: context.cBorder.withValues(alpha: .6)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── Équipe super-admin ───────────────────────────────────────────
        DataPanel(
          title: 'Équipe super-admin',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ScolarisPalette.gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ScolarisPalette.gold.withValues(alpha: .35)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: ScolarisPalette.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lecture seule — l\'ajout ou le retrait d\'un super-admin se '
                    'fait par SQL direct sur `platform_admins`, pour éviter '
                    'qu\'un admin puisse s\'accorder ce statut ou le retirer à '
                    'quelqu\'un d\'autre depuis l\'app.',
                    style: TextStyle(fontSize: 11.5, color: context.cMuted),
                  ),
                ),
              ]),
            ),
            adminsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
              ),
              data: (admins) => admins.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Aucun super-admin trouvé.',
                          style: TextStyle(color: context.cMuted, fontSize: 12.5)),
                    )
                  : Column(children: [
                      for (var i = 0; i < admins.length; i++) ...[
                        _AdminRow(email: admins[i].email, fullName: admins[i].fullName),
                        if (i < admins.length - 1)
                          Divider(height: 14, color: context.cBorder.withValues(alpha: .5)),
                      ],
                    ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Ligne d'offre ─────────────────────────────────────────────────────────────
class _PlanRow extends StatelessWidget {
  final PlatformPlan plan;
  final int price;
  final int? limit;
  final VoidCallback onEdit;
  const _PlanRow({
    required this.plan,
    required this.price,
    required this.limit,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      PlanBadge(plan: plan),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${groupThousands(price)} FCFA / mois',
              style: TextStyle(
                  fontSize: 13.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(
              limit == null
                  ? 'Élèves illimités'
                  : 'Jusqu\'à ${groupThousands(limit!)} élèves',
              style: TextStyle(fontSize: 11.5, color: context.cMuted)),
        ]),
      ),
      ActionButton(
          label: 'Modifier', icon: Icons.edit_outlined, onTap: onEdit),
    ]);
  }
}

// ── Ligne de super-admin (lecture seule) ──────────────────────────────────────
class _AdminRow extends StatelessWidget {
  final String email;
  final String fullName;
  const _AdminRow({required this.email, required this.fullName});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Avatar(name: fullName, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: context.cInk,
                    fontWeight: FontWeight.w600)),
            Text(email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.cMuted)),
          ]),
        ),
      ]),
    );
  }
}

// ── Dialogue : modifier une offre ─────────────────────────────────────────────
class _EditPlanDialog extends StatefulWidget {
  final PlatformPlan plan;
  final int price;
  final int? limit;
  const _EditPlanDialog({
    required this.plan,
    required this.price,
    required this.limit,
  });
  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _price =
      TextEditingController(text: '${widget.price}');
  late final TextEditingController _limit =
      TextEditingController(text: widget.limit?.toString() ?? '');

  @override
  void dispose() {
    _price.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = int.parse(_price.text.trim());
    final limitText = _limit.text.trim();
    final limit = limitText.isEmpty ? null : int.parse(limitText);
    Navigator.pop(context, (price, limit));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        const Text('Modifier l\'offre ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        PlanBadge(plan: widget.plan),
      ]),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(
            controller: _price,
            label: 'Tarif mensuel (FCFA)',
            hint: 'Ex. 14900',
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 0) return 'Montant invalide';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _DialogField(
            controller: _limit,
            label: 'Limite d\'élèves (vide = illimité)',
            hint: 'Ex. 200',
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              final n = int.tryParse(t);
              if (n == null || n <= 0) return 'Nombre invalide';
              return null;
            },
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ScolarisPalette.forestGreen),
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Champ texte theme-aware réutilisé par les dialogues de réglages.
class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  const _DialogField({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              color: context.cMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: .6)),
      const SizedBox(height: 6),
      SizedBox(
        width: 320,
        child: TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(fontSize: 13, color: context.cInk),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 12.5, color: context.cMuted.withValues(alpha: .6)),
            isDense: true,
            filled: true,
            fillColor: context.cSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.cBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ScolarisPalette.terracotta, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ScolarisPalette.terracotta),
            ),
          ),
        ),
      ),
    ]);
  }
}
