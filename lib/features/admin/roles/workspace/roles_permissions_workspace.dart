import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/staff_roles_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'role_org_chart.dart';
import 'role_workspace_models.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _green  = ScolarisPalette.forestGreen;
const _red    = Color(0xFFDC2626);
const _redBg  = Color(0xFFFEF2F2);

String _cycleFromTypes(List<String> types) {
  if (types.contains('universite') || types.contains('superieur')) return 'universite';
  if (types.contains('lycee')) return 'lycee';
  if (types.contains('college')) return 'college';
  return 'primaire';
}

int _draftCounter = 0;
String _newDraftId() => 'draft_${DateTime.now().microsecondsSinceEpoch}_${_draftCounter++}';

/// Workspace rôles & permissions — organigramme, liste de rôles, permissions
/// détaillées, résumé & zone sensible.
/// Fonctionne en mode `onboarding` (première config) ou en page permanente.
class RolesPermissionsWorkspace extends ConsumerStatefulWidget {
  final bool onboarding;
  final VoidCallback? onDone;
  const RolesPermissionsWorkspace({super.key, this.onboarding = false, this.onDone});

  @override
  ConsumerState<RolesPermissionsWorkspace> createState() => _RolesPermissionsWorkspaceState();
}

class _RolesPermissionsWorkspaceState extends ConsumerState<RolesPermissionsWorkspace>
    with SingleTickerProviderStateMixin {

  bool _loading = true;
  bool _saving  = false;
  String? _error;
  List<SbPermissionModule> _catalog = [];
  List<RoleDraft> _roles = [];
  String? _selectedId;
  String _searchQuery = '';
  final Set<String> _openCategories = {};
  final List<String> _pendingDeletes = [];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _dirty => _roles.any((r) => r.isDirty) || _pendingDeletes.isNotEmpty;
  RoleDraft? get _selected => _roles.where((r) => r.draftId == _selectedId).firstOrNull;

  List<RoleDraft> get _filteredRoles {
    if (_searchQuery.trim().isEmpty) return _roles;
    final q = _searchQuery.toLowerCase();
    return _roles.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session  = ref.read(authSessionProvider);
      final schoolId = ref.read(currentSchoolIdProvider);
      final school   = await ref.read(schoolProvider.future);
      final cycle    = _cycleFromTypes(school?.types ?? const []);
      final catalog  = await StaffRolesSource.fetchPermissionCatalog();
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
          description: "Rôle du créateur de l'école — accès total, non modifiable.",
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
        _catalog    = catalog;
        _roles      = drafts;
        _selectedId = drafts.isNotEmpty ? drafts.first.draftId : null;
        _loading    = false;
        if (_openCategories.isEmpty && catalog.isNotEmpty) {
          _openCategories.addAll(catalog.take(2).map((c) => c.key));
        }
      });
    } catch (e) {
      setState(() { _error = 'Erreur de chargement : $e'; _loading = false; });
    }
  }

  void _select(String draftId) {
    setState(() => _selectedId = draftId);
    if (_tabController.index == 0) _tabController.animateTo(1);
  }

  void _addRole() {
    final draft = RoleDraft.blank(draftId: _newDraftId());
    setState(() { _roles.add(draft); _selectedId = draft.draftId; });
    _tabController.animateTo(1);
  }

  void _duplicateRole(RoleDraft src) {
    final copy = RoleDraft(
      draftId: _newDraftId(),
      name: '${src.name} (copie)',
      description: src.description,
      isNew: true, isDirty: true,
      level: src.level, color: src.color, iconKey: src.iconKey,
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
    _tabController.animateTo(0);
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

      final idMap = <String, String>{};
      for (final r in _roles.where((r) => !r.isNew)) {
        idMap[r.draftId] = r.persistedId!;
      }
      for (final r in _roles) {
        if (!r.isDirty) continue;
        if (r.isNew) {
          final newId = await StaffRolesSource.createStaffRole(
            schoolId: schoolId,
            name: r.name, description: r.description,
            isAdminRole: r.isAdminRole, basedOnTemplateId: r.basedOnTemplateId,
            level: r.level, color: r.color, iconKey: r.iconKey, grants: r.grants,
          );
          idMap[r.draftId] = newId;
          r.persistedId = newId;
          r.isNew = false;
        } else {
          await StaffRolesSource.updateRoleMeta(
            roleId: r.persistedId!,
            name: r.name, description: r.description,
            level: r.level, color: r.color, iconKey: r.iconKey,
          );
          if (!r.isAdminRole) {
            await StaffRolesSource.updateRoleGrants(r.persistedId!, r.grants);
          }
        }
        r.isDirty = false;
      }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Hiérarchie des rôles enregistrée.'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sauvegarde : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 960;

    if (_loading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator(color: _terra)),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header compact ──────────────────────────────────────────────────
        _WorkspaceHeader(
          onboarding: widget.onboarding,
          dirty: _dirty, saving: _saving,
          onSave: _save,
        ),
        // ── Bandeau d'erreur ────────────────────────────────────────────────
        if (_error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _redBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withOpacity(.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: _red, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: _red, fontSize: 12.5))),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: _red),
                onPressed: () => setState(() => _error = null),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
          ),
        // ── Corps ───────────────────────────────────────────────────────────
        Expanded(
          child: wide ? _DesktopLayout(
            roles: _roles, filtered: _filteredRoles,
            selectedId: _selectedId, catalog: _catalog,
            openCategories: _openCategories,
            onSelect: _select,
            onSearch: (q) => setState(() => _searchQuery = q),
            onAdd: _addRole,
            onToggleCat: (k) => setState(() =>
                _openCategories.contains(k) ? _openCategories.remove(k) : _openCategories.add(k)),
            onMutate: (fn) { if (_selected != null) _mutate(_selected!, fn); },
            onDuplicate: () { if (_selected != null) _duplicateRole(_selected!); },
            onDelete: () { if (_selected != null) _deleteRole(_selected!); },
          ) : _MobileLayout(
            tabController: _tabController,
            roles: _roles, filtered: _filteredRoles,
            selectedId: _selectedId, catalog: _catalog,
            openCategories: _openCategories,
            onSelect: _select,
            onSearch: (q) => setState(() => _searchQuery = q),
            onAdd: _addRole,
            onToggleCat: (k) => setState(() =>
                _openCategories.contains(k) ? _openCategories.remove(k) : _openCategories.add(k)),
            onMutate: (fn) { if (_selected != null) _mutate(_selected!, fn); },
            onDuplicate: () { if (_selected != null) _duplicateRole(_selected!); },
            onDelete: () { if (_selected != null) _deleteRole(_selected!); },
          ),
        ),
      ],
    );

    if (widget.onboarding) {
      return Scaffold(backgroundColor: cs.surface, body: SafeArea(child: content));
    }
    return Container(color: context.cPage, child: content);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _WorkspaceHeader extends StatelessWidget {
  final bool onboarding;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  const _WorkspaceHeader({
    required this.onboarding, required this.dirty,
    required this.saving, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: context.cCard,
        border: Border(bottom: BorderSide(color: context.cBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Icône badge
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_terra, _orange], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              onboarding ? 'Construire la hiérarchie' : 'Rôles & permissions',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.2),
            ),
            Text(
              onboarding
                  ? "Configurez les rôles du personnel de l'école."
                  : "Organigramme, droits et zones sensibles.",
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        // Bouton Enregistrer
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(onboarding ? Icons.check_rounded : Icons.save_rounded, size: 17),
          label: Text(
            saving ? 'En cours…' : (onboarding ? 'Enregistrer' : (dirty ? 'Sauvegarder' : 'Enregistré')),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: (dirty || onboarding) ? _terra : const Color(0xFF388E3C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DESKTOP — 3 colonnes
// ═══════════════════════════════════════════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final List<RoleDraft> roles;
  final List<RoleDraft> filtered;
  final String? selectedId;
  final List<SbPermissionModule> catalog;
  final Set<String> openCategories;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggleCat;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _DesktopLayout({
    required this.roles, required this.filtered, required this.selectedId,
    required this.catalog, required this.openCategories,
    required this.onSelect, required this.onSearch, required this.onAdd,
    required this.onToggleCat, required this.onMutate,
    required this.onDuplicate, required this.onDelete,
  });

  RoleDraft? get selected => roles.where((r) => r.draftId == selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = selected;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Colonne gauche : organigramme + liste
      SizedBox(
        width: 300,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.cBorder)),
            color: context.cSubtle,
          ),
          child: _RolesListPanel(
            roles: roles, filtered: filtered, selectedId: selectedId,
            onSelect: onSelect, onSearch: onSearch, onAdd: onAdd,
          ),
        ),
      ),
      // Colonne centrale : permissions
      Expanded(
        flex: 3,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(right: BorderSide(color: context.cBorder))),
          child: sel == null
              ? _EmptyCenter()
              : _PermissionsPanel(
                  role: sel, catalog: catalog, openCategories: openCategories,
                  onToggleCat: onToggleCat, onMutate: onMutate, onDuplicate: onDuplicate,
                ),
        ),
      ),
      // Colonne droite : résumé
      SizedBox(
        width: 280,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.cSubtle),
          child: sel == null
              ? const SizedBox.shrink()
              : _SummaryPanel(
                  role: sel, allRoles: roles,
                  onMutate: onMutate, onDelete: onDelete,
                ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE — TabBar avec 3 onglets
// ═══════════════════════════════════════════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final TabController tabController;
  final List<RoleDraft> roles;
  final List<RoleDraft> filtered;
  final String? selectedId;
  final List<SbPermissionModule> catalog;
  final Set<String> openCategories;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggleCat;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _MobileLayout({
    required this.tabController, required this.roles, required this.filtered,
    required this.selectedId, required this.catalog, required this.openCategories,
    required this.onSelect, required this.onSearch, required this.onAdd,
    required this.onToggleCat, required this.onMutate,
    required this.onDuplicate, required this.onDelete,
  });

  RoleDraft? get selected => roles.where((r) => r.draftId == selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = selected;
    return Column(children: [
      // TabBar
      Container(
        color: context.cCard,
        child: TabBar(
          controller: tabController,
          labelColor: _terra,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: _terra,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'Rôles · ${roles.length}'),
            Tab(text: sel == null ? 'Permissions' : 'Permissions'),
            Tab(text: 'Détails'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: tabController,
          children: [
            // Tab 1 — Liste des rôles
            Container(
              color: context.cSubtle,
              child: _RolesListPanel(
                roles: roles, filtered: filtered, selectedId: selectedId,
                onSelect: onSelect, onSearch: onSearch, onAdd: onAdd,
              ),
            ),
            // Tab 2 — Permissions
            sel == null
                ? _EmptyCenter()
                : _PermissionsPanel(
                    role: sel, catalog: catalog, openCategories: openCategories,
                    onToggleCat: onToggleCat, onMutate: onMutate, onDuplicate: onDuplicate,
                  ),
            // Tab 3 — Résumé
            sel == null
                ? _EmptyCenter()
                : Container(
                    color: context.cSubtle,
                    child: _SummaryPanel(
                      role: sel, allRoles: roles,
                      onMutate: onMutate, onDelete: onDelete,
                    ),
                  ),
          ],
        ),
      ),
    ]);
  }
}

class _EmptyCenter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.touch_app_rounded, size: 40, color: context.cMuted.withOpacity(.4)),
        const SizedBox(height: 12),
        Text('Sélectionnez un rôle', style: TextStyle(color: context.cMuted, fontSize: 14)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANNEAU GAUCHE — Organigramme + liste des rôles
// ═══════════════════════════════════════════════════════════════════════════════
class _RolesListPanel extends StatelessWidget {
  final List<RoleDraft> roles;
  final List<RoleDraft> filtered;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _RolesListPanel({
    required this.roles, required this.filtered, required this.selectedId,
    required this.onSelect, required this.onSearch, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      // ── Organigramme ────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: _SectionLabel(label: 'ORGANIGRAMME'),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        // Hauteur FIXE obligatoire : cet InteractiveViewer est dans un ListView,
        // qui donne à ses enfants une hauteur ILLIMITÉE. Un InteractiveViewer est
        // une fenêtre par laquelle on regarde un contenu plus grand — sans bords,
        // il ne peut pas se disposer. L'échec ("was given an infinite size during
        // layout") emportait le rendu de TOUTE la colonne : l'organigramme, mais
        // aussi la liste des rôles en dessous. D'où un panneau vide, où il n'y
        // avait littéralement rien à cliquer.
        child: SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: .6,
              maxScale: 2.5,
              constrained: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: roles.isEmpty
                    ? const SizedBox(height: 60, width: 260)
                    : RoleOrgChart(
                        roles: roles,
                        selectedDraftId: selectedId,
                        onSelect: onSelect,
                      ),
              ),
            ),
          ),
        ),
      ),
      // ── Recherche ───────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: _SearchField(onChanged: onSearch),
      ),
      // ── Étiquette liste ─────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: _SectionLabel(label: 'RÔLES · ${roles.length}'),
      ),
      // ── Items ───────────────────────────────────────────────────────────────
      for (final r in filtered)
        _RoleItem(role: r, selected: r.draftId == selectedId, onTap: () => onSelect(r.draftId)),
      // ── Bouton ajouter ──────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 17, color: _terra),
          label: const Text('Créer un rôle personnalisé',
              style: TextStyle(color: _terra, fontWeight: FontWeight.w700, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _terra.withOpacity(.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .9, color: context.cMuted),
  );
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 17, color: context.cMuted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: TextStyle(fontSize: 13, color: context.cInk),
            decoration: InputDecoration(
              hintText: 'Rechercher un rôle…',
              hintStyle: TextStyle(fontSize: 12.5, color: context.cMuted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Item de rôle ──────────────────────────────────────────────────────────────
class _RoleItem extends StatelessWidget {
  final RoleDraft role;
  final bool selected;
  final VoidCallback onTap;
  const _RoleItem({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(role.color);
    final count = role.grants.length;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.12) : Colors.transparent,
          border: Border.all(color: selected ? color.withOpacity(.5) : Colors.transparent),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          // Icône badge coloré
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(.22) : color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconForKey(role.iconKey), size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(role.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: selected ? color : context.cInk,
                    ),
                  ),
                ),
                if (role.locked)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(Icons.lock_rounded, size: 11, color: context.cMuted),
                  ),
              ]),
              Text(role.level, style: TextStyle(fontSize: 11, color: context.cMuted)),
            ]),
          ),
          // Compteur de permissions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(.18) : context.cBorder.withOpacity(.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.isAdminRole ? '∞' : '$count',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: selected ? color : context.cMuted),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANNEAU CENTRE — Permissions
// ═══════════════════════════════════════════════════════════════════════════════
class _PermissionsPanel extends StatelessWidget {
  final RoleDraft role;
  final List<SbPermissionModule> catalog;
  final Set<String> openCategories;
  final ValueChanged<String> onToggleCat;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDuplicate;

  const _PermissionsPanel({
    required this.role, required this.catalog, required this.openCategories,
    required this.onToggleCat, required this.onMutate, required this.onDuplicate,
  });

  int get _checked => role.isAdminRole
      ? catalog.fold(0, (n, m) => n + m.subPermissions.length)
      : role.grants.length;
  int get _total => catalog.fold(0, (n, m) => n + m.subPermissions.length);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = colorFromHex(role.color);
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      // ── En-tête du rôle sélectionné ─────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: context.cCard,
          border: Border(bottom: BorderSide(color: context.cBorder)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(.3)),
            ),
            child: Icon(iconForKey(role.iconKey), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.cInk)),
              Text(
                role.description.isEmpty ? 'Aucune description' : role.description,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.cMuted),
              ),
            ]),
          ),
          if (!role.locked)
            TextButton.icon(
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_all_rounded, size: 14),
              label: const Text('Dupliquer', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _terra),
            ),
        ]),
      ),
      // ── Barre résumé permissions ─────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_checked / $_total permissions actives',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const Spacer(),
          if (!role.locked) ...[
            _MiniButton(
              label: 'Tout cocher',
              onTap: () => onMutate((r) {
                r.grants = { for (final m in catalog) for (final s in m.subPermissions) '${m.key}.${s.key}' };
              }),
            ),
            const SizedBox(width: 6),
            _MiniButton(
              label: 'Tout décocher',
              onTap: () => onMutate((r) => r.grants = {}),
            ),
          ],
        ]),
      ),
      // ── Accordéon catégories ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Column(children: [
          for (final cat in catalog)
            _CategoryTile(
              module: cat, role: role,
              open: openCategories.contains(cat.key),
              onToggleOpen: () => onToggleCat(cat.key),
              onMutate: onMutate,
            ),
        ]),
      ),
    ]);
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.cBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.cMuted)),
      ),
    );
  }
}

// ─── Tile catégorie ──────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final SbPermissionModule module;
  final RoleDraft role;
  final bool open;
  final VoidCallback onToggleOpen;
  final void Function(void Function(RoleDraft)) onMutate;
  const _CategoryTile({
    required this.module, required this.role, required this.open,
    required this.onToggleOpen, required this.onMutate,
  });

  static const _sensitiveKeys = {'delete', 'export', 'roles'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checked = role.isAdminRole
        ? module.subPermissions.length
        : module.subPermissions.where((s) => role.grants.contains('${module.key}.${s.key}')).length;
    final total = module.subPermissions.length;
    final allChecked  = checked == total;
    final someChecked = checked > 0 && !allChecked;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: context.cCard,
        border: Border.all(color: context.cBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggleOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              AnimatedRotation(
                turns: open ? .25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: context.cMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(module.label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.cInk)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: allChecked ? _green.withOpacity(.12) : context.cSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$checked/$total',
                  style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: allChecked ? _green : context.cMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
            padding: const EdgeInsets.fromLTRB(50, 0, 14, 10),
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
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 19, height: 19,
        decoration: BoxDecoration(
          color: checked ? _terra : (indeterminate ? context.cSubtle : Colors.transparent),
          border: Border.all(color: checked ? _terra : context.cBorder, width: 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : (indeterminate
                ? const Center(child: SizedBox(width: 9, height: 2, child: ColoredBox(color: Color(0xFF9E9E9E))))
                : null),
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
  const _PermRow({
    required this.label, required this.scope, required this.sensitive,
    required this.checked, required this.disabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Opacity(
            opacity: disabled ? .4 : 1,
            child: Container(
              width: 17, height: 17,
              decoration: BoxDecoration(
                color: checked ? _green : Colors.transparent,
                border: Border.all(color: checked ? _green : context.cBorder, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: checked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 3, children: [
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.cInk)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: context.cSubtle, borderRadius: BorderRadius.circular(4)),
                child: Text(scope, style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: context.cMuted)),
              ),
              if (sensitive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: _redBg, borderRadius: BorderRadius.circular(20)),
                  child: const Text('SENSIBLE',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _red, letterSpacing: .4)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANNEAU DROIT — Résumé & édition du rôle
// ═══════════════════════════════════════════════════════════════════════════════
class _SummaryPanel extends StatelessWidget {
  final RoleDraft role;
  final List<RoleDraft> allRoles;
  final void Function(void Function(RoleDraft)) onMutate;
  final VoidCallback onDelete;
  const _SummaryPanel({
    required this.role, required this.allRoles,
    required this.onMutate, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleColor = colorFromHex(role.color);
    final parentOptions = allRoles.where((r) => r.draftId != role.draftId).toList();
    final parent = allRoles.where((r) => r.draftId == role.parentDraftId).firstOrNull;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      _SectionLabel(label: 'RÉSUMÉ DU RÔLE'),
      const SizedBox(height: 12),
      // ── Nom ────────────────────────────────────────────────────────────────
      _FieldLabel('Nom'),
      TextFormField(
        key: ValueKey('name-${role.draftId}'),
        initialValue: role.name,
        enabled: !role.locked,
        onChanged: (v) => onMutate((r) => r.name = v),
        style: TextStyle(fontSize: 13, color: context.cInk),
        decoration: _inputDeco(context),
      ),
      const SizedBox(height: 12),
      // ── Description ────────────────────────────────────────────────────────
      _FieldLabel('Description'),
      TextFormField(
        key: ValueKey('desc-${role.draftId}'),
        initialValue: role.description,
        enabled: !role.locked,
        maxLines: 3,
        onChanged: (v) => onMutate((r) => r.description = v),
        style: TextStyle(fontSize: 12.5, color: context.cInk),
        decoration: _inputDeco(context),
      ),
      const SizedBox(height: 14),
      // ── Stats ──────────────────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _StatCard(
          value: role.isAdminRole ? '∞' : '${role.grants.length}',
          label: 'permissions',
          color: roleColor,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          value: '${allRoles.length}',
          label: 'rôles total',
          color: _terra,
        )),
      ]),
      const SizedBox(height: 14),
      // ── Icône ──────────────────────────────────────────────────────────────
      _FieldLabel('Icône'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in kRoleIcons.entries)
          GestureDetector(
            onTap: role.locked ? null : () => onMutate((r) => r.iconKey = entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: role.iconKey == entry.key ? roleColor.withOpacity(.16) : context.cSubtle,
                border: Border.all(
                  color: role.iconKey == entry.key ? roleColor : context.cBorder,
                  width: role.iconKey == entry.key ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(entry.value, size: 17,
                  color: role.iconKey == entry.key ? roleColor : context.cMuted),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      // ── Couleur ────────────────────────────────────────────────────────────
      _FieldLabel('Couleur'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < ScolarisAccents.all.length; i++)
          GestureDetector(
            onTap: role.locked ? null : () => onMutate((r) => r.color = colorToHex(ScolarisAccents.all[i])),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: ScolarisAccents.all[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorToHex(ScolarisAccents.all[i]) == role.color
                      ? context.cInk : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: colorToHex(ScolarisAccents.all[i]) == role.color
                    ? [BoxShadow(color: ScolarisAccents.all[i].withOpacity(.4), blurRadius: 6)]
                    : null,
              ),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      // ── Niveau ─────────────────────────────────────────────────────────────
      _FieldLabel('Niveau hiérarchique'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final l in kRoleLevels)
          GestureDetector(
            onTap: role.locked ? null : () => onMutate((r) => r.level = l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: role.level == l ? roleColor.withOpacity(.14) : Colors.transparent,
                border: Border.all(color: role.level == l ? roleColor : context.cBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(l, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: role.level == l ? roleColor : context.cMuted,
              )),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      // ── Parent ─────────────────────────────────────────────────────────────
      _FieldLabel('Hérite de'),
      DropdownButtonFormField<String>(
        value: parent?.draftId,
        decoration: _inputDeco(context),
        style: TextStyle(fontSize: 12.5, color: context.cInk),
        dropdownColor: context.cCard,
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('Aucun — indépendant', style: TextStyle(fontSize: 12.5, color: context.cMuted)),
          ),
          for (final p in parentOptions)
            DropdownMenuItem(value: p.draftId, child: Text(p.name, style: const TextStyle(fontSize: 12.5))),
        ],
        onChanged: role.locked ? null : (v) => onMutate((r) => r.parentDraftId = v),
      ),
      const SizedBox(height: 20),
      Divider(color: context.cBorder),
      const SizedBox(height: 10),
      // ── Zone sensible ───────────────────────────────────────────────────────
      if (!role.locked)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _redBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withOpacity(.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: _red),
              SizedBox(width: 6),
              Text('Zone sensible', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _red)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Ce rôle sera définitivement supprimé. Les membres assignés devront être réaffectés.',
              style: TextStyle(fontSize: 11, color: Color(0xFF7A3030), height: 1.4),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Supprimer ce rôle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _red),
                  foregroundColor: _red,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      const SizedBox(height: 16),
      // ── Note sécurité ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_rounded, size: 14, color: _terra),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Chaque permission est revérifiée côté serveur à chaque requête.",
              style: TextStyle(fontSize: 10.5, color: context.cMuted, height: 1.5),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce rôle ?'),
        content: Text('« ${role.name} » sera définitivement retiré après enregistrement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onDelete(); },
            child: const Text('Supprimer', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDeco(BuildContext context) => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
  filled: true,
  fillColor: context.cCard,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.cBorder)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.cBorder)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _terra)),
  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: context.cBorder.withOpacity(.5))),
);

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.cMuted)),
  );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 10.5, color: color.withOpacity(.7))),
      ]),
    );
  }
}
