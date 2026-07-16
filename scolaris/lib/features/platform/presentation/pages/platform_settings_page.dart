import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_settings.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Réglages de la plateforme : offres & tarifs + équipe super-admin.
/// Maquette — les modifications restent en mémoire (cf. [PlatformSettings]).
class PlatformSettingsPage extends StatefulWidget {
  const PlatformSettingsPage({super.key});
  @override
  State<PlatformSettingsPage> createState() => _PlatformSettingsPageState();
}

class _PlatformSettingsPageState extends State<PlatformSettingsPage> {
  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? ScolarisPalette.forestGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _editPlan(PlatformPlan p) async {
    final res = await showDialog<(int, int?)>(
      context: context,
      builder: (_) => _EditPlanDialog(
        plan: p,
        price: PlatformSettings.price[p]!,
        limit: PlatformSettings.limit[p],
      ),
    );
    if (res == null) return;
    setState(() => PlatformSettings.setPlan(p, price: res.$1, limit: res.$2));
    _snack('Offre ${p.label} mise à jour.', color: p.color);
  }

  Future<void> _addAdmin() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _AddAdminDialog(),
    );
    if (email == null) return;
    final ok = PlatformSettings.addAdmin(email);
    if (!ok) {
      _snack('Email invalide ou déjà présent.',
          color: ScolarisPalette.terracotta);
      return;
    }
    setState(() {});
    _snack('Super-admin ajouté.');
  }

  Future<void> _removeAdmin(String email) async {
    if (PlatformSettings.admins.length <= 1) {
      _snack('Impossible de retirer le dernier super-admin.',
          color: ScolarisPalette.terracotta);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Retirer ce super-admin ?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('« $email » perdra l\'accès à la console plateforme.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ScolarisPalette.terracotta),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => PlatformSettings.removeAdmin(email));
    _snack('Super-admin retiré.', color: ScolarisPalette.terracotta);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Réglages',
      subtitle: 'Offres, tarifs & équipe de la plateforme',
      actions: const [PlatformSearchLauncher()],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Rappel maquette.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
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
                'Maquette — les changements restent en mémoire. À terme, ces '
                'réglages piloteront réellement les tarifs et les accès.',
                style: TextStyle(fontSize: 11.5, color: context.cMuted),
              ),
            ),
          ]),
        ),

        // ── Offres & tarifs ──────────────────────────────────────────────
        DataPanel(
          title: 'Offres & tarifs',
          child: Column(children: [
            for (final p in PlatformPlan.values) ...[
              _PlanRow(plan: p, onEdit: () => _editPlan(p)),
              if (p != PlatformPlan.values.last)
                Divider(height: 18, color: context.cBorder.withValues(alpha: .6)),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // ── Équipe super-admin ───────────────────────────────────────────
        DataPanel(
          title: 'Équipe super-admin',
          headerActions: [
            ActionButton(
              label: 'Ajouter',
              icon: Icons.person_add_alt_rounded,
              primary: true,
              onTap: _addAdmin,
            ),
          ],
          child: Column(children: [
            for (var i = 0; i < PlatformSettings.admins.length; i++) ...[
              _AdminRow(
                email: PlatformSettings.admins[i],
                onRemove: () => _removeAdmin(PlatformSettings.admins[i]),
              ),
              if (i < PlatformSettings.admins.length - 1)
                Divider(height: 14, color: context.cBorder.withValues(alpha: .5)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Ligne d'offre ─────────────────────────────────────────────────────────────
class _PlanRow extends StatelessWidget {
  final PlatformPlan plan;
  final VoidCallback onEdit;
  const _PlanRow({required this.plan, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final price = PlatformSettings.price[plan]!;
    final limit = PlatformSettings.limit[plan];
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
                  : 'Jusqu\'à ${groupThousands(limit)} élèves',
              style: TextStyle(fontSize: 11.5, color: context.cMuted)),
        ]),
      ),
      ActionButton(
          label: 'Modifier', icon: Icons.edit_outlined, onTap: onEdit),
    ]);
  }
}

// ── Ligne de super-admin ──────────────────────────────────────────────────────
class _AdminRow extends StatelessWidget {
  final String email;
  final VoidCallback onRemove;
  const _AdminRow({required this.email, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Avatar(name: email, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: ScolarisPalette.terracotta,
          tooltip: 'Retirer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
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

// ── Dialogue : ajouter un super-admin ─────────────────────────────────────────
class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog();
  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _email.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Ajouter un super-admin',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Form(
        key: _formKey,
        child: _DialogField(
          controller: _email,
          label: 'Email',
          hint: 'nom@exemple.com',
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Requis';
            if (!t.contains('@') || !t.contains('.')) return 'Email invalide';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ScolarisPalette.forestGreen),
          onPressed: _save,
          child: const Text('Ajouter'),
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _DialogField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
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
          keyboardType: keyboardType,
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
