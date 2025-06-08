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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: isMobile ? screenWidth * 0.95 : screenWidth * 0.8,
        height: isMobile ? screenHeight * 0.85 : screenHeight * 0.8,
        constraints: isMobile 
          ? const BoxConstraints(maxWidth: 400, maxHeight: 600)
          : null,
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
                    ), // Voting Time
                    _buildTimerSetting(
                      'Voting Time',
                      'Duration for voting phase',
                      Icons.how_to_vote,
                      _settings['votingTime'] ?? 45,
                      (value) => _updateSetting('votingTime', value),
                      presetValues: [30, 45, 60],
                    ),

                    // Discussion Time
                    _buildTimerSetting(
                      'Discussion Time',
                      'Duration for discussion phase',
                      Icons.chat,
                      _settings['discussionTime'] ?? 90,
                      (value) => _updateSetting('discussionTime', value),
                      presetValues: [90, 120, 150],
                    ), // Night Time
                    _buildTimerSetting(
                      'Night Time',
                      'Duration for night phase',
                      Icons.nightlight_round,
                      _settings['nightTime'] ?? 60,
                      (value) => _updateSetting('nightTime', value),
                      presetValues: [45, 60, 75],
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),            // Action buttons - Mobile responsive layout
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF654321),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),              child: MediaQuery.of(context).size.width < 400
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 60, // Increased height for mobile buttons
                          child: _buildActionButton(
                            'CANCEL',
                            Colors.grey,
                            () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 60, // Increased height for mobile buttons
                          child: _buildActionButton(
                            'SAVE\nSETTINGS', // Two lines for better visibility
                            const Color(0xFF228B22), // Forest green
                            () {
                              widget.onSettingsUpdated(_settings);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    )                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 70, // Increased height for desktop buttons
                            child: _buildActionButton(
                              'CANCEL',
                              Colors.grey,
                              () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 70, // Increased height for desktop buttons
                            child: _buildActionButton(
                              'SAVE\nSETTINGS', // Two lines for better visibility
                              const Color(0xFF228B22), // Forest green
                              () {
                                widget.onSettingsUpdated(_settings);
                                Navigator.of(context).pop();
                              },
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

  Widget _buildTimerSetting(
    String title,
    String description,
    IconData icon,
    int currentValue,
    Function(int) onChanged, {
    List<int>? presetValues,
  }) {
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
          const SizedBox(height: 12),          // Timer controls - Mobile responsive layout
          Column(
            children: [              // Main timer controls - Responsive layout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
              ),const SizedBox(height: 8),
              // Preset buttons row - Use Wrap for mobile responsiveness
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6.0,
                runSpacing: 4.0,
                children: [
                  for (int i = 0; i < (presetValues ?? [15, 30, 60]).length; i++)
                    _buildPresetButton(
                      '${(presetValues ?? [15, 30, 60])[i]}s',
                      () => onChanged((presetValues ?? [15, 30, 60])[i]),
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minWidth: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF654321),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: isMobile ? 60 : 70, // Increased height for better text visibility
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24, 
          vertical: isMobile ? 8 : 12,
        ),
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
        child: Center( // Center the text both horizontally and vertically
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: isMobile ? 12 : 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.1, // Tighter line height for better spacing
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // Allow two lines for "SAVE\nSETTINGS"
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
