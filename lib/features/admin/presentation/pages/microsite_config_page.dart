import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

/// Config du mini-site école — module Inscriptions, palier Croissance+.
/// Contenu uniquement : pas de rendu public branché tant que l'hébergement
/// (nom de domaine, sous-domaine par école) n'est pas décidé. Le bouton
/// « Publier » reste désactivé avec un message explicite plutôt que de
/// promettre une fonctionnalité qui ne fait rien.
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

  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_slug, _tagline, _description, _hours, _phone, _email, _address]) {
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
        _slug.text = site.slug;
        _tagline.text = site.tagline ?? '';
        _description.text = site.description ?? '';
        _hours.text = site.hoursText ?? '';
        _phone.text = site.contactPhone ?? '';
        _email.text = site.contactEmail ?? '';
        _address.text = site.address ?? '';
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
    setState(() => _saving = true);
    try {
      await SupabaseDbSource.saveSchoolMicrosite(
        schoolId: schoolId,
        slug: slug,
        tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        hoursText: _hours.text.trim().isEmpty ? null : _hours.text.trim(),
        contactPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        contactEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      );
      ref.invalidate(schoolMicrositeProvider);
      if (!mounted) return;
      setState(() => _saved = true);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Mini-site école',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return PageScaffold(
      title: 'Mini-site école',
      subtitle: 'Vitrine publique de pré-inscription — contenu, pas encore diffusé',
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
          _NotYetHostedBanner(),
          const SizedBox(height: 16),
          _Section(title: 'Identité', children: [
            _Field(label: 'Identifiant du site (slug)', controller: _slug,
                hint: 'ex. college-saint-joseph', required: true),
            const SizedBox(height: 12),
            _Field(label: 'Accroche', controller: _tagline,
                hint: 'ex. Former les leaders de demain'),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Présentation', children: [
            _Field(label: 'Description', controller: _description, maxLines: 5,
                hint: 'Présentez votre établissement en quelques phrases…'),
            const SizedBox(height: 12),
            _Field(label: 'Horaires', controller: _hours,
                hint: 'ex. Lun–Ven, 7h30–16h30'),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Contact', children: [
            _Field(label: 'Téléphone', controller: _phone),
            const SizedBox(height: 12),
            _Field(label: 'Email', controller: _email),
            const SizedBox(height: 12),
            _Field(label: 'Adresse', controller: _address),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NotYetHostedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(.25)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: _gold.withOpacity(.15),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.rocket_launch_outlined, color: _gold, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('La diffusion publique arrive bientôt',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: context.cInk)),
              const SizedBox(height: 3),
              Text(
                'Préparez dès maintenant le contenu de votre mini-site — la mise '
                'en ligne (adresse publique) sera activée dès que l\'hébergement '
                'sera en place. Rien n\'est perdu, tout est déjà enregistré.',
                style: TextStyle(fontSize: 12, color: context.cMuted),
              ),
            ],
          ),
        ),
      ]),
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
