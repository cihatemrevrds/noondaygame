import 'package:flutter/material.dart';
import '../models/role.dart';

class RoleManagementDialog extends StatefulWidget {
  final Map<String, int> currentRoles;
  final Function(Map<String, int>) onRolesUpdated;

  const RoleManagementDialog({
    super.key,
    required this.currentRoles,
    required this.onRolesUpdated,
  });

  @override
  State<RoleManagementDialog> createState() => _RoleManagementDialogState();
}

class _RoleManagementDialogState extends State<RoleManagementDialog> {
  late Map<String, int> _rolesCounts;
  final Map<RoleTeam, List<Role>> _allRoles = Role.getAllRolesByTeam();

  @override
  void initState() {
    super.initState();
    _rolesCounts = Map<String, int>.from(widget.currentRoles);
  }

  void _updateRoleCount(String roleName, int delta) {
    setState(() {
      int currentCount = _rolesCounts[roleName] ?? 0;
      int newCount = (currentCount + delta).clamp(0, 5); // Max 5 of each role
      if (newCount == 0) {
        _rolesCounts.remove(roleName);
      } else {
        _rolesCounts[roleName] = newCount;
      }
    });
  }

  int get _totalRolesCount {
    return _rolesCounts.values.fold(0, (sum, count) => sum + count);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513), // Saddle brown
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD2691E), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFD2691E), // Chocolate
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MANAGE ROLES',
                    style: TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Total roles counter
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF654321),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Total Roles: $_totalRolesCount',
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Roles by team
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    ..._allRoles.entries.map((teamEntry) {
                      final team = teamEntry.key;
                      final roles = teamEntry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Role.getTeamColor(team).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Role.getTeamColor(team),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  team == RoleTeam.town
                                      ? Icons.shield
                                      : team == RoleTeam.bandit
                                      ? Icons.flash_on
                                      : Icons.help_outline,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${Role.getTeamName(team)} Team',
                                  style: const TextStyle(
                                    fontFamily: 'Rye',
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Roles in this team
                          ...roles.map((role) => _buildRoleCard(role)),

                          const SizedBox(height: 20),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF654321),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    'CANCEL',
                    Colors.grey,
                    () => Navigator.of(context).pop(),
                  ),
                  _buildActionButton(
                    'SAVE ROLES',
                    const Color(0xFF228B22), // Forest green
                    () {
                      widget.onRolesUpdated(_rolesCounts);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(Role role) {
    final currentCount = _rolesCounts[role.name] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF654321).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentCount > 0 ? Role.getTeamColor(role.team) : Colors.grey,
          width: currentCount > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Role icon placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Role.getTeamColor(role.team).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Role.getTeamColor(role.team)),
            ),
            child: Icon(
              _getRoleIcon(role.name),
              color: Role.getTeamColor(role.team),
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // Role info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.name,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role.shortDescription,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Count controls
          Row(
            children: [
              _buildCountButton(
                Icons.remove,
                currentCount > 0,
                () => _updateRoleCount(role.name, -1),
              ),

              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
                child: Center(
                  child: Text(
                    currentCount.toString(),
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              _buildCountButton(
                Icons.add,
                currentCount < 5,
                () => _updateRoleCount(role.name, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountButton(
    IconData icon,
    bool enabled,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFD2691E) : Colors.grey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'doctor':
        return Icons.local_hospital;
      case 'sheriff':
        return Icons.security;
      case 'escort':
        return Icons.block;
      case 'peeper':
        return Icons.visibility;
      case 'gunslinger':
        return Icons.gps_fixed;
      case 'gunman':
        return Icons.gps_off;
      case 'chieftain':
        return Icons.star;
      case 'jester':
        return Icons.theater_comedy;
      default:
        return Icons.person;
    }
  }
}
