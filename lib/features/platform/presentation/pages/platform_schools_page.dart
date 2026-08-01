import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/countries.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../../data/platform_school_aggregates.dart';
import '../platform_providers.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';
import 'platform_school_detail.dart';

/// Onglet « Écoles » de la console. Master-détail **inline** : la liste et la
/// fiche s'affichent dans la même zone de contenu (la sidebar reste visible).
class PlatformSchoolsPage extends ConsumerStatefulWidget {
  const PlatformSchoolsPage({super.key});
  @override
  ConsumerState<PlatformSchoolsPage> createState() => _PlatformSchoolsPageState();
}

class _PlatformSchoolsPageState extends ConsumerState<PlatformSchoolsPage> {
  String _query = '';
  String _filter = 'Toutes';
  bool _creating = false;

  static const _filters = ['Toutes', 'À valider', 'Payantes', 'Essai', 'À surveiller'];

  List<PlatformSchool> _filtered(List<PlatformSchool> all) {
    Iterable<PlatformSchool> list = all;
    switch (_filter) {
      case 'À valider':
        list = list.where((s) => !s.isActive);
        break;
      case 'Payantes':
        list = list.where((s) => s.isPaying);
        break;
      case 'Essai':
        list = list.where((s) => s.status == SubStatus.trial);
        break;
      case 'À surveiller':
        final ids = all.needsAttention.map((s) => s.id).toSet();
        list = list.where((s) => ids.contains(s.id));
        break;
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) || s.city.toLowerCase().contains(q));
    }
    return list.toList()..sort((a, b) => b.studentCount.compareTo(a.studentCount));
  }

  Future<void> _openCreated(String schoolId) async {
    ref.invalidate(platformSchoolsProvider);
    final all = await ref.read(platformSchoolsProvider.future);
    final school = all.where((s) => s.id == schoolId).firstOrNull;
    setState(() => _creating = false);
    if (!mounted) return;
    if (school != null) {
      ref.read(selectedPlatformSchoolProvider.notifier).state = school;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(school != null
          ? 'École « ${school.name} » créée (essai 30 j).'
          : 'École créée (essai 30 j).'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ScolarisPalette.forestGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedPlatformSchoolProvider);
    if (selected != null) {
      return PlatformSchoolDetailView(
        school: selected,
        onBack: () =>
            ref.read(selectedPlatformSchoolProvider.notifier).state = null,
      );
    }

    if (_creating) {
      return PageScaffold(
        title: 'Nouvelle école',
        subtitle: 'Créer un établissement sur la plateforme',
        child: _CreateSchoolForm(
          onCancel: () => setState(() => _creating = false),
          onCreated: _openCreated,
        ),
      );
    }

    final schoolsAsync = ref.watch(platformSchoolsProvider);
    return PageScaffold(
      title: 'Écoles',
      subtitle: schoolsAsync.when(
        data: (all) => '${all.length} établissements sur la plateforme',
        loading: () => 'Chargement…',
        error: (e, _) => 'Erreur de chargement',
      ),
      actions: const [PlatformSearchLauncher()],
      child: schoolsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (all) => _body(context, all),
      ),
    );
  }

  Widget _body(BuildContext context, List<PlatformSchool> all) {
    final schools = _filtered(all);
    return Column(children: [
        // Bouton de création (aligné à droite).
        Align(
          alignment: Alignment.centerRight,
          child: ActionButton(
            label: 'Nouvelle école',
            icon: Icons.add_rounded,
            primary: true,
            onTap: () => setState(() => _creating = true),
          ),
        ),
        const SizedBox(height: 12),
        // Filtres
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: ScolarisPalette.terracotta.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _filter == f ? ScolarisPalette.terracotta : context.cMuted,
                    fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        DataPanel(
          title: 'Établissements',
          headerActions: [
            SearchInput(
              hint: 'Rechercher une école…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ],
          child: schools.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Aucune école',
                  description: 'Aucun établissement ne correspond à ce filtre.')
              : DataTablePanel(
                  columns: const [
                    'École', 'Ville', 'Offre', 'Statut', 'Élèves', ''
                  ],
                  flex: const [3, 2, 2, 2, 3, 2],
                  rows: [
                    for (final s in schools)
                      [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(s),
                            child: Row(children: [
                              Avatar(name: s.name, size: 26),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(s.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.cInk,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (!s.isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ScolarisPalette.terracotta
                                        .withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text('À valider',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: ScolarisPalette.terracotta)),
                                ),
                              ],
                            ]),
                          ),
                        ),
                        Text('${s.city}\n${s.country}',
                            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: PlanBadge(plan: s.plan)),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: SubStatusBadge(status: s.status)),
                        _StudentUsage(school: s),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!s.isActive)
                            ActionButton(
                              label: 'Valider',
                              icon: Icons.check_rounded,
                              primary: true,
                              onTap: () => _validate(s),
                            ),
                          IconButton(
                            onPressed: () => _open(s),
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            color: context.cMuted.withValues(alpha: .5),
                            tooltip: 'Voir la fiche',
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints.tightFor(width: 32, height: 32),
                          ),
                        ]),
                      ],
                  ],
                ),
        ),
      ]);
  }

  void _open(PlatformSchool s) =>
      ref.read(selectedPlatformSchoolProvider.notifier).state = s;

  /// Active une école auto-inscrite en attente de validation (cf.
  /// `SchoolRegistrationScreen` / `SupabaseAuthSource._fetchProfile`) —
  /// son responsable peut se connecter juste après.
  Future<void> _validate(PlatformSchool s) async {
    try {
      await PlatformRepository.setSchoolActive(s.id, true);
      ref.invalidate(platformSchoolsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('« ${s.name} » validée — le responsable peut se connecter.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.forestGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la validation : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.terracotta,
      ));
    }
  }
}

/// Formulaire de création d'école — affiché **inline** (pas de route à part).
/// Crée une VRAIE école via l'Edge Function `platform-create-school`
/// (service_role — `onCreated` reçoit l'id, la fiche est ouverte après
/// rafraîchissement de la liste par l'appelant).
class _CreateSchoolForm extends StatefulWidget {
  final VoidCallback onCancel;
  final Future<void> Function(String schoolId) onCreated;
  const _CreateSchoolForm({required this.onCancel, required this.onCreated});
  @override
  State<_CreateSchoolForm> createState() => _CreateSchoolFormState();
}

class _CreateSchoolFormState extends State<_CreateSchoolForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Congo');
  final _director = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  final Set<String> _types = {'primaire'};
  PlatformPlan _plan = PlatformPlan.simple;
  bool _submitting = false;
  String? _error;

  static const _typeOptions = {
    'primaire': 'Primaire',
    'college': 'Collège',
    'lycee': 'Lycée',
    'univ': 'Université',
  };

  @override
  void dispose() {
    for (final c in [_name, _city, _country, _director, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Choisis au moins un niveau.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final countryCode = countryCodeOf(_country.text);
    if (countryCode == null) {
      setState(() => _error = 'Pays inconnu : "${_country.text}". '
          'Utilise un nom reconnu (Congo, Cameroun, France...) ou un code ISO (CG, CM, FR...).');
      return;
    }
    try {
      final schoolId = await PlatformRepository.createSchool(
        name: _name.text,
        city: _city.text,
        country: countryCode,
        types: _types.toList(),
        plan: _plan,
        directorName: _director.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
      );
      await widget.onCreated(schoolId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Retour à la liste (reste dans la console).
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: widget.onCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_rounded, size: 15, color: context.cMuted),
                const SizedBox(width: 6),
                Text('Toutes les écoles',
                    style: TextStyle(
                        fontSize: 12,
                        color: context.cMuted,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Form(
        key: _formKey,
        child: Column(children: [
          DataPanel(
            title: 'Établissement',
            child: Column(children: [
              _Field(
                controller: _name,
                label: 'Nom de l\'école',
                hint: 'Ex. Collège Les Rapides',
                required: true,
              ),
              _twoCols(
                _Field(
                    controller: _city, label: 'Ville', hint: 'Brazzaville',
                    required: true),
                _Field(controller: _country, label: 'Pays', hint: 'Congo'),
              ),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Niveaux'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _typeOptions.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _types.contains(e.key),
                      onSelected: (v) => setState(() =>
                          v ? _types.add(e.key) : _types.remove(e.key)),
                      selectedColor:
                          ScolarisPalette.terracotta.withValues(alpha: .12),
                      checkmarkColor: ScolarisPalette.terracotta,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _types.contains(e.key)
                            ? ScolarisPalette.terracotta
                            : context.cMuted,
                        fontWeight: _types.contains(e.key)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 14),
          DataPanel(
            title: 'Offre de départ',
            child: Column(children: [
              for (final p in PlatformPlan.values) ...[
                _PlanChoice(
                  plan: p,
                  selected: _plan == p,
                  onTap: () => setState(() => _plan = p),
                ),
                if (p != PlatformPlan.values.last) const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: context.cMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'L\'école démarre avec 30 jours d\'essai gratuit.',
                    style: TextStyle(fontSize: 11.5, color: context.cMuted),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          DataPanel(
            title: 'Responsable',
            child: Column(children: [
              _Field(
                  controller: _director,
                  label: 'Nom du responsable',
                  hint: 'Ex. Andrée Koumba',
                  required: true),
              _twoCols(
                _Field(
                  controller: _email,
                  label: 'Email',
                  hint: 'direction@ecole.cg',
                  required: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                _Field(
                    controller: _phone,
                    label: 'Téléphone',
                    hint: '+242 06 000 00 00',
                    keyboardType: TextInputType.phone),
              ),
              _Field(
                controller: _password,
                label: 'Mot de passe (compte du responsable)',
                hint: 'Min. 6 caractères',
                required: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'Min. 6 caractères'
                    : null,
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ScolarisPalette.terracotta.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ScolarisPalette.terracotta.withValues(alpha: .25)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: ScolarisPalette.terracotta, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: ScolarisPalette.terracotta, fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            ActionButton(
                label: 'Annuler',
                onTap: _submitting ? () {} : widget.onCancel),
            const SizedBox(width: 10),
            ActionButton(
              label: _submitting ? 'Création…' : 'Créer l\'école',
              icon: Icons.check_rounded,
              primary: true,
              onTap: _submitting ? () {} : _submit,
            ),
          ]),
        ]),
      ),
    ]);
  }

  /// Deux champs côte à côte (empilés si l'écran est étroit).
  Widget _twoCols(Widget a, Widget b) {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth < 460) {
        return Column(children: [a, b]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ]);
    });
  }
}

/// Libellé de champ (petite majuscule).
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              color: context.cMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: .6)),
    );
  }
}

/// Champ texte theme-aware avec libellé.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.keyboardType,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
                  : null),
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
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ScolarisPalette.terracotta, width: 1.6),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Choix d'offre (ligne sélectionnable) dans le formulaire de création.
class _PlanChoice extends StatelessWidget {
  final PlatformPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanChoice({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? plan.color.withValues(alpha: .08) : context.cCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? plan.color : context.cBorder,
              width: selected ? 2 : 1),
        ),
        child: Row(children: [
          PlanBadge(plan: plan),
          const SizedBox(width: 12),
          Text('${groupThousands(plan.monthlyPrice)} F/mois',
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 18, color: plan.color)
          else
            Text(
                plan.studentLimit == null
                    ? 'illimité'
                    : '≤ ${groupThousands(plan.studentLimit!)}',
                style: TextStyle(fontSize: 11, color: context.cMuted)),
        ]),
      ),
    );
  }
}

/// Effectif + jauge d'usage vs limite d'offre.
class _StudentUsage extends StatelessWidget {
  final PlatformSchool school;
  const _StudentUsage({required this.school});
  @override
  Widget build(BuildContext context) {
    final lim = school.studentLimit;
    final near = school.usageRatio >= 0.9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lim == null
              ? '${groupThousands(school.studentCount)} · illimité'
              : '${groupThousands(school.studentCount)} / ${groupThousands(lim)}',
          style: TextStyle(
              fontSize: 12,
              color: near ? ScolarisPalette.terracotta : context.cInk,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: lim == null ? 1 : school.usageRatio,
            minHeight: 4,
            backgroundColor: context.cSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(
                lim == null ? ScolarisAccents.violet
                    : near ? ScolarisPalette.terracotta : ScolarisPalette.forestGreen),
          ),
        ),
      ],
    );
  }
}
