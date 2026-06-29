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
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Data ──────────────────────────────────────────────────────────────────────
class _Plat {
  final String nom;
  final String description;
  final String emoji;
  final String categorie; // 'entrée' | 'plat' | 'dessert'
  final List<String> allergenes;
  const _Plat({
    required this.nom, required this.description, required this.emoji,
    required this.categorie, this.allergenes = const [],
  });
}

class _MenuJour {
  final String jour;
  final String date;
  final List<_Plat> plats;
  const _MenuJour({required this.jour, required this.date, required this.plats});
}

const _menus = [
  _MenuJour(jour: 'Lundi', date: '30 Juin', plats: [
    _Plat(nom: 'Salade de tomates', description: 'Tomates fraîches, oignons, persil', emoji: '🥗', categorie: 'entrée'),
    _Plat(nom: 'Poulet braisé / Riz', description: 'Poulet mariné aux épices locales avec riz blanc', emoji: '🍗', categorie: 'plat'),
    _Plat(nom: 'Banane plantain', description: 'Plantain frit croustillant', emoji: '🍌', categorie: 'dessert'),
  ]),
  _MenuJour(jour: 'Mardi', date: '1 Juil', plats: [
    _Plat(nom: 'Avocat vinaigrette', description: 'Avocat mûr, citron, huile d\'olive', emoji: '🥑', categorie: 'entrée'),
    _Plat(nom: 'Saka-saka / Fufu', description: 'Feuilles de manioc pilées, poisson fumé', emoji: '🍲', categorie: 'plat', allergenes: ['Poisson']),
    _Plat(nom: 'Orange', description: 'Fruit frais de saison', emoji: '🍊', categorie: 'dessert'),
  ]),
  _MenuJour(jour: 'Mercredi', date: '2 Juil', plats: [
    _Plat(nom: 'Soupe de légumes', description: 'Légumes du marché, bouillon maison', emoji: '🥣', categorie: 'entrée'),
    _Plat(nom: 'Poisson grillé / Attiéké', description: 'Poisson entier grillé avec semoule de manioc', emoji: '🐟', categorie: 'plat', allergenes: ['Poisson']),
    _Plat(nom: 'Yaourt nature', description: 'Yaourt local', emoji: '🍦', categorie: 'dessert', allergenes: ['Lait']),
  ]),
  _MenuJour(jour: 'Jeudi', date: '3 Juil', plats: [
    _Plat(nom: 'Niébé en salade', description: 'Haricots blancs, oignons, épices', emoji: '🫘', categorie: 'entrée'),
    _Plat(nom: 'Bœuf en sauce / Riz', description: 'Ragoût de bœuf aux légumes africains', emoji: '🍛', categorie: 'plat'),
    _Plat(nom: 'Papaye', description: 'Papaye fraîche de saison', emoji: '🍈', categorie: 'dessert'),
  ]),
  _MenuJour(jour: 'Vendredi', date: '4 Juil', plats: [
    _Plat(nom: 'Crudités maison', description: 'Carottes râpées, chou, maïs', emoji: '🥕', categorie: 'entrée'),
    _Plat(nom: 'Tibico (haricots) / Bouillie', description: 'Haricots rouges en sauce, bouillie de maïs', emoji: '🫙', categorie: 'plat'),
    _Plat(nom: 'Mangue', description: 'Mangue fraîche locale', emoji: '🥭', categorie: 'dessert'),
  ]),
];

// ── Page principale ───────────────────────────────────────────────────────────
class MenuCantinePage extends StatefulWidget {
  const MenuCantinePage({super.key});
  @override
  State<MenuCantinePage> createState() => _MenuCantinePageState();
}

class _MenuCantinePageState extends State<MenuCantinePage> {
  int _jourIndex = 0;

  @override
  Widget build(BuildContext context) {
    final menu = _menus[_jourIndex];

    return PageScaffold(
      title: 'Menu Cantine 🍽️',
      subtitle: 'Semaine du 30 Juin au 4 Juillet',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Infos cantine ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _green.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withOpacity(.2)),
          ),
          child: Row(children: [
            const Icon(Icons.restaurant_rounded, color: _green, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cantine de l\'École Primaire',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
              SizedBox(height: 2),
              Text('Service de 12h à 13h30 · Tarif : 500 FCFA/repas',
                  style: TextStyle(fontSize: 11, color: _muted)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Ouvert', style: TextStyle(
                  color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Sélecteur de jour ───────────────────────────────────────────────
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _menus.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final m = _menus[i];
              final sel = i == _jourIndex;
              return GestureDetector(
                onTap: () => setState(() => _jourIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  decoration: BoxDecoration(
                    color: sel ? _terra : _white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? _terra : _border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(m.jour.substring(0, 3),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: sel ? _white.withOpacity(.75) : _muted)),
                    const SizedBox(height: 2),
                    Text(m.date.split(' ').first,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900,
                            color: sel ? _white : _ink)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── En-tête jour ────────────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _terra,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${menu.jour} ${menu.date}',
                style: const TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          const Text('3 plats', style: TextStyle(fontSize: 12, color: _muted)),
        ]),
        const SizedBox(height: 12),

        // ── Plats ───────────────────────────────────────────────────────────
        ...menu.plats.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlatCard(plat: p),
        )),

        const SizedBox(height: 8),

        // ── Note allergènes ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _gold.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withOpacity(.25)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: _gold, size: 15),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Les allergènes sont indiqués sur chaque plat. Signalez toute allergie alimentaire à l\'infirmerie.',
              style: TextStyle(fontSize: 11, color: _ink, height: 1.5),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Carte plat ────────────────────────────────────────────────────────────────
class _PlatCard extends StatelessWidget {
  final _Plat plat;
  const _PlatCard({required this.plat});

  Color get _catColor {
    switch (plat.categorie) {
      case 'entrée': return _green;
      case 'plat': return _terra;
      default: return _gold;
    }
  }

  String get _catLabel {
    switch (plat.categorie) {
      case 'entrée': return 'Entrée';
      case 'plat': return 'Plat principal';
      default: return 'Dessert';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        // Emoji plat
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: _catColor.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(plat.emoji, style: const TextStyle(fontSize: 28))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _catColor.withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_catLabel, style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: _catColor)),
            ),
            if (plat.allergenes.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(Icons.warning_amber_rounded, size: 13, color: _orange),
            ],
          ]),
          const SizedBox(height: 5),
          Text(plat.nom, style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 3),
          Text(plat.description, style: const TextStyle(
              fontSize: 11.5, color: _muted, height: 1.4)),
          if (plat.allergenes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, children: plat.allergenes.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _orange.withOpacity(.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('⚠ $a', style: const TextStyle(
                  fontSize: 9.5, color: _orange, fontWeight: FontWeight.w600)),
            )).toList()),
          ],
        ])),
      ]),
    );
  }
}
