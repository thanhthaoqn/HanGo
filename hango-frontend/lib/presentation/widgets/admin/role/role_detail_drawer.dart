import 'package:flutter/material.dart';

class RoleDetailDrawer extends StatefulWidget {
  final String roleName;
  final List<String> initialPermissions;
  final List<Map<String, dynamic>> allPermissions;
  final Function(List<String> newPermissions) onSave;
  final VoidCallback onCancel;

  const RoleDetailDrawer({
    Key? key,
    required this.roleName,
    required this.initialPermissions,
    required this.allPermissions,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<RoleDetailDrawer> createState() => _RoleDetailDrawerState();
}

class _RoleDetailDrawerState extends State<RoleDetailDrawer> {
  late Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedPermissions = Set<String>.from(widget.initialPermissions);
  }

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final drawerWidth = width > 800 ? 500.0 : width * 0.85;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: drawerWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(-2, 0),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Role Permissions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: ${widget.roleName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: _groupedPermissions.entries.map((entry) {
                    final module = entry.key;
                    final perms = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Text(
                            module,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: perms.map((perm) {
                              final code = perm['code'] as String;
                              
                              final coreRoles = perm['coreForRoles'] as String? ?? '';
                              final restrictedRoles = perm['restrictedForRoles'] as String? ?? '';
                              
                              final isCore = coreRoles.contains(widget.roleName);
                              final isRestricted = restrictedRoles.contains(widget.roleName);
                              
                              if (isRestricted) {
                                return const SizedBox.shrink(); // Hide restricted permissions completely
                              }
                              
                              final isSelected = _selectedPermissions.contains(code) || isCore;

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: isCore ? null : (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedPermissions.add(code);
                                    } else {
                                      _selectedPermissions.remove(code);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF28B79B),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        perm['name'] ?? code,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: isCore ? Colors.grey : const Color(0xFF1E293B),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    if (isCore)
                                      const Icon(Icons.lock, size: 16, color: Colors.grey),
                                  ],
                                ),
                                subtitle: Text(
                                  perm['description'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCore ? Colors.grey.shade400 : const Color(0xFF64748B),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  color: Color(0xFFF9FAFB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => widget.onSave(_selectedPermissions.toList()),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper to show the side drawer
void showRoleDetailDrawer(
  BuildContext context, {
  required String roleName,
  required List<String> initialPermissions,
  required List<Map<String, dynamic>> allPermissions,
  required Function(List<String> newPermissions) onSave,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return RoleDetailDrawer(
        roleName: roleName,
        initialPermissions: initialPermissions,
        allPermissions: allPermissions,
        onSave: (newPermissions) {
          Navigator.of(context).pop();
          onSave(newPermissions);
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
  );
}
