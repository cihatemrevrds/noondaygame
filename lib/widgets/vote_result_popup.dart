import 'package:flutter/material.dart';
import 'dart:async';

class VoteResultPopup extends StatefulWidget {
  final String playerName;
  final String? playerRole;
  final int voteCount;
  final VoidCallback onComplete;

  const VoteResultPopup({
    super.key,
    required this.playerName,
    this.playerRole,
    required this.voteCount,
    required this.onComplete,
  });

  @override
  State<VoteResultPopup> createState() => _VoteResultPopupState();
}

class _VoteResultPopupState extends State<VoteResultPopup>
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.bounceOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animations
    _scaleController.forward();
    _fadeController.forward();

    // Auto-close after 5 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 5), _closePopup);
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _closePopup() {
    _autoCloseTimer?.cancel();
    widget.onComplete();
  }

  Color _getRoleColor(String? role) {
    if (role == null) return const Color(0xFF424242);
    
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

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(widget.playerRole);

    return Material(
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
                      // Gallows icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withOpacity(0.2),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Icon(
                          Icons.gavel,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      const Text(
                        'Vote Result',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Vote result content
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
                        child: Column(
                          children: [
                            // Player name with role color
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                children: [
                                  const TextSpan(text: 'The town has voted to hang '),
                                  TextSpan(
                                    text: widget.playerName,
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: '!'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Vote count
                            Text(
                              'Votes received: ${widget.voteCount}',
                              style: const TextStyle(
                                fontFamily: 'Rye',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // Role reveal if available
                            if (widget.playerRole != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${widget.playerName} was a ${widget.playerRole}',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 14,
                                  color: roleColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
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
    );
  }
}
