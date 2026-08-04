import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'child_detail_page.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;

/// Liste des enfants du parent connecté — porte d'entrée de tout l'espace.
///
/// Lit `myChildrenProvider` (table `parent_student`). Avant, cette page lisait
/// `studentsProvider` = TOUS les élèves de l'école, avec un repli
/// « les 3 premiers, en démo » : un parent voyait les enfants des autres.
class ChildrenPage extends ConsumerWidget {
  const ChildrenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(myChildrenProvider);
    Future<void> refresh() async {
      ref.invalidate(myChildrenProvider);
      await ref.read(myChildrenProvider.future);
    }

    return childrenAsync.when(
      loading: () => PageScaffold(
        title: 'Mes enfants',
        onRefresh: refresh,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes enfants',
        onRefresh: refresh,
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (children) {
        if (children.isEmpty) {
          return PageScaffold(
            title: 'Mes enfants',
            onRefresh: refresh,
            child: const _NoChildren(),
          );
        }
        return PageScaffold(
          title: 'Mes enfants',
          onRefresh: refresh,
          subtitle: children.length > 1
              ? '${children.length} enfants inscrits'
              : '1 enfant inscrit',
          child: LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 720 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 132,
              ),
              itemBuilder: (_, i) => _ChildCard(student: children[i]),
            );
          }),
        );
      },
    );
  }
}

class _ChildCard extends ConsumerWidget {
  final SbStudent student;
  const _ChildCard({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aperçu : la moyenne, calculée sur les vraies notes de CET enfant.
    final grades = ref.watch(gradesForStudentProvider(student.id));
    final list   = grades.valueOrNull ?? const <SbGrade>[];
    final moyenne = list.isEmpty
        ? null
        : list.fold<double>(0, (s, g) => s + g.outOf20) / list.length;

    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChildDetailPage(child: student),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Avatar(name: student.fullName, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName,
                          style: TextStyle(fontSize: 14.5, color: context.cInk,
                              fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(student.classe ?? 'Classe non renseignée',
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                    ])),
                if (moyenne != null)
                  Column(children: [
                    Text(moyenne.toStringAsFixed(1),
                        style: const TextStyle(color: _gold, fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text('/20', style: TextStyle(
                        color: context.cMuted, fontSize: 10)),
                  ]),
              ]),
              const Spacer(),
              Row(children: [
                _Chip(icon: Icons.badge_outlined,
                    label: student.matricule ?? '—'),
                const SizedBox(width: 12),
                _Chip(icon: Icons.school_outlined,
                    label: student.niveau ?? '—'),
                const Spacer(),
                const Text('Voir sa fiche',
                    style: TextStyle(color: _terra, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded,
                    color: _terra, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: context.cMuted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: context.cMuted)),
      ]);
}

/// Aucun enfant rattaché : ce n'est pas une erreur, c'est un lien manquant que
/// seule l'école peut créer (table `parent_student`).
class _NoChildren extends StatelessWidget {
  const _NoChildren();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          Icon(Icons.family_restroom_rounded,
              size: 48, color: context.cMuted.withOpacity(.4)),
          const SizedBox(height: 14),
          Text('Aucun enfant rattaché',
              style: TextStyle(color: context.cInk, fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Votre compte n\'est relié à aucun élève. '
              'Contactez l\'établissement pour qu\'il rattache votre enfant '
              'à votre compte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cMuted, fontSize: 12.5,
                  height: 1.5),
            ),
          ),
        ]),
      );
}
