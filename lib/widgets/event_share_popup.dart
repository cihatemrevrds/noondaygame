import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/role_icons.dart';

class EventSharePopup extends StatefulWidget {
  final String eventDescription;
  final String playerName;
  final String? playerRole;
  final bool isDeath;
  final VoidCallback onComplete;

  const EventSharePopup({
    super.key,
    required this.eventDescription,
    required this.playerName,
    this.playerRole,
    this.isDeath = false,
    required this.onComplete,
  });

  @override
  State<EventSharePopup> createState() => _EventSharePopupState();
}

class _EventSharePopupState extends State<EventSharePopup>
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

  Color _getEventColor() {
    if (widget.isDeath) {
      return const Color(0xFFF44336); // Red for death events
    }
    return const Color(0xFF2196F3); // Blue for other events
  }

  @override
  Widget build(BuildContext context) {
    final eventColor = _getEventColor();

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
                    width: 350,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: eventColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Event Title
                        Text(
                          widget.isDeath ? 'DEATH EVENT' : 'NIGHT EVENT',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: eventColor,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Player Avatar/Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: eventColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: eventColor.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: widget.playerRole != null
                              ? RoleIcons.buildRoleIcon(
                                  roleName: widget.playerRole!,
                                  size: 80,
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Player Name
                        Text(
                          widget.playerName,
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: eventColor,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (widget.playerRole != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.playerRole!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Event Description
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: eventColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: eventColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            widget.eventDescription,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
