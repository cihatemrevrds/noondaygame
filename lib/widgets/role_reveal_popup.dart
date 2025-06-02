import 'package:flutter/material.dart';
import 'dart:async';
import '../models/role.dart';

class RoleRevealPopup extends StatefulWidget {
  final String roleName;
  final VoidCallback onComplete;

  const RoleRevealPopup({
    super.key,
    required this.roleName,
    required this.onComplete,
  });

  @override
  State<RoleRevealPopup> createState() => _RoleRevealPopupState();
}

class _RoleRevealPopupState extends State<RoleRevealPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations
    _scaleController.forward();
    _fadeController.forward();

    // Auto close after 5 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      _closePopup();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _closePopup() async {
    _autoCloseTimer?.cancel();

    // Fade out animation
    await _fadeController.reverse();

    if (mounted) {
      widget.onComplete();
    }
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

  Color _getRoleColor(String roleName) {
    try {
      final role = Role.getAllRoles().firstWhere(
        (r) => r.name.toLowerCase() == roleName.toLowerCase(),
        orElse: () => Role.getAllRoles().first,
      );
      return Role.getTeamColor(role.team);
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getRoleDescription(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'doctor':
        return 'Heal players during the night to save them from elimination';
      case 'sheriff':
        return 'Investigate players to discover their allegiance';
      case 'escort':
        return 'Block a player\'s action for the night';
      case 'peeper':
        return 'Peek at other players\' roles during the night';
      case 'gunslinger':
        return 'Shoot and eliminate a player during the day';
      case 'gunman':
        return 'Work with outlaws to eliminate townspeople';
      case 'chieftain':
        return 'Lead your team to victory with special abilities';
      case 'jester':
        return 'Get yourself eliminated to win the game';
      default:
        return 'A mysterious role with unknown abilities';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  width: 350,
                  height: 450,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(widget.roleName),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        width: double.infinity,
                        child: const Text(
                          'Your Role',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Role Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _getRoleColor(widget.roleName),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(
                                widget.roleName,
                              ).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getRoleIcon(widget.roleName),
                          size: 60,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Role Name
                      Text(
                        widget.roleName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(widget.roleName),
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Role Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          _getRoleDescription(widget.roleName),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Instruction
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tap to continue or wait 5 seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
