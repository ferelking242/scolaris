import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/countries.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = Color(0xFF8B1A00);
const _green  = Color(0xFF2D6A4F);

/// Types d'établissement (`schools.metadata.types`). Les clés sont celles que
/// [SchoolTaxonomy] traduit en cycles du catalogue des niveaux — ne pas les
/// renommer sans mettre la taxonomie à jour.
// Université, enseignement supérieur et établissement spécialisé restent
// `comingSoon` à l'inscription (school_registration_screen.dart) : pas de
// logique métier dédiée derrière (cf. audit crédits/UE du 10/08/2026). On ne
// les propose donc pas ici non plus. La formation professionnelle (`technique`),
// elle, a été ouverte le 10/08/2026 : même modèle qu'un lycée classique
// (SchoolLevel.fromSchoolType la fait déjà pointer vers `lycee`).
const _kTypes = <String, String>{
  'garderie': 'Garderie / Maternelle',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'technique': 'Formation professionnelle',
};

/// Systèmes éducatifs (`schools.metadata.educational_system`). Combinés au pays,
/// ils déterminent le catalogue de niveaux (cf. [SchoolTaxonomy.systemTypeOf]).
///
/// Anglophone/Arabophone/LMD/Grande école existent déjà en base (niveaux
/// réels dans `class_levels`) et dans [SchoolTaxonomy], mais restent masqués
/// ici : LMD/Grande école ne couvrent que le supérieur (jamais atteignable,
/// cf. Université en "Bientôt" à l'inscription) et Anglophone/Arabophone
/// n'ont pas été validés en conditions réelles. Seul le francophone est
/// proposé pour l'instant — retirer ce filtre quand ce sera prêt.
const _kEduSystems = <String, String>{
  'francophone': 'Francophone',
};

/// Devises proposées. La clé est le code ISO 4217 stocké dans `schools.currency`
/// (SchoolFormat en déduit le symbole). Zone CFA + voisins courants.
const _kCurrencies = <String, String>{
  'XAF': 'FCFA — Afrique centrale (XAF)',
  'XOF': 'FCFA — Afrique de l\'Ouest (XOF)',
  'CDF': 'Franc congolais (CDF)',
  'NGN': 'Naira (NGN)',
  'GHS': 'Cedi (GHS)',
  'MAD': 'Dirham marocain (MAD)',
  'USD': 'Dollar US (USD)',
  'EUR': 'Euro (EUR)',
};

/// Barèmes de notation (`schools.grading_scale` — contrainte : ces trois clés).
const _kGradingScales = <String, String>{
  'numeric_10': 'Sur 10',
  'numeric_20': 'Sur 20',
  'numeric_100': 'Sur 100',
  'letter': 'Lettres (A–F)',
};

/// Découpage de l'année (`schools.period_system` — contrainte : ces trois clés).
const _kPeriodSystems = <String, String>{
  'trimester': 'Trimestres (T1 · T2 · T3)',
  'semester': 'Semestres (S1 · S2)',
  'monthly': 'Mensuel (un bulletin par mois)',
};

class AdminSchoolPage extends ConsumerStatefulWidget {
  const AdminSchoolPage({super.key});
  @override
  ConsumerState<AdminSchoolPage> createState() => _AdminSchoolPageState();
}

class _AdminSchoolPageState extends ConsumerState<AdminSchoolPage> {
  final _name         = TextEditingController();
  final _code         = TextEditingController();
  final _city         = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  // Le PAYS est un code ISO, pas une phrase. Un champ libre a produit « Congo »
  // et « congo » en base, et la contrainte `schools_country_iso` refuse
  // desormais ces valeurs : l'enregistrement echouerait. Cf. countries.dart.
  String? _country;
  String? _academicYear;
  final _logoUrl      = TextEditingController();
  String? _accentColor;

  // Format de l'école : devise, barème, découpage de l'année. Jusqu'ici figés
  // sur leurs valeurs par défaut (XAF / /20 / trimestre), sans aucun écran pour
  // les changer.
  String _currency     = 'XAF';
  String _gradingScale = 'numeric_20';
  String _periodSystem = 'trimester';
  /// Surcharges de barème par cycle (clé = SchoolLevel.name). Vide = tous les
  /// cycles suivent `_gradingScale`. N'a de sens que pour un complexe scolaire.
  Map<String, String> _gradingByCycle = {};
  /// Surcharges de périodicité par cycle — même mécanique, pour le primaire
  /// noté chaque mois quand le secondaire reste au trimestre.
  Map<String, String> _periodSystemByCycle = {};

  bool _loading  = true;
  bool _saving   = false;
  bool _saved    = false;
  String? _error;

  /// Cycles de l'établissement (`schools.metadata.types`) et système éducatif.
  /// Pilotent les niveaux de classe proposés — cf. [SchoolTaxonomy].
  final Set<String> _types = {};
  String _eduSystem = 'francophone';

  /// Cycles (SchoolLevel) réellement offerts, dérivés des types. Doublons
  /// fusionnés (garderie+primaire → primaire), triés du plus petit au plus grand.
  /// Le barème par cycle n'a de sens que s'il y en a plusieurs.
  List<SchoolLevel> get _offeredLevels => _types
      .map(SchoolLevel.fromSchoolType)
      .whereType<SchoolLevel>()
      .toSet()
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final school = await ref.read(schoolProvider.future);
      if (school != null && mounted) {
        setState(() {
          _name.text         = school.name;
          _code.text         = school.code         ?? '';
          _city.text         = school.city         ?? '';
          _contactEmail.text = school.contactEmail ?? '';
          _contactPhone.text = school.contactPhone ?? '';
          _country           = kCountries.containsKey(school.country)
                                 ? school.country
                                 : null;   // valeur héritée non normalisée
          _academicYear      = school.academicYear;
          _logoUrl.text      = school.logoUrl      ?? '';
          _accentColor       = school.accentColor;
          _currency          = school.currency;
          _gradingScale      = school.gradingScale;
          _gradingByCycle    = Map.of(school.gradingByCycle);
          _periodSystem      = school.periodSystem;
          _periodSystemByCycle = Map.of(school.periodSystemByCycle);
          _types
            ..clear()
            ..addAll(school.types);
          _eduSystem = school.educationalSystem ?? 'francophone';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Le nom de l\'école est obligatoire.');
      return;
    }
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() { _saving = true; _error = null; });
    try {
      await SupabaseDbSource.updateSchool(
        id:           schoolId,
        name:         _name.text,
        code:         _code.text,
        city:         _city.text,
        country:      _country ?? '',
        academicYear: _academicYear ?? '',
        accentColor:  _accentColor,
        logoUrl:      _logoUrl.text,
        contactEmail: _contactEmail.text,
        contactPhone: _contactPhone.text,
      );
      await SupabaseDbSource.updateSchoolTaxonomy(
        id:                schoolId,
        types:             _types.toList(),
        educationalSystem: _eduSystem,
      );
      await SupabaseDbSource.updateSchoolFormat(
        id:           schoolId,
        currency:     _currency,
        gradingScale: _gradingScale,
        periodSystem: _periodSystem,
        // On ne garde que les surcharges des cycles réellement offerts, pour
        // ne pas laisser traîner un barème d'un cycle que l'école n'a plus.
        gradingByCycle: {
          for (final l in _offeredLevels)
            if (_gradingByCycle[l.name] != null) l.name: _gradingByCycle[l.name]!,
        },
        periodSystemByCycle: {
          for (final l in _offeredLevels)
            if (_periodSystemByCycle[l.name] != null)
              l.name: _periodSystemByCycle[l.name]!,
        },
      );
      ref.invalidate(schoolProvider);
      // Les niveaux de classe proposés en dépendent directement.
      ref.invalidate(classLevelsProvider);
      ref.invalidate(subjectCatalogProvider);
      if (!mounted) return;
      setState(() => _saved = true);
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Informations mises à jour'),
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
        setState(() => _error = e.toString());
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _city.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  /// Cycles (noms [SchoolLevel]) qui ont encore au moins une classe active —
  /// on ne laisse pas l'admin décocher un type qui viderait un cycle en
  /// service : les classes resteraient en base mais disparaîtraient de tous
  /// les sélecteurs de niveau (création de classe, emploi du temps…).
  Set<String> _cyclesWithActiveClasses(WidgetRef ref) {
    final classes = ref.watch(classesProvider).valueOrNull ?? const [];
    final levels  = ref.watch(classLevelsProvider).valueOrNull ?? const [];
    final cycleOfLevel = {for (final l in levels) l.id: l.cycle};
    return {
      for (final c in classes)
        if (c.isActive && cycleOfLevel[c.levelId] != null) cycleOfLevel[c.levelId]!,
    };
  }

  /// Tente de retirer [typeKey] de `_types`. Bloque (avec message) si ça
  /// viderait un cycle qui a encore des classes actives.
  void _tryRemoveType(String typeKey, Set<String> cyclesInUse) {
    final lvl = SchoolLevel.fromSchoolType(typeKey);
    if (lvl != null) {
      final remaining = _types
          .where((t) => t != typeKey)
          .map(SchoolLevel.fromSchoolType)
          .whereType<SchoolLevel>()
          .toSet();
      if (cyclesInUse.contains(lvl.name) && !remaining.contains(lvl)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: _terra),
            title: const Text('Cycle encore en service'),
            content: Text(
                'Impossible de retirer « ${_kTypes[typeKey]} » : des classes '
                'actives existent encore sur ce cycle. Déplacez ou archivez '
                'd\'abord ces classes dans la page Classes.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Compris')),
            ],
          ),
        );
        return;
      }
    }
    setState(() => _types.remove(typeKey));
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Paramètres école',
      onRefresh: () async {
        ref.invalidate(schoolProvider);
        await _load();
      },
      subtitle: 'Informations générales et apparence',
      actions: [_SaveButton(saving: _saving, saved: _saved, onPressed: _save)],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Identité ────────────────────────────────────────────────
                DataPanel(
                  title: 'Identité',
                  child: Column(children: [
                    _Field(
                      controller: _name,
                      label: 'Nom de l\'école *',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _Field(
                          controller: _code,
                          label: 'Code / Sigle',
                          icon: Icons.tag_rounded,
                          hint: 'ex: EAD-BZV',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Picker<String>(
                          value: _academicYear,
                          label: 'Année scolaire',
                          icon: Icons.calendar_today_outlined,
                          items: {
                            // L'année déjà enregistrée reste proposée même si
                            // elle sort de la fenêtre courante.
                            for (final y in academicYears()) y: y,
                            if (_academicYear != null) _academicYear!: _academicYear!,
                          },
                          onChanged: (v) => setState(() => _academicYear = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _Field(
                          controller: _city,
                          label: 'Ville',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Picker<String>(
                          value: _country,
                          label: 'Pays',
                          icon: Icons.public_outlined,
                          items: kCountries,
                          onChanged: (v) => setState(() => _country = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _Field(
                          controller: _contactEmail,
                          label: 'Email de contact',
                          icon: Icons.mail_outline,
                          hint: 'contact@ecole.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          controller: _contactPhone,
                          label: 'Téléphone',
                          icon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Devise, barème & périodes ───────────────────────────────
                // Figés sur XAF / /20 / trimestre jusqu'ici, sans écran pour en
                // changer : une université ne pouvait pas passer en semestres,
                // une école hors zone CFA ne pouvait pas changer de devise.
                DataPanel(
                  title: 'Devise, barème & périodes',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Utilisés partout : montants (facturation), notes et '
                          'bulletins. À régler selon votre pays et votre système.',
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _Picker<String>(
                            value: _currency,
                            label: 'Devise',
                            icon: Icons.payments_outlined,
                            items: _kCurrencies,
                            onChanged: (v) =>
                                setState(() => _currency = v ?? 'XAF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Picker<String>(
                            value: _gradingScale,
                            label: _offeredLevels.length > 1
                                ? 'Barème par défaut'
                                : 'Barème des notes',
                            icon: Icons.grading_outlined,
                            items: _kGradingScales,
                            onChanged: (v) =>
                                setState(() => _gradingScale = v ?? 'numeric_20'),
                          ),
                        ),
                      ]),
                      // Barème PAR CYCLE — seulement pour un complexe scolaire
                      // (primaire + collège + lycée…). Chaque cycle peut suivre le
                      // défaut ou avoir son propre barème (ex. primaire /10).
                      if (_offeredLevels.length > 1) ...[
                        const SizedBox(height: 14),
                        Text('Barème par cycle',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.cMuted)),
                        const SizedBox(height: 4),
                        Text(
                            'Laissez « Barème par défaut » pour suivre le réglage '
                            'ci-dessus. Ex. primaire /10, secondaire /20.',
                            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                        const SizedBox(height: 10),
                        for (final lvl in _offeredLevels) ...[
                          _Picker<String>(
                            value: _gradingByCycle[lvl.name] ?? '',
                            label: 'Barème — ${lvl.label}',
                            icon: Icons.school_outlined,
                            items: {'': 'Barème par défaut', ..._kGradingScales},
                            onChanged: (v) => setState(() {
                              if (v == null || v.isEmpty) {
                                _gradingByCycle.remove(lvl.name);
                              } else {
                                _gradingByCycle[lvl.name] = v;
                              }
                            }),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                      const SizedBox(height: 12),
                      _Picker<String>(
                        value: _periodSystem,
                        label: _offeredLevels.length > 1
                            ? 'Découpage de l\'année (par défaut)'
                            : 'Découpage de l\'année',
                        icon: Icons.calendar_view_month_outlined,
                        items: _kPeriodSystems,
                        onChanged: (v) =>
                            setState(() => _periodSystem = v ?? 'trimester'),
                      ),
                      // Périodicité PAR CYCLE — même logique que le barème par
                      // cycle : le primaire note chaque mois, le secondaire
                      // chaque trimestre, dans le même complexe scolaire.
                      if (_offeredLevels.length > 1) ...[
                        const SizedBox(height: 14),
                        Text('Découpage par cycle',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.cMuted)),
                        const SizedBox(height: 4),
                        Text(
                            'Laissez « Par défaut » pour suivre le réglage '
                            'ci-dessus. Ex. primaire mensuel, secondaire '
                            'trimestriel.',
                            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                        const SizedBox(height: 10),
                        for (final lvl in _offeredLevels) ...[
                          _Picker<String>(
                            value: _periodSystemByCycle[lvl.name] ?? '',
                            label: 'Découpage — ${lvl.label}',
                            icon: Icons.calendar_view_month_outlined,
                            items: {'': 'Par défaut', ..._kPeriodSystems},
                            onChanged: (v) => setState(() {
                              if (v == null || v.isEmpty) {
                                _periodSystemByCycle.remove(lvl.name);
                              } else {
                                _periodSystemByCycle[lvl.name] = v;
                              }
                            }),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Cycles & système ────────────────────────────────────────
                // Figés à l'inscription jusqu'ici. Or une école qui ouvre une
                // section collège ne va pas recréer son compte — et ces deux
                // réglages pilotent les niveaux de classe proposés.
                DataPanel(
                  title: 'Cycles & système éducatif',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Détermine les niveaux de classe proposés '
                          '(CP1→CM2, 6e→3e, 2nde→Terminale…).',
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      const SizedBox(height: 12),
                      Text('Cycles de l\'établissement',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.cMuted)),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final cyclesInUse = _cyclesWithActiveClasses(ref);
                        return Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final t in _kTypes.entries)
                            FilterChip(
                              label: Text(t.value,
                                  style: const TextStyle(fontSize: 12)),
                              selected: _types.contains(t.key),
                              onSelected: (v) {
                                if (v) {
                                  setState(() => _types.add(t.key));
                                } else {
                                  _tryRemoveType(t.key, cyclesInUse);
                                }
                              },
                              selectedColor:
                                  _terra.withValues(alpha: .12),
                              checkmarkColor: _terra,
                              backgroundColor: context.cCard,
                              side: BorderSide(color: context.cBorder),
                            ),
                        ]);
                      }),
                      const SizedBox(height: 16),
                      Text('Système éducatif',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.cMuted)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final s in _kEduSystems.entries)
                          ChoiceChip(
                            label: Text(s.value,
                                style: const TextStyle(fontSize: 12)),
                            selected: _eduSystem == s.key,
                            onSelected: (_) =>
                                setState(() => _eduSystem = s.key),
                            selectedColor:
                                _terra.withValues(alpha: .12),
                            backgroundColor: context.cCard,
                            side: BorderSide(color: context.cBorder),
                          ),
                      ]),
                      if (_types.isEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                            'Aucun cycle sélectionné : les niveaux proposés '
                            'retomberont sur primaire, collège et lycée.',
                            style: TextStyle(
                                fontSize: 11, color: context.cMuted)),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _terra.withValues(alpha: .3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: _terra),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12.5, color: _terra)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Bouton Enregistrer (bas de page) ────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_saving ||
                            !ref.watch(canProvider('parametres.modifier')))
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _saved
                                ? Icons.check_rounded
                                : Icons.save_outlined,
                            size: 18),
                    label: Text(
                        _saving
                            ? 'Enregistrement…'
                            : _saved
                                ? 'Enregistré !'
                                : 'Enregistrer les modifications'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _saved ? _green : _terra,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final bool saved;
  final VoidCallback onPressed;
  const _SaveButton(
      {required this.saving, required this.saved, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: _terra))
          : Icon(
              saved ? Icons.check_rounded : Icons.save_outlined,
              size: 16,
              color: saved ? _green : _terra),
      label: Text(
        saving ? 'Enreg…' : saved ? 'Enregistré' : 'Enregistrer',
        style: TextStyle(
            color: saved ? _green : _terra,
            fontSize: 13,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Un choix dans une liste fermée — pour les champs dont la base impose le
/// format (le pays est un code ISO) ou dont la valeur libre n'a aucun sens
/// (« l'année scolaire », qu'on tapait à la main, faute de frappe comprise).
class _Picker<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData icon;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _Picker({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

