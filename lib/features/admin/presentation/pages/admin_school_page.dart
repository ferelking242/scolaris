import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = Color(0xFF8B1A00);
const _green  = Color(0xFF2D6A4F);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);

// Couleurs accent prédéfinies proposées à l'admin
const _swatches = <({String label, String hex})>[
  (label: 'Terracotta', hex: '#8B1A00'),
  (label: 'Marine',     hex: '#1A3A5C'),
  (label: 'Forêt',      hex: '#2D6A4F'),
  (label: 'Aubergine',  hex: '#4B2045'),
  (label: 'Or',         hex: '#C17F24'),
  (label: 'Ardoise',    hex: '#3B4A5C'),
];

class AdminSchoolPage extends ConsumerStatefulWidget {
  const AdminSchoolPage({super.key});
  @override
  ConsumerState<AdminSchoolPage> createState() => _AdminSchoolPageState();
}

class _AdminSchoolPageState extends ConsumerState<AdminSchoolPage> {
  final _name         = TextEditingController();
  final _code         = TextEditingController();
  final _city         = TextEditingController();
  final _country      = TextEditingController();
  final _academicYear = TextEditingController();
  final _logoUrl      = TextEditingController();
  String? _accentColor;

  bool _loading  = true;
  bool _saving   = false;
  bool _saved    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final school = await ref.read(schoolProvider.future);
      if (school != null && mounted) {
        setState(() {
          _name.text         = school.name;
          _code.text         = school.code         ?? '';
          _city.text         = school.city         ?? '';
          _country.text      = school.country      ?? '';
          _academicYear.text = school.academicYear ?? '';
          _logoUrl.text      = school.logoUrl      ?? '';
          _accentColor       = school.accentColor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Le nom de l\'école est obligatoire.');
      return;
    }
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() { _saving = true; _error = null; });
    try {
      await SupabaseDbSource.updateSchool(
        id:           schoolId,
        name:         _name.text,
        code:         _code.text,
        city:         _city.text,
        country:      _country.text,
        academicYear: _academicYear.text,
        accentColor:  _accentColor,
        logoUrl:      _logoUrl.text,
      );
      ref.invalidate(schoolProvider);
      if (!mounted) return;
      setState(() => _saved = true);
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Informations mises à jour'),
        ]),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      Future.delayed(const Duration(seconds: 2),
          () { if (mounted) setState(() => _saved = false); });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _city.dispose();
    _country.dispose();
    _academicYear.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Paramètres école',
      subtitle: 'Informations générales et apparence',
      actions: [_SaveButton(saving: _saving, saved: _saved, onPressed: _save)],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Identité ────────────────────────────────────────────────
                DataPanel(
                  title: 'Identité',
                  child: Column(children: [
                    _Field(
                      controller: _name,
                      label: 'Nom de l\'école *',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _Field(
                          controller: _code,
                          label: 'Code / Sigle',
                          icon: Icons.tag_rounded,
                          hint: 'ex: EAD-BZV',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          controller: _academicYear,
                          label: 'Année scolaire',
                          icon: Icons.calendar_today_outlined,
                          hint: 'ex: 2025-2026',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _Field(
                          controller: _city,
                          label: 'Ville',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          controller: _country,
                          label: 'Pays',
                          icon: Icons.public_outlined,
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Apparence ───────────────────────────────────────────────
                DataPanel(
                  title: 'Apparence',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Couleur accent',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.cMuted)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final sw in _swatches)
                            _SwatchTile(
                              hex: sw.hex,
                              label: sw.label,
                              selected: _accentColor == sw.hex,
                              onTap: () => setState(() => _accentColor = sw.hex),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _logoUrl,
                        label: 'URL du logo (optionnel)',
                        icon: Icons.image_outlined,
                        hint: 'https://…',
                        keyboardType: TextInputType.url,
                      ),
                      if (_logoUrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _LogoPreview(url: _logoUrl.text.trim()),
                      ],
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _terra.withValues(alpha: .3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: _terra),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12.5, color: _terra)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Bouton Enregistrer (bas de page) ────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _saved
                                ? Icons.check_rounded
                                : Icons.save_outlined,
                            size: 18),
                    label: Text(
                        _saving
                            ? 'Enregistrement…'
                            : _saved
                                ? 'Enregistré !'
                                : 'Enregistrer les modifications'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _saved ? _green : _terra,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final bool saved;
  final VoidCallback onPressed;
  const _SaveButton(
      {required this.saving, required this.saved, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: _terra))
          : Icon(
              saved ? Icons.check_rounded : Icons.save_outlined,
              size: 16,
              color: saved ? _green : _terra),
      label: Text(
        saving ? 'Enreg…' : saved ? 'Enregistré' : 'Enregistrer',
        style: TextStyle(
            color: saved ? _green : _terra,
            fontSize: 13,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final String hex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SwatchTile({
    required this.hex,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  Color get _color => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _color.withValues(alpha: .12) : Colors.transparent,
          border: Border.all(
            color: selected ? _color : _border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: _color.withValues(alpha: .4), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _color : _ink)),
        ]),
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  final String url;
  const _LogoPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 64,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            height: 64,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 24, color: _muted),
                SizedBox(height: 4),
                Text('URL invalide',
                    style: TextStyle(fontSize: 10, color: _muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
