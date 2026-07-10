import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/staff_roles_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import 'role_org_chart.dart';
import 'role_workspace_models.dart';

const _terra = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold = ScolarisPalette.gold;
const _red = Color(0xFFDC2626);
const _redDim = Color(0xFFFEF2F2);

String _cycleFromTypes(List<String> types) {
  if (types.contains('universite') || types.contains('superieur')) return 'universite';
  if (types.contains('lycee')) return 'lycee';
  if (types.contains('college')) return 'college';
  return 'primaire';
}

int _draftCounter = 0;
String _newDraftId() => 'draft_${DateTime.now().microsecondsSinceEpoch}_${_draftCounter++}';

/// Le "package" rôles & permissions : organigramme + liste de rôles à
/// gauche, permissions détaillées au centre, résumé du rôle à droite.
/// Utilisable en mode `onboarding` (première configuration, bloquant) ou en
/// page permanente de gestion accessible depuis la barre latérale.
class RolesPermissionsWorkspace extends ConsumerStatefulWidget {
  final bool onboarding;
  final VoidCallback? onDone;
  const RolesPermissionsWorkspace({super.key, this.onboarding = false, this.onDone});

  @override
  ConsumerState<RolesPermissionsWorkspace> createState() => _RolesPermissionsWorkspaceState();
}

class _RolesPermissionsWorkspaceState extends ConsumerState<RolesPermissionsWorkspace> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<SbPermissionModule> _catalog = [];
  List<RoleDraft> _roles = [];
  String? _selectedId;
  String _searchQuery = '';
  final Set<String> _openCategories = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _dirty => _roles.any((r) => r.isDirty) || _pendingDeletes.isNotEmpty;
  final List<String> _pendingDeletes = [];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(authSessionProvider);
      final schoolId = ref.read(currentSchoolIdProvider);
      final school = await ref.read(schoolProvider.future);
      final cycle = _cycleFromTypes(school?.types ?? const []);
      final catalog = await StaffRolesSource.fetchPermissionCatalog();
      final existing = schoolId == null ? <SbStaffRole>[] : await StaffRolesSource.fetchStaffRoles(schoolId);

      final drafts = <RoleDraft>[];
      if (existing.isNotEmpty) {
        drafts.addAll(existing.map(RoleDraft.fromStaffRole));
      } else {
        final allKeys = <String>{
          for (final m in catalog) for (final s in m.subPermissions) '${m.key}.${s.key}',
        };
        drafts.add(RoleDraft(
          draftId: _newDraftId(),
          name: session?.roleTitle?.isNotEmpty == true ? session!.roleTitle! : 'Fondateur / Admin',
          description: 'Rôle du créateur de l\'école — accès total, non modifiable.',
          isAdminRole: true,
          level: 'Direction',
          color: '#C17F24',
          iconKey: 'star',
          grants: allKeys,
        ));
        final templates = await StaffRolesSource.fetchRoleTemplates(cycle);
        for (final t in templates) {
          drafts.add(RoleDraft.fromTemplate(t, draftId: _newDraftId()));
        }
      }

      setState(() {
        _catalog = catalog;
        _roles = drafts;
        _selectedId = drafts.isNotEmpty ? drafts.first.draftId : null;
        _loading = false;
        if (_openCategories.isEmpty && catalog.isNotEmpty) {
          _openCategories.addAll(catalog.take(2).map((c) => c.key));
        }
      });
    } catch (e) {
      setState(() { _error = 'Erreur de chargement : $e'; _loading = false; });
    }
  }

  RoleDraft? get _selected => _roles.where((r) => r.draftId == _selectedId).firstOrNull;

  List<RoleDraft> get _filteredRoles {
    if (_searchQuery.trim().isEmpty) return _roles;
    final q = _searchQuery.toLowerCase();
    return _roles.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  void _select(String draftId) => setState(() => _selectedId = draftId);

  void _addRole() {
    final draft = RoleDraft.blank(draftId: _newDraftId());
    setState(() { _roles.add(draft); _selectedId = draft.draftId; });
  }

  void _duplicateRole(RoleDraft src) {
    final copy = RoleDraft(
      draftId: _newDraftId(),
      name: '${src.name} (copie)',
      description: src.description,
      isNew: true,
      isDirty: true,
      level: src.level,
      color: src.color,
      iconKey: src.iconKey,
      grants: {...src.grants},
    );
    setState(() { _roles.add(copy); _selectedId = copy.draftId; });
  }

  void _deleteRole(RoleDraft r) {
    if (r.locked) return;
    setState(() {
      _roles.remove(r);
      if (r.persistedId != null) _pendingDeletes.add(r.persistedId!);
      if (_selectedId == r.draftId) {
        _selectedId = _roles.isNotEmpty ? _roles.first.draftId : null;
      }
    });
  }

  void _mutate(RoleDraft r, void Function(RoleDraft) fn) {
    setState(() { fn(r); r.isDirty = true; });
  }

  Future<void> _save() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      for (final id in _pendingDeletes) {
        await StaffRolesSource.deleteRole(id);
      }
      _pendingDeletes.clear();

      // On sauvegarde d'abord les rôles existants pour connaître les ids
      // réels, puis on résout les références "hérite de" au moment de créer.
      final idMap = <String, String>{}; // draftId -> persistedId
      for (final r in _roles.where((r) => !r.isNew)) {
        idMap[r.draftId] = r.persistedId!;
      }
      for (final r in _roles) {
        if (!r.isDirty) continue;
        if (r.isNew) {
          final newId = await StaffRolesSource.createStaffRole(
            schoolId: schoolId,
            name: r.name,
            description: r.description,
            isAdminRole: r.isAdminRole,
            basedOnTemplateId: r.basedOnTemplateId,
            level: r.level,
            color: r.color,
            iconKey: r.iconKey,
            grants: r.grants,
          );
          idMap[r.draftId] = newId;
          r.persistedId = newId;
          r.isNew = false;
        } else {
          await StaffRolesSource.updateRoleMeta(
            roleId: r.persistedId!,
            name: r.name,
            description: r.description,
            level: r.level,
            color: r.color,
            iconKey: r.iconKey,
          );
          if (!r.isAdminRole) {
            await StaffRolesSource.updateRoleGrants(r.persistedId!, r.grants);
          }
        }
        r.isDirty = false;
      }
      // Deuxième passe : résout et enregistre les liens de parenté.
      for (final r in _roles) {
        if (r.parentDraftId == null || r.persistedId == null) continue;
        final resolvedParent = idMap[r.parentDraftId];
        if (resolvedParent != null) {
          await StaffRolesSource.updateRoleMeta(roleId: r.persistedId!, parentRoleId: resolvedParent);
        }
      }

      if (mounted) setState(() {});
      if (widget.onboarding) {
        widget.onDone?.call();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hiérarchie des rôles enregistrée.'), backgroundColor: ScolarisPalette.forestGreen),
        );
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sauvegarde : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _terra)));
    }
    final body = Column(children: [
      _Header(
        onboarding: widget.onboarding,
        dirty: _dirty,
        saving: _saving,
        onSave: _save,
      ),
      if (_error != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _redDim, borderRadius: BorderRadius.circular(10)),
          child: Text(_error!, style: const TextStyle(color: _red)),
        ),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 980;
          if (narrow) {
            return _selected == null
                ? const Center(child: Text('Aucun rôle sélectionné'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _LeftColumn(
                        roles: _roles, filtered: _filteredRoles, selectedId: _selectedId,
                        onSelect: _select, onSearch: (q) => setState(() => _searchQuery = q),
                        onAdd: _addRole, compact: true,
                      ),
                      const SizedBox(height: 16),
                      _PermissionsColumn(
                        role: _selected!, catalog: _catalog, openCategories: _openCategories,
                        onToggleCategoryOpen: (k) => setState(() => _openCategories.contains(k) ? _openCategories.remove(k) : _openCategories.add(k)),
                        onMutate: (fn) => _mutate(_selected!, fn),
                        onDuplicate: () => _duplicateRole(_selected!),
                      ),
                      const SizedBox(height: 16),
                      _SummaryColumn(
                        role: _selected!, allRoles: _roles,
                        onMutate: (fn) => _mutate(_selected!, fn),
                        onDelete: () => _deleteRole(_selected!),
                      ),
                    ]),
                  );
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 340,
              child: Container(
                decoration: BoxDecoration(border: Border(right: BorderSide(color: cs.outlineVariant))),
                child: _LeftColumn(
                  roles: _roles, filtered: _filteredRoles, selectedId: _selectedId,
                  onSelect: _select, onSearch: (q) => setState(() => _searchQuery = q),
                  onAdd: _addRole, compact: false,
                ),
              ),
            ),
            Expanded(
              child: _selected == null
                  ? Center(child: Text('Sélectionnez un rôle', style: TextStyle(color: cs.onSurfaceVariant)))
                  : Container(
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: cs.outlineVariant))),
                      child: _PermissionsColumn(
                        role: _selected!, catalog: _catalog, openCategories: _openCategories,
                        onToggleCategoryOpen: (k) => setState(() => _openCategories.contains(k) ? _openCategories.remove(k) : _openCategories.add(k)),
                        onMutate: (fn) => _mutate(_selected!, fn),
                        onDuplicate: () => _duplicateRole(_selected!),
                      ),
                    ),
            ),
            SizedBox(
              width: 320,
              child: _selected == null
                  ? const SizedBox.shrink()
                  : _SummaryColumn(
                      role: _selected!, allRoles: _roles,
                      onMutate: (fn) => _mutate(_selected!, fn),
                      onDelete: () => _deleteRole(_selected!),
                    ),
            ),
          ]);
        }),
      ),
    ]);

    if (widget.onboarding) {
      return Scaffold(backgroundColor: cs.surface, body: SafeArea(child: body));
    }
    return Container(color: cs.surface, child: body);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Header extends StatelessWidget {
  final bool onboarding;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  const _Header({required this.onboarding, required this.dirty, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_terra, _orange]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_tree_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(onboarding ? 'Construisez la hiérarchie des rôles' : 'Rôles & permissions',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: cs.onSurface)),
            Text(
              onboarding
                  ? "Rôles prédéfinis selon le type d'établissement. Modifiez, supprimez ou créez un rôle — chaque droit est vérifié côté serveur."
                  : "Organigramme, permissions détaillées et zone sensible pour chaque rôle du personnel. Rien n'est codé en dur côté client.",
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(onboarding ? Icons.check_rounded : Icons.save_rounded, size: 18),
          label: Text(onboarding ? 'Enregistrer la hiérarchie' : (dirty ? 'Enregistrer les modifications' : 'Enregistré'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: dirty || onboarding ? _terra : cs.surfaceContainerHighest,
            foregroundColor: dirty || onboarding ? Colors.white : cs.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  final List<RoleDraft> roles;
  final List<RoleDraft> filtered;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final bool compact;
  const _LeftColumn({
    required this.roles, required this.filtered, required this.selectedId,
    required this.onSelect, required this.onSearch, required this.onAdd, required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text('RÔLES · ${roles.length}',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: cs.onSurfaceVariant)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(14),
            color: cs.surfaceContainerHighest.withOpacity(.2),
          ),
          child: Column(children: [
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('ORGANIGRAMME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            RoleOrgChart(roles: roles, selectedDraftId: selectedId, onSelect: onSelect),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: onSearch,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Rechercher un rôle…'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            for (final r in filtered)
              _RoleListItem(role: r, selected: r.draftId == selectedId, onTap: () => onSelect(r.draftId)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 18, color: _terra),
                SizedBox(width: 6),
                Text('Créer un rôle personnalisé', style: TextStyle(color: _terra, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RoleListItem extends StatelessWidget {
  final RoleDraft role;
  final bool selected;
  final VoidCallback onTap;
  const _RoleListItem({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = colorFromHex(role.color);
    final count = role.grants.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.12) : Colors.transparent,
          border: Border.all(color: selected ? color.withOpacity(.4) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(role.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: cs.onSurface))),
                if (role.locked) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.lock_rounded, size: 11, color: Colors.grey)),
              ]),
              Text(role.level, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Text(role.isAdminRole ? 'tout' : '$count', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}

class _PermissionsColumn extends StatelessWidget {
  final RoleDraft role;
  final List<SbPermissionModule> catalog;
  final Set<String> openCategories;
  final ValueChanged<String> onToggleCategoryOpen;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDuplicate;
  const _PermissionsColumn({
    required this.role, required this.catalog, required this.openCategories,
    required this.onToggleCategoryOpen, required this.onMutate, required this.onDuplicate,
  });

  int get _checked => role.isAdminRole
      ? catalog.fold(0, (n, m) => n + m.subPermissions.length)
      : role.grants.length;
  int get _total => catalog.fold(0, (n, m) => n + m.subPermissions.length);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = colorFromHex(role.color);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(11), border: Border.all(color: cs.outlineVariant)),
              child: Icon(iconForKey(role.iconKey), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.onSurface)),
                Text(role.description.isEmpty ? 'Aucune description' : role.description,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ]),
            ),
            if (!role.locked)
              TextButton.icon(onPressed: onDuplicate, icon: const Icon(Icons.copy_rounded, size: 15), label: const Text('Dupliquer', style: TextStyle(fontSize: 12))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Row(children: [
            RichText(text: TextSpan(
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              children: [
                TextSpan(text: '$_checked', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: cs.onSurface)),
                TextSpan(text: ' / $_total permissions activées'),
              ],
            )),
            const Spacer(),
            if (!role.locked) ...[
              TextButton(onPressed: () => onMutate((r) {
                r.grants = {for (final m in catalog) for (final s in m.subPermissions) '${m.key}.${s.key}'};
              }), child: const Text('Tout cocher', style: TextStyle(color: _terra, fontSize: 11.5, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => onMutate((r) => r.grants = {}), child: const Text('Tout décocher', style: TextStyle(color: _terra, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ],
          ]),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 32),
          child: Column(children: [
            for (final cat in catalog)
              _CategoryTile(
                module: cat,
                role: role,
                open: openCategories.contains(cat.key),
                onToggleOpen: () => onToggleCategoryOpen(cat.key),
                onMutate: onMutate,
              ),
          ]),
        ),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final SbPermissionModule module;
  final RoleDraft role;
  final bool open;
  final VoidCallback onToggleOpen;
  final void Function(void Function(RoleDraft)) onMutate;
  const _CategoryTile({required this.module, required this.role, required this.open, required this.onToggleOpen, required this.onMutate});

  static const _sensitiveKeys = {'delete', 'export', 'roles'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checked = role.isAdminRole
        ? module.subPermissions.length
        : module.subPermissions.where((s) => role.grants.contains('${module.key}.${s.key}')).length;
    final total = module.subPermissions.length;
    final allChecked = checked == total;
    final someChecked = checked > 0 && !allChecked;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(11)),
      child: Column(children: [
        InkWell(
          onTap: onToggleOpen,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(module.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                child: Text('$checked/$total', style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              ),
              _MasterCheck(
                checked: allChecked, indeterminate: someChecked, disabled: role.locked,
                onTap: () => onMutate((r) {
                  for (final s in module.subPermissions) {
                    final key = '${module.key}.${s.key}';
                    if (allChecked) { r.grants.remove(key); } else { r.grants.add(key); }
                  }
                }),
              ),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 14, 12),
            child: Column(children: [
              for (final s in module.subPermissions)
                _PermRow(
                  label: s.label,
                  scope: '${module.key}:${s.key}',
                  sensitive: _sensitiveKeys.contains(s.key),
                  checked: role.isAdminRole || role.grants.contains('${module.key}.${s.key}'),
                  disabled: role.locked,
                  onTap: () => onMutate((r) {
                    final key = '${module.key}.${s.key}';
                    if (r.grants.contains(key)) { r.grants.remove(key); } else { r.grants.add(key); }
                  }),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _MasterCheck extends StatelessWidget {
  final bool checked;
  final bool indeterminate;
  final bool disabled;
  final VoidCallback onTap;
  const _MasterCheck({required this.checked, required this.indeterminate, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          color: checked ? _terra : (indeterminate ? cs.surfaceContainerHighest : Colors.transparent),
          border: Border.all(color: checked ? _terra : cs.outlineVariant, width: 1.4),
          borderRadius: BorderRadius.circular(5),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : (indeterminate ? const Center(child: SizedBox(width: 8, height: 1.6, child: ColoredBox(color: Colors.grey))) : null),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final String label;
  final String scope;
  final bool sensitive;
  final bool checked;
  final bool disabled;
  final VoidCallback onTap;
  const _PermRow({required this.label, required this.scope, required this.sensitive, required this.checked, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(.5)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Opacity(
              opacity: disabled ? .4 : 1,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: checked ? ScolarisPalette.forestGreen : Colors.transparent,
                  border: Border.all(color: checked ? ScolarisPalette.forestGreen : cs.outlineVariant, width: 1.4),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: checked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, runSpacing: 3, children: [
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                  child: Text(scope, style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
                ),
                if (sensitive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: _redDim, borderRadius: BorderRadius.circular(20)),
                    child: const Text('SENSIBLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _red, letterSpacing: .4)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final RoleDraft role;
  final List<RoleDraft> allRoles;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDelete;
  const _SummaryColumn({required this.role, required this.allRoles, required this.onMutate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parentOptions = allRoles.where((r) => r.draftId != role.draftId).toList();
    final parent = allRoles.where((r) => r.draftId == role.parentDraftId).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RÉSUMÉ DU RÔLE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        _FieldLabel('Nom du rôle'),
        TextFormField(
          key: ValueKey('name-${role.draftId}'),
          initialValue: role.name,
          enabled: !role.locked,
          onChanged: (v) => onMutate((r) => r.name = v),
          decoration: _fieldDecoration(cs),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Description'),
        TextFormField(
          key: ValueKey('desc-${role.draftId}'),
          initialValue: role.description,
          enabled: !role.locked,
          maxLines: 3,
          onChanged: (v) => onMutate((r) => r.description = v),
          decoration: _fieldDecoration(cs),
          style: const TextStyle(fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _StatCard(value: role.isAdminRole ? '∞' : '${role.grants.length}', label: 'permissions actives')),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '${allRoles.length}', label: 'rôles dans l\'école')),
        ]),
        const SizedBox(height: 16),
        _FieldLabel('Niveau hiérarchique'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in kRoleLevels)
            GestureDetector(
              onTap: role.locked ? null : () => onMutate((r) => r.level = l),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: role.level == l ? colorFromHex(role.color).withOpacity(.14) : Colors.transparent,
                  border: Border.all(color: role.level == l ? colorFromHex(role.color) : cs.outlineVariant),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: role.level == l ? colorFromHex(role.color) : cs.onSurfaceVariant)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        _FieldLabel('Couleur'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in ScolarisAccents.all)
            GestureDetector(
              onTap: role.locked ? null : () => onMutate((r) => r.color = colorToHex(c)),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: colorToHex(c) == role.color ? cs.onSurface : Colors.transparent, width: 2),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        _FieldLabel('Hérite de'),
        DropdownButtonFormField<String>(
          value: parent?.draftId,
          decoration: _fieldDecoration(cs),
          items: [
            const DropdownMenuItem(value: null, child: Text('Aucun — rôle indépendant', style: TextStyle(fontSize: 12.5))),
            for (final p in parentOptions)
              DropdownMenuItem(value: p.draftId, child: Text(p.name, style: const TextStyle(fontSize: 12.5))),
          ],
          onChanged: role.locked ? null : (v) => onMutate((r) => r.parentDraftId = v),
        ),
        const SizedBox(height: 20),
        Divider(color: cs.outlineVariant),
        const SizedBox(height: 12),
        if (!role.locked)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _redDim, borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Zone sensible', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _red)),
              const SizedBox(height: 4),
              const Text('Ce rôle sera supprimé pour cette école. Les membres assignés devront être réaffectés.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7A5A55))),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _red), foregroundColor: _red),
                  child: const Text('Supprimer ce rôle', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withOpacity(.3), borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_rounded, size: 15, color: _terra),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Chaque permission est revérifiée côté serveur à chaque requête. Aucune règle n'est codée en dur côté client.",
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Supprimer ce rôle ?'),
      content: Text('« ${role.name} » sera définitivement retiré après enregistrement.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () { Navigator.pop(ctx); onDelete(); }, child: const Text('Supprimer', style: TextStyle(color: _red))),
      ],
    ));
  }
}

InputDecoration _fieldDecoration(ColorScheme cs) => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: cs.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: cs.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _terra)),
    );

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5, color: cs.onSurfaceVariant)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(11)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: cs.onSurface)),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
