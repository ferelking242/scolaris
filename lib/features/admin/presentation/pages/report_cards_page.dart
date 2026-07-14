import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../core/config/school_format.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/bulletin_view.dart';

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

  SchoolFormat get _fmt => ref.read(schoolFormatProvider);
  String get _period => _selectedPeriod ?? _fmt.periods.first;
  String get _year => ref.read(schoolProvider).valueOrNull?.academicYear ?? '';
  String get _key => '${_classId ?? ''}|$_year|$_period';

  Future<void> _generate() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null || _classId == null || _year.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: 'Générer les bulletins',
      body: 'Calculer les bulletins du ${_fmt.periodLabel(_period)} pour tous les '
          'élèves de la classe.\n\nLes bulletins déjà publiés repasseront en '
          'brouillon : il faudra les republier.',
      action: 'Générer',
      color: _terra,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await SupabaseDbSource.generateReportCards(
        schoolId: schoolId,
        classId: _classId!,
        academicYear: _year,
        period: _period,
        createdBy: ref.read(authSessionProvider)?.id,
      );
      ref.invalidate(reportCardsForClassProvider(_key));
      messenger.showSnackBar(SnackBar(
        content: Text('$n bulletin(s) généré(s) en brouillon.'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } on ReportCardEmpty catch (e) {
      // On dit POURQUOI il n'y a rien à générer. « Aucune note » s'affichait
      // aussi quand la classe était vide, ou sans programme : l'admin cherchait
      // des notes qui existaient bel et bien.
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (_classId == null || _year.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: 'Publier aux familles',
      body: 'Rendre ces bulletins visibles par les élèves et leurs parents. '
          'Action immédiate.',
      action: 'Publier',
      color: _green,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await SupabaseDbSource.publishReportCards(
        classId: _classId!, academicYear: _year, period: _period);
      ref.invalidate(reportCardsForClassProvider(_key));
      messenger.showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Aucun brouillon à publier.'
            : '$n bulletin(s) publié(s).'),
        backgroundColor: n == 0 ? _gold : _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final published = cards.where((c) => c.isPublished).length;
    final drafts = cards.length - published;

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
              onChanged: (v) => setState(() => _classId = v),
            ),
            const SizedBox(height: 14),
            _label(_fmt.periodSystem == 'semester' ? 'SEMESTRE' : 'TRIMESTRE'),
            const SizedBox(height: 6),
            Row(children: [
              for (final p in _fmt.periods) ...[
                _periodChip(p),
                const SizedBox(width: 8),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Bandeau d'état + actions ───────────────────────────────────
        _statusBanner(cards.length, drafts, published, cards),
        const SizedBox(height: 16),

        // ── Aperçu ─────────────────────────────────────────────────────
        if (cardsAsync.isLoading)
          const Padding(padding: EdgeInsets.only(top: 30),
              child: Center(child: CircularProgressIndicator(color: _terra)))
        else if (cards.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Pas encore généré',
            description: 'Clique « Générer » pour calculer les bulletins de ce trimestre.')
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text('Touchez un élève pour voir et imprimer son bulletin.',
                style: TextStyle(fontSize: 12, color: context.cMuted)),
          ),
          for (final c in cards) ...[
            _StudentRow(
              card: c,
              onTap: () => _openBulletin(c),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
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
  }

  Widget _statusBanner(int total, int drafts, int published, List<SbReportCard> cards) {
    final (Color color, IconData icon, String text) = total == 0
        ? (_gold, Icons.pending_outlined, 'Bulletins non générés pour ce trimestre.')
        : published == total
            ? (_green, Icons.verified_rounded, 'Publié — visible par les élèves et parents.')
            : drafts == total
                ? (_terra, Icons.edit_note_rounded, 'Brouillon — $total bulletin(s) non publié(s).')
                : (_gold, Icons.info_outline_rounded,
                    '$published publié(s) · $drafts brouillon(s).');

    final publishedAt = cards
        .where((c) => c.publishedAt != null)
        .map((c) => c.publishedAt!)
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

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
        if (publishedAt != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('Publié le ${DateFormat('d MMM yyyy', 'fr').format(publishedAt)}',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
          ),
        ],
        const SizedBox(height: 12),
        // Générer et publier un bulletin exigent `notes.publier` : la base
        // refuse toute écriture sur report_cards sans ce droit.
        Row(children: [
          if (ref.watch(canProvider('notes.publier')))
            Expanded(
              child: _actionBtn(
                label: total == 0 ? 'Générer' : 'Régénérer',
                icon: Icons.calculate_rounded,
                color: _terra,
                filled: total == 0,
                onTap: _busy ? null : _generate,
              ),
            ),
          if (drafts > 0 && ref.watch(canProvider('notes.publier'))) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _actionBtn(
                label: 'Publier',
                icon: Icons.send_rounded,
                color: _green,
                filled: true,
                onTap: _busy ? null : _publish,
              ),
            ),
          ],
        ]),
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
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _terra : context.cSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _terra : context.cBorder),
        ),
        child: Text(p,
            style: TextStyle(
                color: active ? Colors.white : context.cMuted,
                fontSize: 13, fontWeight: FontWeight.w700)),
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
          ),
        ],
      ),
    );
  }
}
