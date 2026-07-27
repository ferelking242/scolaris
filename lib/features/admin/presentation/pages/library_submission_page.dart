import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

/// Soumission d'un livre/annale/support au catalogue partagé de la
/// bibliothèque. Le contenu reste `pending` — invisible des élèves — tant
/// qu'un super-admin plateforme ne l'a pas validé : une fois publié, il
/// devient visible par TOUTES les écoles, pas seulement celle-ci (cf.
/// `bibliotheque`/`exam_subjects`/`course_materials`, sans `school_id`).
class LibrarySubmissionPage extends ConsumerStatefulWidget {
  const LibrarySubmissionPage({super.key});

  @override
  ConsumerState<LibrarySubmissionPage> createState() =>
      _LibrarySubmissionPageState();
}

enum _Category { book, exam, material }

// Valeurs contraintes en base (CHECK constraint) — pas de texte libre possible.
const _bookTypes = <String, String>{
  'livre': 'Livre',
  'memoire': 'Mémoire',
  'article': 'Article',
  'rapport': 'Rapport',
  'these': 'Thèse',
};
const _examLevels = <String, String>{
  'cepe': 'CEPE',
  'bepc': 'BEPC',
  'bac': 'BAC',
};

class _LibrarySubmissionPageState
    extends ConsumerState<LibrarySubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  _Category _category = _Category.book;

  // Champs communs / livre.
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _domain = TextEditingController();
  String? _bookType; // 'livre'|'memoire'|'article'|'rapport'|'these' — CHECK
  final _year = TextEditingController();
  final _summary = TextEditingController();
  // Annale.
  final _session = TextEditingController();
  String? _examLevel; // 'cepe'|'bepc'|'bac' — CHECK constraint
  bool _hasCorrection = false;
  // Support.
  final _level = TextEditingController();
  final _materialType = TextEditingController();
  final _publisher = TextEditingController();

  PlatformFile? _picked;
  bool _submitting = false;
  List<SbLibrarySubmission> _submissions = [];
  bool _loadingSubmissions = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _domain.dispose();
    _year.dispose();
    _summary.dispose();
    _session.dispose();
    _level.dispose();
    _materialType.dispose();
    _publisher.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    setState(() => _loadingSubmissions = true);
    try {
      final subs = await SupabaseDbSource.getMyLibrarySubmissions(schoolId);
      if (mounted) setState(() => _submissions = subs);
    } finally {
      if (mounted) setState(() => _loadingSubmissions = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4'],
      withData: true,
    );
    final picked =
        (result != null && result.files.isNotEmpty) ? result.files.first : null;
    if (picked == null || picked.bytes == null) return;
    if (picked.size > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fichier trop volumineux (max 20 Mo).'),
        backgroundColor: _terra,
      ));
      return;
    }
    setState(() => _picked = picked);
  }

  String get _categoryTable => switch (_category) {
        _Category.book => 'bibliotheque',
        _Category.exam => 'exam_subjects',
        _Category.material => 'course_materials',
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final schoolId = ref.read(currentSchoolIdProvider);
    final userId = ref.read(authSessionProvider)?.id;
    if (schoolId == null || userId == null) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? fileUrl;
      if (_picked != null) {
        fileUrl = await SupabaseDbSource.uploadLibraryContent(
          category: _categoryTable,
          filename: _picked!.name,
          bytes: _picked!.bytes!,
        );
      }

      switch (_category) {
        case _Category.book:
          await SupabaseDbSource.submitLibraryBook(
            schoolId: schoolId,
            userId: userId,
            titre: _title.text.trim(),
            auteur: _author.text.trim(),
            type: _bookType!,
            domaine: _domain.text.trim(),
            annee: _year.text.trim().isEmpty ? null : _year.text.trim(),
            url: fileUrl,
            resume: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          );
          break;
        case _Category.exam:
          await SupabaseDbSource.submitExamSubject(
            schoolId: schoolId,
            userId: userId,
            title: _title.text.trim(),
            subject: _domain.text.trim(),
            level: _examLevel!,
            year: int.parse(_year.text.trim()),
            session: _session.text.trim().isEmpty ? null : _session.text.trim(),
            hasCorrection: _hasCorrection,
            url: fileUrl,
          );
          break;
        case _Category.material:
          await SupabaseDbSource.submitCourseMaterial(
            schoolId: schoolId,
            userId: userId,
            title: _title.text.trim(),
            subject: _domain.text.trim(),
            type: _materialType.text.trim(),
            level: _level.text.trim().isEmpty ? null : _level.text.trim(),
            publisher:
                _publisher.text.trim().isEmpty ? null : _publisher.text.trim(),
            year: int.tryParse(_year.text.trim()),
            fileUrl: fileUrl,
          );
          break;
      }

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Soumis pour validation — visible par toutes les écoles une fois approuvé par la plateforme.'),
      ));
      _title.clear();
      _author.clear();
      _domain.clear();
      _year.clear();
      _summary.clear();
      _session.clear();
      _level.clear();
      _materialType.clear();
      _publisher.clear();
      setState(() {
        _picked = null;
        _hasCorrection = false;
        _bookType = null;
        _examLevel = null;
      });
      _loadSubmissions();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _terra,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Contribuer à la bibliothèque',
      subtitle:
          'Un contenu approuvé devient visible par toutes les écoles, pas seulement la vôtre.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DataPanel(
          title: 'Nouvelle soumission',
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<_Category>(
                segments: const [
                  ButtonSegment(value: _Category.book, label: Text('Livre')),
                  ButtonSegment(
                      value: _Category.exam, label: Text('Annale d\'examen')),
                  ButtonSegment(
                      value: _Category.material, label: Text('Support de cours')),
                ],
                selected: {_category},
                onSelectionChanged: (s) => setState(() => _category = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Titre *', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              if (_category == _Category.book) ...[
                TextFormField(
                  controller: _author,
                  decoration: const InputDecoration(
                      labelText: 'Auteur *', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _domain,
                decoration: InputDecoration(
                  labelText:
                      _category == _Category.book ? 'Domaine *' : 'Matière *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              if (_category == _Category.book) ...[
                DropdownButtonFormField<String>(
                  value: _bookType,
                  decoration: const InputDecoration(
                      labelText: 'Type *', border: OutlineInputBorder()),
                  items: [
                    for (final e in _bookTypes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _bookType = v),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
              ],
              if (_category == _Category.material) ...[
                TextFormField(
                  controller: _materialType,
                  decoration: const InputDecoration(
                      labelText: 'Type * (ex: TD, Fiche, Vidéo, Diaporama)',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
              ],
              if (_category == _Category.exam) ...[
                DropdownButtonFormField<String>(
                  value: _examLevel,
                  decoration: const InputDecoration(
                      labelText: 'Niveau *', border: OutlineInputBorder()),
                  items: [
                    for (final e in _examLevels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _examLevel = v),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
              ],
              if (_category == _Category.material) ...[
                TextFormField(
                  controller: _level,
                  decoration: const InputDecoration(
                      labelText: 'Niveau', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ],
              if (_category == _Category.exam) ...[
                TextFormField(
                  controller: _session,
                  decoration: const InputDecoration(
                      labelText: 'Session (ex: Juin)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hasCorrection,
                  onChanged: (v) => setState(() => _hasCorrection = v ?? false),
                  title: const Text('Correction disponible'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 4),
              ],
              if (_category == _Category.material) ...[
                TextFormField(
                  controller: _publisher,
                  decoration: const InputDecoration(
                      labelText: 'Déposé par / éditeur',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: _category == _Category.exam ? 'Année *' : 'Année',
                    border: const OutlineInputBorder()),
                validator: _category == _Category.exam
                    ? (v) => (v == null || int.tryParse(v.trim()) == null)
                        ? 'Année requise'
                        : null
                    : null,
              ),
              if (_category == _Category.book) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summary,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Résumé', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_picked == null
                    ? 'Joindre un fichier (PDF, doc, vidéo…)'
                    : _picked!.name),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: _submitting ? 'Envoi…' : 'Soumettre pour validation',
                  icon: Icons.upload_rounded,
                  primary: true,
                  onTap: _submitting ? null : _submit,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        DataPanel(
          title: 'Mes soumissions',
          child: _loadingSubmissions
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _submissions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Aucune soumission pour le moment.',
                          style: TextStyle(color: context.cMuted)),
                    )
                  : Column(
                      children: [
                        for (final s in _submissions)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title,
                                        style: TextStyle(
                                            color: context.cInk,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        '${s.categoryLabel} · ${s.createdAt != null ? DateFormat('dd/MM/yy').format(s.createdAt!) : '—'}',
                                        style: TextStyle(
                                            fontSize: 12, color: context.cMuted)),
                                    if (s.status == 'rejected' &&
                                        s.rejectionReason != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('Motif : ${s.rejectionReason}',
                                            style: const TextStyle(
                                                fontSize: 12, color: _terra)),
                                      ),
                                  ],
                                ),
                              ),
                              switch (s.status) {
                                'published' => StatusPill.success('Publié'),
                                'rejected' => StatusPill.danger('Rejeté'),
                                _ => StatusPill.warning('En attente'),
                              },
                            ]),
                          ),
                      ],
                    ),
        ),
      ]),
    );
  }
}
