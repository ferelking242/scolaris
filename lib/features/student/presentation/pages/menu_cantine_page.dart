import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _orange = ScolarisPalette.orange;

// Neutres (texte/fond/bordure) : jamais figés → `context.c*` (page_scaffold).
// `_white` = texte sur fond de marque coloré → constant, OK dans les 2 thèmes.
const _white  = Colors.white;

// ══════════════════════════════════════════════════════════════════════════
// Menu de la cantine — semaine courante, données réelles.
//
// Le menu appartient à l'ÉCOLE (pas à un élève) : la page est donc identique
// pour l'élève et pour le parent, et n'a pas besoin de `studentId`.
// ══════════════════════════════════════════════════════════════════════════
class MenuCantinePage extends ConsumerStatefulWidget {
  const MenuCantinePage({super.key});
  @override
  ConsumerState<MenuCantinePage> createState() => _MenuCantinePageState();
}

class _MenuCantinePageState extends ConsumerState<MenuCantinePage> {
  /// Index du jour sélectionné dans la liste des menus publiés.
  /// null = « pas encore choisi » → on ouvre sur aujourd'hui s'il existe.
  int? _selected;

  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  static const _mois = [
    'janv.','févr.','mars','avr.','mai','juin','juil.','août',
    'sept.','oct.','nov.','déc.'
  ];

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(canteenMenusProvider);

    return menusAsync.when(
      loading: () => const PageScaffold(
        title: 'Menu Cantine 🍽️',
        child: Center(child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (e, _) => PageScaffold(
        title: 'Menu Cantine 🍽️',
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (menus) {
        if (menus.isEmpty) {
          return PageScaffold(
            title: 'Menu Cantine 🍽️',
            subtitle: 'Aucun menu publié',
            child: Column(children: [
              _CanteenHeader(published: false),
              const SizedBox(height: 20),
              const EmptyState(
                icon: Icons.restaurant_outlined,
                title: 'Pas de menu cette semaine',
                description:
                    'L\'école n\'a pas encore publié le menu de la cantine.',
              ),
            ]),
          );
        }

        // À l'ouverture : le jour d'aujourd'hui s'il a un menu, sinon le premier.
        final today = DateTime.now();
        final todayIdx = menus.indexWhere((m) =>
            m.menuDate.year == today.year &&
            m.menuDate.month == today.month &&
            m.menuDate.day == today.day);
        final index = _selected ?? (todayIdx >= 0 ? todayIdx : 0);
        final menu = menus[index];

        final first = menus.first.menuDate;
        final last  = menus.last.menuDate;

        return PageScaffold(
          title: 'Menu Cantine 🍽️',
          subtitle: 'Semaine du ${_d(first)} au ${_d(last)}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _CanteenHeader(published: true),
            const SizedBox(height: 16),

            // ── Sélecteur de jour (uniquement les jours publiés) ───────────
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: menus.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m   = menus[i];
                  final sel = i == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      decoration: BoxDecoration(
                        color: sel ? _terra : context.cCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel ? _terra : context.cBorder),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(_jours[m.menuDate.weekday - 1].substring(0, 3),
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: sel
                                    ? _white.withOpacity(.75)
                                    : context.cMuted)),
                        const SizedBox(height: 2),
                        Text('${m.menuDate.day}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900,
                                color: sel ? _white : context.cInk)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── En-tête du jour ────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _terra,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    '${_jours[menu.menuDate.weekday - 1]} ${_d(menu.menuDate)}',
                    style: const TextStyle(color: _white, fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text(
                  menu.dishes.length > 1
                      ? '${menu.dishes.length} plats'
                      : '${menu.dishes.length} plat',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            ]),
            const SizedBox(height: 12),

            // ── Plats ──────────────────────────────────────────────────────
            if (menu.dishes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: context.cCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.cBorder),
                ),
                child: Text('Aucun plat renseigné pour ce jour.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.cMuted, fontSize: 12.5)),
              )
            else
              for (final p in menu.dishes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DishCard(dish: p),
                ),

            const SizedBox(height: 8),

            // ── Note du jour (allergènes, service exceptionnel…) ────────────
            if (menu.note != null && menu.note!.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withOpacity(.25)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: _gold, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(menu.note!,
                      style: TextStyle(fontSize: 11, color: context.cInk,
                          height: 1.5))),
                ]),
              ),
          ]),
        );
      },
    );
  }

  String _d(DateTime x) => '${x.day} ${_mois[x.month - 1]}';
}

// ── Bandeau cantine ───────────────────────────────────────────────────────────
class _CanteenHeader extends StatelessWidget {
  final bool published;
  const _CanteenHeader({required this.published});

  @override
  Widget build(BuildContext context) {
    final color = published ? _green : context.cMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(children: [
        Icon(Icons.restaurant_rounded, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cantine scolaire',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: context.cInk)),
          const SizedBox(height: 2),
          Text(
              published
                  ? 'Menu publié par l\'école'
                  : 'Aucun menu publié cette semaine',
              style: TextStyle(fontSize: 11, color: context.cMuted)),
        ])),
        if (published)
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
    );
  }
}

// ── Carte plat ────────────────────────────────────────────────────────────────
class _DishCard extends StatelessWidget {
  final SbCanteenDish dish;
  const _DishCard({required this.dish});

  Color get _courseColor => switch (dish.course) {
        'entree' => _green,
        'plat'   => _terra,
        _        => _gold,
      };

  String get _courseLabel => switch (dish.course) {
        'entree' => 'Entrée',
        'plat'   => 'Plat principal',
        _        => 'Dessert',
      };

  @override
  Widget build(BuildContext context) {
    final c = _courseColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: c.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(dish.emoji ?? '🍽️',
              style: const TextStyle(fontSize: 28))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: c.withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_courseLabel, style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
            ),
            if (dish.allergens.isNotEmpty) ...[
              const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded,
                  size: 13, color: _orange),
            ],
          ]),
          const SizedBox(height: 5),
          Text(dish.name, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w800,
              color: context.cInk)),
          if (dish.description != null &&
              dish.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(dish.description!, style: TextStyle(
                fontSize: 11.5, color: context.cMuted, height: 1.4)),
          ],
          if (dish.allergens.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final a in dish.allergens)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('⚠ $a', style: const TextStyle(
                      fontSize: 9.5, color: _orange,
                      fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
        ])),
      ]),
    );
  }
}
