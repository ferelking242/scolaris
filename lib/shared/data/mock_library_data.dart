import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════
// Models
// ══════════════════════════════════════════════════════════════════════════

enum ExamLevel { cepe, bepc, bac }

enum ResourceType { book, examSubject, material }

class LibraryBook {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final String subject;
  final String classe;
  final int pages;
  final int downloads;
  final double rating;
  final Color coverColor;
  final Color coverColorEnd;
  bool isFavorite;
  bool isDownloaded;
  final int reviewCount;
  final String description;
  const LibraryBook({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.subject,
    required this.classe,
    required this.pages,
    required this.downloads,
    required this.rating,
    required this.coverColor,
    required this.coverColorEnd,
    this.isFavorite = false,
    this.isDownloaded = false,
    required this.reviewCount,
    required this.description,
  });
}

class ExamSubject {
  final String id;
  final String title;
  final String subject;
  final ExamLevel level;
  final String session;
  final int year;
  final bool hasCorrection;
  final Color color;
  bool isFavorite;
  bool isDownloaded;
  const ExamSubject({
    required this.id,
    required this.title,
    required this.subject,
    required this.level,
    required this.session,
    required this.year,
    required this.hasCorrection,
    required this.color,
    this.isFavorite = false,
    this.isDownloaded = false,
  });

  String get levelLabel {
    switch (level) {
      case ExamLevel.cepe: return 'CEPE';
      case ExamLevel.bepc: return 'BEPC';
      case ExamLevel.bac:  return 'BAC';
    }
  }
}

class CourseMaterial {
  final String id;
  final String title;
  final String subject;
  final String classe;
  final String teacher;
  final String size;
  final String addedDate;
  final Color color;
  final IconData icon;
  bool isFavorite;
  bool isDownloaded;
  const CourseMaterial({
    required this.id,
    required this.title,
    required this.subject,
    required this.classe,
    required this.teacher,
    required this.size,
    required this.addedDate,
    required this.color,
    required this.icon,
    this.isFavorite = false,
    this.isDownloaded = false,
  });
}

class ReadingEntry {
  final String resourceId;
  final String title;
  final ResourceType type;
  final DateTime lastOpened;
  final double progress;
  final Color color;
  final IconData icon;
  const ReadingEntry({
    required this.resourceId,
    required this.title,
    required this.type,
    required this.lastOpened,
    required this.progress,
    required this.color,
    required this.icon,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// Mock data
// ══════════════════════════════════════════════════════════════════════════

class MockLibraryData {
  // ── Livres ─────────────────────────────────────────────────────────────
  static final books = <LibraryBook>[
    LibraryBook(id: 'B001', title: 'Mamadou et Bineta lisent et écrivent',
      author: 'A. Davesne', publisher: 'Ligel', subject: 'Français',
      classe: 'CP-CE2', pages: 224, downloads: 3842, rating: 4.7,
      coverColor: const Color(0xFF8B1A00), coverColorEnd: const Color(0xFFD4540A),
      isFavorite: true, reviewCount: 412,
      description: 'Manuel de lecture historique utilisé dans toute l\'Afrique francophone depuis des décennies.'),
    LibraryBook(id: 'B002', title: 'Mathématiques 6e', author: 'Équipe pédagogique',
      publisher: 'MENFOP', subject: 'Mathématiques', classe: '6e',
      pages: 312, downloads: 2910, rating: 4.5,
      coverColor: const Color(0xFF4527A0), coverColorEnd: const Color(0xFF7B1FA2),
      isDownloaded: true, reviewCount: 287,
      description: 'Programme officiel de mathématiques pour la classe de 6e — opérations, fractions, géométrie.'),
    LibraryBook(id: 'B003', title: 'Mathématiques 5e', author: 'Équipe pédagogique',
      publisher: 'MENFOP', subject: 'Mathématiques', classe: '5e',
      pages: 334, downloads: 2744, rating: 4.4,
      coverColor: const Color(0xFF1565C0), coverColorEnd: const Color(0xFF0288D1),
      isFavorite: true, isDownloaded: true, reviewCount: 253,
      description: 'Nombres relatifs, puissances, géométrie dans l\'espace et statistiques.'),
    LibraryBook(id: 'B004', title: 'Mathématiques 4e', author: 'Équipe pédagogique',
      publisher: 'MENFOP', subject: 'Mathématiques', classe: '4e',
      pages: 356, downloads: 2180, rating: 4.3,
      coverColor: const Color(0xFF00695C), coverColorEnd: const Color(0xFF00897B),
      reviewCount: 198,
      description: 'Algèbre, équations du 1er degré, fonctions et statistiques descriptives.'),
    LibraryBook(id: 'B005', title: 'Mathématiques 3e', author: 'Équipe pédagogique',
      publisher: 'MENFOP', subject: 'Mathématiques', classe: '3e',
      pages: 378, downloads: 1980, rating: 4.6,
      coverColor: const Color(0xFF1B5E20), coverColorEnd: const Color(0xFF388E3C),
      reviewCount: 231,
      description: 'Pythagore, trigonométrie, probabilités et préparation au BEPC.'),
    LibraryBook(id: 'B006', title: 'Français — Grammaire et Expression', author: 'M. Mbiya',
      publisher: 'CLE International', subject: 'Français', classe: 'Collège',
      pages: 288, downloads: 2100, rating: 4.2,
      coverColor: const Color(0xFFE65100), coverColorEnd: const Color(0xFFF57C00),
      isDownloaded: true, reviewCount: 176,
      description: 'Grammaire, conjugaison, expression écrite et orale pour le collège.'),
    LibraryBook(id: 'B007', title: 'Sciences de la Vie et de la Terre 5e', author: 'Dr. Yao',
      publisher: 'MENFOP', subject: 'SVT', classe: '5e',
      pages: 256, downloads: 1750, rating: 4.3,
      coverColor: const Color(0xFF00838F), coverColorEnd: const Color(0xFF006064),
      reviewCount: 143,
      description: 'Biodiversité, cellules, écosystèmes et reproduction. Programme 5e.'),
    LibraryBook(id: 'B008', title: 'Physique-Chimie 5e', author: 'Mme Lefèvre',
      publisher: 'Hachette', subject: 'Physique-Chimie', classe: '5e',
      pages: 304, downloads: 1620, rating: 4.1,
      coverColor: const Color(0xFF0D47A1), coverColorEnd: const Color(0xFF1976D2),
      reviewCount: 128,
      description: 'Lumière, électricité, matière et réactions chimiques — niveau 5e.'),
    LibraryBook(id: 'B009', title: 'Histoire-Géographie 4e', author: 'M. Kabamba',
      publisher: 'MENFOP', subject: 'Histoire-Géo', classe: '4e',
      pages: 340, downloads: 1480, rating: 4.0,
      coverColor: const Color(0xFFBF360C), coverColorEnd: const Color(0xFFD84315),
      reviewCount: 109,
      description: 'Renaissance, révolutions, mondialisation et géographie mondiale.'),
    LibraryBook(id: 'B010', title: 'Philosophie Terminale', author: 'Dr. Ngoma',
      publisher: 'CLE International', subject: 'Philosophie', classe: 'Terminale',
      pages: 420, downloads: 1320, rating: 4.8,
      coverColor: const Color(0xFF4A148C), coverColorEnd: const Color(0xFF6A1B9A),
      reviewCount: 189,
      description: 'Grandes doctrines philosophiques, méthodologie dissertation et textes commentés.'),
    LibraryBook(id: 'B011', title: 'Anglais Bridge to English 5e', author: 'Ms. Carter',
      publisher: 'Oxford', subject: 'Anglais', classe: '5e',
      pages: 192, downloads: 1890, rating: 4.4,
      coverColor: const Color(0xFF004D40), coverColorEnd: const Color(0xFF00796B),
      isDownloaded: true, isFavorite: true, reviewCount: 201,
      description: 'Vocabulaire, grammaire et expression orale — niveau A1/A2 du CECRL.'),
    LibraryBook(id: 'B012', title: 'Chimie Terminale', author: 'Dr. Kasongo',
      publisher: 'MENFOP', subject: 'Chimie', classe: 'Terminale',
      pages: 390, downloads: 1100, rating: 4.5,
      coverColor: const Color(0xFF880E4F), coverColorEnd: const Color(0xFFC2185B),
      reviewCount: 142,
      description: 'Chimie organique, thermodynamique et électrochimie. Niveau BAC.'),
  ];

  // ── Sujets d'examens ────────────────────────────────────────────────────
  static final examSubjects = <ExamSubject>[
    // CEPE
    ExamSubject(id: 'E001', title: 'CEPE 2024 — Session 1', subject: 'Français',
      level: ExamLevel.cepe, session: 'Session 1', year: 2024, hasCorrection: true,
      color: const Color(0xFF8B1A00)),
    ExamSubject(id: 'E002', title: 'CEPE 2024 — Session 1', subject: 'Mathématiques',
      level: ExamLevel.cepe, session: 'Session 1', year: 2024, hasCorrection: true,
      color: const Color(0xFF8B1A00)),
    ExamSubject(id: 'E003', title: 'CEPE 2023 — Session 1', subject: 'Français',
      level: ExamLevel.cepe, session: 'Session 1', year: 2023, hasCorrection: false,
      color: const Color(0xFF8B1A00), isDownloaded: true),
    ExamSubject(id: 'E004', title: 'CEPE 2023 — Session 2', subject: 'Mathématiques',
      level: ExamLevel.cepe, session: 'Session 2', year: 2023, hasCorrection: true,
      color: const Color(0xFF8B1A00)),
    ExamSubject(id: 'E005', title: 'CEPE 2022 — Session 1', subject: 'Éveil',
      level: ExamLevel.cepe, session: 'Session 1', year: 2022, hasCorrection: true,
      color: const Color(0xFF8B1A00)),
    ExamSubject(id: 'E006', title: 'CEPE 2022 — Session 1', subject: 'Français',
      level: ExamLevel.cepe, session: 'Session 1', year: 2022, hasCorrection: false,
      color: const Color(0xFF8B1A00)),
    // BEPC
    ExamSubject(id: 'E007', title: 'BEPC 2024 — Session 1', subject: 'Mathématiques',
      level: ExamLevel.bepc, session: 'Session 1', year: 2024, hasCorrection: true,
      color: const Color(0xFF1B5E20), isFavorite: true),
    ExamSubject(id: 'E008', title: 'BEPC 2024 — Session 1', subject: 'Français',
      level: ExamLevel.bepc, session: 'Session 1', year: 2024, hasCorrection: true,
      color: const Color(0xFF1B5E20)),
    ExamSubject(id: 'E009', title: 'BEPC 2024 — Session 1', subject: 'Physique-Chimie',
      level: ExamLevel.bepc, session: 'Session 1', year: 2024, hasCorrection: false,
      color: const Color(0xFF1B5E20)),
    ExamSubject(id: 'E010', title: 'BEPC 2023 — Session 1', subject: 'Histoire-Géo',
      level: ExamLevel.bepc, session: 'Session 1', year: 2023, hasCorrection: true,
      color: const Color(0xFF1B5E20), isDownloaded: true),
    ExamSubject(id: 'E011', title: 'BEPC 2023 — Session 2', subject: 'Mathématiques',
      level: ExamLevel.bepc, session: 'Session 2', year: 2023, hasCorrection: true,
      color: const Color(0xFF1B5E20)),
    ExamSubject(id: 'E012', title: 'BEPC 2022 — Session 1', subject: 'SVT',
      level: ExamLevel.bepc, session: 'Session 1', year: 2022, hasCorrection: false,
      color: const Color(0xFF1B5E20)),
    // BAC
    ExamSubject(id: 'E013', title: 'BAC 2024 — Série A', subject: 'Philosophie',
      level: ExamLevel.bac, session: 'Série A', year: 2024, hasCorrection: true,
      color: const Color(0xFF6D28D9)),
    ExamSubject(id: 'E014', title: 'BAC 2024 — Série C', subject: 'Mathématiques',
      level: ExamLevel.bac, session: 'Série C', year: 2024, hasCorrection: true,
      color: const Color(0xFF6D28D9)),
    ExamSubject(id: 'E015', title: 'BAC 2024 — Série D', subject: 'SVT',
      level: ExamLevel.bac, session: 'Série D', year: 2024, hasCorrection: false,
      color: const Color(0xFF6D28D9)),
    ExamSubject(id: 'E016', title: 'BAC 2023 — Série C', subject: 'Physique-Chimie',
      level: ExamLevel.bac, session: 'Série C', year: 2023, hasCorrection: true,
      color: const Color(0xFF6D28D9)),
    ExamSubject(id: 'E017', title: 'BAC 2023 — Série A', subject: 'Français',
      level: ExamLevel.bac, session: 'Série A', year: 2023, hasCorrection: true,
      color: const Color(0xFF6D28D9), isFavorite: true),
    ExamSubject(id: 'E018', title: 'BAC 2022 — Série D', subject: 'Biologie',
      level: ExamLevel.bac, session: 'Série D', year: 2022, hasCorrection: false,
      color: const Color(0xFF6D28D9)),
  ];

  // ── Supports de cours ───────────────────────────────────────────────────
  static final materials = <CourseMaterial>[
    CourseMaterial(id: 'M001', title: 'Cours Mathématiques — Chapitre 7',
      subject: 'Mathématiques', classe: '5e', teacher: 'M. Dupont',
      size: '2.4 MB', addedDate: '28 Mai 2026',
      color: const Color(0xFF6D28D9), icon: Icons.calculate_rounded,
      isFavorite: true, isDownloaded: true),
    CourseMaterial(id: 'M002', title: 'Résumé Physique-Chimie T2',
      subject: 'Physique-Chimie', classe: '5e', teacher: 'Mme Lefèvre',
      size: '1.8 MB', addedDate: '25 Mai 2026',
      color: const Color(0xFF0891B2), icon: Icons.science_rounded,
      isDownloaded: true),
    CourseMaterial(id: 'M003', title: 'Fiches de révision Français',
      subject: 'Français', classe: '5e', teacher: 'M. Mbiya',
      size: '3.1 MB', addedDate: '22 Mai 2026',
      color: const Color(0xFFEA580C), icon: Icons.menu_book_rounded,
      isFavorite: true),
    CourseMaterial(id: 'M004', title: 'Exercices corrigés Histoire T1',
      subject: 'Histoire-Géo', classe: '5e', teacher: 'M. Kabamba',
      size: '4.2 MB', addedDate: '18 Mai 2026',
      color: const Color(0xFFDB2777), icon: Icons.public_rounded),
    CourseMaterial(id: 'M005', title: 'SVT — Biodiversité et écosystèmes',
      subject: 'SVT', classe: '5e', teacher: 'Dr. Yao',
      size: '5.6 MB', addedDate: '15 Mai 2026',
      color: const Color(0xFF059669), icon: Icons.biotech_rounded),
    CourseMaterial(id: 'M006', title: 'Anglais — Grammar Practice',
      subject: 'Anglais', classe: '5e', teacher: 'Ms. Carter',
      size: '1.2 MB', addedDate: '12 Mai 2026',
      color: const Color(0xFF0D9488), icon: Icons.translate_rounded,
      isDownloaded: true),
    CourseMaterial(id: 'M007', title: 'Informatique — Introduction Python',
      subject: 'Informatique', classe: '4e', teacher: 'M. Mukasa',
      size: '2.8 MB', addedDate: '10 Mai 2026',
      color: const Color(0xFF374151), icon: Icons.terminal_rounded),
    CourseMaterial(id: 'M008', title: 'Mathématiques 3e — Préparation BEPC',
      subject: 'Mathématiques', classe: '3e', teacher: 'M. Dupont',
      size: '6.4 MB', addedDate: '8 Mai 2026',
      color: const Color(0xFF6D28D9), icon: Icons.calculate_rounded,
      isFavorite: true),
  ];

  // ── Historique de lecture ────────────────────────────────────────────────
  static final readingHistory = <ReadingEntry>[
    ReadingEntry(resourceId: 'B003', title: 'Mathématiques 5e',
      type: ResourceType.book, lastOpened: DateTime(2026, 6, 2, 10, 30),
      progress: 0.45, color: const Color(0xFF1565C0), icon: Icons.calculate_rounded),
    ReadingEntry(resourceId: 'M001', title: 'Cours Maths — Chapitre 7',
      type: ResourceType.material, lastOpened: DateTime(2026, 6, 1, 16, 0),
      progress: 0.80, color: const Color(0xFF6D28D9), icon: Icons.description_rounded),
    ReadingEntry(resourceId: 'E007', title: 'BEPC 2024 — Maths',
      type: ResourceType.examSubject, lastOpened: DateTime(2026, 5, 31, 14, 15),
      progress: 0.60, color: const Color(0xFF1B5E20), icon: Icons.quiz_rounded),
    ReadingEntry(resourceId: 'B011', title: 'Anglais Bridge 5e',
      type: ResourceType.book, lastOpened: DateTime(2026, 5, 30, 9, 0),
      progress: 0.25, color: const Color(0xFF004D40), icon: Icons.translate_rounded),
  ];

  // ── Statistiques de lecture ─────────────────────────────────────────────
  static const readingStats = (
    booksRead: 3,
    documentsOpened: 14,
    readingHours: 4.5,
    pagesRead: 312,
    topSubject: 'Mathématiques',
    weeklyMinutes: [45.0, 30.0, 75.0, 50.0, 90.0, 20.0, 60.0],
    weekDays: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    subjectBreakdown: [
      (subject: 'Mathématiques', pct: 40.0, color: Color(0xFF6D28D9)),
      (subject: 'Physique',      pct: 22.0, color: Color(0xFF0891B2)),
      (subject: 'Français',      pct: 18.0, color: Color(0xFFEA580C)),
      (subject: 'Histoire',      pct: 12.0, color: Color(0xFFDB2777)),
      (subject: 'Anglais',       pct: 8.0,  color: Color(0xFF059669)),
    ],
  );

  // ── Ressources recommandées (pour classe 5e) ────────────────────────────
  static List<LibraryBook> recommendedForClasse(String classe) {
    if (classe.contains('6e')) {
      return books.where((b) => ['6e','CP-CE2'].contains(b.classe)).toList();
    }
    if (classe.contains('5e')) {
      return books.where((b) => b.classe == '5e' || b.classe == 'Collège').toList();
    }
    if (classe.contains('4e') || classe.contains('3e')) {
      return books.where((b) => ['4e','3e','Collège'].contains(b.classe)).toList();
    }
    return books.where((b) => b.classe == 'Terminale').toList();
  }

  static List<ExamSubject> recommendedExamsForClasse(String classe) {
    if (classe.contains('6e') || classe.contains('5e')) {
      return examSubjects.where((e) => e.level == ExamLevel.cepe).toList();
    }
    if (classe.contains('4e') || classe.contains('3e')) {
      return examSubjects.where((e) => e.level == ExamLevel.bepc).toList();
    }
    return examSubjects.where((e) => e.level == ExamLevel.bac).toList();
  }

  // Agrégats
  static int get totalResources => books.length + examSubjects.length + materials.length;
  static int get totalBooks => books.length;
  static int get totalExams => examSubjects.length;
  static int get totalMaterials => materials.length;

  static List<LibraryBook> get popularBooks =>
      List.of(books)..sort((a, b) => b.downloads.compareTo(a.downloads));

  static List<LibraryBook> get topRatedBooks =>
      List.of(books)..sort((a, b) => b.rating.compareTo(a.rating));

  static List<LibraryBook> get favoriteBooks =>
      books.where((b) => b.isFavorite).toList();

  static List<ExamSubject> get favoriteExams =>
      examSubjects.where((e) => e.isFavorite).toList();

  static List<CourseMaterial> get favoriteMaterials =>
      materials.where((m) => m.isFavorite).toList();

  static List<CourseMaterial> get downloadedMaterials =>
      materials.where((m) => m.isDownloaded).toList();

  static List<LibraryBook> get downloadedBooks =>
      books.where((b) => b.isDownloaded).toList();

  static double get downloadedSizeMb =>
      downloadedMaterials.fold<double>(0.0, (acc, m) {
        final raw = double.tryParse(m.size.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return acc + raw;
      }) + downloadedBooks.length * 15.0;
}
