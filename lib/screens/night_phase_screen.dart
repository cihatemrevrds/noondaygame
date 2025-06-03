import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/role_utils.dart';

class NightPhaseScreen extends StatefulWidget {
  final String lobbyCode;
  final String currentUserId;
  final String? myRole;
  final String? myRoleDesc;
  final String? nightActionResult;
  final List<Player> players;
  final bool isLoading;
  final Function(String, String) onNightAction;
  final Function(String?) onSetNightActionResult;

  const NightPhaseScreen({
    super.key,
    required this.lobbyCode,
    required this.currentUserId,
    required this.myRole,
    required this.myRoleDesc,
    required this.nightActionResult,
    required this.players,
    required this.isLoading,
    required this.onNightAction,
    required this.onSetNightActionResult,
  });

  @override
  State<NightPhaseScreen> createState() => _NightPhaseScreenState();
}

class _NightPhaseScreenState extends State<NightPhaseScreen> {
  Widget _buildNightActionUI() {
    // Rol rengini ve ikonunu belirle
    Color roleColor = RoleUtils.getRoleColor(widget.myRole ?? 'Unknown');
    IconData roleIcon = RoleUtils.getRoleIcon(widget.myRole ?? 'Unknown');

    // Rol aksiyonu adını belirle
    String actionName;
    String actionType;

    switch (widget.myRole) {
      case 'Doctor':
        actionName = 'Koru';
        actionType = 'doctorProtect';
        break;
      case 'Gunman':
        actionName = 'Öldür';
        actionType = 'gunmanKill';
        break;
      case 'Sheriff':
        actionName = 'Araştır';
        actionType = 'sheriffInvestigate';
        break;
      case 'Prostitute':
        actionName = 'Engelle';
        actionType = 'prostituteBlock';
        break;
      case 'Peeper':
        actionName = 'Gözetle';
        actionType = 'peeperSpy';
        break;
      default:
        actionName = 'Aksiyon';
        actionType = '';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst kısım - Rol bilgisi ve ikonu
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Rol ikonu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(roleIcon, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Rol adı
                Text(
                  widget.myRole ?? 'Unknown',
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Rol açıklaması
                Text(
                  widget.myRoleDesc ?? 'Rol açıklaması yükleniyor...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Aksiyon sonucu (varsa)
                if (widget.nightActionResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.nightActionResult!,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),

                // Aksiyon butonları
                RoleUtils.hasNightAction(widget.myRole ?? '')
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pas geç butonu
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ElevatedButton(
                              onPressed:
                                  widget.isLoading
                                      ? null
                                      : () {
                                        // Pas geçme işlemi
                                        widget.onSetNightActionResult(
                                          "Bu gece aksiyon yapmamayı seçtin.",
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[700],
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Pas Geç',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Rol aksiyonu butonu
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ElevatedButton(
                              onPressed:
                                  widget.isLoading
                                      ? null
                                      : () {
                                        // Oyuncu seçim modunu aç
                                        _showPlayerSelectionModal(
                                          actionName,
                                          actionType,
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: roleColor,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                actionName,
                                style: const TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : const Text(
                      'Gece aksiyonu bulunmuyor',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Oyuncu seçim modalını göster
  void _showPlayerSelectionModal(String actionName, String actionType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF2D1B0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RoleUtils.getRoleColor(widget.myRole ?? ''),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      RoleUtils.getRoleIcon(widget.myRole ?? ''),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "$actionName - Oyuncu Seç",
                      style: const TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.players.where((p) => p.isAlive).length,
                  itemBuilder: (context, index) {
                    final player =
                        widget.players.where((p) => p.isAlive).toList()[index];

                    // Rolüne göre bazı oyuncuları hariç tutma
                    bool canTarget = true;

                    switch (widget.myRole) {
                      case 'Gunman':
                      case 'Sheriff':
                      case 'Prostitute':
                      case 'Peeper':
                        canTarget =
                            player.id !=
                            widget.currentUserId; // Kendisi hedeflenemez
                        break;
                    }

                    if (!canTarget) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Card(
                        color: Colors.brown.withValues(alpha: 0.7),
                        elevation: 4,
                        child: InkWell(
                          onTap:
                              widget.isLoading
                                  ? null
                                  : () {
                                    Navigator.pop(context);
                                    widget.onNightAction(actionType, player.id);
                                  },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey[400],
                                  child: Text(
                                    player.name.isNotEmpty
                                        ? player.name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Rye',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white70,
                                  size: 18,
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
              // İptal butonu
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildNightActionUI());
  }
}
