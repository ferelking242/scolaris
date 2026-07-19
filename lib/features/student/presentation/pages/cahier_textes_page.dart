import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _orange = ScolarisPalette.orange;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;

// ── Mock data ─────────────────────────────────────────────────────────────────
class _Entry {
  final String matiere;
  final String contenu;
  final String prof;
  final String date;
  final Color color;
  final IconData icon;
  final String? travail;
  const _Entry({
    required this.matiere, required this.contenu, required this.prof,
    required this.date, required this.color, required this.icon, this.travail,
  });
}

const _entries = [
  _Entry(
    matiere: 'Mathématiques', date: '27 Jun', prof: 'M. Ngoma',
    icon: Icons.calculate_rounded, color: _terra,
    contenu: 'Dérivées et primitives — fonctions composées. Exercices d\'application sur les polynômes du 2nd degré.',
    travail: 'Ex. 14 p.82 + Ex. 16 p.83',
  ),
  _Entry(
    matiere: 'Sciences Physiques', date: '26 Jun', prof: 'Mme Okoko',
    icon: Icons.science_rounded, color: _green,
    contenu: 'TP Électricité : circuit RC, mesure de la constante de temps τ. Compte-rendu à remettre.',
    travail: 'Rédiger le compte-rendu du TP',
  ),
  _Entry(
    matiere: 'Français', date: '25 Jun', prof: 'M. Moanda',
    icon: Icons.menu_book_rounded, color: _gold,
    contenu: 'Lecture analytique : L\'Étranger de Camus. Étude du personnage de Meursault, indifférence et absurde.',
  ),
  _Entry(
    matiere: 'Histoire-Géo', date: '24 Jun', prof: 'Mme Biyela',
    icon: Icons.public_rounded, color: _orange,
    contenu: 'Décolonisation en Afrique subsaharienne 1945-1960. Étude de cas : Congo, Cameroun, Sénégal.',
    travail: 'Fiche de révision sur les dates clés',
  ),
  _Entry(
    matiere: 'Algorithmique', date: '23 Jun', prof: 'M. Kinsounda',
    icon: Icons.code_rounded, color: Color(0xFF6D28D9),
    contenu: 'Algorithmes de tri : tri à bulles, tri rapide (quicksort). Complexité temporelle O(n²) vs O(n log n).',
    travail: 'Implémenter quicksort en Python',
  ),
  _Entry(
    matiere: 'Anglais', date: '22 Jun', prof: 'Mme Ntoko',
    icon: Icons.translate_rounded, color: Color(0xFF0891B2),
    contenu: 'Present Perfect vs Simple Past. Exercices de dialogue sur les expériences de voyage.',
  ),
  _Entry(
    matiere: 'Chimie', date: '21 Jun', prof: 'M. Mbemba',
    icon: Icons.biotech_rounded, color: Color(0xFF059669),
    contenu: 'Réactions d\'oxydo-réduction. Équilibrage des équations, notion de nombre d\'oxydation.',
    travail: 'Exercices 5 à 9 p.104',
  ),
  _Entry(
    matiere: 'Philosophie', date: '20 Jun', prof: 'M. Loubelo',
    icon: Icons.psychology_rounded, color: Color(0xFFDB2777),
    contenu: 'La conscience : Descartes et le cogito. Distinction conscience/inconscient (Freud).',
  ),
];

final _matieres = ['Toutes', ..._entries.map((e) => e.matiere).toSet().toList()];

// ── Page principale ───────────────────────────────────────────────────────────
class CahierTextesPage extends StatefulWidget {
  const CahierTextesPage({super.key});
  @override
  State<CahierTextesPage> createState() => _CahierTextesPageState();
}

class _CahierTextesPageState extends State<CahierTextesPage> {
  String _filtre = 'Toutes';
  String _search = '';

  List<_Entry> get _filtered => _entries
      .where((e) => _filtre == 'Toutes' || e.matiere == _filtre)
      .where((e) => _search.isEmpty ||
          e.matiere.toLowerCase().contains(_search.toLowerCase()) ||
          e.contenu.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return PageScaffold(
      title: 'Cahier de textes',
      subtitle: '${filtered.length} leçon(s)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Barre de recherche ─────────────────────────────────────────────
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 16, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une leçon…',
                  hintStyle: TextStyle(fontSize: 13, color: _muted),
                  isCollapsed: true, border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Filtre par matière ─────────────────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _matieres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final m = _matieres[i];
              final sel = m == _filtre;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => setState(() => _filtre = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _terra : _white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _terra : _border),
                  ),
                  child: Text(m,
                      style: TextStyle(
                          color: sel ? _white : _muted,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Liste des entrées ──────────────────────────────────────────────
        if (filtered.isEmpty)
          const EmptyState(
            icon: Icons.book_outlined,
            title: 'Aucune leçon trouvée',
            description: 'Modifiez votre filtre ou recherche.',
          )
        else
          ...filtered.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EntryCard(entry: e),
          )),
      ]),
    );
  }
}

// ── Carte d'entrée ────────────────────────────────────────────────────────────
class _EntryCard extends StatefulWidget {
  final _Entry entry;
  const _EntryCard({required this.entry});
  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _expanded ? e.color.withOpacity(.4) : _border),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: e.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(e.icon, color: e.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e.matiere,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: _bg, borderRadius: BorderRadius.circular(6)),
                    child: Text(e.date,
                        style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: 11, color: _muted),
                  const SizedBox(width: 4),
                  Text(e.prof, style: const TextStyle(fontSize: 11, color: _muted)),
                ]),
              ])),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _muted, size: 20),
            ]),
          ),
        ),
        // ── Contenu expansible ──────────────────────────────────────────────
        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 1, color: _border, margin: const EdgeInsets.only(bottom: 12)),
              Text(e.contenu,
                  style: const TextStyle(fontSize: 13, color: _ink, height: 1.6)),
              if (e.travail != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withOpacity(.25)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.assignment_rounded, color: _gold, size: 15),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('À faire', style: TextStyle(
                          color: _gold, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(e.travail!, style: const TextStyle(
                          color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}
