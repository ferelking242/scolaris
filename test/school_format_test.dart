import 'package:flutter_test/flutter_test.dart';
import 'package:scolaris/core/config/school_format.dart';

/// Le barème et la devise sont lus par TOUS les écrans (bulletin, gradebook,
/// factures). Une régression ici casse silencieusement l'affichage partout,
/// sans jamais lever d'exception — d'où l'intérêt de figer le comportement.
void main() {
  group('SchoolFormat.grade — barème /20 (défaut, secondaire)', () {
    const f = SchoolFormat();

    test('note entière sans décimale', () {
      expect(f.grade(14), '14/20');
    });
    test('note décimale avec virgule française (2 décimales sur /20)', () {
      expect(f.grade(14.5), '14,50/20');
    });
    test('note nulle affichée, pas confondue avec absente', () {
      expect(f.grade(0), '0/20');
    });
    test('note absente = tiret', () {
      expect(f.grade(null), '—');
    });
    test('maxScore et gradeHeader cohérents', () {
      expect(f.maxScore, 20);
      expect(f.gradeHeader, 'Note/20');
    });
  });

  group('SchoolFormat.grade — barème /10 (primaire)', () {
    const f = SchoolFormat(gradingScale: 'numeric_10');

    test('note sur 10, pas convertie sur 20', () {
      expect(f.grade(8.5), '8,5/10');
    });
    test('maxScore = 10', () {
      expect(f.maxScore, 10);
      expect(f.gradeHeader, 'Note/10');
    });
    test('ratio() reste 0→1 quel que soit le barème', () {
      expect(f.ratio(5), closeTo(0.5, 0.001));
    });
  });

  group('SchoolFormat.grade — barème /100', () {
    const f = SchoolFormat(gradingScale: 'numeric_100');
    test('arrondi à l\'entier, pas de décimale', () {
      expect(f.grade(72.4), '72/100');
    });
  });

  group('SchoolFormat.grade — barème lettre', () {
    const f = SchoolFormat(gradingScale: 'letter');
    // Converti via % du maxScore interne (20), donc 14/20 = 70% → 'A'.
    test('conversion numérique interne → lettre', () {
      expect(f.grade(14), 'A'); // 70%
      expect(f.grade(12), 'B'); // 60%
      expect(f.grade(10), 'C'); // 50%
      expect(f.grade(9), 'D');  // 45%
      expect(f.grade(8), 'E');  // 40%
      expect(f.grade(4), 'F');  // 20%
    });
  });

  group('SchoolFormat.money', () {
    test('FCFA : pas de décimales, symbole après, espace milliers', () {
      const f = SchoolFormat();
      // Espace insécable étroite (U+202F) entre les milliers, pas un espace ASCII.
      expect(f.money(150000), '150 000 FCFA');
    });
    test('Euro : 2 décimales, symbole devant', () {
      const f = SchoolFormat(currency: 'EUR');
      expect(f.money(1250.5), '€ 1 250,50');
    });
    test('montant négatif : signe conservé devant les chiffres', () {
      const f = SchoolFormat();
      expect(f.money(-500), '-500 FCFA');
    });
  });

  group('SchoolFormat.periods — piège où saisie et bulletin doivent lire la même liste', () {
    test('trimester (défaut)', () {
      expect(const SchoolFormat().periods, ['T1', 'T2', 'T3']);
    });
    test('semester', () {
      expect(const SchoolFormat(periodSystem: 'semester').periods, ['S1', 'S2']);
    });
    test('monthly avec année scolaire valide : septembre → juin, 10 périodes', () {
      const f = SchoolFormat(periodSystem: 'monthly', academicYear: '2025-2026');
      expect(f.periods.first, '2025-09');
      expect(f.periods.last, '2026-06');
      expect(f.periods.length, 10);
    });
    test('monthly avec année scolaire absente : retombe sur M1..M10, ne plante pas', () {
      const f = SchoolFormat(periodSystem: 'monthly');
      expect(f.periods.first, 'M1');
      expect(f.periods.length, 10);
    });
  });

  group('SchoolFormat.isFinalPeriod — la décision de passage ne doit apparaître qu\'en fin d\'année', () {
    test('T3 est la dernière période en trimestre', () {
      const f = SchoolFormat();
      expect(f.isFinalPeriod('T3'), true);
      expect(f.isFinalPeriod('T1'), false);
    });
    test('dernier mois de l\'année scolaire en periodSystem monthly', () {
      const f = SchoolFormat(periodSystem: 'monthly', academicYear: '2025-2026');
      expect(f.isFinalPeriod('2026-06'), true);
      expect(f.isFinalPeriod('2025-09'), false);
    });
  });
}
