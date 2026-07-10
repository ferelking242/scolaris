import 'package:supabase_flutter/supabase_flutter.dart';

/// Un module de permission (ex: "eleves") + ses sous-permissions (ex: "voir").
class SbPermissionModule {
  final String key;
  final String label;
  final List<SbSubPermission> subPermissions;
  const SbPermissionModule({required this.key, required this.label, required this.subPermissions});
}

class SbSubPermission {
  final String key;
  final String label;
  const SbSubPermission({required this.key, required this.label});
}

/// Modèle de rôle prédéfini (catalogue global, par cycle scolaire).
class SbRoleTemplate {
  final String id;
  final String cycle;
  final String name;
  final String? description;
  final String level;
  final String color;
  final String iconKey;
  /// Ensemble de "permission.sous_permission" accordées par défaut.
  final Set<String> grants;
  const SbRoleTemplate({
    required this.id, required this.cycle, required this.name, this.description,
    this.level = 'Pédagogique', this.color = '#8B1A00', this.iconKey = 'badge',
    required this.grants,
  });
}

/// Rôle réel d'une école (créé à partir d'un template ou de zéro).
class SbStaffRole {
  final String id;
  final String schoolId;
  final String name;
  final String? description;
  final bool isAdminRole;
  final String level;
  final String color;
  final String iconKey;
  final String? parentRoleId;
  final Set<String> grants; // "permission.sous_permission"
  const SbStaffRole({
    required this.id, required this.schoolId, required this.name,
    this.description, required this.isAdminRole, required this.grants,
    this.level = 'Pédagogique', this.color = '#8B1A00', this.iconKey = 'badge',
    this.parentRoleId,
  });

  SbStaffRole copyWith({
    String? name, String? description, String? level, String? color,
    String? iconKey, Set<String>? grants,
  }) => SbStaffRole(
        id: id, schoolId: schoolId, isAdminRole: isAdminRole, parentRoleId: parentRoleId,
        name: name ?? this.name, description: description ?? this.description,
        level: level ?? this.level, color: color ?? this.color, iconKey: iconKey ?? this.iconKey,
        grants: grants ?? this.grants,
      );
}

class StaffRolesSource {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// Catalogue complet des permissions/sous-permissions (référence, pas de school_id).
  static Future<List<SbPermissionModule>> fetchPermissionCatalog() async {
    final perms = await _sb.from('permission_catalog').select('key,label,order_num').order('order_num');
    final subs  = await _sb.from('sub_permission_catalog').select('permission_key,key,label,order_num').order('order_num');
    return (perms as List).map((p) {
      final subList = (subs as List)
          .where((s) => s['permission_key'] == p['key'])
          .map((s) => SbSubPermission(key: s['key'] as String, label: s['label'] as String))
          .toList();
      return SbPermissionModule(key: p['key'] as String, label: p['label'] as String, subPermissions: subList);
    }).toList();
  }

  /// Modèles de rôles prédéfinis pour un cycle donné ('primaire'|'college'|'lycee'|'universite').
  static Future<List<SbRoleTemplate>> fetchRoleTemplates(String cycle) async {
    final templates = await _sb.from('role_templates')
        .select('id,cycle,name,description,order_num,level,color,icon_key')
        .eq('cycle', cycle)
        .order('order_num');
    final ids = (templates as List).map((t) => t['id'] as String).toList();
    if (ids.isEmpty) return [];
    final perms = await _sb.from('role_template_permissions')
        .select('role_template_id,permission_key,sub_permission_key')
        .inFilter('role_template_id', ids);
    return templates.map((t) {
      final grants = (perms as List)
          .where((p) => p['role_template_id'] == t['id'])
          .map((p) => '${p['permission_key']}.${p['sub_permission_key']}')
          .toSet();
      return SbRoleTemplate(
        id: t['id'] as String, cycle: t['cycle'] as String, name: t['name'] as String,
        description: t['description'] as String?, grants: grants,
        level: t['level'] as String? ?? 'Pédagogique',
        color: t['color'] as String? ?? '#8B1A00',
        iconKey: t['icon_key'] as String? ?? 'badge',
      );
    }).toList();
  }

  static Future<List<SbStaffRole>> fetchStaffRoles(String schoolId) async {
    final roles = await _sb.from('staff_roles')
        .select('id,school_id,name,description,is_admin_role,level,color,icon_key,parent_role_id')
        .eq('school_id', schoolId)
        .order('created_at');
    final ids = (roles as List).map((r) => r['id'] as String).toList();
    final perms = ids.isEmpty
        ? []
        : await _sb.from('staff_role_permissions')
            .select('staff_role_id,permission_key,sub_permission_key')
            .inFilter('staff_role_id', ids);
    return roles.map((r) {
      final grants = (perms as List)
          .where((p) => p['staff_role_id'] == r['id'])
          .map((p) => '${p['permission_key']}.${p['sub_permission_key']}')
          .toSet();
      return SbStaffRole(
        id: r['id'] as String, schoolId: r['school_id'] as String, name: r['name'] as String,
        description: r['description'] as String?, isAdminRole: r['is_admin_role'] as bool,
        grants: grants,
        level: r['level'] as String? ?? 'Pédagogique',
        color: r['color'] as String? ?? '#8B1A00',
        iconKey: r['icon_key'] as String? ?? 'badge',
        parentRoleId: r['parent_role_id'] as String?,
      );
    }).toList();
  }

  /// Crée un rôle pour l'école, avec ses permissions. [grants] = "permission.sous_permission".
  static Future<String> createStaffRole({
    required String schoolId,
    required String name,
    String? description,
    bool isAdminRole = false,
    String? basedOnTemplateId,
    String level = 'Pédagogique',
    String color = '#8B1A00',
    String iconKey = 'badge',
    String? parentRoleId,
    required Set<String> grants,
  }) async {
    final row = await _sb.from('staff_roles').insert({
      'school_id': schoolId,
      'name': name,
      'description': description,
      'is_admin_role': isAdminRole,
      'based_on_template_id': basedOnTemplateId,
      'level': level,
      'color': color,
      'icon_key': iconKey,
      'parent_role_id': parentRoleId,
    }).select('id').single();
    final roleId = row['id'] as String;
    if (!isAdminRole && grants.isNotEmpty) {
      await _sb.from('staff_role_permissions').insert([
        for (final g in grants)
          {
            'staff_role_id': roleId,
            'permission_key': g.split('.').first,
            'sub_permission_key': g.split('.').skip(1).join('.'),
          }
      ]);
    }
    return roleId;
  }

  static Future<void> updateRoleGrants(String roleId, Set<String> grants) async {
    await _sb.from('staff_role_permissions').delete().eq('staff_role_id', roleId);
    if (grants.isNotEmpty) {
      await _sb.from('staff_role_permissions').insert([
        for (final g in grants)
          {
            'staff_role_id': roleId,
            'permission_key': g.split('.').first,
            'sub_permission_key': g.split('.').skip(1).join('.'),
          }
      ]);
    }
  }

  static Future<void> deleteRole(String roleId) async {
    await _sb.from('staff_roles').delete().eq('id', roleId);
  }

  static Future<void> updateRoleMeta({
    required String roleId,
    String? name,
    String? description,
    String? level,
    String? color,
    String? iconKey,
    String? parentRoleId,
  }) async {
    final update = <String, dynamic>{};
    if (name != null) update['name'] = name;
    if (description != null) update['description'] = description;
    if (level != null) update['level'] = level;
    if (color != null) update['color'] = color;
    if (iconKey != null) update['icon_key'] = iconKey;
    if (parentRoleId != null) update['parent_role_id'] = parentRoleId == '' ? null : parentRoleId;
    if (update.isEmpty) return;
    await _sb.from('staff_roles').update(update).eq('id', roleId);
  }

  static Future<void> renameRole(String roleId, String name, String? description) async {
    await _sb.from('staff_roles').update({'name': name, 'description': description}).eq('id', roleId);
  }
}
