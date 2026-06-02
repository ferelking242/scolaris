import 'package:flutter/material.dart';

// ─── Time slot ────────────────────────────────────────────────────────────────
class TSlot {
  final int sh, sm, eh, em;
  const TSlot(this.sh, this.sm, this.eh, this.em);
  int get startMin => sh * 60 + sm;
  int get endMin   => eh * 60 + em;
  bool overlaps(TSlot o) => startMin < o.endMin && o.startMin < endMin;
  String get label => '${_p(sh)}h${_p(sm)}–${_p(eh)}h${_p(em)}';
  String get start => '${_p(sh)}h${_p(sm)}';
  String get end   => '${_p(eh)}h${_p(em)}';
  static String _p(int v) => v.toString().padLeft(2, '0');
  @override bool operator ==(Object o) =>
      o is TSlot && sh == o.sh && sm == o.sm && eh == o.eh && em == o.em;
  @override int get hashCode => Object.hash(sh, sm, eh, em);
}

const kStdSlots = [
  TSlot(7, 30, 9,  0),
  TSlot(9, 15, 10, 45),
  TSlot(11,  0, 12, 30),
  TSlot(14,  0, 15, 30),
  TSlot(15, 45, 17, 15),
];
const kJoursWeek = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

// ─── Session ──────────────────────────────────────────────────────────────────
class TSession {
  final String id, matiere, enseignant, salle, jour;
  final TSlot   slot;
  final List<String> filieres;
  const TSession({
    required this.id, required this.matiere, required this.enseignant,
    required this.salle, required this.jour, required this.slot,
    required this.filieres,
  });
  Color get color => getSubjectMeta(matiere).color;
  TSession copyWith({String? matiere, String? enseignant, String? salle,
      String? jour, TSlot? slot, List<String>? filieres}) =>
    TSession(id: id,
      matiere: matiere ?? this.matiere, enseignant: enseignant ?? this.enseignant,
      salle: salle ?? this.salle, jour: jour ?? this.jour,
      slot: slot ?? this.slot, filieres: filieres ?? this.filieres);
}

// ─── Conflicts ────────────────────────────────────────────────────────────────
enum TConflictType { salle, enseignant, filiere }

class TConflict {
  final TConflictType type;
  final TSession a, b;
  const TConflict(this.type, this.a, this.b);

  String get description {
    switch (type) {
      case TConflictType.salle:
        return 'Salle ${a.salle} réservée en double : "${a.matiere}" (${a.filieres.join(", ")}) & "${b.matiere}" (${b.filieres.join(", ")}) — ${a.jour} ${a.slot.label}';
      case TConflictType.enseignant:
        return '${a.enseignant} enseignant en double : "${a.matiere}" & "${b.matiere}" — ${a.jour} ${a.slot.label}';
      case TConflictType.filiere:
        final s = a.filieres.toSet().intersection(b.filieres.toSet()).join(', ');
        return 'Filière $s : deux cours simultanés ("${a.matiere}" & "${b.matiere}") — ${a.jour} ${a.slot.label}';
    }
  }
  Color get color {
    switch (type) {
      case TConflictType.salle: return const Color(0xFFDC2626);
      case TConflictType.enseignant: return const Color(0xFFD97706);
      case TConflictType.filiere: return const Color(0xFF7C3AED);
    }
  }
  IconData get icon {
    switch (type) {
      case TConflictType.salle: return Icons.meeting_room_rounded;
      case TConflictType.enseignant: return Icons.person_off_rounded;
      case TConflictType.filiere: return Icons.group_off_rounded;
    }
  }
  String get typeLabel {
    switch (type) {
      case TConflictType.salle: return 'Salle';
      case TConflictType.enseignant: return 'Professeur';
      case TConflictType.filiere: return 'Filière';
    }
  }
}

List<TConflict> detectConflicts(List<TSession> sessions) {
  final result = <TConflict>[];
  final seen   = <String>{};
  for (int i = 0; i < sessions.length; i++) {
    for (int j = i + 1; j < sessions.length; j++) {
      final a = sessions[i], b = sessions[j];
      if (a.jour != b.jour) continue;
      if (!a.slot.overlaps(b.slot)) continue;
      final k = '${a.id}_${b.id}';
      if (a.salle.isNotEmpty && a.salle == b.salle && seen.add('s$k'))
        result.add(TConflict(TConflictType.salle, a, b));
      if (a.enseignant.isNotEmpty && a.enseignant == b.enseignant && seen.add('e$k'))
        result.add(TConflict(TConflictType.enseignant, a, b));
      final shared = a.filieres.toSet().intersection(b.filieres.toSet());
      if (shared.isNotEmpty && seen.add('f$k'))
        result.add(TConflict(TConflictType.filiere, a, b));
    }
  }
  return result;
}

// ─── Subject meta ─────────────────────────────────────────────────────────────
class SubjectMeta {
  final Color color;
  final List<String> symbols;
  final IconData icon;
  const SubjectMeta({required this.color, required this.symbols, required this.icon});
}

const kSubjectMeta = <String, SubjectMeta>{
  'Mathématiques':      SubjectMeta(color: Color(0xFF6D28D9), icon: Icons.calculate_rounded,
      symbols: ['+', '×', '÷', '=', 'π', '√', '∑', '∫', '≤', '²', '≠', 'f(x)']),
  'Maths Avancées':     SubjectMeta(color: Color(0xFF4C1D95), icon: Icons.calculate_rounded,
      symbols: ['∫', 'Σ', '∂', '∇', 'dx', 'lim', '⊗', 'ℝ', 'ℂ', '∞']),
  'Sciences Physiques': SubjectMeta(color: Color(0xFF0EA5E9), icon: Icons.science_rounded,
      symbols: ['⚡', 'λ', 'Ω', 'F', 'V', 'Hz', 'e⁻', '~', 'J', 'N', 'E']),
  'Physique':           SubjectMeta(color: Color(0xFF0284C7), icon: Icons.science_rounded,
      symbols: ['⚡', 'λ', 'Ω', 'F', 'V', 'Hz', '~', 'J', 'N']),
  'Chimie':             SubjectMeta(color: Color(0xFF059669), icon: Icons.biotech_rounded,
      symbols: ['H₂O', 'CO₂', 'O₂', '⚗', '→', '⇌', 'pH']),
  'SVT':                SubjectMeta(color: Color(0xFF2D6A4F), icon: Icons.eco_rounded,
      symbols: ['☘', '◉', '○', '◎', '⬡', '●', '⊗', '⊙']),
  'Biologie':           SubjectMeta(color: Color(0xFF166534), icon: Icons.biotech_rounded,
      symbols: ['☘', '◉', '○', '◎', '⬡', '●', '⊙']),
  'Histoire-Géo':       SubjectMeta(color: Color(0xFFDB2777), icon: Icons.public_rounded,
      symbols: ['◈', '●', '◊', '⊕', '▷', '◆', '↗', '♦']),
  'Géographie':         SubjectMeta(color: Color(0xFFBE185D), icon: Icons.map_rounded,
      symbols: ['◈', '◊', '⊕', '▷', '◆', '♦', '≈']),
  'Histoire':           SubjectMeta(color: Color(0xFFDB2777), icon: Icons.history_edu_rounded,
      symbols: ['◈', '♦', '◊', '⊕', '★', '▷']),
  'Français':           SubjectMeta(color: Color(0xFFEA580C), icon: Icons.menu_book_rounded,
      symbols: ['"', '"', '«', '»', '—', '…', '!', '?', 'é', 'è']),
  'Littérature':        SubjectMeta(color: Color(0xFFDC2626), icon: Icons.auto_stories_rounded,
      symbols: ['"', '"', '«', '»', '—', '…', '§', '¶', '!']),
  'Philosophie':        SubjectMeta(color: Color(0xFF78716C), icon: Icons.psychology_rounded,
      symbols: ['∞', '?', '∀', '∃', '⟹', '¬', '∧', '∨', '⊢']),
  'Anglais':            SubjectMeta(color: Color(0xFF0284C7), icon: Icons.translate_rounded,
      symbols: ['A', 'B', 'C', 'the', 'is', '!', '?', 'abc']),
  'EPS':                SubjectMeta(color: Color(0xFF16A34A), icon: Icons.sports_soccer_rounded,
      symbols: ['◉', '→', '↑', '↗', '◎', '⊙', '◀', '▶', '○']),
  'Sport':              SubjectMeta(color: Color(0xFF15803D), icon: Icons.sports_rounded,
      symbols: ['◉', '→', '↑', '↗', '◎', '⊙', '○']),
  'Informatique':       SubjectMeta(color: Color(0xFF334155), icon: Icons.computer_rounded,
      symbols: ['</>', '{}', '[]', '01', '10', '##', 'if', '=>', '&&']),
  'Algorithmique':      SubjectMeta(color: Color(0xFF1E3A5F), icon: Icons.account_tree_rounded,
      symbols: ['if', 'for', '{', '}', '=>', '[]', 'fn()', '0x', '&&']),
  'Arts':               SubjectMeta(color: Color(0xFFC17F24), icon: Icons.palette_rounded,
      symbols: ['◐', '◑', '●', '○', '★', '✦', '✧', '♥']),
  'Électricité':        SubjectMeta(color: Color(0xFFD97706), icon: Icons.bolt_rounded,
      symbols: ['⚡', 'Ω', 'V', 'A', '~', 'W', '∿', 'kV']),
  'Électronique':       SubjectMeta(color: Color(0xFFB45309), icon: Icons.memory_rounded,
      symbols: ['Ω', 'V', 'A', '~', 'Hz', 'F', 'H', 'dB', 'μ']),
  'Réseaux':            SubjectMeta(color: Color(0xFF0891B2), icon: Icons.hub_rounded,
      symbols: ['◎', '—', '●', '⊗', '◈', '⊙', 'IP', 'LAN']),
  'Comptabilité':       SubjectMeta(color: Color(0xFF7C3AED), icon: Icons.account_balance_rounded,
      symbols: ['€', '÷', '+', '=', '∑', 'Dr', 'Cr', '%']),
};

SubjectMeta getSubjectMeta(String m) =>
    kSubjectMeta[m] ??
    const SubjectMeta(
        color: Color(0xFF6B7280),
        symbols: ['●', '○', '◆', '◇', '▲'],
        icon: Icons.school_rounded);

// ─── Catalogs ─────────────────────────────────────────────────────────────────
const kFilieres = ['Tle C', 'Tle A', '3e A', 'L3 Info', 'L3 Électro', 'BTS Réseaux'];

const kMatieres = [
  'Mathématiques', 'Maths Avancées', 'Sciences Physiques', 'Physique', 'Chimie',
  'SVT', 'Biologie', 'Histoire-Géo', 'Géographie', 'Histoire', 'Français',
  'Littérature', 'Philosophie', 'Anglais', 'EPS', 'Sport', 'Informatique',
  'Algorithmique', 'Arts', 'Électricité', 'Électronique', 'Réseaux', 'Comptabilité',
];

const kProfs = [
  'M. Ngakosso J.-P.', 'Mme Mavoungou C.', 'M. Massamba B.',
  'Mme Nzaba M.', 'M. Tsimba G.', 'Mme Banzouzi P.',
  'M. Mouyabi R.', 'Mme Kikhounga O.', 'M. Ondamba P.',
  'M. Mabika J.-C.', 'M. Ngandzali T.', 'M. Itoua F.',
  'Mme Elenga R.', 'M. Bouya J.', 'Mme Loubaki H.',
];

const kSalles = [
  'A-101', 'A-102', 'A-110', 'A-201', 'A-205',
  'B-101', 'B-102', 'B-103', 'B-201', 'B-204',
  'C-105', 'C-201', 'C-301', 'L-001', 'L-002',
  'Amphi A', 'Amphi B', 'Terrain',
];

// ─── Session data (populated from Supabase schedule_slots table) ─────────────
List<TSession> buildMockSessions() {
  // schedule_slots table is currently empty.
  // Add rows there to populate the timetable.
  return [];
}
