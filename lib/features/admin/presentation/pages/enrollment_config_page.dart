import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/pages/enrollment_page.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/preregistration_link_panel.dart';

const _terra   = Color(0xFF8B1A00);
const _green   = Color(0xFF2D6A4F);
const _gold    = Color(0xFFC17F24);

class EnrollmentConfigPage extends ConsumerStatefulWidget {
  const EnrollmentConfigPage({super.key});
  @override
  ConsumerState<EnrollmentConfigPage> createState() =>
      _EnrollmentConfigPageState();
}

class _EnrollmentConfigPageState extends ConsumerState<EnrollmentConfigPage> {
  late EnrollmentConfig _config;
  bool _saved = false;
  bool _saving = false;
  bool _loading = true;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _config = EnrollmentConfig.defaults();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ref.read(enrollmentConfigProvider.future);
      if (json != null && mounted) {
        setState(() => _config = EnrollmentConfig.fromJson(json));
      }
    } catch (_) {
      // garde la config par défaut si la lecture échoue
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleField(String id, bool enabled) {
    final f = EnrollmentFields.all.firstWhere((f) => f.id == id);
    if (f.alwaysRequired) return;
    setState(() {
      _config.fields[id]!.enabled = enabled;
      if (!enabled) _config.fields[id]!.required = false;
    });
  }

  void _toggleRequired(String id, bool req) {
    final f = EnrollmentFields.all.firstWhere((f) => f.id == id);
    if (f.alwaysRequired) return;
    setState(() {
      _config.fields[id]!.required = req;
      if (req) _config.fields[id]!.enabled = true;
    });
  }

  Future<void> _save() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (schoolId == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseDbSource.saveEnrollmentConfig(schoolId, _config.toJson());
      ref.invalidate(enrollmentConfigProvider);
      if (!mounted) return;
      setState(() => _saved = true);
      messenger.showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Configuration sauvegardée avec succès'),
          ]),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2),
          () { if (mounted) setState(() => _saved = false); });
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Échec de la sauvegarde : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preview() => setState(() => _previewing = true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Page d\'Inscription — Configuration',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Prévisualisation inline (dans le shell), pas de route plein écran.
    if (_previewing) {
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
                  onTap: () => setState(() => _previewing = false),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 15, color: context.cMuted),
                      const SizedBox(width: 6),
                      Text('Retour à la configuration',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.cMuted,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: EnrollmentPage(config: _config, isAdminMode: true),
          ),
        ]),
      );
    }

    final cats = EnrollmentFields.categories;
    final enabledCount = _config.enabledFields.length;
    final requiredCount =
        _config.enabledFields.where((f) => _config.isRequired(f.id)).length;

    return PageScaffold(
      title: 'Page d\'Inscription — Configuration',
      subtitle: '$enabledCount champs actifs · $requiredCount obligatoires',
      actions: [
        ActionButton(
          label: 'Prévisualiser',
          icon: Icons.preview_rounded,
          onTap: _preview,
        ),
        const SizedBox(width: 8),
        ActionButton(
          label: _saving
              ? 'Enregistrement…'
              : (_saved ? 'Sauvegardé !' : 'Sauvegarder'),
          icon: _saved ? Icons.check_rounded : Icons.save_rounded,
          primary: true,
          onTap: _saving ? () {} : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Lien de pré-inscription (partage lien + QR + période) ───────
          const PreRegistrationLinkPanel(),
          const SizedBox(height: 16),

          // ── Info banner ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _gold.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(.25)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _gold.withOpacity(.15),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.tune_rounded, color: _gold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personnalisation du formulaire d\'inscription',
                        style: TextStyle(fontSize: 12.5, color: context.cInk,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Activez ou désactivez les champs selon les besoins de votre '
                      'établissement. Les champs marqués ★ sont obligatoires '
                      'et ne peuvent pas être désactivés.',
                      style: TextStyle(fontSize: 11, color: context.cMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Stats row ───────────────────────────────────────────────────
          Row(children: [
            _MiniStat(
              icon: Icons.toggle_on_rounded,
              label: 'Champs actifs',
              value: '$enabledCount',
              color: _green,
            ),
            const SizedBox(width: 10),
            _MiniStat(
              icon: Icons.star_rounded,
              label: 'Obligatoires',
              value: '$requiredCount',
              color: _terra,
            ),
            const SizedBox(width: 10),
            _MiniStat(
              icon: Icons.list_alt_rounded,
              label: 'Total champs',
              value: '${EnrollmentFields.all.length}',
              color: context.cMuted,
            ),
          ]),
          const SizedBox(height: 16),

          // ── Field config by category ─────────────────────────────────
          for (final cat in cats) ...[
            _CatSection(
              category: cat,
              config: _config,
              onToggle: _toggleField,
              onToggleRequired: _toggleRequired,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────
class _CatSection extends StatefulWidget {
  final String category;
  final EnrollmentConfig config;
  final void Function(String, bool) onToggle;
  final void Function(String, bool) onToggleRequired;

  const _CatSection({
    required this.category,
    required this.config,
    required this.onToggle,
    required this.onToggleRequired,
  });

  @override
  State<_CatSection> createState() => _CatSectionState();
}

class _CatSectionState extends State<_CatSection> {
  bool _open = true;

  static const _catIcons = {
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
    final fields = EnrollmentFields.byCategory(widget.category);
    final icon = _catIcons[widget.category] ?? Icons.list_rounded;
    final activeCount = fields.where(
        (f) => widget.config.fields[f.id]?.enabled == true).length;

    return DataPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Text(widget.category,
                      style: TextStyle(color: context.cInk, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _terra.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$activeCount/${fields.length}',
                        style: const TextStyle(color: _terra, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18, color: context.cMuted,
                  ),
                ]),
              ),
            ),
          ),

          if (_open) ...[
            Container(height: 1, color: context.cBorder),
            for (final field in fields) ...[
              _FieldConfigRow(
                field: field,
                state: widget.config.fields[field.id]!,
                onToggle: widget.onToggle,
                onToggleRequired: widget.onToggleRequired,
              ),
              if (field != fields.last)
                Container(height: 1, color: const Color(0xFFF0E8DC)),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Field config row ──────────────────────────────────────────────────────
class _FieldConfigRow extends StatelessWidget {
  final EnrollmentField field;
  final EnrollmentFieldState state;
  final void Function(String, bool) onToggle;
  final void Function(String, bool) onToggleRequired;

  const _FieldConfigRow({
    required this.field,
    required this.state,
    required this.onToggle,
    required this.onToggleRequired,
  });

  IconData get _typeIcon {
    switch (field.type) {
      case FieldType.photo:    return Icons.add_a_photo_rounded;
      case FieldType.file:     return Icons.attach_file_rounded;
      case FieldType.select:   return Icons.arrow_drop_down_circle_rounded;
      case FieldType.toggle:   return Icons.toggle_on_rounded;
      case FieldType.date:     return Icons.calendar_today_rounded;
      case FieldType.textarea: return Icons.notes_rounded;
      case FieldType.email:    return Icons.email_rounded;
      case FieldType.phone:    return Icons.phone_rounded;
      default:                 return Icons.text_fields_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = field.alwaysRequired;
    final enabled = state.enabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: enabled ? context.cCard : context.cSubtle,
      child: Row(children: [
        // Type icon
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: enabled
                ? _terra.withOpacity(.07)
                : context.cMuted.withOpacity(.07),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(_typeIcon, size: 13,
              color: enabled ? _terra : context.cMuted.withOpacity(.5)),
        ),
        const SizedBox(width: 10),

        // Label + hint
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(field.label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: enabled ? context.cInk : context.cMuted.withOpacity(.5))),
              if (locked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _terra.withOpacity(.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('★ FIXE',
                      style: TextStyle(fontSize: 8, color: _terra,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            if (field.hint != null)
              Text(field.hint!,
                  style: TextStyle(fontSize: 10,
                      color: enabled ? context.cMuted : context.cMuted.withOpacity(.4))),
          ]),
        ),

        // Required toggle
        if (enabled && !locked)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onToggleRequired(field.id, !state.required),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.required
                        ? _terra.withOpacity(.1)
                        : context.cMuted.withOpacity(.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: state.required
                            ? _terra.withOpacity(.3)
                            : context.cBorder),
                  ),
                  child: Text(
                    state.required ? 'Obligatoire' : 'Optionnel',
                    style: TextStyle(
                        fontSize: 10,
                        color: state.required ? _terra : context.cMuted,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),

        // Enable toggle
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: enabled,
            activeColor: _terra,
            onChanged: locked ? null : (v) => onToggle(field.id, v),
          ),
        ),
      ]),
    );
  }
}

// ── Mini stat ─────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: context.cMuted)),
            Text(value,
                style: TextStyle(fontSize: 18, color: color,
                    fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
    );
  }
}
