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
  'Mathématiques':         SubjectMeta(color: Color(0xFF6D28D9), icon: Icons.calculate_rounded,
      symbols: ['+', '×', '÷', '=', 'π', '√', '∑', '∫', '≤', '²', '≠', 'f(x)']),
  'Maths Avancées':        SubjectMeta(color: Color(0xFF4C1D95), icon: Icons.calculate_rounded,
      symbols: ['∫', 'Σ', '∂', '∇', 'dx', 'lim', '⊗', 'ℝ', 'ℂ', '∞']),
  'Sciences Physiques':    SubjectMeta(color: Color(0xFF0EA5E9), icon: Icons.science_rounded,
      symbols: ['⚡', 'λ', 'Ω', 'F', 'V', 'Hz', 'e⁻', '~', 'J', 'N', 'E']),
  'Physique':              SubjectMeta(color: Color(0xFF0284C7), icon: Icons.science_rounded,
      symbols: ['⚡', 'λ', 'Ω', 'F', 'V', 'Hz', '~', 'J', 'N']),
  'Chimie':                SubjectMeta(color: Color(0xFF059669), icon: Icons.biotech_rounded,
      symbols: ['H₂O', 'CO₂', 'O₂', '⚗', '→', '⇌', 'pH']),
  'SVT':                   SubjectMeta(color: Color(0xFF2D6A4F), icon: Icons.eco_rounded,
      symbols: ['☘', '◉', '○', '◎', '⬡', '●', '⊗', '⊙']),
  'Biologie':              SubjectMeta(color: Color(0xFF166534), icon: Icons.biotech_rounded,
      symbols: ['☘', '◉', '○', '◎', '⬡', '●', '⊙']),
  'Histoire-Géo':          SubjectMeta(color: Color(0xFFDB2777), icon: Icons.public_rounded,
      symbols: ['◈', '●', '◊', '⊕', '▷', '◆', '↗', '♦']),
  'Géographie':            SubjectMeta(color: Color(0xFFBE185D), icon: Icons.map_rounded,
      symbols: ['◈', '◊', '⊕', '▷', '◆', '♦', '≈']),
  'Histoire':              SubjectMeta(color: Color(0xFFDB2777), icon: Icons.history_edu_rounded,
      symbols: ['◈', '♦', '◊', '⊕', '★', '▷']),
  'Français':              SubjectMeta(color: Color(0xFFEA580C), icon: Icons.menu_book_rounded,
      symbols: ['"', '"', '«', '»', '—', '…', '!', '?', 'é', 'è']),
  'Littérature':           SubjectMeta(color: Color(0xFFDC2626), icon: Icons.auto_stories_rounded,
      symbols: ['"', '"', '«', '»', '—', '…', '§', '¶', '!']),
  'Philosophie':           SubjectMeta(color: Color(0xFF78716C), icon: Icons.psychology_rounded,
      symbols: ['∞', '?', '∀', '∃', '⟹', '¬', '∧', '∨', '⊢']),
  'Anglais':               SubjectMeta(color: Color(0xFF0284C7), icon: Icons.translate_rounded,
      symbols: ['A', 'B', 'C', 'the', 'is', '!', '?', 'abc']),
  'EPS':                   SubjectMeta(color: Color(0xFF16A34A), icon: Icons.sports_soccer_rounded,
      symbols: ['◉', '→', '↑', '↗', '◎', '⊙', '◀', '▶', '○']),
  'Sport':                 SubjectMeta(color: Color(0xFF15803D), icon: Icons.sports_rounded,
      symbols: ['◉', '→', '↑', '↗', '◎', '⊙', '○']),
  'Informatique':          SubjectMeta(color: Color(0xFF334155), icon: Icons.computer_rounded,
      symbols: ['</>', '{}', '[]', '01', '10', '##', 'if', '=>', '&&']),
  'Algorithmique':         SubjectMeta(color: Color(0xFF1E3A5F), icon: Icons.account_tree_rounded,
      symbols: ['if', 'for', '{', '}', '=>', '[]', 'fn()', '0x', '&&']),
  'Arts':                  SubjectMeta(color: Color(0xFFC17F24), icon: Icons.palette_rounded,
      symbols: ['◐', '◑', '●', '○', '★', '✦', '✧', '♥']),
  'Électricité':           SubjectMeta(color: Color(0xFFD97706), icon: Icons.bolt_rounded,
      symbols: ['⚡', 'Ω', 'V', 'A', '~', 'W', '∿', 'kV']),
  'Électronique':          SubjectMeta(color: Color(0xFFB45309), icon: Icons.memory_rounded,
      symbols: ['Ω', 'V', 'A', '~', 'Hz', 'F', 'H', 'dB', 'μ']),
  'Réseaux':               SubjectMeta(color: Color(0xFF0891B2), icon: Icons.hub_rounded,
      symbols: ['◎', '—', '●', '⊗', '◈', '⊙', 'IP', 'LAN']),
  'Comptabilité':          SubjectMeta(color: Color(0xFF7C3AED), icon: Icons.account_balance_rounded,
      symbols: ['€', '÷', '+', '=', '∑', 'Dr', 'Cr', '%']),
  // ── EMI spécifiques ───────────────────────────────────────────────────────
  'Sciences de l\'Ingénieur': SubjectMeta(color: Color(0xFF0F766E), icon: Icons.precision_manufacturing_rounded,
      symbols: ['⚙', '⟳', '▲', '◈', '◎', '⊕', '⊗', '✦']),
  'Dessin Technique':      SubjectMeta(color: Color(0xFF0369A1), icon: Icons.architecture_rounded,
      symbols: ['⬜', '◻', '▭', '—', '|', '⌐', '⌐', '⊓']),
  'Technologie':           SubjectMeta(color: Color(0xFF7C3AED), icon: Icons.settings_rounded,
      symbols: ['⚙', '⟳', '⊕', '▲', '●', '◎', '⊗']),
  'Mécanique':             SubjectMeta(color: Color(0xFF92400E), icon: Icons.build_rounded,
      symbols: ['⚙', '⟳', '▲', '⊕', '⊗', '●', '◎']),
};

SubjectMeta getSubjectMeta(String m) =>
    kSubjectMeta[m] ??
    const SubjectMeta(
        color: Color(0xFF6B7280),
        symbols: ['●', '○', '◆', '◇', '▲'],
        icon: Icons.school_rounded);

// ─── Catalogs ─────────────────────────────────────────────────────────────────
const kFilieres = ['EMI', 'Tle C', 'Tle A', '3e A', 'L3 Info', 'L3 Électro', 'BTS Réseaux'];

const kMatieres = [
  'Mathématiques', 'Maths Avancées', 'Sciences Physiques', 'Physique', 'Chimie',
  'SVT', 'Biologie', 'Histoire-Géo', 'Géographie', 'Histoire', 'Français',
  'Littérature', 'Philosophie', 'Anglais', 'EPS', 'Sport', 'Informatique',
  'Algorithmique', 'Arts', 'Électricité', 'Électronique', 'Réseaux', 'Comptabilité',
  'Sciences de l\'Ingénieur', 'Dessin Technique', 'Technologie', 'Mécanique',
];

const kProfs = [
  'M. Ngakosso J.-P.', 'Mme Mavoungou C.', 'M. Massamba B.',
  'Mme Nzaba M.', 'M. Tsimba G.', 'Mme Banzouzi P.',
  'M. Mouyabi R.', 'Mme Kikhounga O.', 'M. Ondamba P.',
  'M. Mabika J.-C.', 'M. Ngandzali T.', 'M. Itoua F.',
  'Mme Elenga R.', 'M. Bouya J.', 'Mme Loubaki H.',
  'M. Kimbembi R.', 'Mme Mabanza H.', 'M. Nkounkou E.',
];

const kSalles = [
  'A-101', 'A-102', 'A-110', 'A-201', 'A-205',
  'B-101', 'B-102', 'B-103', 'B-201', 'B-204',
  'C-105', 'C-201', 'C-301', 'L-001', 'L-002',
  'Labo Info', 'Labo Élec', 'Atelier',
  'Amphi A', 'Amphi B', 'Terrain',
];

// ─── Sessions complètes (Ferel Ondongo — Tle EMI + autres filières) ───────────
List<TSession> buildMockSessions() {
  // ── FILIÈRE EMI — Ferel Ondongo ─────────────────────────────────────────
  const emi = ['EMI'];

  // LUNDI
  const s_emi_lu1 = TSession(id: 'emi-lu-1', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-201',
      jour: 'Lundi', slot: TSlot(7, 30, 9, 0), filieres: emi);
  const s_emi_lu2 = TSession(id: 'emi-lu-2', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Lundi', slot: TSlot(9, 15, 10, 45), filieres: emi);
  const s_emi_lu3 = TSession(id: 'emi-lu-3', matiere: 'Informatique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Lundi', slot: TSlot(11, 0, 12, 30), filieres: emi);
  const s_emi_lu4 = TSession(id: 'emi-lu-4', matiere: 'Algorithmique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Lundi', slot: TSlot(14, 0, 15, 30), filieres: emi);
  const s_emi_lu5 = TSession(id: 'emi-lu-5', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-101',
      jour: 'Lundi', slot: TSlot(15, 45, 17, 15), filieres: emi);

  // MARDI
  const s_emi_ma1 = TSession(id: 'emi-ma-1', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-201',
      jour: 'Mardi', slot: TSlot(7, 30, 9, 0), filieres: emi);
  const s_emi_ma2 = TSession(id: 'emi-ma-2', matiere: 'Électronique',
      enseignant: 'M. Kimbembi R.', salle: 'Labo Élec',
      jour: 'Mardi', slot: TSlot(9, 15, 10, 45), filieres: emi);
  const s_emi_ma3 = TSession(id: 'emi-ma-3', matiere: 'Chimie',
      enseignant: 'M. Bouya J.', salle: 'L-002',
      jour: 'Mardi', slot: TSlot(11, 0, 12, 30), filieres: emi);
  const s_emi_ma4 = TSession(id: 'emi-ma-4', matiere: 'Français',
      enseignant: 'Mme Mavoungou C.', salle: 'B-102',
      jour: 'Mardi', slot: TSlot(14, 0, 15, 30), filieres: emi);
  const s_emi_ma5 = TSession(id: 'emi-ma-5', matiere: 'EPS',
      enseignant: 'M. Ondamba P.', salle: 'Terrain',
      jour: 'Mardi', slot: TSlot(15, 45, 17, 15), filieres: emi);

  // MERCREDI
  const s_emi_me1 = TSession(id: 'emi-me-1', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Mercredi', slot: TSlot(7, 30, 9, 0), filieres: emi);
  const s_emi_me2 = TSession(id: 'emi-me-2', matiere: 'Algorithmique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Mercredi', slot: TSlot(9, 15, 10, 45), filieres: emi);
  const s_emi_me3 = TSession(id: 'emi-me-3', matiere: 'Informatique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Mercredi', slot: TSlot(11, 0, 12, 30), filieres: emi);
  const s_emi_me4 = TSession(id: 'emi-me-4', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-201',
      jour: 'Mercredi', slot: TSlot(14, 0, 15, 30), filieres: emi);

  // JEUDI
  const s_emi_je1 = TSession(id: 'emi-je-1', matiere: 'Chimie',
      enseignant: 'M. Bouya J.', salle: 'L-002',
      jour: 'Jeudi', slot: TSlot(7, 30, 9, 0), filieres: emi);
  const s_emi_je2 = TSession(id: 'emi-je-2', matiere: 'Électronique',
      enseignant: 'M. Kimbembi R.', salle: 'Labo Élec',
      jour: 'Jeudi', slot: TSlot(9, 15, 10, 45), filieres: emi);
  const s_emi_je3 = TSession(id: 'emi-je-3', matiere: 'Histoire-Géo',
      enseignant: 'M. Tsimba G.', salle: 'C-201',
      jour: 'Jeudi', slot: TSlot(11, 0, 12, 30), filieres: emi);
  const s_emi_je4 = TSession(id: 'emi-je-4', matiere: 'Philosophie',
      enseignant: 'M. Ngandzali T.', salle: 'B-201',
      jour: 'Jeudi', slot: TSlot(14, 0, 15, 30), filieres: emi);
  const s_emi_je5 = TSession(id: 'emi-je-5', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-101',
      jour: 'Jeudi', slot: TSlot(15, 45, 17, 15), filieres: emi);

  // VENDREDI
  const s_emi_ve1 = TSession(id: 'emi-ve-1', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-201',
      jour: 'Vendredi', slot: TSlot(7, 30, 9, 0), filieres: emi);
  const s_emi_ve2 = TSession(id: 'emi-ve-2', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Vendredi', slot: TSlot(9, 15, 10, 45), filieres: emi);
  const s_emi_ve3 = TSession(id: 'emi-ve-3', matiere: 'Informatique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Vendredi', slot: TSlot(11, 0, 12, 30), filieres: emi);
  const s_emi_ve4 = TSession(id: 'emi-ve-4', matiere: 'EPS',
      enseignant: 'M. Ondamba P.', salle: 'Terrain',
      jour: 'Vendredi', slot: TSlot(14, 0, 15, 30), filieres: emi);
  const s_emi_ve5 = TSession(id: 'emi-ve-5', matiere: 'Français',
      enseignant: 'Mme Mavoungou C.', salle: 'B-102',
      jour: 'Vendredi', slot: TSlot(15, 45, 17, 15), filieres: emi);

  // ── FILIÈRE Tle C ──────────────────────────────────────────────────────────
  const tlec = ['Tle C'];

  const s_tlec_lu1 = TSession(id: 'tlec-lu-1', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-110',
      jour: 'Lundi', slot: TSlot(7, 30, 9, 0), filieres: tlec);
  const s_tlec_lu2 = TSession(id: 'tlec-lu-2', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Lundi', slot: TSlot(9, 15, 10, 45), filieres: tlec);
  const s_tlec_lu3 = TSession(id: 'tlec-lu-3', matiere: 'SVT',
      enseignant: 'Mme Nzaba M.', salle: 'B-201',
      jour: 'Lundi', slot: TSlot(11, 0, 12, 30), filieres: tlec);
  const s_tlec_lu4 = TSession(id: 'tlec-lu-4', matiere: 'Philosophie',
      enseignant: 'M. Ngandzali T.', salle: 'C-201',
      jour: 'Lundi', slot: TSlot(14, 0, 15, 30), filieres: tlec);
  const s_tlec_lu5 = TSession(id: 'tlec-lu-5', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-103',
      jour: 'Lundi', slot: TSlot(15, 45, 17, 15), filieres: tlec);

  const s_tlec_ma1 = TSession(id: 'tlec-ma-1', matiere: 'Maths Avancées',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-110',
      jour: 'Mardi', slot: TSlot(7, 30, 9, 0), filieres: tlec);
  const s_tlec_ma2 = TSession(id: 'tlec-ma-2', matiere: 'Chimie',
      enseignant: 'M. Bouya J.', salle: 'L-002',
      jour: 'Mardi', slot: TSlot(9, 15, 10, 45), filieres: tlec);
  const s_tlec_ma3 = TSession(id: 'tlec-ma-3', matiere: 'Français',
      enseignant: 'Mme Mavoungou C.', salle: 'B-204',
      jour: 'Mardi', slot: TSlot(11, 0, 12, 30), filieres: tlec);
  const s_tlec_ma4 = TSession(id: 'tlec-ma-4', matiere: 'Histoire-Géo',
      enseignant: 'M. Tsimba G.', salle: 'C-105',
      jour: 'Mardi', slot: TSlot(14, 0, 15, 30), filieres: tlec);
  const s_tlec_me1 = TSession(id: 'tlec-me-1', matiere: 'SVT',
      enseignant: 'Mme Nzaba M.', salle: 'B-201',
      jour: 'Mercredi', slot: TSlot(7, 30, 9, 0), filieres: tlec);
  const s_tlec_me2 = TSession(id: 'tlec-me-2', matiere: 'Mathématiques',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-110',
      jour: 'Mercredi', slot: TSlot(9, 15, 10, 45), filieres: tlec);
  const s_tlec_me3 = TSession(id: 'tlec-me-3', matiere: 'Informatique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Mercredi', slot: TSlot(11, 0, 12, 30), filieres: tlec);
  const s_tlec_je1 = TSession(id: 'tlec-je-1', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Jeudi', slot: TSlot(7, 30, 9, 0), filieres: tlec);
  const s_tlec_je2 = TSession(id: 'tlec-je-2', matiere: 'Maths Avancées',
      enseignant: 'M. Ngakosso J.-P.', salle: 'A-110',
      jour: 'Jeudi', slot: TSlot(9, 15, 10, 45), filieres: tlec);
  const s_tlec_je3 = TSession(id: 'tlec-je-3', matiere: 'EPS',
      enseignant: 'M. Ondamba P.', salle: 'Terrain',
      jour: 'Jeudi', slot: TSlot(14, 0, 15, 30), filieres: tlec);
  const s_tlec_ve1 = TSession(id: 'tlec-ve-1', matiere: 'Chimie',
      enseignant: 'M. Bouya J.', salle: 'L-002',
      jour: 'Vendredi', slot: TSlot(7, 30, 9, 0), filieres: tlec);
  const s_tlec_ve2 = TSession(id: 'tlec-ve-2', matiere: 'Philosophie',
      enseignant: 'M. Ngandzali T.', salle: 'C-201',
      jour: 'Vendredi', slot: TSlot(9, 15, 10, 45), filieres: tlec);
  const s_tlec_ve3 = TSession(id: 'tlec-ve-3', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-103',
      jour: 'Vendredi', slot: TSlot(11, 0, 12, 30), filieres: tlec);

  // ── FILIÈRE Tle A ──────────────────────────────────────────────────────────
  const tlea = ['Tle A'];

  const s_tlea_lu1 = TSession(id: 'tlea-lu-1', matiere: 'Français',
      enseignant: 'Mme Mavoungou C.', salle: 'C-301',
      jour: 'Lundi', slot: TSlot(7, 30, 9, 0), filieres: tlea);
  const s_tlea_lu2 = TSession(id: 'tlea-lu-2', matiere: 'Philosophie',
      enseignant: 'M. Ngandzali T.', salle: 'C-201',
      jour: 'Lundi', slot: TSlot(9, 15, 10, 45), filieres: tlea);
  const s_tlea_lu3 = TSession(id: 'tlea-lu-3', matiere: 'Histoire-Géo',
      enseignant: 'M. Tsimba G.', salle: 'C-105',
      jour: 'Lundi', slot: TSlot(11, 0, 12, 30), filieres: tlea);
  const s_tlea_lu4 = TSession(id: 'tlea-lu-4', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-101',
      jour: 'Lundi', slot: TSlot(14, 0, 15, 30), filieres: tlea);
  const s_tlea_ma1 = TSession(id: 'tlea-ma-1', matiere: 'Littérature',
      enseignant: 'Mme Mavoungou C.', salle: 'C-301',
      jour: 'Mardi', slot: TSlot(7, 30, 9, 0), filieres: tlea);
  const s_tlea_ma2 = TSession(id: 'tlea-ma-2', matiere: 'Mathématiques',
      enseignant: 'M. Mouyabi R.', salle: 'A-102',
      jour: 'Mardi', slot: TSlot(9, 15, 10, 45), filieres: tlea);
  const s_tlea_ma3 = TSession(id: 'tlea-ma-3', matiere: 'EPS',
      enseignant: 'M. Ondamba P.', salle: 'Terrain',
      jour: 'Mardi', slot: TSlot(14, 0, 15, 30), filieres: tlea);
  const s_tlea_je1 = TSession(id: 'tlea-je-1', matiere: 'Philosophie',
      enseignant: 'M. Ngandzali T.', salle: 'C-201',
      jour: 'Jeudi', slot: TSlot(7, 30, 9, 0), filieres: tlea);
  const s_tlea_je2 = TSession(id: 'tlea-je-2', matiere: 'Français',
      enseignant: 'Mme Mavoungou C.', salle: 'C-301',
      jour: 'Jeudi', slot: TSlot(9, 15, 10, 45), filieres: tlea);
  const s_tlea_ve1 = TSession(id: 'tlea-ve-1', matiere: 'Histoire-Géo',
      enseignant: 'M. Tsimba G.', salle: 'C-105',
      jour: 'Vendredi', slot: TSlot(7, 30, 9, 0), filieres: tlea);
  const s_tlea_ve2 = TSession(id: 'tlea-ve-2', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-101',
      jour: 'Vendredi', slot: TSlot(9, 15, 10, 45), filieres: tlea);

  // ── FILIÈRE 3e A ───────────────────────────────────────────────────────────
  const col3a = ['3e A'];

  const s_col_lu1 = TSession(id: 'col-lu-1', matiere: 'Mathématiques',
      enseignant: 'M. Mouyabi R.', salle: 'A-101',
      jour: 'Lundi', slot: TSlot(7, 30, 9, 0), filieres: col3a);
  const s_col_lu2 = TSession(id: 'col-lu-2', matiere: 'Français',
      enseignant: 'Mme Kikhounga O.', salle: 'B-101',
      jour: 'Lundi', slot: TSlot(9, 15, 10, 45), filieres: col3a);
  const s_col_lu3 = TSession(id: 'col-lu-3', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Lundi', slot: TSlot(11, 0, 12, 30), filieres: col3a);
  const s_col_ma1 = TSession(id: 'col-ma-1', matiere: 'Histoire-Géo',
      enseignant: 'M. Tsimba G.', salle: 'C-105',
      jour: 'Mardi', slot: TSlot(7, 30, 9, 0), filieres: col3a);
  const s_col_ma2 = TSession(id: 'col-ma-2', matiere: 'SVT',
      enseignant: 'Mme Nzaba M.', salle: 'B-204',
      jour: 'Mardi', slot: TSlot(9, 15, 10, 45), filieres: col3a);
  const s_col_ma3 = TSession(id: 'col-ma-3', matiere: 'Anglais',
      enseignant: 'Mme Banzouzi P.', salle: 'B-103',
      jour: 'Mardi', slot: TSlot(11, 0, 12, 30), filieres: col3a);
  const s_col_je1 = TSession(id: 'col-je-1', matiere: 'Mathématiques',
      enseignant: 'M. Mouyabi R.', salle: 'A-101',
      jour: 'Jeudi', slot: TSlot(7, 30, 9, 0), filieres: col3a);
  const s_col_je2 = TSession(id: 'col-je-2', matiere: 'Informatique',
      enseignant: 'M. Mabika J.-C.', salle: 'Labo Info',
      jour: 'Jeudi', slot: TSlot(9, 15, 10, 45), filieres: col3a);
  const s_col_je3 = TSession(id: 'col-je-3', matiere: 'EPS',
      enseignant: 'M. Ondamba P.', salle: 'Terrain',
      jour: 'Jeudi', slot: TSlot(14, 0, 15, 30), filieres: col3a);
  const s_col_ve1 = TSession(id: 'col-ve-1', matiere: 'Français',
      enseignant: 'Mme Kikhounga O.', salle: 'B-101',
      jour: 'Vendredi', slot: TSlot(7, 30, 9, 0), filieres: col3a);
  const s_col_ve2 = TSession(id: 'col-ve-2', matiere: 'Sciences Physiques',
      enseignant: 'M. Massamba B.', salle: 'L-001',
      jour: 'Vendredi', slot: TSlot(9, 15, 10, 45), filieres: col3a);

  return [
    // EMI — Ferel Ondongo
    s_emi_lu1, s_emi_lu2, s_emi_lu3, s_emi_lu4, s_emi_lu5,
    s_emi_ma1, s_emi_ma2, s_emi_ma3, s_emi_ma4, s_emi_ma5,
    s_emi_me1, s_emi_me2, s_emi_me3, s_emi_me4,
    s_emi_je1, s_emi_je2, s_emi_je3, s_emi_je4, s_emi_je5,
    s_emi_ve1, s_emi_ve2, s_emi_ve3, s_emi_ve4, s_emi_ve5,
    // Tle C
    s_tlec_lu1, s_tlec_lu2, s_tlec_lu3, s_tlec_lu4, s_tlec_lu5,
    s_tlec_ma1, s_tlec_ma2, s_tlec_ma3, s_tlec_ma4,
    s_tlec_me1, s_tlec_me2, s_tlec_me3,
    s_tlec_je1, s_tlec_je2, s_tlec_je3,
    s_tlec_ve1, s_tlec_ve2, s_tlec_ve3,
    // Tle A
    s_tlea_lu1, s_tlea_lu2, s_tlea_lu3, s_tlea_lu4,
    s_tlea_ma1, s_tlea_ma2, s_tlea_ma3,
    s_tlea_je1, s_tlea_je2,
    s_tlea_ve1, s_tlea_ve2,
    // 3e A
    s_col_lu1, s_col_lu2, s_col_lu3,
    s_col_ma1, s_col_ma2, s_col_ma3,
    s_col_je1, s_col_je2, s_col_je3,
    s_col_ve1, s_col_ve2,
  ];
}
