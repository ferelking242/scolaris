import 'package:flutter_test/flutter_test.dart';
import 'package:scolaris/core/bulletin/bulletin_math.dart';
import 'package:scolaris/data/sources/remote/supabase_db_source.dart';

/// Le calcul du bulletin, vérifié contre un VRAI bulletin.
///
/// Complexe Scolaire Bilingue Félix Éboué — Brazzaville.
/// MOMBEKI Jules Hardly, Première Scientifique, T1 2022-2023.
/// Moyenne 12,28 · Rang 4ᵉ · Total 368,33 · Coef 30.
///
/// Si ces chiffres changent, c'est le calcul qui a bougé — pas le bulletin.
/// Un bulletin faux, c'est un élève qui redouble à tort.
void main() {
  // Les 9 matières du bulletin : nom, coef, [Devoir 1, Devoir 2, D.D], Compo,
  // puis ce que le PAPIER affiche : M.C, Moy, Total.
  const rows = [
    ('Français', 3, [12.50, 10.00, 13.00], 12.50, 11.83, 12.17, 36.50),
    ('Anglais', 3, [10.00, 11.00, 15.00], 11.50, 12.00, 11.75, 35.25),
    ('Philosophie', 3, [10.00, 11.00, 11.00], 10.00, 10.67, 10.33, 31.00),
    ('Histoire - Géographie', 3, [12.50, 12.00, 14.50], 13.00, 13.00, 14.75, 44.25),
    ('SVT', 4, [13.00, 14.00, 11.00], 13.00, 12.67, 12.83, 51.33),
    ('Sciences Physiques', 5, [11.00, 11.00, 13.00], 12.00, 11.67, 11.83, 59.17),
    ('Mathématiques', 5, [11.00, 9.50, 11.00], 11.00, 10.50, 10.75, 53.75),
    ('Informatiques', 1, [15.00, 14.00, 15.00], 16.00, 14.67, 15.33, 15.33),
    ('Éducation Civique et Morale', 1, [11.00, 14.00, 15.50], 17.00, 13.50, 15.25, 15.25),
    ('Éducation Physique et Sportive', 2, [12.00, 13.50, 12.00], 14.00, 12.50, 13.25, 26.50),
  ];

  SbGrade g(String subject, String type, int seq, double score) => SbGrade(
        id: '$subject-$type-$seq',
        studentId: 'jules',
        subjectId: subject,
        score: score,
        period: 'T1',
        type: type,
        sequence: seq,
      );

  test('la moyenne d’une matière suit la règle du bulletin, pas une moyenne bête', () {
    // Histoire-Géographie du bulletin : M.C 13,00 mais Moy 14,75 — ces deux
    // valeurs sont incompatibles avec (13,00 + 13,00)/2 = 13,00. Le papier a
    // manifestement une coquille sur cette ligne (Total 44,25 = 14,75 × 3, donc
    // c'est bien 14,75 qui est retenu). On la met de côté et on vérifie les
    // NEUF autres, où le calcul tombe juste au centime.
    final rules = const BulletinRules(devoirs: 3, compoWeight: 0.5);

    for (final r in rows) {
      final (name, coef, devoirs, compo, mc, moy, total) = r;
      if (name == 'Histoire - Géographie') continue;

      final result = buildBulletins(
        studentIds: const ['jules'],
        programme: [
          SbCourse(
              id: name, schoolId: 's', classId: 'c',
              subjectId: name, name: name, coefficient: coef),
        ],
        grades: [
          for (var i = 0; i < devoirs.length; i++)
            g(name, 'devoir', i + 1, devoirs[i]),
          g(name, 'examen', 1, compo),
        ],
        rules: rules,
      )['jules']!;

      final line = result.lines.single;
      expect(line.mc, closeTo(mc, 0.01), reason: '$name — M.C');
      expect(line.average, closeTo(moy, 0.01), reason: '$name — Moy');
      expect(line.total, closeTo(total, 0.01), reason: '$name — Total');
    }
  });

  test('la moyenne générale est la somme des totaux sur la somme des coefs', () {
    final grades = <SbGrade>[];
    final programme = <SbCourse>[];
    for (final r in rows) {
      final (name, coef, devoirs, compo, _, _, _) = r;
      programme.add(SbCourse(
          id: name, schoolId: 's', classId: 'c',
          subjectId: name, name: name, coefficient: coef));
      for (var i = 0; i < devoirs.length; i++) {
        grades.add(g(name, 'devoir', i + 1, devoirs[i]));
      }
      grades.add(g(name, 'examen', 1, compo));
    }

    final b = buildBulletins(
      studentIds: const ['jules'],
      programme: programme,
      grades: grades,
      rules: const BulletinRules(),
    )['jules']!;

    // Σ Coef = 30, exactement comme le papier.
    expect(b.totalCoef, 30);
    // La moyenne du papier : 12,28. (Elle inclut la ligne Histoire-Géo à 14,75 ;
    // notre calcul donne 13,00 pour cette ligne, d'où l'écart attendu de
    // (14,75-13,00) × 3 / 30 = 0,175.)
    expect(b.average, closeTo(12.28 - 0.175, 0.02));
    expect(b.mention, 'Assez-Bien');
    expect(b.decision, 'ADMIS(E)');
  });

  test('le rang par matière et le rang général classent bien la classe', () {
    SbGrade gg(String sid, String subj, String type, int seq, double v) =>
        SbGrade(
            id: '$sid-$subj-$type-$seq',
            studentId: sid,
            subjectId: subj,
            score: v,
            period: 'T1',
            type: type,
            sequence: seq);

    final b = buildBulletins(
      studentIds: const ['a', 'b', 'c'],
      programme: const [
        SbCourse(
            id: 'maths', schoolId: 's', classId: 'c',
            subjectId: 'maths', name: 'Maths', coefficient: 4),
      ],
      grades: [
        gg('a', 'maths', 'devoir', 1, 10), gg('a', 'maths', 'examen', 1, 10),
        gg('b', 'maths', 'devoir', 1, 18), gg('b', 'maths', 'examen', 1, 18),
        gg('c', 'maths', 'devoir', 1, 14), gg('c', 'maths', 'examen', 1, 14),
      ],
      rules: const BulletinRules(),
    );

    expect(b['b']!.rank, 1);
    expect(b['c']!.rank, 2);
    expect(b['a']!.rank, 3);
    expect(b['b']!.lines.single.rank, 1); // le « RG » de la matière
    expect(b['a']!.classSize, 3);
    expect(b['a']!.classAverage, closeTo(14.0, 0.01));
    expect(b['a']!.bestAverage, 18);
    expect(b['a']!.worstAverage, 10);
  });

  test('une composition manquante ne vaut pas zéro', () {
    SbGrade ga(String subject, String type, int seq, double score) => SbGrade(
          id: '$subject-$type-$seq',
          studentId: 'a',
          subjectId: subject,
          score: score,
          period: 'T1',
          type: type,
          sequence: seq,
        );
    // En cours de trimestre, la compo n'est pas passée. Si on la comptait comme
    // un zéro, tous les parents verraient leur enfant s'effondrer.
    final b = buildBulletins(
      studentIds: const ['a'],
      programme: const [
        SbCourse(
            id: 'maths', schoolId: 's', classId: 'c',
            subjectId: 'maths', name: 'Maths', coefficient: 2),
      ],
      grades: [ga('maths', 'devoir', 1, 14), ga('maths', 'devoir', 2, 16)],
      rules: const BulletinRules(),
    )['a']!;

    expect(b.lines.single.mc, 15);
    expect(b.lines.single.average, 15); // et non 7,5
  });
}
