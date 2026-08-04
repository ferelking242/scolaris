import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/locales.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../shared/pages/account_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../platform_providers.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Réglages de la plateforme : compte personnel du super-admin + offres &
/// tarifs (réels) + équipe super-admin (lecture seule — l'ajout/retrait se
/// fait par SQL direct, volontairement : cf. le commentaire sur
/// `platform_admins`, pas de policy insert/update côté client pour éviter
/// l'auto-attribution de ce statut).
class PlatformSettingsPage extends ConsumerWidget {
  const PlatformSettingsPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final locale = await showDialog<Locale>(
      context: context,
      builder: (_) => const _LanguageDialog(),
    );
    if (locale != null && context.mounted) context.setLocale(locale);
  }

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
    final user = ref.watch(authSessionProvider);

    return PageScaffold(
      title: 'Réglages',
      onRefresh: () async {
        ref.invalidate(platformPlanSettingsProvider);
        ref.invalidate(platformAdminsProvider);
        await Future.wait([
          ref.read(platformPlanSettingsProvider.future),
          ref.read(platformAdminsProvider.future),
        ]);
      },
      subtitle: 'Compte, offres, tarifs & équipe de la plateforme',
      actions: const [PlatformSearchLauncher()],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Compte ────────────────────────────────────────────────────────
        if (user != null)
          DataPanel(
            title: 'Compte',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AccountRow(icon: Icons.badge_outlined, label: 'Nom', value: user.fullName),
              Divider(height: 18, color: context.cBorder.withValues(alpha: .6)),
              _AccountRow(icon: Icons.alternate_email_rounded, label: 'Email', value: user.email),
              Divider(height: 18, color: context.cBorder.withValues(alpha: .6)),
              _AccountRow(
                icon: Icons.language_outlined,
                label: 'Langue',
                value: AppLocales.label(context.locale),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionButton(
                  label: 'Gérer le profil',
                  icon: Icons.person_outline_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AccountPage())),
                ),
                ActionButton(
                  label: 'Changer le mot de passe',
                  icon: Icons.lock_outline_rounded,
                  onTap: () => _changePassword(context),
                ),
                ActionButton(
                  label: 'Changer la langue',
                  icon: Icons.translate_rounded,
                  onTap: () => _pickLanguage(context),
                ),
              ]),
            ]),
          ),
        if (user != null) const SizedBox(height: 14),

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

// ── Ligne d'identité (section Compte) ──────────────────────────────────────────
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AccountRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: context.cMuted),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              fontSize: 11.5, color: context.cMuted, fontWeight: FontWeight.w600)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Dialogue : changer le mot de passe ──────────────────────────────────────────
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _newPwd.text.trim()));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('Mot de passe modifié avec succès.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.forestGreen,
      ));
    } on AuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Une erreur est survenue. Réessayez.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Changer le mot de passe',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(
            controller: _newPwd,
            label: 'Nouveau mot de passe',
            hint: 'Au moins 8 caractères',
            validator: (v) => (v == null || v.trim().length < 8)
                ? 'Au moins 8 caractères'
                : null,
          ),
          const SizedBox(height: 12),
          _DialogField(
            controller: _confirmPwd,
            label: 'Confirmer le mot de passe',
            validator: (v) =>
                v?.trim() != _newPwd.text.trim() ? 'Ne correspond pas' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style:
                    const TextStyle(color: ScolarisPalette.terracotta, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ScolarisPalette.forestGreen),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Modifier'),
        ),
      ],
    );
  }
}

// ── Dialogue : changer la langue ────────────────────────────────────────────────
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Langue de l\'interface',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final l in AppLocales.supported)
          ListTile(
            title: Text(AppLocales.label(l)),
            trailing: context.locale == l
                ? const Icon(Icons.check_circle_rounded,
                    color: ScolarisPalette.terracotta)
                : null,
            onTap: () => Navigator.pop(context, l),
          ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
      ],
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
