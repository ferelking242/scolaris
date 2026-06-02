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
// Data source — Supabase-backed
// ══════════════════════════════════════════════════════════════════════════

class _ReadingStats {
  final int booksRead, documentsOpened, readingHours, pagesRead;
  final List<double> weeklyMinutes;
  const _ReadingStats({
    required this.booksRead, required this.documentsOpened,
    required this.readingHours, required this.pagesRead,
    required this.weeklyMinutes,
  });
}

class MockLibraryData {
  static List<LibraryBook> _books = [];
  static bool _loaded = false;

  static List<LibraryBook> get books => _books;

  static final List<ExamSubject> examSubjects = [];
  static final List<CourseMaterial> materials = [];
  static final List<ReadingEntry> recentlyRead = [];
  static List<LibraryBook> get favoriteBooks => _books.where((b) => b.isFavorite).toList();
  static List<ExamSubject> get favoriteExams => examSubjects.where((e) => e.isFavorite).toList();
  static List<CourseMaterial> get favoriteMaterials => materials.where((m) => m.isFavorite).toList();
  static const readingStats = _ReadingStats(
    booksRead: 0, documentsOpened: 0, readingHours: 0, pagesRead: 0,
    weeklyMinutes: [0, 0, 0, 0, 0, 0, 0],
  );

  static Color _domainColor(String? domain) {
    switch (domain?.toLowerCase()) {
      case 'informatique': return const Color(0xFF0891B2);
      case 'mathématiques': return const Color(0xFF6D28D9);
      case 'physique':
      case 'sciences physiques': return const Color(0xFF0284C7);
      case 'biologie':
      case 'svt': return const Color(0xFF059669);
      case 'histoire':
      case 'géographie': return const Color(0xFFDB2777);
      case 'français':
      case 'littérature': return const Color(0xFFEA580C);
      case 'philosophie': return const Color(0xFF7C3AED);
      case 'économie':
      case 'comptabilité': return const Color(0xFF16A34A);
      default: return const Color(0xFF8B1A00);
    }
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final rows = await Supabase.instance.client
          .from('bibliotheque')
          .select('id, titre, auteur, type, domaine, annee, url, acces, resume')
          .order('titre');
      _books = (rows as List)
          .map((r) {
            final c = _domainColor(r['domaine'] as String?);
            return LibraryBook(
              id: r['id'] as String,
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
              reviewCount: 0,
              description: r['resume'] as String? ?? '',
              url: r['url'] as String?,
            );
          })
          .toList();
      _loaded = true;
    } catch (_) {
      _books = [];
    }
  }
}
