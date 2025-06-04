import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/role_icons.dart';

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
    _startAnimations();

    // Auto-close after 5 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      _closePopup();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
  }

  void _closePopup() {
    _autoCloseTimer?.cancel();
    widget.onComplete();
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Doctor':
        return const Color(0xFF4CAF50); // Green
      case 'Sheriff':
        return const Color(0xFF2196F3); // Blue
      case 'Escort':
        return const Color(0xFFE91E63); // Pink
      case 'Peeper':
        return const Color(0xFFFF9800); // Orange
      case 'Gunslinger':
        return const Color(0xFF9C27B0); // Purple
      case 'Gunman':
        return const Color(0xFFF44336); // Red
      case 'Chieftain':
        return const Color(0xFF795548); // Brown
      case 'Jester':
        return const Color(0xFFFFEB3B); // Yellow
      case 'Townsperson':
        return const Color(0xFF607D8B); // Blue Grey
      default:
        return const Color(0xFF424242); // Dark Grey
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Doctor':
        return 'You can protect one person each night from being eliminated. You can protect yourself.';
      case 'Sheriff':
        return 'Each night, you can investigate a player to learn their team allegiance.';
      case 'Escort':
        return 'Each night, you can block a player from using their night action.';
      case 'Peeper':
        return 'Each night, you can spy on a player to learn their exact role.';
      case 'Gunslinger':
        return 'During the day, you can challenge another player to a duel.';
      case 'Gunman':
        return 'Each night, you can eliminate one player. Choose wisely!';
      case 'Chieftain':
        return 'You are the leader of the outlaws. The Sheriff sees you as innocent.';
      case 'Jester':
        return 'Your goal is to be eliminated by the town. If successful, you win!';
      case 'Townsperson':
        return 'You are a member of the town. Use voting to find and eliminate the outlaws.';
      default:
        return 'A mysterious role with unknown abilities.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(widget.roleName);
    final roleDescription = _getRoleDescription(widget.roleName);

    return PopScope(
      canPop: false, // Prevent back button dismissal
      child: Material(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Role Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: roleColor.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: RoleIcons.buildRoleIcon(
                            roleName: widget.roleName,
                            size: 80,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Role Name
                        Text(
                          widget.roleName,
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Role Description
                        Text(
                          roleDescription,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Auto-close countdown hint
                        Text(
                          'Automatically continuing in 5 seconds...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
