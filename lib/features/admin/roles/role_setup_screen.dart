import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/staff_roles_source.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';

const _terra = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

/// Brouillon de rôle en cours de configuration (avant sauvegarde).
class _RoleDraft {
  String name;
  String? description;
  bool included;
  final bool isAdminRole;
  final bool isCustom;
  Set<String> grants;
  final String? templateId;

  _RoleDraft({
    required this.name,
    this.description,
    required this.included,
    this.isAdminRole = false,
    this.isCustom = false,
    required this.grants,
    this.templateId,
  });
}

String _cycleFromTypes(List<String> types) {
  if (types.contains('universite') || types.contains('superieur')) return 'universite';
  if (types.contains('lycee')) return 'lycee';
  if (types.contains('college')) return 'college';
  return 'primaire';
}

/// Étape post-inscription : configuration de la hiérarchie des rôles du
/// personnel — style "scopes" GitHub. S'affiche une seule fois, à la
/// première connexion du fondateur/admin, tant qu'aucun rôle n'existe.
class RoleSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const RoleSetupScreen({super.key, required this.onDone});

  @override
  ConsumerState<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends ConsumerState<RoleSetupScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<SbPermissionModule> _catalog = [];
  List<_RoleDraft> _roles = [];
  String _cycle = 'lycee';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = ref.read(authSessionProvider);
      final school = await ref.read(schoolProvider.future);
      final cycle = _cycleFromTypes(school?.types ?? const []);
      final catalog = await StaffRolesSource.fetchPermissionCatalog();
      final templates = await StaffRolesSource.fetchRoleTemplates(cycle);
      final allKeys = <String>{
        for (final m in catalog) for (final s in m.subPermissions) '${m.key}.${s.key}',
      };

      final drafts = <_RoleDraft>[
        _RoleDraft(
          name: session?.roleTitle?.isNotEmpty == true ? session!.roleTitle! : 'Fondateur / Admin',
          description: 'Rôle du créateur de l\'école — accès total, non modifiable.',
          included: true,
          isAdminRole: true,
          grants: allKeys,
        ),
        for (final t in templates)
          _RoleDraft(name: t.name, description: t.description, included: true, grants: {...t.grants}, templateId: t.id),
      ];

      setState(() {
        _catalog = catalog;
        _roles = drafts;
        _cycle = cycle;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Erreur de chargement : $e'; _loading = false; });
    }
  }

  void _addCustomRole() {
    setState(() {
      _roles.add(_RoleDraft(name: 'Nouveau rôle', included: true, isCustom: true, grants: {}));
    });
  }

  void _removeRole(_RoleDraft r) {
    if (r.isAdminRole) return;
    setState(() => _roles.remove(r));
  }

  Future<void> _editPermissions(_RoleDraft r) async {
    if (r.isAdminRole) return;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PermissionEditorSheet(role: r, catalog: _catalog),
    );
    if (result != null) setState(() => r.grants = result);
  }

  Future<void> _save() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      for (final r in _roles.where((r) => r.included)) {
        await StaffRolesSource.createStaffRole(
          schoolId: schoolId,
          name: r.name,
          description: r.description,
          isAdminRole: r.isAdminRole,
          basedOnTemplateId: r.templateId,
          grants: r.grants,
        );
      }
      widget.onDone();
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sauvegarde : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _terra)));
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_terra, _orange]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Configurez les rôles de votre équipe',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
                      Text('Cycle détecté : ${_cycleLabel(_cycle)} — modifiez librement chaque rôle et ses permissions.',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: ListView(
                    children: [
                      for (final r in _roles) _RoleCard(
                        role: r,
                        catalog: _catalog,
                        onToggleIncluded: r.isAdminRole ? null : (v) => setState(() => r.included = v),
                        onEdit: () => _editPermissions(r),
                        onDelete: r.isAdminRole ? null : () => _removeRole(r),
                        onRename: r.isAdminRole ? null : (name) => setState(() => r.name = name),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addCustomRole,
                        icon: const Icon(Icons.add_rounded, color: _terra),
                        label: const Text('Créer un rôle personnalisé', style: TextStyle(color: _terra, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _terra),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _terra,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : const Text('Enregistrer la hiérarchie des rôles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _cycleLabel(String c) => switch (c) {
        'primaire' => 'Primaire',
        'college' => 'Collège',
        'lycee' => 'Lycée',
        'universite' => 'Université',
        _ => c,
      };
}

class _RoleCard extends StatelessWidget {
  final _RoleDraft role;
  final List<SbPermissionModule> catalog;
  final ValueChanged<bool>? onToggleIncluded;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRename;
  const _RoleCard({
    required this.role, required this.catalog, required this.onToggleIncluded,
    required this.onEdit, required this.onDelete, required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grantCount = role.isAdminRole ? -1 : role.grants.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: role.isAdminRole ? _gold.withOpacity(.5) : cs.outlineVariant),
      ),
      child: Row(children: [
        Checkbox(
          value: role.included,
          onChanged: onToggleIncluded == null ? null : (v) => onToggleIncluded!(v ?? true),
          activeColor: _terra,
        ),
        Icon(role.isAdminRole ? Icons.workspace_premium_rounded : Icons.badge_outlined,
            color: role.isAdminRole ? _gold : _terra, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            onRename == null
                ? Text(role.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: cs.onSurface))
                : _InlineNameField(initial: role.name, onChanged: onRename!),
            Text(
              role.isAdminRole ? 'Accès total — toutes permissions' : '$grantCount permission${grantCount > 1 ? "s" : ""} accordée${grantCount > 1 ? "s" : ""}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        if (!role.isAdminRole)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune_rounded, size: 16, color: _terra),
            label: const Text('Permissions', style: TextStyle(color: _terra, fontWeight: FontWeight.w700)),
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
          ),
      ]),
    );
  }
}

class _InlineNameField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _InlineNameField({required this.initial, required this.onChanged});
  @override
  State<_InlineNameField> createState() => _InlineNameFieldState();
}

class _InlineNameFieldState extends State<_InlineNameField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
      decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
    );
  }
}

/// Éditeur de permissions — même logique qu'un écran de scopes de token
/// (GitHub) : modules dépliables, cases à cocher par sous-permission,
/// tout/rien par module.
class _PermissionEditorSheet extends StatefulWidget {
  final _RoleDraft role;
  final List<SbPermissionModule> catalog;
  const _PermissionEditorSheet({required this.role, required this.catalog});

  @override
  State<_PermissionEditorSheet> createState() => _PermissionEditorSheetState();
}

class _PermissionEditorSheetState extends State<_PermissionEditorSheet> {
  late Set<String> _grants = {...widget.role.grants};

  bool _moduleFullyGranted(SbPermissionModule m) =>
      m.subPermissions.every((s) => _grants.contains('${m.key}.${s.key}'));
  bool _modulePartiallyGranted(SbPermissionModule m) =>
      m.subPermissions.any((s) => _grants.contains('${m.key}.${s.key}'));

  void _toggleModule(SbPermissionModule m, bool value) {
    setState(() {
      for (final s in m.subPermissions) {
        final key = '${m.key}.${s.key}';
        if (value) {
          _grants.add(key);
        } else {
          _grants.remove(key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: .85,
      minChildSize: .5,
      maxChildSize: .95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text('Permissions — ${widget.role.name}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: cs.onSurface)),
              ),
              TextButton(onPressed: () => Navigator.pop(context, _grants),
                  child: const Text('Terminé', style: TextStyle(color: _terra, fontWeight: FontWeight.w800))),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final m in widget.catalog) _ModuleTile(
                  module: m,
                  grants: _grants,
                  fullyGranted: _moduleFullyGranted(m),
                  partiallyGranted: _modulePartiallyGranted(m),
                  onToggleModule: (v) => _toggleModule(m, v),
                  onToggleSub: (subKey, v) => setState(() {
                    final key = '${m.key}.$subKey';
                    if (v) { _grants.add(key); } else { _grants.remove(key); }
                  }),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ModuleTile extends StatefulWidget {
  final SbPermissionModule module;
  final Set<String> grants;
  final bool fullyGranted;
  final bool partiallyGranted;
  final ValueChanged<bool> onToggleModule;
  final void Function(String subKey, bool value) onToggleSub;
  const _ModuleTile({
    required this.module, required this.grants, required this.fullyGranted,
    required this.partiallyGranted, required this.onToggleModule, required this.onToggleSub,
  });

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => _expanded = !_expanded),
          leading: Checkbox(
            tristate: true,
            value: widget.fullyGranted ? true : (widget.partiallyGranted ? null : false),
            activeColor: _terra,
            onChanged: (_) => widget.onToggleModule(!widget.fullyGranted),
          ),
          title: Text(widget.module.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: cs.onSurfaceVariant),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 12, bottom: 8),
            child: Column(children: [
              for (final s in widget.module.subPermissions)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: widget.grants.contains('${widget.module.key}.${s.key}'),
                  activeColor: _terra,
                  title: Text(s.label, style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => widget.onToggleSub(s.key, v ?? false),
                ),
            ]),
          ),
      ]),
    );
  }
}
