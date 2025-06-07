import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/role_icons.dart';
import '../config/message_config.dart';

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
      // Citizens (Green shades)
      case 'Doctor':
        return const Color(0xFF2E7D32); // Dark Green
      case 'Sheriff':
        return const Color(0xFF388E3C); // Medium Green
      case 'Escort':
        return const Color(0xFF43A047); // Light Green
      case 'Peeper':
        return const Color(0xFF4CAF50); // Standard Green
      case 'Gunslinger':
        return const Color(0xFF66BB6A); // Lighter Green
      // Bandits (Red shades)
      case 'Gunman':
        return const Color(0xFFC62828); // Dark Red
      case 'Chieftain':
        return const Color(0xFFD32F2F); // Medium Red
      // Neutrals (Gray shades)
      case 'Jester':
        return const Color(0xFF616161); // Medium Gray
      default:
        return const Color(0xFF424242); // Dark Grey
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Doctor':
        return 'You can protect one person each night from being eliminated. You can protect yourself for once.';
      case 'Sheriff':
        return 'Each night, you can investigate a player to learn their team allegiance.';
      case 'Escort':
        return 'Each night, you can block a player from using their night action.';
      case 'Peeper':
        return 'Each night, you can spy on a player house to see who visited them.';      case 'Gunslinger':
        return 'You have 1 bullet. Each night, you can select a target to shoot. When you shoot, your identity is revealed.';
      case 'Gunman':
        return 'Each night, you can eliminate one player.';
      case 'Chieftain':
        return 'You are the leader of the outlaws. The Sheriff sees you as innocent.';
      case 'Jester':
        return 'Your goal is to be eliminated by the town. If successful, you win!';
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
        color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2B1810), Color(0xFF1A0F08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: roleColor.withOpacity(0.2),
                            border: Border.all(color: roleColor, width: 2),
                          ),
                          child: RoleIcons.buildRoleIcon(
                            roleName: widget.roleName,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // "Your Role" title
                        Text(
                          MessageConfig.getPopupTitle('role_reveal'),
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Role Name
                        Text(
                          widget.roleName,
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 24,
                            color: roleColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Role Description
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            roleDescription,
                            style: const TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Manual close button
                        ElevatedButton(
                          onPressed: _closePopup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4513),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
