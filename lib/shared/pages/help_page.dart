import 'package:flutter/material.dart';

import '../widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

/// Le centre d'aide : une checklist « Bien démarrer » (l'ordre RÉEL dans
/// lequel une école qui vient de s'inscrire doit configurer l'app — sans
/// grille de frais, impossible d'encaisser ; sans classe, impossible
/// d'inscrire un élève, etc.) + quelques fiches pratiques pour les tâches du
/// quotidien. Contenu statique volontairement : pas de CMS tant qu'il n'y a
/// rien à éditer souvent (cf. discussion 2026-08-04).
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _steps = [
    (
      Icons.school_rounded,
      'Configurer l\'école',
      'Réglages → École : type d\'établissement, système éducatif, année '
          'scolaire. La base dont dépend tout le reste.',
    ),
    (
      Icons.class_rounded,
      'Créer les classes',
      'Classes → Nouvelle classe. Une classe par niveau (CP1, 6ème…) — sans '
          'elle, impossible d\'y rattacher un élève ou une grille de frais.',
    ),
    (
      Icons.payments_rounded,
      'Définir les frais de scolarité',
      'Facturation → Frais de scolarité : tarif mensuel par classe, et '
          'éventuellement des frais d\'inscription/réinscription. Sans cette '
          'étape, aucun encaissement n\'est possible.',
    ),
    (
      Icons.badge_rounded,
      'Inviter le personnel',
      'Personnel → Inviter : profs, secrétaire, comptable — chacun avec son '
          'rôle et ses droits précis.',
    ),
    (
      Icons.groups_rounded,
      'Inscrire les élèves',
      'Élèves & familles → Inscrire un élève, puis rattacher son/ses '
          'parent(s). L\'école est prête à fonctionner.',
    ),
  ];

  static const _guides = [
    (
      Icons.receipt_long_rounded,
      'Encaisser un paiement',
      [
        'Facturation → Comptes scolarité → cherchez l\'élève.',
        'Cliquez « Encaisser » et choisissez Scolarité ou Inscription (ce '
            'sont toujours deux versements séparés).',
        'Saisissez le montant reçu — un reçu est créé immédiatement, '
            'consultable dans Historique des paiements.',
      ],
    ),
    (
      Icons.fact_check_rounded,
      'Saisir des notes et générer un bulletin',
      [
        'Notes & Bulletins → choisissez la classe et la période.',
        'Saisissez les notes par matière (devoirs, composition) — la '
            'moyenne, le rang et la mention se calculent automatiquement.',
        'Cliquez sur un élève pour prévisualiser son bulletin et l\'imprimer.',
      ],
    ),
    (
      Icons.move_up_rounded,
      'Passage de classe en fin d\'année',
      [
        'Passage de classe → choisissez la classe concernée.',
        'Pour chaque élève : Passe, Redouble, Transféré, Diplômé ou '
            'Radiation — la classe de destination est suggérée depuis la '
            'moyenne, mais reste modifiable.',
        'Envoyer en ré-inscription applique tout en un clic — le dossier '
            '(notes, factures) de chaque élève reste intact, rien n\'est '
            'jamais recréé.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Centre d\'aide',
      subtitle: 'Bien démarrer avec Scolaris, et les gestes du quotidien',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DataPanel(
          title: 'Bien démarrer — dans cet ordre',
          child: Column(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              _StepRow(index: i + 1, icon: _steps[i].$1, title: _steps[i].$2, body: _steps[i].$3),
              if (i < _steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: context.cBorder),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        Text('Fiches pratiques',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: context.cInk)),
        const SizedBox(height: 10),
        for (final g in _guides) ...[
          _GuideCard(icon: g.$1, title: g.$2, steps: g.$3),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String body;
  const _StepRow(
      {required this.index, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _terra.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Text('$index',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _terra)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 15, color: context.cMuted),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: context.cInk)),
            ]),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(fontSize: 12, color: context.cMuted, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

class _GuideCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<String> steps;
  const _GuideCard({required this.icon, required this.title, required this.steps});

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: context.cInk)),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: context.cMuted),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < widget.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.cMuted)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.steps[i],
                          style: TextStyle(fontSize: 12.5, color: context.cInk, height: 1.4)),
                    ),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}
