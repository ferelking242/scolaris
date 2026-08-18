import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

/// URL provisoire du mini-site publié, tant qu'aucun domaine n'est acheté :
/// sert `site_saas/ecole.html`, hébergé sur le même GitHub Pages que le site
/// vitrine (cf. `PreRegStore.baseUrl`, corrigé le 18/08/2026). À remplacer
/// par un sous-domaine `<slug>.scolaris.app` le jour où le domaine existe —
/// juste ce constant à changer, rien d'autre côté app.
const _micrositeBaseUrl = 'https://boveldy.github.io/scolaris-site/ecole.html';

/// Config du mini-site école — module Inscriptions, palier Croissance+.
/// La publication (Phase 2, 18/08/2026) sert une URL provisoire du type
/// `.../ecole.html?slug=...` — pas encore le sous-domaine par école prévu à
/// terme (Phase 3, réservé à Complet), qui demande un vrai nom de domaine.
class MicrositeConfigPage extends ConsumerStatefulWidget {
  const MicrositeConfigPage({super.key});
  @override
  ConsumerState<MicrositeConfigPage> createState() =>
      _MicrositeConfigPageState();
}

class _MicrositeConfigPageState extends ConsumerState<MicrositeConfigPage> {
  final _slug = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _hours = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _photos = TextEditingController();
  final _customDomain = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  bool _hasSite = false;
  bool _published = false;
  bool _publishing = false;
  String _templateId = 'basique';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_slug, _tagline, _description, _hours, _phone, _email,
        _address, _photos, _customDomain]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final site = await ref.read(schoolMicrositeProvider.future);
      final school = await ref.read(schoolProvider.future);
      if (!mounted) return;
      if (site != null) {
        _hasSite = true;
        _published = site.published;
        _templateId = site.templateId;
        _slug.text = site.slug;
        _tagline.text = site.tagline ?? '';
        _description.text = site.description ?? '';
        _hours.text = site.hoursText ?? '';
        _phone.text = site.contactPhone ?? '';
        _email.text = site.contactEmail ?? '';
        _address.text = site.address ?? '';
        _photos.text = site.photos.join('\n');
        _customDomain.text = site.customDomain ?? '';
      } else if (school != null) {
        // Pré-remplissage depuis les infos déjà connues de l'école — ne pas
        // faire ressaisir ce qui est déjà en base.
        _phone.text = school.contactPhone ?? '';
        _email.text = school.contactEmail ?? '';
      }
    } catch (_) {
      // garde le formulaire vide si la lecture échoue
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (schoolId == null) return;
    final slug = _slug.text.trim();
    if (slug.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('L\'identifiant du site est obligatoire.'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final planCode = ref.read(currentPlanCodeProvider).valueOrNull;
    final isComplet = planMeetsRequirement(planCode, 'max');
    final maxPhotos = isComplet ? 12 : 3;
    final photos = _photos.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxPhotos)
        .toList();
    // Un modèle payant (Complet) reste actif si déjà choisi avant un
    // rétrogradage, mais ne peut plus être sélectionné à nouveau — cf.
    // `_TemplatePicker`. Ici on protège juste l'écriture directe.
    final template = kMicrositeTemplates.firstWhere(
        (t) => t.$1 == _templateId, orElse: () => kMicrositeTemplates.first);
    final templateId =
        planMeetsRequirement(planCode, template.$3) ? _templateId : 'basique';

    setState(() => _saving = true);
    try {
      await SupabaseDbSource.saveSchoolMicrosite(
        schoolId: schoolId,
        slug: slug,
        templateId: templateId,
        tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        hoursText: _hours.text.trim().isEmpty ? null : _hours.text.trim(),
        contactPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        contactEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        photos: photos,
        customDomain: isComplet && _customDomain.text.trim().isNotEmpty
            ? _customDomain.text.trim()
            : null,
      );
      ref.invalidate(schoolMicrositeProvider);
      if (!mounted) return;
      setState(() { _saved = true; _hasSite = true; });
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Contenu du mini-site enregistré'),
        ]),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      Future.delayed(const Duration(seconds: 2),
          () { if (mounted) setState(() => _saved = false); });
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Échec de l\'enregistrement : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePublish(bool value) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (schoolId == null) return;
    setState(() => _publishing = true);
    try {
      await SupabaseDbSource.setSchoolMicrositePublished(schoolId, value);
      ref.invalidate(schoolMicrositeProvider);
      if (!mounted) return;
      setState(() => _published = value);
      messenger.showSnackBar(SnackBar(
        content: Text(value
            ? 'Mini-site publié — visible publiquement.'
            : 'Mini-site dépublié — plus visible en ligne.'),
        backgroundColor: value ? _green : _terra,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Échec : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Mini-site école',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final planCode = ref.watch(currentPlanCodeProvider).valueOrNull;
    final isComplet = planMeetsRequirement(planCode, 'max');
    return PageScaffold(
      title: 'Mini-site école',
      subtitle: _published
          ? 'Vitrine publique — actuellement en ligne'
          : 'Vitrine publique de pré-inscription',
      actions: [
        ActionButton(
          label: _saving ? 'Enregistrement…' : (_saved ? 'Enregistré !' : 'Enregistrer'),
          icon: _saved ? Icons.check_rounded : Icons.save_rounded,
          primary: true,
          onTap: _saving ? () {} : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PublishPanel(
            hasSite: _hasSite,
            published: _published,
            publishing: _publishing,
            slug: _slug.text.trim(),
            onToggle: _hasSite ? _togglePublish : null,
          ),
          const SizedBox(height: 16),
          _Section(title: 'Identité', children: [
            _Field(label: 'Identifiant du site (slug)', controller: _slug,
                hint: 'ex. college-saint-joseph', required: true),
            const SizedBox(height: 12),
            _Field(label: 'Accroche', controller: _tagline,
                hint: 'ex. Former les leaders de demain'),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Modèle de site', children: [
            _TemplatePicker(
              current: _templateId,
              isComplet: isComplet,
              onChanged: (id) => setState(() => _templateId = id),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Présentation', children: [
            _Field(label: 'Description', controller: _description, maxLines: 5,
                hint: 'Présentez votre établissement en quelques phrases…'),
            const SizedBox(height: 12),
            _Field(label: 'Horaires', controller: _hours,
                hint: 'ex. Lun–Ven, 7h30–16h30'),
            const SizedBox(height: 12),
            _Field(
              label: isComplet
                  ? 'Photos (une URL par ligne, jusqu\'à 12)'
                  : 'Photos (une URL par ligne, jusqu\'à 3 — Complet débloque jusqu\'à 12)',
              controller: _photos,
              maxLines: 4,
              hint: 'https://…',
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Contact', children: [
            _Field(label: 'Téléphone', controller: _phone),
            const SizedBox(height: 12),
            _Field(label: 'Email', controller: _email),
            const SizedBox(height: 12),
            _Field(label: 'Adresse', controller: _address),
          ]),
          const SizedBox(height: 16),
          isComplet
              ? _Section(title: 'Domaine personnalisé', children: [
                  _Field(label: 'Votre domaine', controller: _customDomain,
                      hint: 'ex. www.mon-ecole.cg'),
                  const SizedBox(height: 8),
                  Text(
                    'Une fois enregistré, contactez le support Scolaris pour '
                    'brancher le domaine (pas encore automatisé).',
                    style: TextStyle(fontSize: 11.5, color: context.cMuted),
                  ),
                ])
              : PlanGateBanner(
                  minPlan: 'max',
                  featureLabel: 'Domaine personnalisé',
                  description:
                      'Utilisez votre propre nom de domaine pour le mini-site '
                      'de votre école.',
                ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PublishPanel extends StatelessWidget {
  final bool hasSite;
  final bool published;
  final bool publishing;
  final String slug;
  final ValueChanged<bool>? onToggle;

  const _PublishPanel({
    required this.hasSite,
    required this.published,
    required this.publishing,
    required this.slug,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final link = '$_micrositeBaseUrl?slug=$slug';
    final color = published ? _green : _gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(.15),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(
                published ? Icons.public_rounded : Icons.rocket_launch_outlined,
                color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(published ? 'Mini-site en ligne' : 'Mini-site non publié',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: context.cInk)),
                const SizedBox(height: 3),
                Text(
                  hasSite
                      ? (published
                          ? 'Visible publiquement. Adresse provisoire : le vrai '
                              'sous-domaine par école arrivera avec l\'achat d\'un '
                              'nom de domaine.'
                          : 'Le contenu est enregistré mais pas encore visible. '
                              'Publiez quand vous êtes prêt.')
                      : 'Enregistrez d\'abord le contenu ci-dessous avant de '
                          'pouvoir publier.',
                  style: TextStyle(fontSize: 12, color: context.cMuted),
                ),
              ],
            ),
          ),
          if (hasSite)
            Switch(
              value: published,
              onChanged: publishing ? null : onToggle,
              activeThumbColor: _green,
            ),
        ]),
        if (published) ...[
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Lien copié.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: _green,
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.cCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.cBorder),
              ),
              child: Row(children: [
                Icon(Icons.link_rounded, size: 14, color: context.cMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(link,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.cMuted)),
                ),
                Icon(Icons.copy_rounded, size: 14, color: context.cMuted),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  final String current;
  final bool isComplet;
  final ValueChanged<String> onChanged;

  const _TemplatePicker({
    required this.current,
    required this.isComplet,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kMicrositeTemplates.map((t) {
        final (id, label, minPlan) = t;
        final locked = minPlan == 'max' && !isComplet;
        final selected = current == id;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: locked ? null : () => onChanged(id),
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _terra.withOpacity(.08) : context.cSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? _terra : context.cBorder,
                  width: selected ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : (selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded),
                    size: 16,
                    color: locked
                        ? context.cMuted
                        : (selected ? _terra : context.cMuted)),
              ]),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: locked ? context.cMuted : context.cInk)),
              if (locked) ...[
                const SizedBox(height: 2),
                Text('Offre Complet',
                    style: TextStyle(fontSize: 10.5, color: context.cMuted)),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: context.cInk)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final bool required;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(required ? '$label *' : label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: context.cMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.cSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.cBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.cBorder),
            ),
          ),
        ),
      ],
    );
  }
}
