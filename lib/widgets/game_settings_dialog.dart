import 'package:flutter/material.dart';

class GameSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> currentSettings;
  final Function(Map<String, dynamic>) onSettingsUpdated;

  const GameSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSettingsUpdated,
  });

  @override
  State<GameSettingsDialog> createState() => _GameSettingsDialogState();
}

class _GameSettingsDialogState extends State<GameSettingsDialog> {
  late Map<String, dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.currentSettings);
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
    });
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
                    'GAME SETTINGS',
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

            // Settings content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    // Timer Settings Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF654321).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD2691E),
                          width: 2,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Timer Settings',
                            style: TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Voting Time
                    _buildTimerSetting(
                      'Voting Time',
                      'Duration for voting phase',
                      Icons.how_to_vote,
                      _settings['votingTime'] ?? 30,
                      (value) => _updateSetting('votingTime', value),
                    ),

                    // Discussion Time
                    _buildTimerSetting(
                      'Discussion Time',
                      'Duration for discussion phase',
                      Icons.chat,
                      _settings['discussionTime'] ?? 60,
                      (value) => _updateSetting('discussionTime', value),
                    ),

                    // Night Time
                    _buildTimerSetting(
                      'Night Time',
                      'Duration for night phase',
                      Icons.nightlight_round,
                      _settings['nightTime'] ?? 45,
                      (value) => _updateSetting('nightTime', value),
                    ),

                    // Role Action Time
                    _buildTimerSetting(
                      'Role Action Time',
                      'Time limit for role actions',
                      Icons.sports_esports,
                      _settings['roleActionTime'] ?? 30,
                      (value) => _updateSetting('roleActionTime', value),
                    ),

                    const SizedBox(height: 20),

                    // Game Rules Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF654321).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD2691E),
                          width: 2,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.rule, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Game Rules',
                            style: TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Allow killing at first night
                    _buildToggleSetting(
                      'Allow Killing at First Night',
                      'Whether players can be eliminated on the first night',
                      Icons.nightlight_round,
                      _settings['allowFirstNightKill'] ?? false,
                      (value) => _updateSetting('allowFirstNightKill', value),
                    ),

                    // Show vote counts
                    _buildToggleSetting(
                      'Show Vote Counts',
                      'Display the number of votes each player received',
                      Icons.poll,
                      _settings['showVoteCounts'] ?? true,
                      (value) => _updateSetting('showVoteCounts', value),
                    ),

                    // Show who votes whom
                    _buildToggleSetting(
                      'Show Vote Targets',
                      'Reveal who each player voted for',
                      Icons.visibility,
                      _settings['showVoteTargets'] ?? false,
                      (value) => _updateSetting('showVoteTargets', value),
                    ),

                    // Show role when player is dead
                    _buildToggleSetting(
                      'Show Role on Death',
                      'Reveal player\'s role when they are eliminated',
                      Icons.person_off,
                      _settings['showRoleOnDeath'] ?? true,
                      (value) => _updateSetting('showRoleOnDeath', value),
                    ),

                    const SizedBox(height: 20),
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
                    'SAVE SETTINGS',
                    const Color(0xFF228B22), // Forest green
                    () {
                      widget.onSettingsUpdated(_settings);
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

  Widget _buildTimerSetting(
    String title,
    String description,
    IconData icon,
    int currentValue,
    Function(int) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF654321).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD2691E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2691E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD2691E)),
                ),
                child: Icon(icon, color: const Color(0xFFD2691E), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timer controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildTimerButton(
                    Icons.remove,
                    currentValue > 10,
                    () => onChanged((currentValue - 5).clamp(10, 300)),
                  ),
                  Container(
                    width: 60,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Center(
                      child: Text(
                        '${currentValue}s',
                        style: const TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildTimerButton(
                    Icons.add,
                    currentValue < 300,
                    () => onChanged((currentValue + 5).clamp(10, 300)),
                  ),
                ],
              ),

              // Preset buttons
              Row(
                children: [
                  _buildPresetButton('15s', () => onChanged(15)),
                  const SizedBox(width: 4),
                  _buildPresetButton('30s', () => onChanged(30)),
                  const SizedBox(width: 4),
                  _buildPresetButton('60s', () => onChanged(60)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    String description,
    IconData icon,
    bool currentValue,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF654321).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD2691E), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD2691E).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD2691E)),
            ),
            child: Icon(icon, color: const Color(0xFFD2691E), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Toggle switch
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: currentValue,
              onChanged: onChanged,
              activeColor: const Color(0xFFD2691E),
              activeTrackColor: const Color(0xFFD2691E).withOpacity(0.4),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerButton(
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

  Widget _buildPresetButton(String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF654321),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
}
