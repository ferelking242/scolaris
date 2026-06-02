import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/surface.dart';
import 'pdf_reader_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _cyan   = Color(0xFF0891B2);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;

class CourseMaterialsPage extends StatefulWidget {
  const CourseMaterialsPage({super.key});
  @override
  State<CourseMaterialsPage> createState() => _CourseMaterialsPageState();
}

class _CourseMaterialsPageState extends State<CourseMaterialsPage> {
  bool _loading = true;
  String _search   = '';
  String _subject  = 'Toutes';
  String _classe   = 'Toutes';
  String _sortBy   = 'Date';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

  List<String> get _subjects {
    final s = <String>{'Toutes'};
    for (final m in MockLibraryData.materials) s.add(m.subject);
    return s.toList();
  }

  List<String> get _classes {
    final s = <String>{'Toutes'};
    for (final m in MockLibraryData.materials) s.add(m.classe);
    return s.toList();
  }

  List<CourseMaterial> get _filtered {
    var list = MockLibraryData.materials.where((m) {
      if (_subject != 'Toutes' && m.subject != _subject) return false;
      if (_classe  != 'Toutes' && m.classe  != _classe)  return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return m.title.toLowerCase().contains(q) ||
            m.subject.toLowerCase().contains(q) ||
            m.teacher.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    if (_sortBy == 'Nom') list.sort((a, b) => a.title.compareTo(b.title));
    if (_sortBy == 'Taille') {
      list.sort((a, b) {
        final aVal = double.tryParse(a.size.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        final bVal = double.tryParse(b.size.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return bVal.compareTo(aVal);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final mats = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _MaterialHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search
            _SearchBar(onChanged: (q) => setState(() => _search = q)),
            const SizedBox(height: 10),
            // Filters row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _ChipFilter(label: 'Matière', options: _subjects, selected: _subject,
                    onSelect: (v) => setState(() => _subject = v)),
                const SizedBox(width: 8),
                _ChipFilter(label: 'Classe', options: _classes, selected: _classe,
                    onSelect: (v) => setState(() => _classe = v)),
                const SizedBox(width: 8),
                _SortButton(current: _sortBy, onSelect: (v) => setState(() => _sortBy = v)),
              ]),
            ),
            const SizedBox(height: 14),

            // Stats overview
            _StatsRow(),
            const SizedBox(height: 14),

            // Count
            Text('${mats.length} support${mats.length > 1 ? 's' : ''}',
                style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            // List
            Skeletonizer(
              enabled: _loading,
              effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
              child: Column(
                children: (_loading ? _placeholders() : mats).map((m) =>
                    Padding(padding: const EdgeInsets.only(bottom: 10),
                        child: _MaterialCard(material: m))).toList(),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  List<CourseMaterial> _placeholders() => List.generate(5, (i) => CourseMaterial(
    id: 'p$i', title: 'Chargement du support…', subject: 'Matière',
    classe: '5e', teacher: 'Prof. …', size: '— MB', addedDate: '-- --- 2026',
    color: _cyan, icon: Icons.description_rounded,
  ));
}

// ── Header ───────────────────────────────────────────────────────────────────
class _MaterialHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF004D5E), _cyan],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 16),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _white),
              onPressed: () => Navigator.pop(context)),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Supports de cours', style: TextStyle(
                color: _white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text('Fiches · Exercices · Révisions', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Text('📄', style: TextStyle(fontSize: 22))),
        ]),
      )),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final downloaded = MockLibraryData.downloadedMaterials.length;
    final favorites  = MockLibraryData.favoriteMaterials.length;
    final sizeMb     = MockLibraryData.downloadedSizeMb;
    return Row(children: [
      _StatCard('${MockLibraryData.totalMaterials}', 'Supports', Icons.folder_rounded, _cyan),
      const SizedBox(width: 8),
      _StatCard('$downloaded', 'Hors-ligne', Icons.download_done_rounded, const Color(0xFF1B5E20)),
      const SizedBox(width: 8),
      _StatCard('$favorites', 'Favoris', Icons.favorite_rounded, const Color(0xFFDB2777)),
      const SizedBox(width: 8),
      _StatCard('${sizeMb.toStringAsFixed(0)} MB', 'Stockage', Icons.storage_rounded, _terra),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String val, label;
  final IconData icon;
  final Color color;
  const _StatCard(this.val, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20))),
    child: Column(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _muted, fontSize: 9.5), textAlign: TextAlign.center),
    ]),
  ));
}

// ── Search ───────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44, decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      const Icon(Icons.search_rounded, size: 18, color: _muted),
      const SizedBox(width: 8),
      Expanded(child: TextField(onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5, color: _ink),
        decoration: const InputDecoration(
          hintText: 'Rechercher un support…', hintStyle: TextStyle(fontSize: 13.5, color: _muted),
          isCollapsed: true, border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10)),
      )),
    ]),
  );
}

// ── Chip filter ──────────────────────────────────────────────────────────────
class _ChipFilter extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const _ChipFilter({required this.label, required this.options,
      required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final active = selected != 'Toutes';
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _PickerSheet(label: label, options: options,
            selected: selected, onSelect: onSelect)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _cyan.withOpacity(0.10) : _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _cyan.withOpacity(0.40) : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: $selected', style: TextStyle(
              color: active ? _cyan : _muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 14, color: active ? _cyan : _muted),
        ]),
      ),
    );
  }
}

// ── Sort button ──────────────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _SortButton({required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(label: 'Trier par',
          options: const ['Date', 'Nom', 'Taille'],
          selected: current, onSelect: onSelect)),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: _terra.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _terra.withOpacity(0.30))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sort_rounded, size: 14, color: _terra),
        const SizedBox(width: 4),
        Text('Tri: $current', style: const TextStyle(
            color: _terra, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const _PickerSheet({required this.label, required this.options,
      required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Padding(padding: const EdgeInsets.all(16),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink))),
    const Divider(height: 1),
    Flexible(child: ListView(shrinkWrap: true, children: options.map((o) => ListTile(
      title: Text(o, style: TextStyle(color: o == selected ? _cyan : _ink,
          fontWeight: o == selected ? FontWeight.w700 : FontWeight.w500)),
      trailing: o == selected ? const Icon(Icons.check_rounded, color: _cyan) : null,
      onTap: () { Navigator.pop(context); onSelect(o); },
    )).toList())),
    const SizedBox(height: 16),
  ]);
}

// ── Material card ─────────────────────────────────────────────────────────────
class _MaterialCard extends StatefulWidget {
  final CourseMaterial material;
  const _MaterialCard({required this.material});
  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}
class _MaterialCardState extends State<_MaterialCard> {
  late bool _fav;
  late bool _dl;
  @override
  void initState() {
    super.initState();
    _fav = widget.material.isFavorite;
    _dl  = widget.material.isDownloaded;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          PdfReaderPage(title: m.title, color: m.color, totalPages: 24))),
      child: Container(
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: m.color.withOpacity(0.18)),
            boxShadow: [BoxShadow(color: m.color.withOpacity(0.08),
                blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: m.color.withOpacity(0.30),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(m.icon, color: _white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(m.subject, style: TextStyle(color: m.color, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Par ${m.teacher}', style: const TextStyle(color: _muted, fontSize: 11.5)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                GestureDetector(
                  onTap: () => setState(() => _fav = !_fav),
                  child: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _fav ? Colors.red.shade400 : _muted, size: 20),
                ),
                const SizedBox(height: 8),
                Text(m.size, style: TextStyle(color: m.color, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: m.color.withOpacity(0.05),
              border: Border(top: BorderSide(color: m.color.withOpacity(0.12))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(children: [
              // Meta chips
              _MetaChip(m.classe, Icons.class_rounded, m.color),
              const SizedBox(width: 6),
              _MetaChip(m.addedDate, Icons.calendar_today_rounded, _muted),
              const Spacer(),
              // Actions
              _IconBtn(icon: Icons.share_rounded, color: m.color, onTap: () {}),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _dl = !_dl),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _dl ? const Color(0xFF1B5E20).withOpacity(0.10) : m.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _dl ? const Color(0xFF1B5E20).withOpacity(0.30) : m.color.withOpacity(0.25)),
                  ),
                  child: Icon(_dl ? Icons.download_done_rounded : Icons.download_rounded,
                      size: 14, color: _dl ? const Color(0xFF1B5E20) : m.color),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.80)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Ouvrir', style: TextStyle(
                    color: _white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MetaChip(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 10, color: color.withOpacity(0.70)),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withOpacity(0.20))),
      child: Icon(icon, size: 14, color: color)),
  );
}
