import 'package:flutter/material.dart';
import 'dart:async';
import '../models/player.dart';
import '../utils/role_icons.dart';
import '../services/game_state_manager.dart';

class VictoryScreenWidget extends StatefulWidget {
  final Map<String, dynamic> winCondition;
  final List<Player> finalPlayers;
  final String currentUserId;
  final bool isHost;
  final String lobbyCode;

  const VictoryScreenWidget({
    super.key,
    required this.winCondition,
    required this.finalPlayers,
    required this.currentUserId,
    required this.isHost,
    required this.lobbyCode,
  });

  @override
  State<VictoryScreenWidget> createState() => _VictoryScreenWidgetState();
}

class _VictoryScreenWidgetState extends State<VictoryScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.bounceOut),
    );    // Start animations with slight delays
    _fadeController.forward();
    Timer(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
    Timer(const Duration(milliseconds: 400), () {
      _slideController.forward();
    });

    // Don't auto-close - let host manually end the game
  }
  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _endGame() async {
    final gameStateManager = GameStateManager();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game?'),
        content: const Text('This will end the game for all players.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await gameStateManager.endGame(
                widget.lobbyCode,
                widget.isHost,
                (message) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                },
              );
            },
            child: const Text('END GAME'),
          ),
        ],
      ),
    );
  }

  Color _getWinnerColor(String winner) {
    switch (winner) {
      case 'Town':
        return const Color(0xFF2E7D32); // Green for Town
      case 'Bandit':
        return const Color(0xFFC62828); // Red for Bandits
      case 'Jester':
        return const Color(0xFF616161); // Gray for Jester
      default:
        return const Color(0xFF424242); // Default gray
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      // Citizens (Green shades)
      case 'Doctor':
        return const Color(0xFF2E7D32);
      case 'Sheriff':
        return const Color(0xFF388E3C);
      case 'Escort':
        return const Color(0xFF43A047);
      case 'Peeper':
        return const Color(0xFF4CAF50);
      case 'Gunslinger':
        return const Color(0xFF66BB6A);
      // Bandits (Red shades)
      case 'Gunman':
        return const Color(0xFFC62828);
      case 'Chieftain':
        return const Color(0xFFD32F2F);
      // Neutrals (Gray shades)
      case 'Jester':
        return const Color(0xFF616161);
      default:
        return const Color(0xFF424242);
    }
  }

  String _getWinMessage() {
    final winner = widget.winCondition['winner'] as String? ?? 'Unknown';
    final winType = widget.winCondition['winType'] as String? ?? '';
    final gameOver = widget.winCondition['gameOver'] as bool? ?? false;

    if (!gameOver) {
      return 'Game ended unexpectedly';
    }

    switch (winner) {
      case 'Town':
        return 'The Town has triumphed!\nAll bandits have been eliminated.';
      case 'Bandit':
        return 'The Bandits have taken over!\nThe town has fallen to the outlaws.';
      case 'Jester':
        if (winType == 'jester_vote_out') {
          return 'The Jester wins!\nChaos reigns as the fool gets the last laugh.';
        }
        return 'The Jester has won!';
      default:
        if (winner.isNotEmpty) {
          return '$winner has won!\nVictory through survival and cunning.';
        }
        return 'Game Over';
    }
  }

  String _getWinIcon() {
    final winner = widget.winCondition['winner'] as String? ?? 'Unknown';
    
    switch (winner) {
      case 'Town':
        return '🏛️'; // Town hall/government building
      case 'Bandit':
        return '🔫'; // Gun for bandits
      case 'Jester':
        return '🃏'; // Playing card joker
      default:
        return '🏆'; // Trophy for generic win
    }
  }

  List<Player> _getAlivePlayers() {
    return widget.finalPlayers.where((p) => p.isAlive).toList();
  }

  List<Player> _getDeadPlayers() {
    return widget.finalPlayers.where((p) => !p.isAlive).toList();
  }

  bool _didCurrentPlayerWin() {
    final winner = widget.winCondition['winner'] as String? ?? '';
    final currentPlayer = widget.finalPlayers.firstWhere(
      (p) => p.id == widget.currentUserId,
      orElse: () => Player(name: 'Unknown'),
    );

    if (currentPlayer.role == null) return false;

    switch (winner) {
      case 'Town':
        return ['Doctor', 'Sheriff', 'Escort', 'Peeper', 'Gunslinger']
            .contains(currentPlayer.role);
      case 'Bandit':
        return ['Gunman', 'Chieftain'].contains(currentPlayer.role);
      case 'Jester':
        return currentPlayer.role == 'Jester';
      default:
        // For role-specific wins (like neutral roles)
        return currentPlayer.role == winner;
    }
  }

  @override
  Widget build(BuildContext context) {
    final winnerColor = _getWinnerColor(widget.winCondition['winner'] as String? ?? '');
    final didWin = _didCurrentPlayerWin();
    final alivePlayers = _getAlivePlayers();
    final deadPlayers = _getDeadPlayers();

    return Material(
      color: Colors.black87,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.9,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2B1810).withOpacity(0.95),
                        const Color(0xFF1A0F08).withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: winnerColor.withOpacity(0.7),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: winnerColor.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Victory Header with animation
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              // Win Icon
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: winnerColor.withOpacity(0.2),
                                  border: Border.all(color: winnerColor, width: 3),
                                ),
                                child: Text(
                                  _getWinIcon(),
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Victory/Defeat Title
                              Text(
                                didWin ? 'VICTORY!' : 'DEFEAT',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: didWin ? Colors.orange : Colors.red.shade300,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.8),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Win Message
                              Text(
                                _getWinMessage(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 18,
                                  color: Colors.orange,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Game Statistics
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'FINAL STANDINGS',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 20,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Survivors Section
                              if (alivePlayers.isNotEmpty) ...[
                                Text(
                                  'SURVIVORS (${alivePlayers.length})',
                                  style: const TextStyle(
                                    fontFamily: 'Rye',
                                    fontSize: 16,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...alivePlayers.map((player) => _buildPlayerTile(player, true)),
                                const SizedBox(height: 16),
                              ],
                              
                              // Casualties Section
                              if (deadPlayers.isNotEmpty) ...[
                                Text(
                                  'CASUALTIES (${deadPlayers.length})',
                                  style: TextStyle(
                                    fontFamily: 'Rye',
                                    fontSize: 16,
                                    color: Colors.red.shade300,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...deadPlayers.map((player) => _buildPlayerTile(player, false)),
                              ],
                            ],
                          ),
                        ),                        const SizedBox(height: 24),
                        
                        // End Game Button (Host Only)
                        if (widget.isHost)
                          Center(
                            child: ElevatedButton(
                              onPressed: _endGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                              ),
                              child: const Text(
                                'END GAME',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerTile(Player player, bool isAlive) {
    final roleColor = _getRoleColor(player.role ?? '');
    final isCurrentPlayer = player.id == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? Colors.orange.withOpacity(0.2) 
            : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer 
              ? Colors.orange.withOpacity(0.6)
              : roleColor.withOpacity(0.5),
          width: isCurrentPlayer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Role Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: roleColor, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: RoleIcons.buildRoleIcon(
                roleName: player.role ?? '',
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 14,
                        color: isCurrentPlayer ? Colors.orange : Colors.white,
                        fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isCurrentPlayer) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(YOU)',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 12,
                          color: Colors.orange.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  player.role ?? 'Unknown',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 12,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isAlive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isAlive ? Colors.green : Colors.red.shade300,
                width: 1,
              ),
            ),
            child: Text(
              isAlive ? 'ALIVE' : 'DEAD',
              style: TextStyle(
                fontFamily: 'Rye',
                fontSize: 10,
                color: isAlive ? Colors.green : Colors.red.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
