import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../core/config/school_format.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart' show SchoolLevel;
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/bulletin_view.dart';
import 'bulletin_pdf.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold  = Color(0xFFC17F24);

/// Écran admin : génération + publication des bulletins officiels d'une classe
/// pour un trimestre. L'admin GÉNÈRE (brouillon, calcul figé) puis PUBLIE aux
/// familles. Tant que ce n'est pas publié, l'élève/parent ne voit rien.
class ReportCardsPage extends ConsumerStatefulWidget {
  /// `true` quand la page est rendue comme ONGLET dans « Notes & Bulletins » :
  /// on retire alors son propre en-tête (le parent en fournit un) pour ne pas
  /// empiler deux bandeaux.
  final bool embedded;
  const ReportCardsPage({super.key, this.embedded = false});
  @override
  ConsumerState<ReportCardsPage> createState() => _ReportCardsPageState();
}

class _ReportCardsPageState extends ConsumerState<ReportCardsPage> {
  String? _classId;
  // Trimestres ou semestres : c'est l'école qui décide (cf. SchoolFormat), et
  // c'est la MÊME liste que celle où les profs saisissent les notes.
  String? _selectedPeriod;
  bool _busy = false;

  /// Cycle de la classe sélectionnée (primaire/collège/lycée…) — la
  /// périodicité (mensuelle au primaire, trimestrielle ailleurs) en dépend.
  SchoolLevel? get _cycle {
    final classes = ref.read(classesProvider).valueOrNull ?? const <SbClass>[];
    final level = classes.where((c) => c.id == _classId).map((c) => c.level).firstOrNull;
    return SchoolLevel.fromClassName(level);
  }

  SchoolFormat get _fmt => ref.read(schoolFormatForLevelProvider(_cycle));
  String get _period => _selectedPeriod ?? _fmt.periods.first;
  String get _year => ref.read(schoolProvider).valueOrNull?.academicYear ?? '';
  String get _key => '${_classId ?? ''}|$_year|$_period';

  String get _periodKey => '${_classId ?? ''}|$_period';

  void _refresh() {
    ref.invalidate(reportCardsForClassProvider(_key));
    ref.invalidate(gradePeriodProvider(_periodKey));
    ref.invalidate(gradesForClassProvider(_classId ?? ''));
    ref.invalidate(classBulletinsProvider(_periodKey));
    ref.invalidate(periodAuditProvider(_periodKey));
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Écrit (ou réécrit) le snapshot officiel. Réutilisé par la validation et par
  /// « Recalculer ». Renvoie le nombre de bulletins, ou `null` si rien (motif
  /// déjà affiché).
  Future<int?> _writeSnapshot() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null || _classId == null || _year.isEmpty) return null;
    try {
      return await SupabaseDbSource.generateReportCards(
        schoolId: schoolId,
        classId: _classId!,
        academicYear: _year,
        period: _period,
        createdBy: ref.read(authSessionProvider)?.id,
      );
    } on ReportCardEmpty catch (e) {
      // « Aucune note » recouvrait trois causes (classe vide, pas de programme,
      // pas de note) : on dit laquelle.
      _toast(e.message, _gold);
      return null;
    }
  }

  /// VALIDER : fige le bulletin officiel PUIS gèle les notes de la période.
  /// Les deux vont ensemble — figer sans geler laisserait le snapshot dériver.
  Future<void> _validate() async {
    if (_classId == null) return;
    final ok = await _confirm(
      title: 'Valider la période',
      body: 'Le bulletin de chaque élève va être figé, et les notes du '
          '${_fmt.periodLabel(_period)} ne seront plus modifiables par les '
          'professeurs.\n\nUne correction restera possible pour l’administration, '
          'avec motif et trace.',
      action: 'Valider',
      color: _terra,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await _writeSnapshot();
      if (n == null) return; // rien à figer : message déjà montré
      await SupabaseDbSource.validatePeriod(_classId!, _period);
      _refresh();
      _toast('Période validée · $n bulletin(s) figé(s).', _green);
    } catch (e) {
      _toast('Échec : $e', _terra);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// RECALCULER : reporte les corrections dans le bulletin officiel. Remplace
  /// l’ancien « Régénérer » — il n’a de sens QUE quand une correction a eu lieu
  /// depuis la validation, et le bandeau ne le propose que dans ce cas.
  Future<void> _recompute() async {
    setState(() => _busy = true);
    try {
      final n = await _writeSnapshot();
      if (n == null) return;
      _refresh();
      _toast('Bulletin officiel recalculé ($n).', _green);
    } catch (e) {
      _toast('Échec : $e', _terra);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lock() async {
    if (_classId == null) return;
    final ok = await _confirm(
      title: 'Verrouiller la période',
      body: 'Plus AUCUNE note ne pourra être modifiée, par personne — même pas '
          'l’administration. Il faudra déverrouiller pour corriger.',
      action: 'Verrouiller',
      color: _terra,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await SupabaseDbSource.lockPeriod(_classId!, _period);
      _refresh();
      _toast('Période verrouillée.', _green);
    } catch (e) {
      _toast('Échec : $e', _terra);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen({required bool locked}) async {
    if (_classId == null) return;
    // Rouvrir une période VERROUILLÉE exige un motif (la base le refusera sinon).
    final reason = locked ? await _askReason('Rouvrir la période verrouillée') : null;
    if (locked && (reason == null || reason.isEmpty)) return;
    if (!locked) {
      final ok = await _confirm(
        title: 'Rouvrir la période',
        body: 'Les professeurs pourront de nouveau modifier les notes. Le '
            'bulletin figé sera obsolète jusqu’à une nouvelle validation.',
        action: 'Rouvrir',
        color: _terra,
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseDbSource.reopenPeriod(_classId!, _period, reason: reason);
      _refresh();
      _toast('Période rouverte.', _green);
    } catch (e) {
      _toast('Échec : $e', _terra);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(String title) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motif',
            hintText: 'Il sera enregistré dans l’historique.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<bool?> _confirm({
    required String title, required String body,
    required String action, required Color color,
  }) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(action),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(schoolProvider); // rebuild quand l'année académique est chargée
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.valueOrNull ?? const <SbClass>[];
    // Sélection par défaut : première classe.
    if (_classId == null && classes.isNotEmpty) {
      _classId = classes.first.id;
    }

    final content = classesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _terra)),
      error: (e, _) => Center(child: Text('Erreur : $e',
          style: TextStyle(color: context.cMuted))),
      data: (cls) => cls.isEmpty
          ? const Center(child: EmptyState(
              icon: Icons.class_outlined,
              title: 'Aucune classe',
              description: 'Crée des classes pour générer leurs bulletins.'))
          : _body(cls),
    );

    // En onglet, on ne rend QUE le contenu : l'en-tête vient de la page parente.
    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: context.cPage,
      body: Column(children: [
        GradientHeader(
          title: 'Bulletins',
          subtitle: 'Génération & publication · Année ${_year.isEmpty ? '—' : _year}',
          icon: Icons.workspace_premium_rounded,
        ),
        Expanded(child: content),
      ]),
    );
  }

  Widget _body(List<SbClass> classes) {
    final cardsAsync = ref.watch(reportCardsForClassProvider(_key));
    final cards = cardsAsync.valueOrNull ?? const <SbReportCard>[];

    return ListView(
      // En onglet, la page parente fait déjà défiler : ce ListView doit alors
      // se contenter de sa hauteur naturelle, sinon deux zones de défilement
      // s'emboîtent (ou le rendu plante faute de hauteur bornée).
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 0 : 18, 16, 32),
      children: [
        // ── Sélecteurs classe + trimestre ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('CLASSE'),
            const SizedBox(height: 6),
            _dropdown<String>(
              value: _classId,
              items: [for (final c in classes)
                DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() {
                _classId = v;
                // Une classe d'un autre cycle a sa propre liste de périodes
                // (mois vs trimestre) : l'ancienne sélection n'a plus de sens.
                _selectedPeriod = null;
              }),
            ),
            const SizedBox(height: 14),
            _label(switch (_fmt.periodSystem) {
              'semester' => 'SEMESTRE',
              'monthly' => 'MOIS',
              _ => 'TRIMESTRE',
            }),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _fmt.periods) _periodChip(p),
            ]),
            const SizedBox(height: 14),
            _label('MODÈLE DE BULLETIN'),
            const SizedBox(height: 6),
            _templateGallery(),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Bandeau d'état + actions (piloté par l'état de la période) ──
        _workflowBanner(cards),
        const SizedBox(height: 16),

        // ── Aperçu ─────────────────────────────────────────────────────
        if (cardsAsync.isLoading)
          const Padding(padding: EdgeInsets.only(top: 30),
              child: Center(child: CircularProgressIndicator(color: _terra)))
        else if (cards.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Pas encore clôturé',
            description: 'Validez la période pour figer les bulletins de ce trimestre.')
        else ...[
          Row(children: [
            Expanded(
              child: Text('Touchez un élève pour voir son bulletin.',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            ),
            _actionBtn(
              label: 'Imprimer toute la classe',
              icon: Icons.print_rounded,
              color: _terra,
              filled: false,
              onTap: _busy ? null : () => _printAll(cards),
            ),
          ]),
          const SizedBox(height: 10),
          for (final c in cards) ...[
            _StudentRow(
              card: c,
              onTap: () => _openBulletin(c),
            ),
            const SizedBox(height: 8),
          ],
        ],

        // ── Historique des modifications ────────────────────────────────
        const SizedBox(height: 16),
        _AuditPanel(periodKey: _periodKey),
      ],
    );
  }

  /// Imprime tous les bulletins FIGÉS de la classe en un seul document.
  Future<void> _printAll(List<SbReportCard> cards) async {
    final school = ref.read(schoolProvider).valueOrNull;
    final className =
        (ref.read(classesProvider).valueOrNull ?? const <SbClass>[])
            .where((c) => c.id == _classId)
            .map((c) => c.name)
            .firstOrNull ??
            '';
    final items = [
      for (final c in cards)
        BulletinToPrint(
          student: SbStudent(
              id: c.studentId, nom: c.studentName ?? '', prenom: '',
              classe: className),
          className: className,
          bulletin: c.toBulletin(),
          classId: _classId,
        ),
    ];
    try {
      await printClassBulletins(
        school: school,
        periodLabel: _fmt.periodLabel(_period),
        rules: BulletinRules.fromSchool(school),
        items: items,
        academicYear: _year,
        periodCode: _period,
      );
    } catch (e) {
      _toast('Impression impossible : $e', _terra);
    }
  }

  /// Ouvre le bulletin **figé** : on le relit tel qu'il a été généré, on ne le
  /// recalcule pas. C'est la photo officielle, pas l'aperçu vivant.
  void _openBulletin(SbReportCard card) {
    final school = ref.read(schoolProvider).valueOrNull;
    final className =
        (ref.read(classesProvider).valueOrNull ?? const <SbClass>[])
            .where((c) => c.id == card.classId)
            .map((c) => c.name)
            .firstOrNull ??
            '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FrozenBulletinPage(
        card: card,
        school: school,
        className: className,
        periodLabel: _fmt.periodLabel(card.period),
        rules: BulletinRules.fromSchool(school),
      ),
    ));
    // classId/academicYear/period pour la synthèse annuelle du modèle détaillé
    // voyagent déjà avec la fiche `card` (classId, academicYear, period) —
    // cf. _FrozenBulletinPage.build, qui les relit directement dessus.
  }

  /// Le bandeau qui pilote la clôture. Ce qu'il montre — et propose — dépend de
  /// l'ÉTAT de la période, plus du nombre de brouillons/publiés (la publication
  /// aux familles n'existe plus).
  Widget _workflowBanner(List<SbReportCard> cards) {
    final period = ref.watch(gradePeriodProvider(_periodKey)).valueOrNull;
    final status = period?.status ?? 'open';

    final canValider = ref.watch(canProvider('notes.valider'));
    final canVerrou = ref.watch(canProvider('notes.verrouiller'));

    // Une correction depuis la génération ? On compare la dernière écriture de
    // note à la date où le bulletin officiel a été (re)calculé — PAS à la
    // validation : « Appliquer les corrections » réécrit le snapshot sans
    // toucher à validatedAt, donc comparer à validatedAt laisserait le bouton
    // éternellement actif. Si une note est plus récente que le snapshot, le
    // bulletin figé n'est plus à jour — c'est là, et LÀ SEULEMENT, qu'on
    // propose de recalculer (l'ex-« Régénérer », qui ne servait à rien).
    final grades = ref.watch(gradesForClassProvider(_classId ?? '')).valueOrNull
            ?? const <SbGrade>[];
    final lastEdit = grades
        .where((g) => g.period == _period)
        .map((g) => g.updatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final snapshotAt = cards
        .map((c) => c.generatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final pending = status == 'validated' &&
        snapshotAt != null &&
        lastEdit != null &&
        lastEdit.isAfter(snapshotAt);

    final (Color color, IconData icon, String text) = switch (status) {
      'validated' => (_green, Icons.verified_rounded,
          'Période validée · notes gelées. Correction possible avec motif.'),
      'locked' => (_terra, Icons.lock_rounded,
          'Période verrouillée · aucune modification possible.'),
      _ => (_gold, Icons.lock_open_rounded,
          'Période ouverte · les professeurs saisissent librement.'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
        if (period?.validatedAt != null && status != 'open') ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('Validée le ${DateFormat('d MMM yyyy', 'fr').format(period!.validatedAt!)}',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Des corrections ne sont pas encore dans le bulletin officiel.',
              style: TextStyle(fontSize: 12, color: context.cInk),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          // OUVERTE → Valider.
          if (status == 'open' && canValider)
            _actionBtn(label: 'Valider la période',
                icon: Icons.verified_outlined, color: _terra, filled: true,
                onTap: _busy ? null : _validate),
          // VALIDÉE → Recalculer (si corrections), Verrouiller, Rouvrir.
          if (status == 'validated') ...[
            if (pending && canValider)
              _actionBtn(label: 'Appliquer les corrections',
                  icon: Icons.sync_rounded, color: _gold, filled: true,
                  onTap: _busy ? null : _recompute),
            if (canVerrou)
              _actionBtn(label: 'Verrouiller',
                  icon: Icons.lock_outline_rounded, color: _terra, filled: false,
                  onTap: _busy ? null : _lock),
            if (canVerrou)
              _actionBtn(label: 'Rouvrir',
                  icon: Icons.lock_open_outlined, color: context.cMuted, filled: false,
                  onTap: _busy ? null : () => _reopen(locked: false)),
          ],
          // VERROUILLÉE → Déverrouiller.
          if (status == 'locked' && canVerrou)
            _actionBtn(label: 'Déverrouiller',
                icon: Icons.lock_open_outlined, color: _terra, filled: true,
                onTap: _busy ? null : () => _reopen(locked: true)),
        ]),
      ]),
    );
  }

  /// La galerie des 4 modèles de bulletin — un réglage de l'école, pas de la
  /// page : cf. `SbSchool.bulletinTemplate` / `updateSchoolBulletinTemplate`.
  /// Les libellés viennent de `bulletinTemplates` (bulletin_pdf.dart), source
  /// unique partagée avec le moteur PDF — pas de duplication des noms ici.
  Widget _templateGallery() {
    final school = ref.watch(schoolProvider).valueOrNull;
    final selected = school?.bulletinTemplate ?? 'standard';
    Future<void> pick(String key) async {
      if (school == null || key == selected) return;
      try {
        await SupabaseDbSource.updateSchoolBulletinTemplate(
            id: school.id, template: key);
        ref.invalidate(schoolProvider);
        _toast('Modèle de bulletin mis à jour.', _green);
      } catch (e) {
        _toast('Échec : $e', _terra);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final entry in bulletinTemplates.entries) ...[
          _TemplateCard(
            templateKey: entry.key,
            label: entry.value.label,
            description: entry.value.description,
            selected: entry.key == selected,
            onTap: () => pick(entry.key),
          ),
          const SizedBox(width: 10),
        ],
      ]),
    );
  }

  // ── petits widgets ────────────────────────────────────────────────────────
  Widget _label(String t) => Text(t,
      style: TextStyle(color: context.cMuted, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: .5));

  Widget _dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value, isExpanded: true, isDense: true,
            items: items, onChanged: onChanged,
          ),
        ),
      );

  Widget _periodChip(String p) {
    final active = _period == p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _terra : context.cSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _terra : context.cBorder),
          ),
          child: Text(_fmt.periodShort(p),
              style: TextStyle(
                  color: active ? Colors.white : context.cMuted,
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label, required IconData icon,
    required Color color, required bool filled, required VoidCallback? onTap,
  }) => Opacity(
        opacity: onTap == null ? .5 : 1,
        child: Material(
          color: filled ? color : context.cCard,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: filled ? null : Border.all(color: color.withValues(alpha: .4)),
              ),
              child: _busy && onTap == null
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 16, color: filled ? Colors.white : color),
                      const SizedBox(width: 7),
                      Text(label, style: TextStyle(
                          color: filled ? Colors.white : color,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      );
}

/// Une carte de la galerie « MODÈLE DE BULLETIN » : un aperçu miniature (pas
/// un vrai PDF rendu — trop lourd pour une simple sélection), le nom du
/// modèle, sa description, et un état sélectionné.
class _TemplateCard extends StatelessWidget {
  final String templateKey;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.templateKey,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 168,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? _terra : context.cBorder,
                width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              _preview(context),
              if (selected)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: _terra, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: context.cInk, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.cMuted, fontSize: 10, height: 1.25)),
          ]),
        ),
      ),
    );
  }

  /// Une mini-maquette au look propre à chaque modèle — pas un rendu PDF réel.
  Widget _preview(BuildContext context) {
    final line = context.cBorder;
    Widget bar({double w = double.infinity, double h = 5, Color? color}) =>
        Container(
            width: w, height: h,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
                color: color ?? line, borderRadius: BorderRadius.circular(2)));

    switch (templateKey) {
      case 'detailed':
        // Bandeau pêche + bandeau vert, comme le papier Emma & Bénie.
        return Container(
          height: 108,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: context.cSubtle, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            bar(h: 10, color: const Color(0xFFF4D9B0)),
            const SizedBox(height: 3),
            bar(h: 8, color: const Color(0xFFCDE8CB)),
            const SizedBox(height: 6),
            for (var i = 0; i < 4; i++) bar(h: 4),
          ]),
        );
      case 'compact':
        // Un unique bloc dense, sans bandeau distinct.
        return Container(
          height: 108,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: context.cSubtle, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            bar(h: 7),
            const SizedBox(height: 5),
            for (var i = 0; i < 5; i++) bar(h: 3.5),
            const SizedBox(height: 5),
            bar(h: 8, color: context.cMuted.withValues(alpha: .3)),
          ]),
        );
      case 'modern':
        // En-tête et lignes teintées de la couleur d'accent, coins arrondis.
        return Container(
          height: 108,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: context.cSubtle, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            bar(h: 14, color: _terra),
            const SizedBox(height: 5),
            for (var i = 0; i < 4; i++)
              bar(h: 4, color: i.isOdd ? _terra.withValues(alpha: .15) : null),
            const SizedBox(height: 4),
            Center(
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
              ),
            ),
          ]),
        );
      case 'standard':
      default:
        // Sobre : gris/blanc, tableau simple.
        return Container(
          height: 108,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: context.cSubtle, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            bar(h: 8, color: context.cMuted.withValues(alpha: .35)),
            const SizedBox(height: 6),
            for (var i = 0; i < 6; i++) bar(h: 3.5),
          ]),
        );
    }
  }
}

class _StudentRow extends StatelessWidget {
  final SbReportCard card;
  final VoidCallback onTap;
  const _StudentRow({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avg = card.generalAverage;
    final avgColor = avg >= 14 ? _green : avg >= 10 ? _gold : _terra;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        // Rang
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _terra.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(card.rank != null ? '${card.rank}' : '—',
              style: const TextStyle(color: _terra, fontSize: 14, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(card.studentName ?? '—',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.cInk, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${card.lines.length} matière(s)'
              '${card.mention != null ? ' · ${card.mention}' : ''}',
              style: TextStyle(color: context.cMuted, fontSize: 11.5)),
        ])),
        const SizedBox(width: 10),
        Text(avg.toStringAsFixed(2),
            style: TextStyle(color: avgColor, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        card.isPublished
            ? StatusPill.success('Publié')
            : StatusPill.warning('Brouillon'),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, size: 20, color: context.cMuted),
      ]),
    ),
    );
  }
}

/// Le bulletin **figé** — relu depuis l'archive, pas recalculé. La photo
/// officielle : le rang et la moyenne de la classe sont ceux du jour de la
/// génération, même si des notes ont bougé depuis.
class _FrozenBulletinPage extends StatelessWidget {
  final SbReportCard card;
  final SbSchool? school;
  final String className;
  final String periodLabel;
  final BulletinRules rules;
  const _FrozenBulletinPage({
    required this.card,
    required this.school,
    required this.className,
    required this.periodLabel,
    required this.rules,
  });

  @override
  Widget build(BuildContext context) {
    // Un élève-fiche : le bulletin figé porte le nom, pas le compte. On
    // reconstruit juste ce dont la vue et le PDF ont besoin.
    final student = SbStudent(
      id: card.studentId,
      nom: card.studentName ?? '',
      prenom: '', // fullName = « <nom> » : le nom est déjà complet dans l'archive
      classe: className,
    );
    return Scaffold(
      backgroundColor: context.cPage,
      appBar: AppBar(
        backgroundColor: context.cCard,
        foregroundColor: context.cInk,
        title: Text('Bulletin · ${card.studentName ?? ''}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          BulletinView(
            school: school,
            student: student,
            className: className,
            periodLabel: periodLabel,
            bulletin: card.toBulletin(),
            rules: rules,
            frozen: true,
            classId: card.classId,
            academicYear: card.academicYear,
            periodCode: card.period,
          ),
        ],
      ),
    );
  }
}

/// L'historique des modifications de la période — la frise de traçabilité.
///
/// Chaque correction de note, chaque changement d'état y apparaît : qui, quand,
/// de quelle valeur à quelle valeur, et le motif. C'est ce qui permet de
/// justifier un changement en cas de litige. Lecture réservée à `notes.voir` —
/// la base refuse le reste.
class _AuditPanel extends ConsumerWidget {
  final String periodKey;
  const _AuditPanel({required this.periodKey});

  static const _terra = Color(0xFF8B1A00);
  static const _gold = Color(0xFFC17F24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(periodAuditProvider(periodKey));
    final entries = async.valueOrNull ?? const <SbAuditEntry>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 16, color: context.cMuted),
          const SizedBox(width: 8),
          Text('Historique des modifications',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.cInk)),
        ]),
        const SizedBox(height: 10),
        if (async.isLoading)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (entries.isEmpty)
          Text('Aucune modification enregistrée pour cette période.',
              style: TextStyle(fontSize: 12, color: context.cMuted))
        else
          for (final e in entries) _row(context, e),
      ]),
    );
  }

  Widget _row(BuildContext context, SbAuditEntry e) {
    // La phrase qui décrit le changement, lisible d'un coup d'œil.
    final (IconData icon, Color color, String what) = switch (e.changeType) {
      'note' => (Icons.edit_rounded, _gold,
          '${e.field ?? 'Note'} : ${e.oldValue ?? '—'} → ${e.newValue ?? '—'}'),
      'appreciation' => (Icons.notes_rounded, _gold, 'Appréciation modifiée'),
      'suppression' => (Icons.delete_outline_rounded, _terra,
          'Note supprimée (${e.oldValue ?? '—'})'),
      'statut_periode' => (Icons.flag_rounded, context.cMuted,
          'Période : ${_statusLabel(e.oldValue)} → ${_statusLabel(e.newValue)}'),
      _ => (Icons.circle, context.cMuted, e.changeType),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(what,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.cInk)),
            const SizedBox(height: 1),
            Text(
              '${e.actorName} · ${DateFormat('d MMM yyyy, HH:mm', 'fr').format(e.createdAt)}'
              '${e.reason != null ? ' · « ${e.reason} »' : ''}',
              style: TextStyle(fontSize: 11, color: context.cMuted),
            ),
          ]),
        ),
      ]),
    );
  }

  String _statusLabel(String? s) => switch (s) {
        'open' => 'ouverte',
        'validated' => 'validée',
        'locked' => 'verrouillée',
        _ => s ?? '—',
      };
}
