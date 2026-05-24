import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/enrollment_config.dart';

const _terra   = Color(0xFF8B1A00);
const _orange  = Color(0xFFD4540A);
const _gold    = Color(0xFFC17F24);
const _green   = Color(0xFF2D6A4F);
const _ink     = Color(0xFF1A0A00);
const _muted   = Color(0xFF7A5C44);
const _white   = Colors.white;
const _bg      = Color(0xFFF5EEE6);
const _borderC = Color(0xFFDDCCBB);
const _sh1     = Color(0xFF1A0A00);
const _sh2     = Color(0xFF3E1A00);

// ─────────────────────────────────────────────────────────────────────────────
/// Page d'inscription configurable.
/// Utilisée pour :
///   1. Inscrire un élève depuis users_page (admin)
///   2. Auto-inscription publique (parent inscrit son enfant)
///
/// [config] — config admin. Si null, utilise les defaults.
/// [onSubmit] — callback avec les données saisies (map fieldId → valeur).
// ─────────────────────────────────────────────────────────────────────────────
class EnrollmentPage extends StatefulWidget {
  final EnrollmentConfig? config;
  final void Function(Map<String, dynamic> data)? onSubmit;
  final bool isAdminMode;

  const EnrollmentPage({
    super.key,
    this.config,
    this.onSubmit,
    this.isAdminMode = false,
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
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

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

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _loading = false; _submitted = true; });

    final data = <String, dynamic>{};
    for (final f in _config.enabledFields) {
      data[f.id] = _controllers[f.id]?.text ?? _values[f.id];
    }
    widget.onSubmit?.call(data);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(isAdmin: widget.isAdminMode);

    final cats = _fieldsByCategory;

    return Container(
      color: _bg,
      child: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _EnrollHeader(isAdmin: widget.isAdminMode)),

            // ── Welcome message ──────────────────────────────────────────
            if (_config.welcomeMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gold.withOpacity(.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: _gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_config.welcomeMessage!,
                            style: const TextStyle(color: _ink, fontSize: 12.5,
                                height: 1.4)),
                      ),
                    ]),
                  ),
                ),
              ),

            // ── Progress indicator ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProgressBar(
                filled: _values.length,
                total: _config.enabledFields.length,
              ),
            ),

            // ── Field sections ───────────────────────────────────────────
            for (final entry in cats.entries) ...[
              SliverToBoxAdapter(
                child: _CategoryHeader(label: entry.key),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FieldWidget(
                        field: entry.value[i],
                        required: _config.isRequired(entry.value[i].id),
                        controller: _controllers[entry.value[i].id],
                        value: _values[entry.value[i].id],
                        onChanged: (v) =>
                            setState(() => _values[entry.value[i].id] = v),
                      ),
                    ),
                    childCount: entry.value.length,
                  ),
                ),
              ),
            ],

            // ── Submit ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                child: _SubmitButton(loading: _loading, onTap: _submit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _EnrollHeader extends StatelessWidget {
  final bool isAdmin;
  const _EnrollHeader({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sh1, _sh2, Color(0xFF5A1A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _sh1.withOpacity(.3),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(painter: _HexPainter()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _terra.withOpacity(.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _terra.withOpacity(.5)),
                  ),
                  child: Text(
                    isAdmin ? 'INSCRIPTION — ADMIN' : 'NOUVELLE INSCRIPTION',
                    style: const TextStyle(color: _white, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Formulaire d\'Inscription',
                    style: TextStyle(color: _white, fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Remplissez les informations de l\'élève à inscrire.'
                      : 'Complétez toutes les informations requises pour inscrire votre enfant.',
                  style: TextStyle(color: _white.withOpacity(.6),
                      fontSize: 12.5, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: _white.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _white.withOpacity(.2)),
              ),
              child: const Icon(Icons.how_to_reg_rounded, color: _white, size: 28),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int filled;
  final int total;
  const _ProgressBar({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _borderC,
              valueColor: const AlwaysStoppedAnimation(_terra),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$filled/$total champs',
            style: const TextStyle(fontSize: 11, color: _muted,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Header
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryHeader extends StatelessWidget {
  final String label;
  const _CategoryHeader({required this.label});

  static const _icons = {
    'Identité':   Icons.badge_rounded,
    'Documents':  Icons.folder_rounded,
    'Académique': Icons.school_rounded,
    'Contact':    Icons.contact_phone_rounded,
    'Tuteur':     Icons.family_restroom_rounded,
    'Paiement':   Icons.payment_rounded,
    'Médical':    Icons.medical_information_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[label] ?? Icons.list_rounded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _terra.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _terra),
        ),
        const SizedBox(width: 10),
        Text(label.toUpperCase(),
            style: const TextStyle(color: _terra, fontSize: 11.5,
                fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: _borderC)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Widget — adapte l'UI selon le FieldType
// ─────────────────────────────────────────────────────────────────────────────
class _FieldWidget extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController? controller;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _FieldWidget({
    required this.field,
    required this.required,
    this.controller,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FieldType.photo:
        return _PhotoField(field: field, required: required, onChanged: onChanged);
      case FieldType.file:
        return _FileField(field: field, required: required, onChanged: onChanged);
      case FieldType.select:
        return _SelectField(field: field, required: required,
            value: value as String?, onChanged: onChanged);
      case FieldType.toggle:
        return _ToggleField(field: field, value: value as bool? ?? false,
            onChanged: onChanged);
      case FieldType.textarea:
        return _TextAreaField(field: field, required: required,
            controller: controller!);
      case FieldType.date:
        return _DateField(field: field, required: required,
            controller: controller!, onChanged: onChanged);
      default:
        return _TextInputField(field: field, required: required,
            controller: controller!);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable field shell
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
        Text(field.label,
            style: const TextStyle(fontSize: 12.5, color: _ink,
                fontWeight: FontWeight.w700)),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: _terra,
              fontWeight: FontWeight.w900)),
        ],
      ]),
      if (field.hint != null) ...[
        const SizedBox(height: 2),
        Text(field.hint!,
            style: const TextStyle(fontSize: 10.5, color: _muted)),
      ],
      const SizedBox(height: 6),
      child,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text input
// ─────────────────────────────────────────────────────────────────────────────
class _TextInputField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController controller;

  const _TextInputField({
    required this.field,
    required this.required,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: TextFormField(
        controller: controller,
        keyboardType: field.type == FieldType.email
            ? TextInputType.emailAddress
            : field.type == FieldType.phone
                ? TextInputType.phone
                : field.type == FieldType.number
                    ? TextInputType.number
                    : TextInputType.text,
        decoration: _inputDecor(field.placeholder),
        style: const TextStyle(fontSize: 13, color: _ink),
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
// Textarea
// ─────────────────────────────────────────────────────────────────────────────
class _TextAreaField extends StatelessWidget {
  final EnrollmentField field;
  final bool required;
  final TextEditingController controller;

  const _TextAreaField({
    required this.field,
    required this.required,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: field,
      required: required,
      child: TextFormField(
        controller: controller,
        maxLines: 3,
        decoration: _inputDecor(field.placeholder),
        style: const TextStyle(fontSize: 13, color: _ink),
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
// Date picker
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
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 15),
            firstDate: DateTime(1940),
            lastDate: now,
            builder: (ctx, child) => Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: _terra),
              ),
              child: child!,
            ),
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
            decoration: _inputDecor('JJ/MM/AAAA',
                suffix: const Icon(Icons.calendar_today_rounded,
                    size: 16, color: _muted)),
            style: const TextStyle(fontSize: 13, color: _ink),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Ce champ est obligatoire'
                    : null
                : null,
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
              color: _white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: state.hasError ? _terra : _borderC),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text(field.placeholder.isEmpty
                  ? 'Sélectionner...'
                  : field.placeholder,
                  style: const TextStyle(fontSize: 13, color: _muted)),
              icon: const Icon(Icons.expand_more_rounded,
                  size: 16, color: _muted),
              style: const TextStyle(fontSize: 13, color: _ink,
                  fontFamily: 'Poppins'),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderC),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(field.label,
                style: const TextStyle(fontSize: 12.5, color: _ink,
                    fontWeight: FontWeight.w700)),
            if (field.hint != null)
              Text(field.hint!,
                  style: const TextStyle(fontSize: 11, color: _muted)),
          ]),
        ),
        Switch(
          value: value,
          activeColor: _terra,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoField extends StatefulWidget {
  final EnrollmentField field;
  final bool required;
  final ValueChanged<dynamic> onChanged;

  const _PhotoField({
    required this.field,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<_PhotoField> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: widget.field,
      required: widget.required,
      child: GestureDetector(
        onTap: () => setState(() {
          _selected = true;
          widget.onChanged('photo_selected');
        }),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: _selected ? _terra.withOpacity(.06) : _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _selected ? _terra.withOpacity(.3) : _borderC,
                style: BorderStyle.solid),
          ),
          child: _selected
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.check_circle_rounded, color: _green, size: 24),
                  SizedBox(width: 8),
                  Text('Photo sélectionnée',
                      style: TextStyle(color: _green, fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.add_a_photo_rounded, color: _muted, size: 28),
                  SizedBox(height: 8),
                  Text('Cliquez pour ajouter une photo',
                      style: TextStyle(color: _muted, fontSize: 12)),
                ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File
// ─────────────────────────────────────────────────────────────────────────────
class _FileField extends StatefulWidget {
  final EnrollmentField field;
  final bool required;
  final ValueChanged<dynamic> onChanged;

  const _FileField({
    required this.field,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_FileField> createState() => _FileFieldState();
}

class _FileFieldState extends State<_FileField> {
  String? _fileName;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      field: widget.field,
      required: widget.required,
      child: GestureDetector(
        onTap: () => setState(() {
          _fileName = 'document_${widget.field.id}.pdf';
          widget.onChanged(_fileName);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _fileName != null
                ? _green.withOpacity(.3)
                : _borderC),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _fileName != null
                    ? _green.withOpacity(.1)
                    : _muted.withOpacity(.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _fileName != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_rounded,
                color: _fileName != null ? _green : _muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _fileName ?? 'Cliquez pour sélectionner un fichier',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: _fileName != null ? _ink : _muted,
                      fontWeight: _fileName != null
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
                Text('PDF, JPG, PNG — max 5 Mo',
                    style: const TextStyle(fontSize: 10, color: _muted)),
              ]),
            ),
            if (_fileName != null)
              GestureDetector(
                onTap: () => setState(() { _fileName = null; }),
                child: const Icon(Icons.close_rounded, size: 16, color: _muted),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit button
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: loading
                ? [_muted, _muted.withOpacity(.7)]
                : [_terra, _orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [BoxShadow(color: _terra.withOpacity(.3),
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
                  Icon(Icons.how_to_reg_rounded, color: _white, size: 18),
                  SizedBox(width: 10),
                  Text('Valider l\'inscription',
                      style: TextStyle(color: _white, fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success view
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final bool isAdmin;
  const _SuccessView({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _green.withOpacity(.1),
                shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(.3), width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Inscription enregistrée !',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Le dossier de l\'élève a été créé avec succès.'
                  : 'Votre dossier a été soumis. L\'équipe administrative '
                    'vous contactera sous 48h pour confirmer l\'inscription.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _terra,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Retour à la liste',
                      style: TextStyle(color: _white, fontWeight: FontWeight.w700,
                          fontSize: 13)),
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
// Input decoration helper
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _inputDecor(String hint, {Widget? suffix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: _muted),
  suffixIcon: suffix,
  filled: true,
  fillColor: _white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _borderC),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _borderC),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _terra, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _terra),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Hex painter
// ─────────────────────────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x05FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    const r = 18.0;
    final dx = r * math.sqrt(3);
    final dy = r * 1.5;
    for (double y = -r; y < size.height + r * 2; y += dy) {
      for (double x = -dx; x < size.width + dx; x += dx) {
        final off = ((y / dy).floor() % 2 == 0) ? 0.0 : dx / 2;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final p = Offset(x + off + r * math.cos(a), y + r * math.sin(a));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
