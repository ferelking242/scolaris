import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../domain/entities/user_entity.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// Neutres (texte/fond/bordure) : jamais figés → `context.c*` (page_scaffold).
// Ces deux-là sont du texte posé sur un fond de marque coloré : ils restent
// constants, valables en clair comme en sombre.
const _white  = Colors.white;        // sur terracotta / couleur de catégorie
const _onGold = Color(0xFF1A0A00);   // sur la pastille or

// ── Catégories ────────────────────────────────────────────────────────────────
// Le vocabulaire vient de la base (contrainte `category` de `liaison_entries`).
// Un cahier de liaison réel parle de sorties, de médicaments, de permissions —
// pas de « types de message ».
class _Cat {
  final String label;
  final Color color;
  final IconData icon;
  const _Cat(this.label, this.color, this.icon);
}

const _categories = <String, _Cat>{
  'info':          _Cat('Information',   Color(0xFF0891B2), Icons.info_rounded),
  'devoir':        _Cat('Devoir',        Color(0xFF1565C0), Icons.assignment_rounded),
  'sortie':        _Cat('Sortie',        Color(0xFF6D28D9), Icons.directions_bus_rounded),
  'medicament':    _Cat('Médicament',    Color(0xFFDB2777), Icons.medical_services_rounded),
  'permission':    _Cat('Permission',    _gold,             Icons.event_available_rounded),
  'felicitation':  _Cat('Félicitation',  _green,            Icons.emoji_events_rounded),
  'avertissement': _Cat('Avertissement', _terra,            Icons.warning_amber_rounded),
};

_Cat _catOf(String key) =>
    _categories[key] ?? const _Cat('Information', Color(0xFF0891B2), Icons.info_rounded);

// ══════════════════════════════════════════════════════════════════════════
// Page — le cahier de liaison d'un élève.
//
// `studentId` null = l'élève connecté (vue élève).
// `studentId` renseigné = vue parent sur un de ses enfants.
//
// Seul le PARENT peut accuser réception : c'est la signature du cahier papier,
// et elle n'a de sens que d'un adulte. La RLS l'impose déjà en base — l'UI ne
// fait que refléter cette règle.
// ══════════════════════════════════════════════════════════════════════════
class CahierLiaisonPage extends ConsumerStatefulWidget {
  final String? studentId;
  final String? title;
  const CahierLiaisonPage({super.key, this.studentId, this.title});

  @override
  ConsumerState<CahierLiaisonPage> createState() => _CahierLiaisonPageState();
}

class _CahierLiaisonPageState extends ConsumerState<CahierLiaisonPage> {
  String? _filtre;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final sid     = widget.studentId ?? session?.id;
    final heading = widget.title ?? 'Cahier de liaison';
    final isParent = session?.role == UserRole.parent;

    if (sid == null) {
      return PageScaffold(title: heading, child: const SizedBox());
    }

    final entriesAsync = ref.watch(liaisonEntriesForStudentProvider(sid));
    final acks = ref.watch(myLiaisonAcksProvider).valueOrNull ?? const <String>{};

    return entriesAsync.when(
      loading: () => PageScaffold(
        title: heading,
        child: const Center(child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (e, _) => PageScaffold(
        title: heading,
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (entries) {
        // « Non lu » côté parent = pas encore signé. Côté élève, la notion
        // n'existe pas : il n'y a rien à signer.
        final aSigner = isParent
            ? entries.where((e) => e.requiresAck && !acks.contains(e.id)).length
            : 0;

        final visible = _filtre == null
            ? entries
            : entries.where((e) => e.category == _filtre).toList();

        final usedCats = entries.map((e) => e.category).toSet().toList()
          ..sort((a, b) => _catOf(a).label.compareTo(_catOf(b).label));

        return PageScaffold(
          title: heading,
          subtitle: entries.isEmpty
              ? 'Aucun mot pour l\'instant'
              : isParent && aSigner > 0
                  ? '$aSigner mot(s) à signer'
                  : '${entries.length} mot(s)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _Header(count: entries.length, aSigner: aSigner),
            const SizedBox(height: 14),

            if (usedCats.isNotEmpty) ...[
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      color: _terra,
                      selected: _filtre == null,
                      onTap: () => setState(() => _filtre = null),
                    ),
                    const SizedBox(width: 6),
                    for (final c in usedCats) ...[
                      _FilterChip(
                        label: _catOf(c).label,
                        color: _catOf(c).color,
                        selected: _filtre == c,
                        onTap: () => setState(
                            () => _filtre = _filtre == c ? null : c),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (visible.isEmpty)
              EmptyState(
                icon: Icons.import_contacts_outlined,
                title: entries.isEmpty
                    ? 'Le cahier est vide'
                    : 'Aucun mot pour ce filtre',
                description: entries.isEmpty
                    ? 'Les mots de l\'enseignant apparaîtront ici.'
                    : 'Essayez un autre filtre.',
              )
            else
              for (final e in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryCard(
                    entry: e,
                    canAck: isParent,
                    acked: acks.contains(e.id),
                    onAck: () => _ack(e),
                  ),
                ),
          ]),
        );
      },
    );
  }

  Future<void> _ack(SbLiaisonEntry entry) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await SupabaseDbSource.ackLiaisonEntry(
        entryId: entry.id,
        parentId: session.id,
      );
      ref.invalidate(myLiaisonAcksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot signé — l\'école est informée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de signer : $e')),
      );
    }
  }
}

// ── Bandeau ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count, aSigner;
  const _Header({required this.count, required this.aSigner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _terra],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _white.withOpacity(.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.import_contacts_rounded,
              color: _white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cahier de liaison',
              style: TextStyle(color: _white, fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            count == 0
                ? 'Aucun mot de l\'école'
                : '$count mot(s) de l\'école',
            style: TextStyle(color: _white.withOpacity(.7), fontSize: 11),
          ),
        ])),
        if (aSigner > 0)
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
            child: Center(child: Text('$aSigner',
                style: const TextStyle(color: _onGold, fontSize: 12,
                    fontWeight: FontWeight.w900))),
          ),
      ]),
    );
  }
}

// ── Filtre ────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : context.cCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : context.cBorder),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? _white : context.cMuted,
            fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

// ── Carte d'un mot ────────────────────────────────────────────────────────────
class _EntryCard extends StatefulWidget {
  final SbLiaisonEntry entry;
  final bool canAck, acked;
  final VoidCallback onAck;
  const _EntryCard({required this.entry, required this.canAck,
      required this.acked, required this.onAck});

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e   = widget.entry;
    final cat = _catOf(e.category);
    // Un mot qui attend une signature se distingue visuellement.
    final pending = widget.canAck && e.requiresAck && !widget.acked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: pending ? cat.color.withOpacity(.08) : context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pending ? cat.color.withOpacity(.45) : context.cBorder,
          width: pending ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, color: cat.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(cat.label, style: TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w700,
                        color: cat.color)),
                  ),
                  if (e.isForWholeClass) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.cSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Toute la classe', style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w600,
                          color: context.cMuted)),
                    ),
                  ],
                  const Spacer(),
                  Text(_fmt(e.createdAt),
                      style: TextStyle(fontSize: 10, color: context.cMuted)),
                ]),
                const SizedBox(height: 5),
                Text(e.title, style: TextStyle(
                    fontSize: 13,
                    fontWeight: pending ? FontWeight.w800 : FontWeight.w600,
                    color: context.cInk)),
                const SizedBox(height: 3),
                Text(e.authorName ?? 'L\'école',
                    style: TextStyle(fontSize: 10.5, color: context.cMuted)),
              ])),
              const SizedBox(width: 6),
              Icon(_expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18, color: context.cMuted),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 1, color: context.cBorder,
                  margin: const EdgeInsets.only(bottom: 10)),
              Text(e.body, style: TextStyle(
                  fontSize: 13, color: context.cInk, height: 1.6)),

              // Signature — parent uniquement.
              if (widget.canAck && e.requiresAck) ...[
                const SizedBox(height: 14),
                if (widget.acked)
                  Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: _green, size: 16),
                    const SizedBox(width: 6),
                    Text('Vous avez signé ce mot',
                        style: TextStyle(color: context.cMuted, fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                  ])
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onAck,
                      icon: const Icon(Icons.draw_rounded, size: 16),
                      label: const Text('J\'ai lu — signer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cat.color,
                        foregroundColor: _white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ]),
          ),
      ]),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août',
                  'sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }
}
