/// Import d'élèves en masse depuis un fichier Excel (.xlsx) ou CSV.
///
/// Trois étapes : choisir le fichier → relire l'aperçu (une ligne = un
/// élève, erreurs mises en évidence) → confirmer. Chaque ligne valide passe
/// par le MÊME chemin qu'une inscription au clavier (`createStudent` +
/// `createOrLinkGuardian`, cf. `_saveStudent` dans users_page.dart) — la
/// limite d'élèves de l'offre est donc respectée exactement pareil, ligne
/// par ligne (elle peut couper l'import en cours de route).
library;

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold = Color(0xFFC17F24);

enum _Stage { pick, preview, importing, done }

/// Une ligne du fichier, une fois reconnue — ou pas (`errors` non vide).
class _ImportRow {
  final int lineNumber; // ligne du fichier (1 = en-têtes), pour retrouver la source
  String firstName = '';
  String lastName = '';
  String birthDate = ''; // ISO yyyy-MM-dd, déjà convertie
  String birthPlace = '';
  String gender = '';
  String nationality = '';
  String matricule = '';
  String email = '';
  String phone = '';
  String className = '';
  String guardianName = '';
  String guardianPhone = '';
  String guardianEmail = '';
  String guardianRelation = '';
  String? classId; // résolu contre les classes de l'école
  bool classNotFound = false;
  final List<String> errors = [];

  _ImportRow(this.lineNumber);

  String get fullName => '$firstName $lastName'.trim();
  bool get isValid => errors.isEmpty;
}

/// Alias reconnus pour chaque en-tête, normalisés (minuscules, sans accent,
/// espaces simples) — tolère pas mal de variations sans imposer un gabarit
/// rigide à l'école qui exporte depuis son propre tableur.
const Map<String, List<String>> _kHeaderAliases = {
  'lastName': ['nom', 'nom de famille'],
  'firstName': ['prenom', 'prenoms', 'prenom(s)'],
  'fullName': ['nom complet', 'nom et prenom', 'nom et prenoms'],
  'birthDate': ['date de naissance', 'naissance', 'date naissance'],
  'birthPlace': ['lieu de naissance', 'lieu naissance'],
  'gender': ['genre', 'sexe'],
  'nationality': ['nationalite'],
  'className': ['classe', 'classe demandee'],
  'matricule': ['matricule'],
  'email': ['email', 'email eleve', 'mail'],
  'phone': ['telephone', 'telephone eleve', 'tel'],
  'guardianName': ['nom du tuteur', 'tuteur', 'nom du parent', 'parent', 'nom parent/tuteur'],
  'guardianPhone': ['telephone du tuteur', 'telephone tuteur', 'telephone parent'],
  'guardianEmail': ['email du tuteur', 'email tuteur', 'email parent'],
  'guardianRelation': ['lien de parente', 'relation', 'lien'],
};

String _normalizeHeader(String s) {
  var out = s.trim().toLowerCase();
  const accents = {
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'à': 'a', 'â': 'a', 'ä': 'a',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };
  accents.forEach((from, to) => out = out.replaceAll(from, to));
  return out.replaceAll(RegExp(r'\s+'), ' ');
}

String _cellToString(dynamic v) {
  if (v == null) return '';
  if (v is xlsx.TextCellValue) return v.value.text ?? '';
  if (v is xlsx.IntCellValue) return v.value.toString();
  if (v is xlsx.DoubleCellValue) {
    final d = v.value;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }
  if (v is xlsx.BoolCellValue) return v.value.toString();
  if (v is xlsx.DateCellValue) {
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
  }
  if (v is xlsx.DateTimeCellValue) {
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
  }
  if (v is xlsx.FormulaCellValue) return v.formula;
  return v.toString();
}

/// Date de naissance → ISO `yyyy-MM-dd`. Une cellule Excel typée Date passe
/// directement (pas de round-trip texte) ; sinon on essaie `JJ/MM/AAAA`,
/// `JJ-MM-AAAA` puis `AAAA-MM-JJ`. `null` si rien ne correspond.
String? _parseBirthDate(dynamic v) {
  if (v is xlsx.DateCellValue) {
    return '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  if (v is xlsx.DateTimeCellValue) {
    return '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  final s = _cellToString(v).trim();
  if (s.isEmpty) return null;
  var m = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(s);
  if (m != null) {
    final d = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    return '${m.group(3)}-$mo-$d';
  }
  m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m != null) {
    return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
  }
  return null;
}

String _normalizeGender(String s) {
  final g = _normalizeHeader(s);
  if (g.startsWith('m')) return 'Masculin';
  if (g.startsWith('f')) return 'Féminin';
  return '';
}

class StudentsImportPage extends ConsumerStatefulWidget {
  final String schoolId;
  final List<SbClass> classes;
  final VoidCallback onBack;
  /// Appelé après un import (même partiel) pour rafraîchir la liste.
  final VoidCallback onImported;
  const StudentsImportPage({
    super.key,
    required this.schoolId,
    required this.classes,
    required this.onBack,
    required this.onImported,
  });

  @override
  ConsumerState<StudentsImportPage> createState() => _StudentsImportPageState();
}

class _StudentsImportPageState extends ConsumerState<StudentsImportPage> {
  _Stage _stage = _Stage.pick;
  String? _fileName;
  String? _pickError;
  List<_ImportRow> _rows = [];

  int _importDone = 0;
  int _importSucceeded = 0;
  final List<(String name, String reason)> _importFailed = [];
  bool _importStopped = false; // limite d'élèves atteinte en cours de route

  Map<String, dynamic> get _classByNormalizedName => {
        for (final c in widget.classes) _normalizeHeader(c.name): c.id,
      };

  Future<void> _pickFile() async {
    setState(() => _pickError = null);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _pickError = 'Impossible de lire ce fichier.');
      return;
    }
    try {
      final ext = (file.extension ?? '').toLowerCase();
      final rows = ext == 'csv'
          ? _parseCsv(bytes)
          : _parseXlsx(bytes);
      if (rows.isEmpty) {
        setState(() => _pickError =
            'Le fichier ne contient aucune ligne exploitable (vérifiez qu\'il a bien une ligne d\'en-têtes suivie de lignes d\'élèves).');
        return;
      }
      setState(() {
        _fileName = file.name;
        _rows = rows;
        _stage = _Stage.preview;
      });
    } catch (e) {
      setState(() => _pickError = 'Fichier illisible : $e');
    }
  }

  List<_ImportRow> _parseCsv(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      // Beaucoup de tableurs exportent en Windows-1252 sur Windows : on
      // retombe sur latin1 plutôt que planter sur un accent.
      text = latin1.decode(bytes);
    }
    final table = const CsvToListConverter(shouldParseNumbers: false).convert(text, eol: '\n');
    return _rowsFromTable(table);
  }

  List<_ImportRow> _parseXlsx(Uint8List bytes) {
    final book = xlsx.Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return [];
    final sheet = book.tables.values.first;
    return _rowsFromTable(sheet.rows.map((r) => r.map((c) => c?.value).toList()).toList());
  }

  List<_ImportRow> _rowsFromTable(List<List<dynamic>> table) {
    if (table.isEmpty) return [];
    final headers = table.first.map((h) => _normalizeHeader(_cellToString(h))).toList();

    // en-tête normalisé → index de colonne
    final colIndex = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      for (final entry in _kHeaderAliases.entries) {
        if (entry.value.contains(h) && !colIndex.containsKey(entry.key)) {
          colIndex[entry.key] = i;
        }
      }
    }

    String cell(List<dynamic> line, String field) {
      final i = colIndex[field];
      if (i == null || i >= line.length) return '';
      return _cellToString(line[i]).trim();
    }

    final out = <_ImportRow>[];
    for (var li = 1; li < table.length; li++) {
      final line = table[li];
      // Ligne entièrement vide (souvent en fin de feuille) — ignorée sans erreur.
      if (line.every((c) => _cellToString(c).trim().isEmpty)) continue;

      final row = _ImportRow(li + 1);
      final fullName = cell(line, 'fullName');
      if (fullName.isNotEmpty) {
        final parts = fullName.split(RegExp(r'\s+'));
        row.firstName = parts.first;
        row.lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      } else {
        row.firstName = cell(line, 'firstName');
        row.lastName = cell(line, 'lastName');
      }
      row.birthDate = colIndex.containsKey('birthDate')
          ? (_parseBirthDate(line[colIndex['birthDate']!]) ?? '')
          : '';
      final birthDateRaw = cell(line, 'birthDate');
      row.birthPlace = cell(line, 'birthPlace');
      row.gender = _normalizeGender(cell(line, 'gender'));
      row.nationality = cell(line, 'nationality');
      row.matricule = cell(line, 'matricule');
      row.email = cell(line, 'email');
      row.phone = cell(line, 'phone');
      row.className = cell(line, 'className');
      row.guardianName = cell(line, 'guardianName');
      row.guardianPhone = cell(line, 'guardianPhone');
      row.guardianEmail = cell(line, 'guardianEmail');
      row.guardianRelation = cell(line, 'guardianRelation');

      if (row.className.isNotEmpty) {
        final id = _classByNormalizedName[_normalizeHeader(row.className)];
        if (id != null) {
          row.classId = id as String;
        } else {
          row.classNotFound = true;
        }
      }

      if (row.firstName.isEmpty && row.lastName.isEmpty) {
        row.errors.add('Nom manquant');
      }
      if (birthDateRaw.isNotEmpty && row.birthDate.isEmpty) {
        row.errors.add('Date de naissance illisible ("$birthDateRaw") — attendu JJ/MM/AAAA');
      }
      out.add(row);
    }
    return out;
  }

  Future<void> _confirmImport() async {
    final valid = _rows.where((r) => r.isValid).toList();
    setState(() {
      _stage = _Stage.importing;
      _importDone = 0;
      _importSucceeded = 0;
      _importFailed.clear();
      _importStopped = false;
    });
    final familiesEnabled = await ref.read(familyAccountsEnabledProvider.future);
    for (final row in valid) {
      if (!mounted) return;
      final canAdd = await SupabaseDbSource.canAddStudent(widget.schoolId);
      if (!canAdd) {
        setState(() => _importStopped = true);
        break;
      }
      try {
        final studentId = await SupabaseDbSource.createStudent(
          schoolId: widget.schoolId,
          fullName: row.fullName.isEmpty ? 'Élève' : row.fullName,
          email: row.email.isEmpty ? null : row.email,
          phone: row.phone.isEmpty ? null : row.phone,
          classId: row.classId,
          matricule: row.matricule.isEmpty ? null : row.matricule,
          birthDate: row.birthDate.isEmpty ? null : row.birthDate,
          birthPlace: row.birthPlace.isEmpty ? null : row.birthPlace,
          gender: row.gender.isEmpty ? null : row.gender,
          nationality: row.nationality.isEmpty ? null : row.nationality,
        );
        if (familiesEnabled && row.guardianName.isNotEmpty) {
          await SupabaseDbSource.createOrLinkGuardian(
            schoolId: widget.schoolId,
            studentId: studentId,
            guardianName: row.guardianName,
            phone: row.guardianPhone.isEmpty ? null : row.guardianPhone,
            email: row.guardianEmail.isEmpty ? null : row.guardianEmail,
            relationship: row.guardianRelation.isEmpty ? 'Parent' : row.guardianRelation,
          );
        }
        if (!mounted) return;
        setState(() => _importSucceeded++);
      } catch (e) {
        if (!mounted) return;
        setState(() => _importFailed.add((row.fullName, e.toString())));
      }
      if (!mounted) return;
      setState(() => _importDone++);
    }
    if (!mounted) return;
    widget.onImported();
    setState(() => _stage = _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cPage,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: widget.onBack,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_rounded, size: 15, color: context.cMuted),
                    const SizedBox(width: 6),
                    Text('Retour aux élèves',
                        style: TextStyle(
                            fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: switch (_stage) {
              _Stage.pick => _buildPick(context),
              _Stage.preview => _buildPreview(context),
              _Stage.importing => _buildImporting(context),
              _Stage.done => _buildDone(context),
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildPick(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Importer des élèves',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cInk)),
      const SizedBox(height: 4),
      Text('Depuis un fichier Excel (.xlsx) ou CSV — une ligne = un élève.',
          style: TextStyle(fontSize: 13, color: context.cMuted)),
      const SizedBox(height: 20),
      DataPanel(
        title: 'Colonnes reconnues',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'La première ligne du fichier doit contenir les en-têtes. L\'ordre des '
              'colonnes n\'importe pas, et vous pouvez en omettre — seuls Nom et Prénom '
              '(ou « Nom complet ») sont obligatoires.',
              style: TextStyle(fontSize: 12.5, color: context.cMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in [
                'Nom', 'Prénom', 'Date de naissance', 'Lieu de naissance', 'Genre',
                'Nationalité', 'Classe', 'Matricule', 'Email', 'Téléphone',
                'Nom du tuteur', 'Téléphone du tuteur', 'Email du tuteur', 'Lien de parenté',
              ])
                Chip(
                  label: Text(h, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: context.cSubtle,
                  side: BorderSide(color: context.cBorder),
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(
                    text: 'Nom;Prénom;Date de naissance;Lieu de naissance;Genre;'
                        'Nationalité;Classe;Matricule;Email;Téléphone;Nom du tuteur;'
                        'Téléphone du tuteur;Email du tuteur;Lien de parenté'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('En-têtes copiés — collez-les en première ligne de votre fichier.'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copier les en-têtes'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      if (_pickError != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _terra.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
          child: Text(_pickError!, style: const TextStyle(color: _terra, fontSize: 12.5)),
        ),
        const SizedBox(height: 12),
      ],
      FilledButton.icon(
        onPressed: _pickFile,
        style: FilledButton.styleFrom(backgroundColor: _terra),
        icon: const Icon(Icons.upload_file_rounded, size: 17),
        label: const Text('Choisir un fichier'),
      ),
    ]);
  }

  Widget _buildPreview(BuildContext context) {
    final valid = _rows.where((r) => r.isValid).toList();
    final invalid = _rows.where((r) => !r.isValid).toList();
    final noClass = valid.where((r) => r.className.isNotEmpty && r.classNotFound).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Aperçu — $_fileName',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cInk)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _CountChip(icon: Icons.check_circle_rounded, color: _green, label: '${valid.length} valides'),
        if (invalid.isNotEmpty)
          _CountChip(icon: Icons.error_rounded, color: _terra, label: '${invalid.length} en erreur'),
        if (noClass.isNotEmpty)
          _CountChip(
              icon: Icons.warning_rounded, color: _gold, label: '${noClass.length} classe introuvable'),
      ]),
      const SizedBox(height: 16),
      DataPanel(
        title: 'Lignes du fichier',
        child: Column(children: [for (final r in _rows) _ImportRowTile(row: r)]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        TextButton(
          onPressed: () => setState(() { _stage = _Stage.pick; _rows = []; }),
          child: const Text('Choisir un autre fichier'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: valid.isEmpty ? null : _confirmImport,
          style: FilledButton.styleFrom(backgroundColor: _terra),
          icon: const Icon(Icons.check_rounded, size: 17),
          label: Text('Importer ${valid.length} élève${valid.length > 1 ? 's' : ''}'),
        ),
      ]),
    ]);
  }

  Widget _buildImporting(BuildContext context) {
    final total = _rows.where((r) => r.isValid).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Import en cours…',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cInk)),
      const SizedBox(height: 16),
      LinearProgressIndicator(value: total == 0 ? null : _importDone / total),
      const SizedBox(height: 10),
      Text('$_importDone / $total', style: TextStyle(fontSize: 12.5, color: context.cMuted)),
    ]);
  }

  Widget _buildDone(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.check_circle_rounded, color: _green, size: 22),
        const SizedBox(width: 8),
        Text('Import terminé',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cInk)),
      ]),
      const SizedBox(height: 8),
      Text('$_importSucceeded élève${_importSucceeded > 1 ? 's' : ''} inscrit${_importSucceeded > 1 ? 's' : ''}.',
          style: TextStyle(fontSize: 13, color: context.cMuted)),
      if (_importStopped) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _gold.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
          child: const Text(
            'Import interrompu : limite d\'élèves de votre offre atteinte. '
            'Passez à l\'offre supérieure pour importer le reste.',
            style: TextStyle(color: _gold, fontSize: 12.5),
          ),
        ),
      ],
      if (_importFailed.isNotEmpty) ...[
        const SizedBox(height: 16),
        DataPanel(
          title: '${_importFailed.length} échec${_importFailed.length > 1 ? 's' : ''}',
          child: Column(children: [
            for (final f in _importFailed)
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline_rounded, color: _terra, size: 18),
                title: Text(f.$1.isEmpty ? '(sans nom)' : f.$1,
                    style: TextStyle(fontSize: 13, color: context.cInk)),
                subtitle: Text(f.$2, style: TextStyle(fontSize: 11.5, color: context.cMuted)),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: widget.onBack,
        style: FilledButton.styleFrom(backgroundColor: _terra),
        child: const Text('Terminer'),
      ),
    ]);
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _CountChip({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ImportRowTile extends StatelessWidget {
  final _ImportRow row;
  const _ImportRowTile({required this.row});
  @override
  Widget build(BuildContext context) {
    final ok = row.isValid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.cBorder)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            size: 16, color: ok ? _green : _terra),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text('L${row.lineNumber}',
              style: TextStyle(fontSize: 11, color: context.cMuted)),
        ),
        Expanded(
          flex: 3,
          child: Text(row.fullName.isEmpty ? '(sans nom)' : row.fullName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cInk)),
        ),
        Expanded(
          flex: 2,
          child: row.className.isEmpty
              ? Text('Sans classe', style: TextStyle(fontSize: 12, color: context.cMuted))
              : Text(
                  row.classNotFound ? '${row.className} (introuvable)' : row.className,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: row.classNotFound ? _gold : context.cMuted,
                      fontWeight: row.classNotFound ? FontWeight.w700 : FontWeight.normal),
                ),
        ),
        Expanded(
          flex: 3,
          child: row.errors.isEmpty
              ? const SizedBox.shrink()
              : Text(row.errors.join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _terra)),
        ),
      ]),
    );
  }
}
