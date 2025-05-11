import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/role_card.dart';
import '../models/role.dart';

class RoleSelectionPage extends StatefulWidget {
  final List<Player> players;

  const RoleSelectionPage({super.key, required this.players});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  late List<Role> roles;
  late int totalRolesSelected;
  bool _randomRolesEnabled = false;
  late List<bool> _roleIncluded;

  @override
  void initState() {
    super.initState();
    // Get standard roles from the Role model
    roles = Role.getStandardRoles();

    // Initialize all roles as included for random mode
    _roleIncluded = List.generate(roles.length, (index) => true);

    totalRolesSelected = roles.fold(0, (sum, role) => sum + role.count);
  }
  
  // Show role info dialog
  void _showRoleInfo(Role role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          role.name,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 24,
            color: Color(0xFF4E2C0B),
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.brown[700]!, width: 3),
                ),
                child: Center(
                  child: Text(
                    role.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.brown[800],
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                role.description,
                style: const TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.brown[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: Color(0xFF4E2C0B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void updateRole(int index, bool increment) {
    setState(() {
      if (increment) {
        if (totalRolesSelected < widget.players.length) {
          roles[index] = roles[index].copyWith(
            count: roles[index].count + 1,
          );
          totalRolesSelected++;
        } else {
          _showErrorSnackBar('Cannot add more roles than players');
        }
      } else {
        if (roles[index].count > 0) {
          roles[index] = roles[index].copyWith(
            count: roles[index].count - 1,
          );
          totalRolesSelected--;
        }
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'SELECT ROLES',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Random Roles',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 18,
                          color: Colors.brown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _randomRolesEnabled,
                        onChanged: (value) {
                          setState(() {
                            _randomRolesEnabled = value;
                            // Reset role counts if switching to random mode
                            if (value) {
                              // In random mode, we'll use included/excluded roles instead of counts
                              _roleIncluded = List.generate(roles.length, (index) => true);
                            } else {
                              // Reset counts when switching back to manual mode
                              totalRolesSelected = roles.fold(0, (sum, role) => sum + role.count);
                            }
                          });
                        },
                        activeColor: Colors.brown,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.brown),
                  if (!_randomRolesEnabled) ...[
                    Text(
                      'Total Roles: $totalRolesSelected/${widget.players.length}',
                      style: const TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 18,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      totalRolesSelected == widget.players.length
                          ? 'All roles assigned!'
                          : totalRolesSelected < widget.players.length
                              ? 'Add ${widget.players.length - totalRolesSelected} more roles'
                              : 'Remove ${totalRolesSelected - widget.players.length} roles',
                      style: TextStyle(
                        fontSize: 14,
                        color: totalRolesSelected != widget.players.length ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (_randomRolesEnabled)
                    const Text(
                      'Select which roles to include in the random distribution',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // Changed to 3 roles per row
                  crossAxisSpacing: 12, // Slightly reduced spacing to fit 3 cards
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7, // Adjusted for taller cards
                ),
                itemCount: roles.length,
                itemBuilder: (context, index) {
                  if (_randomRolesEnabled) {
                    // In random mode, show a switch for including/excluding the role
                    return GestureDetector(
                      onTap: () => _showRoleInfo(roles[index]), // Add tap to view role info
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4E2C0B),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Role image placeholder
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.brown[700]!, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  roles[index].name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.brown[800],
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Role name
                            Text(
                              roles[index].name,
                              style: const TextStyle(
                                fontFamily: 'Rye',
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            // Include/exclude toggle
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Include',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                Switch(
                                  value: _roleIncluded[index],
                                  onChanged: (value) {
                                    setState(() {
                                      _roleIncluded[index] = value;
                                    });
                                  },
                                  activeColor: Colors.brown[300],
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // In manual mode, show the counter UI
                    return RoleCard(
                      name: roles[index].name,
                      imageName: roles[index].imageName,
                      count: roles[index].count,
                      description: roles[index].description,
                      onIncrement: () => updateRole(index, true),
                      onDecrement: () => updateRole(index, false),
                      onTap: () => _showRoleInfo(roles[index]), // Add tap to view role info
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_randomRolesEnabled && totalRolesSelected != widget.players.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        totalRolesSelected < widget.players.length
                            ? 'Need ${widget.players.length - totalRolesSelected} more roles to start'
                            : 'Remove ${totalRolesSelected - widget.players.length} roles to start',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _randomRolesEnabled || totalRolesSelected == widget.players.length
                        ? () {
                            // In a real app, this would generate and distribute roles to players
                            if (_randomRolesEnabled) {
                              // Random mode logic: check if at least one role is included
                              if (!_roleIncluded.contains(true)) {
                                _showErrorSnackBar('Please include at least one role');
                                return;
                              }
                            }
                            // Show a success message about role distribution
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Roles have been distributed to all players!',
                                  style: TextStyle(fontFamily: 'Rye'),
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            
                            // Navigate back after a short delay
                            Future.delayed(const Duration(seconds: 2), () {
                              Navigator.pop(context); // Go back to the previous screen
                              // In a full implementation, you'd navigate to the game screen
                              // Navigator.push(...)
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E2C0B),
                      minimumSize: const Size(250, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'START GAME',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
