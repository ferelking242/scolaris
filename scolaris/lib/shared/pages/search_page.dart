import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

enum _ResultType { student, course, teacher, room, event, grade }

class _SearchResult {
  final String title;
  final String subtitle;
  final _ResultType type;
  final String? badge;
  const _SearchResult({
    required this.title, required this.subtitle,
    required this.type, this.badge,
  });
}

const _allResults = [
  _SearchResult(title: 'Amadou Diallo', subtitle: 'Étudiant · Terminale A · ID: 2401-DA', type: _ResultType.student),
  _SearchResult(title: 'Fatou Ndiaye', subtitle: 'Étudiant · 1ère B · ID: 2402-FN', type: _ResultType.student),
  _SearchResult(title: 'Ibrahim Konaté', subtitle: 'Étudiant · Terminale S · ID: 2403-IK', type: _ResultType.student),
  _SearchResult(title: 'Mathématiques', subtitle: 'Cours · Terminale A & S · M. Diallo', type: _ResultType.course, badge: 'Lundi 08h'),
  _SearchResult(title: 'Français Littérature', subtitle: 'Cours · 1ère A · Mme Ndiaye', type: _ResultType.course, badge: 'Mardi 10h'),
  _SearchResult(title: 'Physique-Chimie', subtitle: 'Cours · Terminale S · M. Ouédraogo', type: _ResultType.course, badge: 'Merc 14h'),
  _SearchResult(title: 'Sciences de la Vie', subtitle: 'Cours · 1ère S · Dr. Kaboré', type: _ResultType.course),
  _SearchResult(title: 'M. Seydou Diallo', subtitle: 'Enseignant · Mathématiques & Physique', type: _ResultType.teacher),
  _SearchResult(title: 'Mme Awa Ndiaye', subtitle: 'Enseignante · Français & Philosophie', type: _ResultType.teacher),
  _SearchResult(title: 'Dr. Moussa Kaboré', subtitle: 'Enseignant · SVT & Sciences', type: _ResultType.teacher),
  _SearchResult(title: 'Salle A12', subtitle: 'Salle de classe · Capacité 35 places · Bâtiment A', type: _ResultType.room),
  _SearchResult(title: 'Laboratoire 1', subtitle: 'Laboratoire de sciences · Capacité 28 places', type: _ResultType.room),
  _SearchResult(title: 'Salle Informatique', subtitle: 'Salle info · 30 postes · Bâtiment B', type: _ResultType.room),
  _SearchResult(title: 'Réunion Parents', subtitle: 'Événement · 15 Mai 2025 · 18h00', type: _ResultType.event, badge: '15 Mai'),
  _SearchResult(title: 'Examens Trimestriels', subtitle: 'Événement · 20-24 Mai 2025', type: _ResultType.event, badge: '20 Mai'),
  _SearchResult(title: 'Moyenne Trimestre 2', subtitle: 'Note · 15.4/20 · Terminale A', type: _ResultType.grade, badge: '15.4/20'),
];

const _categories = [
  (icon: Icons.people_rounded,      label: 'Étudiants',   type: _ResultType.student),
  (icon: Icons.menu_book_rounded,   label: 'Cours',       type: _ResultType.course),
  (icon: Icons.person_rounded,      label: 'Enseignants', type: _ResultType.teacher),
  (icon: Icons.door_front_door_rounded, label: 'Salles',  type: _ResultType.room),
  (icon: Icons.event_rounded,       label: 'Événements',  type: _ResultType.event),
  (icon: Icons.grading_rounded,     label: 'Notes',       type: _ResultType.grade),
];

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();
  String _query  = '';
  _ResultType? _filter;
  bool _active   = false;

  List<String> _recentSearches = ['Mathématiques', 'Amadou Diallo', 'Salle A12'];

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_SearchResult> get _results {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
    return _allResults.where((r) {
      final matchFilter = _filter == null || r.type == _filter;
      final matchQuery  = r.title.toLowerCase().contains(q) ||
                          r.subtitle.toLowerCase().contains(q);
      return matchFilter && matchQuery;
    }).toList();
  }

  void _search(String v) {
    setState(() { _query = v; });
  }

  void _submitSearch(String v) {
    if (v.trim().isEmpty) return;
    setState(() {
      if (!_recentSearches.contains(v.trim())) {
        _recentSearches.insert(0, v.trim());
        if (_recentSearches.length > 6) _recentSearches.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _SearchBar(
            ctrl: _ctrl,
            focus: _focus,
            active: _active,
            onChanged: _search,
            onSubmitted: _submitSearch,
            onFocusChange: (f) => setState(() => _active = f),
            onClear: () {
              _ctrl.clear();
              setState(() { _query = ''; });
            },
          ),
          _FilterRow(selected: _filter, onSelect: (t) => setState(() {
            _filter = _filter == t ? null : t;
          })),
          Expanded(
            child: _query.isEmpty
                ? _buildIdle()
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            _SectionTitle('Recherches récentes', action: 'Effacer',
                onAction: () => setState(() => _recentSearches.clear())),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _recentSearches.map((s) => GestureDetector(
                onTap: () {
                  _ctrl.text = s;
                  setState(() => _query = s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 14, color: _muted),
                    const SizedBox(width: 6),
                    Text(s, style: const TextStyle(color: _ink, fontSize: 13)),
                  ]),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          _SectionTitle('Catégories', action: null, onAction: null),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: _categories.map((c) {
              final sel = _filter == c.type;
              return GestureDetector(
                onTap: () => setState(() {
                  _filter = sel ? null : c.type;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: sel ? _terra.withOpacity(.1) : _white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel ? _terra.withOpacity(.4) : _border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(c.icon, color: sel ? _terra : _muted, size: 26),
                    const SizedBox(height: 6),
                    Text(c.label,
                        style: TextStyle(
                            color: sel ? _terra : _ink,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Suggestions', action: null, onAction: null),
          const SizedBox(height: 10),
          ...[
            'Mathématiques Terminale',
            'Résultats du trimestre',
            'Emploi du temps semaine',
            'M. Diallo',
          ].map((s) => GestureDetector(
            onTap: () {
              _ctrl.text = s;
              setState(() => _query = s);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 16, color: _muted),
                const SizedBox(width: 12),
                Expanded(child: Text(s, style: const TextStyle(color: _ink, fontSize: 13.5))),
                Icon(Icons.north_west_rounded, size: 14, color: _muted),
              ]),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final res = _results;
    if (res.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _terra.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: _terra, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Aucun résultat', style: TextStyle(color: _ink, fontSize: 16,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Essayez un autre terme de recherche',
              style: TextStyle(color: _muted, fontSize: 13)),
        ]),
      );
    }

    final grouped = <_ResultType, List<_SearchResult>>{};
    for (final r in res) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text('${res.length} résultat${res.length > 1 ? 's' : ''}',
              style: const TextStyle(color: _muted, fontSize: 12.5)),
        ),
        for (final entry in grouped.entries) ...[
          _GroupHeader(type: entry.key),
          ...entry.value.map((r) => _ResultTile(result: r)),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool active;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onClear;
  const _SearchBar({
    required this.ctrl, required this.focus, required this.active,
    required this.onChanged, required this.onSubmitted,
    required this.onFocusChange, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Focus(
        onFocusChange: onFocusChange,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EEE6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? _terra.withOpacity(.5) : _border,
              width: active ? 1.8 : 1,
            ),
            boxShadow: active ? [BoxShadow(
                color: _terra.withOpacity(.08), blurRadius: 10)] : [],
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.search_rounded, color: _muted, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: const TextStyle(color: _ink, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Rechercher cours, étudiant, salle…',
                  hintStyle: TextStyle(color: _muted.withOpacity(.6), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  isDense: true,
                ),
              ),
            ),
            if (ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                        color: _muted.withOpacity(.2), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 12, color: _muted),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _ResultType? selected;
  final ValueChanged<_ResultType> onSelect;
  const _FilterRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _categories.map((c) {
          final sel = selected == c.type;
          return GestureDetector(
            onTap: () => onSelect(c.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8, bottom: 8, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: sel ? _terra : const Color(0xFFF5EEE6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? _terra : _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(c.icon, size: 13, color: sel ? _white : _muted),
                const SizedBox(width: 5),
                Text(c.label,
                    style: TextStyle(
                        color: sel ? _white : _ink,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final _ResultType type;
  const _GroupHeader({required this.type});

  String get _label {
    switch (type) {
      case _ResultType.student:  return 'Étudiants';
      case _ResultType.course:   return 'Cours';
      case _ResultType.teacher:  return 'Enseignants';
      case _ResultType.room:     return 'Salles';
      case _ResultType.event:    return 'Événements';
      case _ResultType.grade:    return 'Notes';
    }
  }

  IconData get _icon {
    switch (type) {
      case _ResultType.student:  return Icons.people_rounded;
      case _ResultType.course:   return Icons.menu_book_rounded;
      case _ResultType.teacher:  return Icons.person_rounded;
      case _ResultType.room:     return Icons.door_front_door_rounded;
      case _ResultType.event:    return Icons.event_rounded;
      case _ResultType.grade:    return Icons.grading_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Icon(_icon, size: 14, color: _terra),
        const SizedBox(width: 6),
        Text(_label.toUpperCase(),
            style: const TextStyle(color: _terra, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  const _ResultTile({required this.result});

  Color get _typeColor {
    switch (result.type) {
      case _ResultType.student:  return _terra;
      case _ResultType.course:   return _gold;
      case _ResultType.teacher:  return _green;
      case _ResultType.room:     return const Color(0xFF0284C7);
      case _ResultType.event:    return const Color(0xFF7C3AED);
      case _ResultType.grade:    return _terra;
    }
  }

  IconData get _typeIcon {
    switch (result.type) {
      case _ResultType.student:  return Icons.person_rounded;
      case _ResultType.course:   return Icons.menu_book_rounded;
      case _ResultType.teacher:  return Icons.school_rounded;
      case _ResultType.room:     return Icons.door_front_door_rounded;
      case _ResultType.event:    return Icons.event_rounded;
      case _ResultType.grade:    return Icons.grading_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEE5D8)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title, style: const TextStyle(color: _ink, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(result.subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              )),
              if (result.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(result.badge!, style: TextStyle(color: _typeColor,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(color: _terra, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}
