import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import '../data/enrollment_config.dart';
import '../widgets/page_scaffold.dart';

// Accents de marque — constants dans les deux thèmes (cf. convention thème).
const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold   = Color(0xFFC17F24);
const _green  = Color(0xFF2D6A4F);

// ─────────────────────────────────────────────────────────────────────────────
/// Page d'inscription configurable — restylée sur le design system (sections
/// `DataPanel`, neutres via `context.c*` → compatible mode sombre).
///
/// Utilisée pour :
///   1. Inscrire un élève depuis users_page (admin)
///   2. Auto-inscription publique (parent inscrit son enfant)
///
/// [config] — config admin. Si null, utilise les defaults.
/// [onSubmit] — callback avec les données saisies (map fieldId → valeur).
// ─────────────────────────────────────────────────────────────────────────────
class EnrollmentPage extends StatefulWidget {
  final EnrollmentConfig? config;
  final Future<void> Function(Map<String, dynamic> data)? onSubmit;
  final bool isAdminMode;
  final List<SbClass>? adminClasses;

  /// Effectif actuel par classe (`class_id` → nombre d'élèves actifs) —
  /// affiché à côté du nom dans le sélecteur admin (ex. « 8ème A (12/40) »),
  /// sur le même modèle que `admin_classes_page.dart`. `null`/classe absente
  /// de la map ⇒ affiché comme vide (0).
  final Map<String, int>? classStudentCounts;

  /// École cible des photos/documents déposés (bucket `enrollment-documents`,
  /// dossier `{schoolId}/...`). `null` désactive l'upload réel (ex. aperçu de
  /// configuration admin, où il n'y a pas de dossier à créer).
  final String? schoolId;

  const EnrollmentPage({
    super.key,
    this.config,
    this.onSubmit,
    this.isAdminMode = false,
    this.adminClasses,
    this.classStudentCounts,
    this.schoolId,
  });

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  late final EnrollmentConfig _config;
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _submitted = false;
  bool _loading = false;
  String? _selectedClassId;

  /// Regroupe tous les fichiers d'une même soumission avant que la demande
  /// n'existe encore en base (pré-inscription publique, sans compte).
  final String _uploadSessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? EnrollmentConfig.defaults();
    for (final f in _config.enabledFields) {
      if (f.type == FieldType.text ||
          f.type == FieldType.email ||
          f.type == FieldType.phone ||
          f.type == FieldType.number ||
          f.type == FieldType.textarea ||
          f.type == FieldType.date) {
        _controllers[f.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Un champ est « rempli » s'il a une valeur non vide (toggle décoché = non).
  bool _isFilled(EnrollmentField f) {
    final v = _controllers[f.id]?.text ?? _values[f.id];
    if (v == null || v == false) return false;
    return v.toString().trim().isNotEmpty;
  }

  int get _filledCount => _config.enabledFields.where(_isFilled).length;

  Map<String, List<EnrollmentField>> get _fieldsByCategory {
    final result = <String, List<EnrollmentField>>{};
    for (final f in _config.enabledFields) {
      result.putIfAbsent(f.category, () => []).add(f);
    }
    return result;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final data = <String, dynamic>{};
    for (final f in _config.enabledFields) {
      data[f.id] = _controllers[f.id]?.text ?? _values[f.id];
    }
    if (widget.isAdminMode && widget.adminClasses != null) {
      data['class_id'] = _selectedClassId;
    }

    setState(() => _loading = true);
    try {
      await widget.onSubmit?.call(data);
      if (!mounted) return;
      setState(() { _loading = false; _submitted = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // Le trigger serveur (enrollment_requests_guard) renvoie un message
      // clair (« Champs obligatoires manquants : ... », clé invalide…) dans
      // PostgrestException.message — on l'affiche tel quel plutôt que le
      // texte brut de l'exception (illisible pour un visiteur du formulaire).
      final message = e is PostgrestException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi : $message'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(isAdmin: widget.isAdminMode);

    final cats = _fieldsByCategory;

    return Container(
      color: context.cPage,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              _EnrollHeader(isAdmin: widget.isAdminMode),
              const SizedBox(height: 14),

              // ── Message d'accueil ─────────────────────────────────────
              if (_config.welcomeMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withValues(alpha: .3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: _gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_config.welcomeMessage!,
                          style: TextStyle(
                              color: context.cInk, fontSize: 12.5, height: 1.4)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ── Progression ───────────────────────────────────────────
              _ProgressBar(
                filled: _filledCount,
                total: _config.enabledFields.length,
              ),
              const SizedBox(height: 14),

              // ── Sélecteur de classe (admin uniquement) ────────────────
              if (widget.isAdminMode &&
                  widget.adminClasses != null &&
                  widget.adminClasses!.isNotEmpty) ...[
                _AdminClassPicker(
                  classes: widget.adminClasses!,
                  studentCounts: widget.classStudentCounts ?? const {},
                  selectedId: _selectedClassId,
                  onChanged: (id) => setState(() => _selectedClassId = id),
                ),
                const SizedBox(height: 14),
              ],

              // ── Sections par catégorie ────────────────────────────────
              for (final entry in cats.entries) ...[
                DataPanel(
                  title: entry.key,
                  headerActions: [
                    Text(
                        '${entry.value.where(_isFilled).length}/${entry.value.length}',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.cMuted,
                            fontWeight: FontWeight.w700)),
                  ],
                  child: LayoutBuilder(builder: (_, c) {
                    const gap = 14.0;
                    final twoCol = c.maxWidth >= 520;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final f in entry.value)
                          SizedBox(
                            width: (!twoCol || _spansFull(f.type))
                                ? c.maxWidth
                                : (c.maxWidth - gap) / 2,
                            child: _FieldWidget(
                              field: f,
                              required: _config.isRequired(f.id),
                              controller: _controllers[f.id],
                              value: _values[f.id],
                              schoolId: widget.schoolId,
                              uploadSessionId: _uploadSessionId,
                              onChanged: (v) =>
                                  setState(() => _values[f.id] = v),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],

              // ── Bouton d'envoi ────────────────────────────────────────
              const SizedBox(height: 4),
              _SubmitButton(loading: _loading, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (bandeau de marque — dégradé terracotta, texte blanc : OK en sombre)
// ─────────────────────────────────────────────────────────────────────────────
class _EnrollHeader extends StatelessWidget {
  final bool isAdmin;
  const _EnrollHeader({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_terra, _orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _terra.withValues(alpha: .3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .35)),
              ),
              child: Text(
                isAdmin ? 'INSCRIPTION — ADMIN' : 'NOUVELLE INSCRIPTION',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Formulaire d\'inscription',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? 'Remplissez les informations de l\'élève à inscrire.'
                  : 'Complétez les informations requises pour inscrire votre enfant.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .85),
                  fontSize: 12.5,
                  height: 1.4),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
          ),
          child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 26),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progression
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int filled;
  final int total;
  const _ProgressBar({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: context.cSubtle,
            valueColor: const AlwaysStoppedAnimation(_terra),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text('$filled/$total champs',
          style: TextStyle(
              fontSize: 11, color: context.cMuted, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Champs qui prennent toute la largeur (même en grille 2 colonnes) : ils
/// respirent mal sur une demi-largeur.
bool _spansFull(FieldType t) =>
    t == FieldType.textarea || t == FieldType.photo || t == FieldType.file;

// ─────────────────────────────────────────────────────────────────────────────
// Field Widget — adapte l'UI selon le FieldType
// ─────────────────────────────────────────────────────────────────────────────
class _FieldWidget extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController? controller;
  final dynamic value;
  final String? schoolId;
  final String uploadSessionId;
  final ValueChanged<dynamic> onChanged;

  const _FieldWidget({
    required this.field,
    required this.required,
    this.controller,
    this.value,
    required this.schoolId,
    required this.uploadSessionId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FieldType.photo:
        return _PhotoField(field: field, required: required,
            schoolId: schoolId, uploadSessionId: uploadSessionId,
            onChanged: onChanged);
      case FieldType.file:
        return _FileField(field: field, required: required,
            schoolId: schoolId, uploadSessionId: uploadSessionId,
            onChanged: onChanged);
      case FieldType.select:
        return _SelectField(field: field, required: required,
            value: value as String?, onChanged: onChanged);
      case FieldType.toggle:
        return _ToggleField(field: field, value: value as bool? ?? false,
            onChanged: onChanged);
      case FieldType.textarea:
        return _TextAreaField(field: field, required: required,
            controller: controller!, onChanged: onChanged);
      case FieldType.date:
        return _DateField(field: field, required: required,
            controller: controller!, onChanged: onChanged);
      default:
        return _TextInputField(field: field, required: required,
            controller: controller!, onChanged: onChanged);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coquille réutilisable (libellé + astérisque + hint)
// ─────────────────────────────────────────────────────────────────────────────
class _FieldShell extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final Widget child;

  const _FieldShell({
    required this.field,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
          child: Text(field.label,
              style: TextStyle(
                  fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w700)),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(color: _terra, fontWeight: FontWeight.w900)),
        ],
      ]),
      if (field.hint != null) ...[
        const SizedBox(height: 2),
        Text(field.hint!,
            style: TextStyle(fontSize: 10.5, color: context.cMuted)),
      ],
      const SizedBox(height: 6),
      child,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Décoration d'input theme-aware
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _decor(BuildContext context, String hint, {Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: context.cMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.cSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.cBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _terra, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _terra),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _terra, width: 1.5),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Texte
// ─────────────────────────────────────────────────────────────────────────────
class _TextInputField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController controller;
  final ValueChanged<dynamic> onChanged;

  const _TextInputField({
    required this.field,
    required this.required,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: field.type == FieldType.email
            ? TextInputType.emailAddress
            : field.type == FieldType.phone
                ? TextInputType.phone
                : field.type == FieldType.number
                    ? TextInputType.number
                    : TextInputType.text,
        decoration: _decor(context, field.placeholder),
        style: TextStyle(fontSize: 13, color: context.cInk),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? 'Ce champ est obligatoire'
                : null
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone de texte
// ─────────────────────────────────────────────────────────────────────────────
class _TextAreaField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController controller;
  final ValueChanged<dynamic> onChanged;

  const _TextAreaField({
    required this.field,
    required this.required,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        maxLines: 3,
        decoration: _decor(context, field.placeholder),
        style: TextStyle(fontSize: 13, color: context.cInk),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? 'Ce champ est obligatoire'
                : null
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date
// ─────────────────────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController controller;
  final ValueChanged<dynamic> onChanged;

  const _DateField({
    required this.field,
    required this.required,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 15),
            firstDate: DateTime(1940),
            lastDate: now,
          );
          if (picked != null) {
            final str =
                '${picked.day.toString().padLeft(2, '0')}/'
                '${picked.month.toString().padLeft(2, '0')}/'
                '${picked.year}';
            controller.text = str;
            onChanged(str);
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: controller,
            decoration: _decor(context, 'JJ/MM/AAAA',
                suffix: Icon(Icons.calendar_today_rounded,
                    size: 16, color: context.cMuted)),
            style: TextStyle(fontSize: 13, color: context.cInk),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Ce champ est obligatoire'
                    : null
                : null,
          ),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select
// ─────────────────────────────────────────────────────────────────────────────
class _SelectField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final String? value;
  final ValueChanged<dynamic> onChanged;

  const _SelectField({
    required this.field,
    required this.required,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: FormField<String>(
        initialValue: value,
        validator: required && value == null
            ? (_) => 'Sélectionnez une option'
            : null,
        builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: state.hasError ? _terra : context.cBorder),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: context.cCard,
              hint: Text(field.placeholder.isEmpty
                  ? 'Sélectionner...'
                  : field.placeholder,
                  style: TextStyle(fontSize: 13, color: context.cMuted)),
              icon: Icon(Icons.expand_more_rounded, size: 16, color: context.cMuted),
              style: TextStyle(fontSize: 13, color: context.cInk),
              items: field.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(color: _terra, fontSize: 11)),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleField extends StatelessWidget {
  final EnrollmentField field;
  final bool value;
  final ValueChanged<dynamic> onChanged;

  const _ToggleField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(field.label,
                style: TextStyle(
                    fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w700)),
            if (field.hint != null)
              Text(field.hint!,
                  style: TextStyle(fontSize: 11, color: context.cMuted)),
          ]),
        ),
        Switch(value: value, activeColor: _terra, onChanged: onChanged),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo — sélection réelle (galerie) + upload vers Supabase Storage
// (bucket privé `enrollment-documents`). `onChanged` reçoit le CHEMIN de
// stockage (pas une URL publique) : cf. `getEnrollmentDocumentUrl` pour
// l'afficher plus tard côté admin.
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoField extends StatefulWidget {
  final EnrollmentField field;
  final bool required;
  final String? schoolId;
  final String uploadSessionId;
  final ValueChanged<dynamic> onChanged;

  const _PhotoField({
    required this.field,
    required this.required,
    required this.schoolId,
    required this.uploadSessionId,
    required this.onChanged,
  });

  @override
  State<_PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<_PhotoField> {
  bool _uploading = false;
  Uint8List? _bytes; // aperçu immédiat

  Future<void> _pick() async {
    final schoolId = widget.schoolId;
    if (schoolId == null || _uploading) return;
    final XFile? picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _uploading = true; _bytes = bytes; });
    try {
      final url = await SupabaseDbSource.uploadStudentPhoto(
        schoolId: schoolId,
        sessionId: widget.uploadSessionId,
        filename: picked.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      widget.onChanged(url);
    } catch (e) {
      if (!mounted) return;
      // L'aperçu local reste affiché, mais _url reste null : la photo ne
      // sera pas jointe à la fiche tant que l'envoi n'a pas réussi.
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi de la photo : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _bytes != null;
    return _FieldShell(
      field: widget.field,
      required: widget.required,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
        onTap: _pick,
        child: Container(
          height: 100,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? _terra.withValues(alpha: .06) : context.cSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? _terra.withValues(alpha: .3) : context.cBorder),
          ),
          child: selected
              ? Row(children: [
                  SizedBox(
                    width: 100, height: 100,
                    child: Image.memory(_bytes!, fit: BoxFit.cover),
                  ),
                  Expanded(
                    child: Center(
                      child: _uploading
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                              const SizedBox(height: 4),
                              Text('Photo ajoutée',
                                  style: const TextStyle(color: _green,
                                      fontWeight: FontWeight.w700, fontSize: 12.5)),
                            ]),
                    ),
                  ),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_rounded, color: context.cMuted, size: 28),
                  const SizedBox(height: 8),
                  Text('Cliquez pour ajouter une photo',
                      style: TextStyle(color: context.cMuted, fontSize: 12)),
                ]),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fichier — sélection réelle (PDF/image) + upload vers Supabase Storage.
// ─────────────────────────────────────────────────────────────────────────────
class _FileField extends StatefulWidget {
  final EnrollmentField field;
  final bool required;
  final String? schoolId;
  final String uploadSessionId;
  final ValueChanged<dynamic> onChanged;

  const _FileField({
    required this.field,
    required this.required,
    required this.schoolId,
    required this.uploadSessionId,
    required this.onChanged,
  });

  @override
  State<_FileField> createState() => _FileFieldState();
}

class _FileFieldState extends State<_FileField> {
  bool _uploading = false;
  String? _fileName;

  Future<void> _pick() async {
    final schoolId = widget.schoolId;
    if (schoolId == null || _uploading) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final picked =
        (result != null && result.files.isNotEmpty) ? result.files.first : null;
    if (picked == null || picked.bytes == null) return;
    if (picked.size > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fichier trop volumineux (max 5 Mo).'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _uploading = true);
    try {
      final path = await SupabaseDbSource.uploadEnrollmentDocument(
        schoolId: schoolId,
        sessionId: widget.uploadSessionId,
        fieldId: widget.field.id,
        filename: picked.name,
        bytes: picked.bytes!,
      );
      if (!mounted) return;
      setState(() { _uploading = false; _fileName = picked.name; });
      widget.onChanged(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: widget.field,
      required: widget.required,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
        onTap: _pick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _fileName != null
                ? _green.withValues(alpha: .3)
                : context.cBorder),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _fileName != null
                    ? _green.withValues(alpha: .1)
                    : context.cCard,
                borderRadius: BorderRadius.circular(9),
              ),
              child: _uploading
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _fileName != null
                          ? Icons.check_circle_outline_rounded
                          : Icons.upload_file_rounded,
                      color: _fileName != null ? _green : context.cMuted,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _fileName ?? 'Cliquez pour sélectionner un fichier',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: _fileName != null ? context.cInk : context.cMuted,
                      fontWeight: _fileName != null
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
                Text('PDF, JPG, PNG — max 5 Mo',
                    style: TextStyle(fontSize: 10, color: context.cMuted)),
              ]),
            ),
            if (_fileName != null)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => setState(() { _fileName = null; widget.onChanged(null); }),
                child: Icon(Icons.close_rounded, size: 16, color: context.cMuted),
                ),
              ),
          ]),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton d'envoi (dégradé de marque — texte blanc OK en sombre)
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: loading
                ? [context.cMuted, context.cMuted.withValues(alpha: .7)]
                : [_terra, _orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [BoxShadow(color: _terra.withValues(alpha: .3),
                  blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Valider l\'inscription',
                      style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran de succès
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final bool isAdmin;
  const _SuccessView({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cPage,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: .1),
                shape: BoxShape.circle,
                border: Border.all(color: _green.withValues(alpha: .3), width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Inscription enregistrée !',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cInk, fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Le dossier de l\'élève a été créé avec succès.'
                  : 'Votre dossier a été soumis. L\'équipe administrative '
                    'vous contactera pour confirmer l\'inscription.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cMuted, fontSize: 13, height: 1.5),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _terra,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Retour à la liste',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur de classe — mode admin uniquement
// ─────────────────────────────────────────────────────────────────────────────
class _AdminClassPicker extends StatelessWidget {
  final List<SbClass> classes;
  final Map<String, int> studentCounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _AdminClassPicker({
    required this.classes,
    required this.studentCounts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Affectation à une classe',
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cBorder),
        ),
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: context.cCard,
          hint: Text('Sélectionner une classe (optionnel)',
              style: TextStyle(fontSize: 13, color: context.cMuted)),
          icon: Icon(Icons.expand_more_rounded, size: 16, color: context.cMuted),
          style: TextStyle(fontSize: 13, color: context.cInk),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('— Aucune classe —',
                  style: TextStyle(
                      color: context.cMuted, fontStyle: FontStyle.italic)),
            ),
            for (final c in classes)
              DropdownMenuItem(
                value: c.id,
                child: Builder(builder: (context) {
                  final count = studentCounts[c.id] ?? 0;
                  final full = count >= c.maxStudents;
                  return Text(
                    '${c.name} ($count/${c.maxStudents})'
                    '${full ? ' — complet' : ''}',
                    style: TextStyle(
                        color: full ? _terra : context.cInk,
                        fontWeight: full ? FontWeight.w700 : FontWeight.normal),
                  );
                }),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
