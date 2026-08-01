import 'package:flutter/material.dart';

class RoleMatrixTab extends StatefulWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> allPermissions;
  final List<Map<String, dynamic>> rolesWithPermissions;
  final Function(String roleName, List<String> currentCodes) onEditRole;

  const RoleMatrixTab({
    Key? key,
    required this.isLoading,
    required this.allPermissions,
    required this.rolesWithPermissions,
    required this.onEditRole,
  }) : super(key: key);

  @override
  State<RoleMatrixTab> createState() => _RoleMatrixTabState();
}

class _RoleMatrixTabState extends State<RoleMatrixTab> {
  // Map module name to list of permissions
  Map<String, List<Map<String, dynamic>>> get _groupedPermissions {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var perm in widget.allPermissions) {
      final module = perm['module'] as String? ?? 'Others';
      if (!map.containsKey(module)) {
        map[module] = [];
      }
      map[module]!.add(perm);
    }
    return map;
  }

  // Predefined role order
  final List<String> _roleOrder = [
    'ADMINISTRATOR',
    'COURSE_MANAGER',
    'TRAINER',
    'LEARNER'
  ];

  String _formatRoleName(String backendRole) {
    if (backendRole == 'ADMINISTRATOR') return 'Admin';
    if (backendRole == 'COURSE_MANAGER') return 'Course Manager';
    if (backendRole == 'TRAINER') return 'Trainer';
    if (backendRole == 'LEARNER') return 'Learner';
    return backendRole;
  }

  bool _hasPermission(String roleName, String permCode) {
    final roleObj = widget.rolesWithPermissions.firstWhere(
      (r) => r['roleName'] == roleName,
      orElse: () => {'permissions': []},
    );
    final perms = roleObj['permissions'] as List? ?? [];
    return perms.any((p) => p['code'] == permCode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
          ),
        ),
      );
    }

    final groups = _groupedPermissions;
    final roles = _roleOrder.where((r) => widget.rolesWithPermissions.any((wr) => wr['roleName'] == r)).toList();
    if (roles.isEmpty) {
      // Fallback if the predefined roles don't match
      roles.addAll(widget.rolesWithPermissions.map((e) => e['roleName'].toString()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Role Configurations',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Permission Matrix (Read-only). Click Edit on a role to modify.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 300,
                          child: Text(
                            'Permissions',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF374151),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        ...roles.map((r) => SizedBox(
                              width: 140,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatRoleName(r),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                      fontFamily: 'Outfit',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  if (r != 'ADMINISTRATOR')
                                    InkWell(
                                      onTap: () {
                                        final roleObj = widget.rolesWithPermissions.firstWhere((element) => element['roleName'] == r);
                                        final perms = roleObj['permissions'] as List? ?? [];
                                        final currentCodes = perms.map((p) => p['code'] as String).toList();
                                        widget.onEditRole(r, currentCodes);
                                      },
                                      child: const Text(
                                        'Edit Role',
                                        style: TextStyle(
                                          color: Color(0xFF28B79B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'System Default',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  // Body
                  ...groups.entries.map((entry) {
                    final moduleName = entry.key;
                    final perms = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Module Group Header
                        Container(
                          color: const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.folder_open, size: 18, color: const Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Text(
                                moduleName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        // Permissions in this module
                        ...perms.map((perm) {
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 300,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            perm['name'] ?? perm['code'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            perm['description'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...roles.map((r) => SizedBox(
                                          width: 140,
                                          child: Center(
                                            child: _hasPermission(r, perm['code'])
                                                ? const Icon(Icons.check_circle, color: Color(0xFF28B79B), size: 22)
                                                : const Icon(Icons.cancel, color: Color(0xFFD1D5DB), size: 22),
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            ],
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
