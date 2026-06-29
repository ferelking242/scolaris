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
class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explication;
  const _QuizQuestion({
    required this.question, required this.options,
    required this.correctIndex, required this.explication,
  });
}

class _QuizSet {
  final String matiere;
  final String titre;
  final int nbQuestions;
  final int dureeMin;
  final Color color;
  final IconData icon;
  final List<_QuizQuestion> questions;
  const _QuizSet({
    required this.matiere, required this.titre, required this.nbQuestions,
    required this.dureeMin, required this.color, required this.icon,
    required this.questions,
  });
}

const _quizSets = [
  _QuizSet(
    matiere: 'Mathématiques', titre: 'Dérivées — Niveau Terminale',
    nbQuestions: 5, dureeMin: 10, color: _terra, icon: Icons.calculate_rounded,
    questions: [
      _QuizQuestion(
        question: 'Quelle est la dérivée de f(x) = x³ + 2x² - 5x + 1 ?',
        options: ['f\'(x) = 3x² + 4x - 5', 'f\'(x) = 3x² + 2x - 5', 'f\'(x) = x² + 4x', 'f\'(x) = 3x + 4'],
        correctIndex: 0,
        explication: 'On dérive terme à terme : (x³)\' = 3x², (2x²)\' = 4x, (-5x)\' = -5, (1)\' = 0.',
      ),
      _QuizQuestion(
        question: 'f(x) = sin(2x), quelle est f\'(x) ?',
        options: ['cos(2x)', '2cos(2x)', '-2cos(2x)', 'sin(2x)'],
        correctIndex: 1,
        explication: 'Règle de la chaîne : f\'(x) = 2 × cos(2x).',
      ),
      _QuizQuestion(
        question: 'La dérivée de e^(3x) est :',
        options: ['e^(3x)', '3e^(3x)', 'e^(3)', '3x·e^(x)'],
        correctIndex: 1,
        explication: '(e^(ax))\' = a·e^(ax), donc ici a=3.',
      ),
      _QuizQuestion(
        question: 'f(x) = ln(x²+1), f\'(x) = ?',
        options: ['1/(x²+1)', '2x/(x²+1)', 'ln(2x)', '2/(x²+1)'],
        correctIndex: 1,
        explication: '(ln(u))\' = u\'/u. Ici u = x²+1, u\' = 2x.',
      ),
      _QuizQuestion(
        question: 'Si f est strictement croissante sur [a,b], alors f\' est :',
        options: ['Négative', 'Positive ou nulle', 'Forcément positive', 'Nulle partout'],
        correctIndex: 1,
        explication: 'f croissante ⟹ f\'(x) ≥ 0 sur [a,b] (positive ou nulle).',
      ),
    ],
  ),
  _QuizSet(
    matiere: 'Sciences Physiques', titre: 'Électricité — Loi d\'Ohm et circuits',
    nbQuestions: 4, dureeMin: 8, color: _green, icon: Icons.science_rounded,
    questions: [
      _QuizQuestion(
        question: 'La loi d\'Ohm établit que U = ?',
        options: ['U = R/I', 'U = R×I', 'U = I²×R', 'U = P/I²'],
        correctIndex: 1,
        explication: 'La loi d\'Ohm : U = R×I (tension = résistance × intensité).',
      ),
      _QuizQuestion(
        question: 'En série, la résistance équivalente est :',
        options: ['R_éq = R₁ × R₂', 'R_éq = R₁ + R₂', '1/R_éq = 1/R₁ + 1/R₂', 'R_éq = (R₁ + R₂)/2'],
        correctIndex: 1,
        explication: 'En série : R_éq = R₁ + R₂ + ... (les résistances s\'additionnent).',
      ),
      _QuizQuestion(
        question: 'La puissance électrique P est égale à :',
        options: ['P = U/I', 'P = U²/R', 'P = U×I', 'P = R×I'],
        correctIndex: 2,
        explication: 'P = U×I (et aussi P = R×I² = U²/R par substitution).',
      ),
      _QuizQuestion(
        question: 'En dérivation (parallèle), les tensions aux bornes de chaque branche sont :',
        options: ['Différentes', 'Égales', 'La somme de U total', 'Proportionnelles aux résistances'],
        correctIndex: 1,
        explication: 'En parallèle : la tension est la même aux bornes de chaque branche.',
      ),
    ],
  ),
  _QuizSet(
    matiere: 'Algorithmique', titre: 'Complexité et algorithmes de tri',
    nbQuestions: 4, dureeMin: 8, color: Color(0xFF6D28D9), icon: Icons.code_rounded,
    questions: [
      _QuizQuestion(
        question: 'Quelle est la complexité dans le pire cas du tri à bulles ?',
        options: ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
        correctIndex: 2,
        explication: 'Le tri à bulles compare chaque paire : O(n²) dans le pire cas.',
      ),
      _QuizQuestion(
        question: 'La dichotomie (recherche binaire) a une complexité de :',
        options: ['O(n)', 'O(log n)', 'O(n²)', 'O(1)'],
        correctIndex: 1,
        explication: 'À chaque étape on divise l\'espace par 2 : O(log n).',
      ),
      _QuizQuestion(
        question: 'Le quicksort a une complexité moyenne de :',
        options: ['O(n)', 'O(n²)', 'O(n log n)', 'O(log n)'],
        correctIndex: 2,
        explication: 'En moyenne, quicksort est O(n log n). Pire cas : O(n²).',
      ),
      _QuizQuestion(
        question: 'Une file (queue) suit le principe :',
        options: ['LIFO', 'FIFO', 'Aléatoire', 'Priorité'],
        correctIndex: 1,
        explication: 'FIFO = First In, First Out. La pile (stack) suit LIFO.',
      ),
    ],
  ),
];

// ── Page principale ───────────────────────────────────────────────────────────
class AnnalesQuizPage extends StatefulWidget {
  const AnnalesQuizPage({super.key});
  @override
  State<AnnalesQuizPage> createState() => _AnnalesQuizPageState();
}

class _AnnalesQuizPageState extends State<AnnalesQuizPage> {
  _QuizSet? _activeQuiz;

  @override
  Widget build(BuildContext context) {
    if (_activeQuiz != null) {
      return _QuizRunner(
        quiz: _activeQuiz!,
        onFinish: () => setState(() => _activeQuiz = null),
      );
    }

    return PageScaffold(
      title: 'Annales & Quiz',
      subtitle: 'Entraîne-toi avant les examens',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Bannière motivation ─────────────────────────────────────────────
        Container(
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
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _white.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.quiz_rounded, color: _white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quiz d\'auto-évaluation', style: TextStyle(
                  color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Teste tes connaissances par matière · Correction immédiate',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        const Text('Choisir un quiz', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 12),

        ..._quizSets.map((q) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _QuizCard(
            quiz: q,
            onStart: () => setState(() => _activeQuiz = q),
          ),
        )),
      ]),
    );
  }
}

// ── Carte quiz ────────────────────────────────────────────────────────────────
class _QuizCard extends StatelessWidget {
  final _QuizSet quiz;
  final VoidCallback onStart;
  const _QuizCard({required this.quiz, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: quiz.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(quiz.icon, color: quiz.color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(quiz.titre, style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 3),
          Text(quiz.matiere, style: TextStyle(fontSize: 11.5, color: quiz.color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Row(children: [
            _Chip(label: '${quiz.nbQuestions} questions', color: _muted),
            const SizedBox(width: 6),
            _Chip(label: '${quiz.dureeMin} min', color: _muted),
          ]),
        ])),
        GestureDetector(
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: quiz.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Commencer', style: TextStyle(
                color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── Runner de quiz ────────────────────────────────────────────────────────────
class _QuizRunner extends StatefulWidget {
  final _QuizSet quiz;
  final VoidCallback onFinish;
  const _QuizRunner({required this.quiz, required this.onFinish});
  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _current = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _done = false;

  _QuizQuestion get q => widget.quiz.questions[_current];

  void _answer(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _answered = true;
      if (i == q.correctIndex) _score++;
    });
  }

  void _next() {
    if (_current < widget.quiz.questions.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    } else {
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult();

    final total = widget.quiz.questions.length;
    final progress = (_current + 1) / total;

    return Container(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              GestureDetector(
                onTap: widget.onFinish,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _white, shape: BoxShape.circle, border: Border.all(color: _border)),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: _ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.quiz.titre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
                Text('Question ${_current + 1} sur $total',
                    style: const TextStyle(fontSize: 11, color: _muted)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _terra.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_score/$total', style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: _terra)),
              ),
            ]),
            const SizedBox(height: 14),

            // Progression
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: _border.withOpacity(.5),
                valueColor: AlwaysStoppedAnimation(widget.quiz.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 24),

            // Question
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Text(q.question,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink, height: 1.5)),
            ),
            const SizedBox(height: 16),

            // Options
            ...q.options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              Color bg = _white;
              Color border = _border;
              Color textColor = _ink;
              IconData? trailingIcon;

              if (_answered) {
                if (i == q.correctIndex) {
                  bg = _green.withOpacity(.1); border = _green; textColor = _green;
                  trailingIcon = Icons.check_circle_rounded;
                } else if (i == _selected) {
                  bg = _terra.withOpacity(.1); border = _terra; textColor = _terra;
                  trailingIcon = Icons.cancel_rounded;
                }
              } else if (_selected == i) {
                bg = widget.quiz.color.withOpacity(.08);
                border = widget.quiz.color;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _answer(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: border.withOpacity(.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: Text(
                            String.fromCharCode('A'.codeUnitAt(0) + i),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: border == _border ? _muted : border))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(opt, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: textColor))),
                      if (trailingIcon != null) Icon(trailingIcon, color: border, size: 18),
                    ]),
                  ),
                ),
              );
            }),

            // Explication
            if (_answered) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withOpacity(.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_rounded, color: _gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(q.explication,
                      style: const TextStyle(fontSize: 12, color: _ink, height: 1.5))),
                ]),
              ),
            ],
            const Spacer(),

            // Bouton suivant
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.quiz.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _next,
                  child: Text(
                    _current < widget.quiz.questions.length - 1 ? 'Question suivante →' : 'Voir mon résultat',
                    style: const TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final total = widget.quiz.questions.length;
    final pct = _score / total;
    final color = pct >= 0.8 ? _green : pct >= 0.5 ? _gold : _terra;
    final mention = pct >= 0.8 ? 'Excellent !' : pct >= 0.6 ? 'Bien joué !' : pct >= 0.4 ? 'Continuez !' : 'À revoir';

    return Container(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(.3), width: 2),
              ),
              child: Icon(pct >= 0.8 ? Icons.emoji_events_rounded : Icons.bar_chart_rounded,
                  color: color, size: 36),
            ),
            const SizedBox(height: 20),
            Text(mention, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 8),
            Text('$_score / $total bonnes réponses',
                style: const TextStyle(fontSize: 16, color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${(pct * 100).round()} %',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onFinish,
                  child: const Text('Retour', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.quiz.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() {
                    _current = 0; _selected = null; _answered = false; _score = 0; _done = false;
                  }),
                  child: const Text('Recommencer', style: TextStyle(color: _white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
