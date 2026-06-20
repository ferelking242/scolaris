import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final bool isFavorite;
  final bool isDownloaded;
  final int reviewCount;
  final String description;
  final String? url;
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
    this.url,
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
  final bool isFavorite;
  final bool isDownloaded;
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
  final String type;
  final String classe;
  final String uploadedBy;
  final int year;
  final Color color;
  final IconData icon;
  final bool isFavorite;
  final bool isDownloaded;
  final String size;
  final String addedDate;
  const CourseMaterial({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.classe,
    required this.uploadedBy,
    required this.year,
    required this.color,
    required this.icon,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.size = '—',
    this.addedDate = '—',
  });

  String get teacher => uploadedBy;
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
// Data source — Supabase-backed
//
// NB historique : cette classe s'appelait « Mock » quand seuls les livres
// venaient de Supabase. Désormais TOUT est réel : livres (`bibliotheque`),
// annales (`exam_subjects`), supports (`course_materials`), favoris
// (`library_favorites`) et suivi de lecture (`reading_progress`).
//
// Les trois CATALOGUES (livres/annales/supports) sont un fonds PARTAGÉ curé par
// la plateforme : même contenu pour toutes les écoles (lecture publique). La
// restriction Pro/Max est faite côté app (PlanGate sur l'entrée Bibliothèque),
// pas en base. Les favoris et le suivi de lecture sont PAR UTILISATEUR (RLS
// `auth.uid()`). `load()` reste donc sans paramètre. Les requêtes échouent
// silencieusement (tables absentes / hors-ligne) → listes vides, comme avant.
// ══════════════════════════════════════════════════════════════════════════

class SubjectStat {
  final String subject;
  final double pct;
  final Color color;
  const SubjectStat({required this.subject, required this.pct, required this.color});
}

class ReadingStats {
  final int booksRead, documentsOpened, readingHours, pagesRead;
  final List<double> weeklyMinutes;
  final List<String> weekDays;
  final List<SubjectStat> subjectBreakdown;
  const ReadingStats({
    required this.booksRead,
    required this.documentsOpened,
    required this.readingHours,
    required this.pagesRead,
    required this.weeklyMinutes,
    this.weekDays = const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    this.subjectBreakdown = const [],
  });
}

class MockLibraryData {
  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // ── Caches de lignes brutes (pour reconstruire après un toggle favori) ──────
  static List<Map<String, dynamic>> _bookRows = [];
  static List<Map<String, dynamic>> _examRows = [];
  static List<Map<String, dynamic>> _materialRows = [];

  // ── Favoris (clés « type:id ») ──────────────────────────────────────────────
  static final Set<String> _favorites = {};
  static String _favKey(ResourceType t, String id) => '${_favStr(t)}:$id';
  static String _favStr(ResourceType t) => switch (t) {
        ResourceType.book => 'book',
        ResourceType.examSubject => 'exam',
        ResourceType.material => 'material',
      };

  // ── Données dérivées exposées à l'UI ────────────────────────────────────────
  static List<LibraryBook> _books = [];
  static List<ExamSubject> examSubjects = [];
  static List<CourseMaterial> materials = [];
  static List<ReadingEntry> recentlyRead = [];
  static ReadingStats readingStats = const ReadingStats(
    booksRead: 0,
    documentsOpened: 0,
    readingHours: 0,
    pagesRead: 0,
    weeklyMinutes: [0, 0, 0, 0, 0, 0, 0],
  );

  static bool _loaded = false;

  static List<LibraryBook> get books => _books;

  static List<LibraryBook> get favoriteBooks =>
      _books.where((b) => b.isFavorite).toList();
  static List<ExamSubject> get favoriteExams =>
      examSubjects.where((e) => e.isFavorite).toList();
  static List<CourseMaterial> get favoriteMaterials =>
      materials.where((m) => m.isFavorite).toList();

  static int get totalBooks     => _books.length;
  static int get totalExams     => examSubjects.length;
  static int get totalMaterials => materials.length;

  static List<LibraryBook>    get downloadedBooks     =>
      _books.where((b) => b.isDownloaded).toList();
  static List<CourseMaterial> get downloadedMaterials =>
      materials.where((m) => m.isDownloaded).toList();

  /// Estimation du stockage occupé hors-ligne (en Mo) — les tailles réelles
  /// ne sont pas suivies, on approxime à partir du nombre d'éléments.
  static double get downloadedSizeMb =>
      downloadedBooks.length * 4.5 + downloadedMaterials.length * 1.8;

  static List<ReadingEntry> get readingHistory => recentlyRead;

  static List<LibraryBook> recommendedForClasse(String classe) =>
      _books.where((b) => b.classe == classe || b.classe == 'Toutes').toList();

  static List<ExamSubject> recommendedExamsForClasse(String classe) =>
      examSubjects.toList();

  // ── Couleurs / icônes dérivées ──────────────────────────────────────────────
  static Color _domainColor(String? domain) {
    switch (domain?.toLowerCase()) {
      case 'informatique':         return const Color(0xFF0891B2);
      case 'mathématiques':        return const Color(0xFF6D28D9);
      case 'physique':
      case 'sciences physiques':   return const Color(0xFF0284C7);
      case 'biologie':
      case 'svt':                  return const Color(0xFF059669);
      case 'histoire':
      case 'géographie':           return const Color(0xFFDB2777);
      case 'français':
      case 'littérature':          return const Color(0xFFEA580C);
      case 'philosophie':          return const Color(0xFF7C3AED);
      case 'économie':
      case 'comptabilité':         return const Color(0xFF16A34A);
      default:                     return const Color(0xFF8B1A00);
    }
  }

  static IconData _materialIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'td':
      case 'exercices':   return Icons.edit_note_rounded;
      case 'fiche':       return Icons.sticky_note_2_rounded;
      case 'vidéo':
      case 'video':       return Icons.play_circle_rounded;
      case 'diaporama':   return Icons.slideshow_rounded;
      default:            return Icons.description_rounded;
    }
  }

  static ExamLevel _examLevel(String? s) {
    switch (s?.toLowerCase()) {
      case 'cepe': return ExamLevel.cepe;
      case 'bepc': return ExamLevel.bepc;
      default:     return ExamLevel.bac;
    }
  }

  static String _formatSize(int? kb) {
    if (kb == null || kb <= 0) return '—';
    if (kb < 1024) return '$kb Ko';
    return '${(kb / 1024).toStringAsFixed(1)} Mo';
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ── Construction des modèles depuis les lignes brutes + favoris ─────────────
  static void _buildBooks() {
    _books = _bookRows.map((r) {
      final c = _domainColor(r['domaine'] as String?);
      final id = r['id'] as String;
      return LibraryBook(
        id: id,
        title: r['titre'] as String? ?? '—',
        author: r['auteur'] as String? ?? '—',
        publisher: r['type'] as String? ?? '—',
        subject: r['domaine'] as String? ?? 'Général',
        classe: 'Toutes',
        pages: 200,
        downloads: 0,
        rating: 4.0,
        coverColor: c,
        coverColorEnd: c.withValues(alpha: .7),
        isFavorite: _favorites.contains(_favKey(ResourceType.book, id)),
        reviewCount: 0,
        description: r['resume'] as String? ?? '',
        url: r['url'] as String?,
      );
    }).toList();
  }

  static void _buildExams() {
    examSubjects = _examRows.map((r) {
      final id = r['id'] as String;
      final subject = r['subject'] as String? ?? 'Général';
      return ExamSubject(
        id: id,
        title: r['title'] as String? ?? '—',
        subject: subject,
        level: _examLevel(r['level'] as String?),
        session: r['session'] as String? ?? '—',
        year: (r['year'] as num?)?.toInt() ?? 0,
        hasCorrection: r['has_correction'] as bool? ?? false,
        color: _domainColor(subject),
        isFavorite: _favorites.contains(_favKey(ResourceType.examSubject, id)),
      );
    }).toList();
  }

  static void _buildMaterials() {
    materials = _materialRows.map((r) {
      final id = r['id'] as String;
      final subject = r['subject'] as String? ?? 'Général';
      final type = r['type'] as String? ?? 'Cours';
      final created = DateTime.tryParse(r['created_at'] as String? ?? '');
      return CourseMaterial(
        id: id,
        title: r['title'] as String? ?? '—',
        subject: subject,
        type: type,
        classe: r['level'] as String? ?? '—',
        uploadedBy: r['publisher'] as String? ?? '—',
        year: (r['year'] as num?)?.toInt() ?? 0,
        color: _domainColor(subject),
        icon: _materialIcon(type),
        isFavorite: _favorites.contains(_favKey(ResourceType.material, id)),
        size: _formatSize((r['size_kb'] as num?)?.toInt()),
        addedDate: _formatDate(created),
      );
    }).toList();
  }

  static void _rebuild() {
    _buildBooks();
    _buildExams();
    _buildMaterials();
  }

  // ── Suivi de lecture → entrées « reprendre » + statistiques ─────────────────
  static IconData _readingIcon(String? type) => switch (type) {
        'exam' => Icons.quiz_rounded,
        'material' => Icons.description_rounded,
        _ => Icons.menu_book_rounded,
      };

  static void _buildReading(List<Map<String, dynamic>> rows) {
    // Entrées « reprendre la lecture » : non terminées, plus récentes d'abord.
    recentlyRead = rows
        .where((r) => ((r['progress'] as num?)?.toDouble() ?? 0) < 1)
        .map((r) {
          final subject = r['subject'] as String?;
          return ReadingEntry(
            resourceId: r['resource_id'] as String? ?? '',
            title: r['title'] as String? ?? '—',
            type: switch (r['resource_type']) {
              'exam' => ResourceType.examSubject,
              'material' => ResourceType.material,
              _ => ResourceType.book,
            },
            lastOpened:
                DateTime.tryParse(r['last_opened'] as String? ?? '') ?? DateTime.now(),
            progress: (r['progress'] as num?)?.toDouble() ?? 0,
            color: _domainColor(subject),
            icon: _readingIcon(r['resource_type'] as String?),
          );
        })
        .take(8)
        .toList();

    // Statistiques agrégées.
    final booksRead = rows
        .where((r) =>
            r['resource_type'] == 'book' &&
            ((r['progress'] as num?)?.toDouble() ?? 0) >= 1)
        .length;
    final totalMinutes =
        rows.fold<int>(0, (a, r) => a + ((r['minutes'] as num?)?.toInt() ?? 0));
    final pagesRead =
        rows.fold<int>(0, (a, r) => a + ((r['pages_read'] as num?)?.toInt() ?? 0));

    // Minutes par jour sur les 7 derniers jours (rolling).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const joursFr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final weekly = List<double>.filled(7, 0);
    final labels = <String>[];
    for (int i = 6; i >= 0; i--) {
      labels.add(joursFr[today.subtract(Duration(days: i)).weekday - 1]);
    }
    for (final r in rows) {
      final d = DateTime.tryParse(r['last_opened'] as String? ?? '');
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays; // 0 = aujourd'hui
      if (diff >= 0 && diff < 7) {
        weekly[6 - diff] += (r['minutes'] as num?)?.toDouble() ?? 0;
      }
    }

    // Répartition par matière (part des minutes de lecture), top 5.
    final bySubject = <String, double>{};
    for (final r in rows) {
      final s = (r['subject'] as String?)?.trim();
      if (s == null || s.isEmpty) continue;
      bySubject[s] = (bySubject[s] ?? 0) + ((r['minutes'] as num?)?.toDouble() ?? 0);
    }
    final totalSubjectMin = bySubject.values.fold<double>(0, (a, b) => a + b);
    final breakdown = <SubjectStat>[];
    if (totalSubjectMin > 0) {
      final sorted = bySubject.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted.take(5)) {
        breakdown.add(SubjectStat(
          subject: e.key,
          pct: (e.value / totalSubjectMin * 100),
          color: _domainColor(e.key),
        ));
      }
    }

    readingStats = ReadingStats(
      booksRead: booksRead,
      documentsOpened: rows.length,
      readingHours: (totalMinutes / 60).round(),
      pagesRead: pagesRead,
      weeklyMinutes: weekly,
      weekDays: labels,
      subjectBreakdown: breakdown,
    );
  }

  // ── Chargement ──────────────────────────────────────────────────────────────
  static Future<void> load() async {
    if (_loaded) return;
    await reload();
  }

  /// Force un rechargement complet depuis Supabase.
  static Future<void> reload() async {
    // Favoris (avant de construire les modèles pour positionner isFavorite).
    try {
      final favs = await _db
          .from('library_favorites')
          .select('resource_type, resource_id');
      _favorites
        ..clear()
        ..addAll((favs as List).map((r) =>
            '${r['resource_type']}:${r['resource_id']}'));
    } catch (_) {/* table absente / hors-ligne → pas de favoris */}

    // Livres (catalogue partagé).
    try {
      final rows = await _db
          .from('bibliotheque')
          .select('id, titre, auteur, type, domaine, annee, url, acces, resume')
          .order('titre');
      _bookRows = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _bookRows = [];
    }

    // Annales (catalogue partagé).
    try {
      final rows = await _db
          .from('exam_subjects')
          .select('id, title, subject, level, session, year, has_correction, url, correction_url')
          .order('year', ascending: false);
      _examRows = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _examRows = [];
    }

    // Supports de cours (catalogue partagé, curé par la plateforme).
    try {
      final rows = await _db
          .from('course_materials')
          .select('id, title, subject, type, level, publisher, year, file_url, size_kb, created_at')
          .order('created_at', ascending: false);
      _materialRows = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _materialRows = [];
    }

    _rebuild();

    // Suivi de lecture (par utilisateur via RLS).
    try {
      final rows = await _db
          .from('reading_progress')
          .select('resource_type, resource_id, title, subject, progress, pages_read, minutes, last_opened')
          .order('last_opened', ascending: false);
      _buildReading(List<Map<String, dynamic>>.from(rows as List));
    } catch (_) {
      _buildReading(const []);
    }

    _loaded = true;
  }

  /// Ajoute ou retire un favori (persisté). Met à jour les modèles en mémoire.
  static Future<void> toggleFavorite(ResourceType type, String id) async {
    final uid = _uid;
    if (uid == null) return;
    final key = _favKey(type, id);
    final wasFav = _favorites.contains(key);
    // Optimiste : on bascule en mémoire puis on reconstruit.
    if (wasFav) {
      _favorites.remove(key);
    } else {
      _favorites.add(key);
    }
    _rebuild();
    try {
      if (wasFav) {
        await _db
            .from('library_favorites')
            .delete()
            .eq('user_id', uid)
            .eq('resource_type', _favStr(type))
            .eq('resource_id', id);
      } else {
        await _db.from('library_favorites').insert({
          'user_id': uid,
          'resource_type': _favStr(type),
          'resource_id': id,
        });
      }
    } catch (_) {
      // Échec réseau → on annule le changement optimiste.
      if (wasFav) {
        _favorites.add(key);
      } else {
        _favorites.remove(key);
      }
      _rebuild();
    }
  }

  static bool isFavorite(ResourceType type, String id) =>
      _favorites.contains(_favKey(type, id));

  /// Enregistre/ met à jour la progression de lecture d'une ressource.
  static Future<void> recordReading({
    required ResourceType type,
    required String id,
    required String title,
    String? subject,
    double progress = 0,
    int pagesRead = 0,
    int addMinutes = 0,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.from('reading_progress').upsert({
        'user_id': uid,
        'resource_type': _favStr(type),
        'resource_id': id,
        'title': title,
        if (subject != null) 'subject': subject,
        'progress': progress.clamp(0, 1),
        'pages_read': pagesRead,
        'minutes': addMinutes,
        'last_opened': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,resource_type,resource_id');
    } catch (_) {/* silencieux */}
  }
}
