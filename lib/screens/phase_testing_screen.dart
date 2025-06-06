import 'package:flutter/material.dart';
import '../widgets/discussion_phase_widget.dart';
import '../widgets/voting_phase_widget.dart';
import '../widgets/role_reveal_popup.dart';
import '../widgets/event_share_popup.dart';
import '../widgets/night_outcome_popup.dart';
import '../widgets/vote_result_popup.dart';
import '../models/player.dart';
import '../config/message_config.dart';

class PhaseTestingScreen extends StatefulWidget {
  const PhaseTestingScreen({super.key});

  @override
  State<PhaseTestingScreen> createState() => _PhaseTestingScreenState();
}

class _PhaseTestingScreenState extends State<PhaseTestingScreen> {
  String _selectedPhase = 'discussion';
  String _selectedRole = 'Sheriff'; // For role reveal testing
  String _selectedEvent = 'kill_success'; // For event sharing testing
  String _selectedPrivateEvent =
      'kill_success_private'; // For night outcome testing
  String _selectedVoteResult = 'gunman_executed'; // For vote result testing

  // Mock data for testing
  final List<Player> _mockPlayers = [
    Player(id: '1', name: 'Sheriff Jack', isLeader: true),
    Player(id: '2', name: 'Doc Smith', isLeader: false),
    Player(id: '3', name: 'Gunman Pete', isLeader: false),
    Player(id: '4', name: 'Doctor Mary', isLeader: false),
    Player(id: '5', name: 'Escort Belle', isLeader: false),
    Player(id: '6', name: 'Peeper Tom', isLeader: false),
    Player(id: '7', name: 'Chieftain Joe', isLeader: false),
    Player(id: '8', name: 'Jester Bob', isLeader: false),
    Player(id: '9', name: 'Gunslinger Kate', isLeader: false),
    Player(id: '10', name: 'Deputy Luke', isLeader: false),
    Player(id: '11', name: 'Medic Sarah', isLeader: false),
    Player(id: '12', name: 'Outlaw Rex', isLeader: false),
    Player(id: '13', name: 'Villager Ann', isLeader: false),
    Player(id: '14', name: 'Bandit Will', isLeader: false),
    Player(id: '15', name: 'Ranger Max', isLeader: false),
    Player(id: '16', name: 'Settler Eva', isLeader: false),
    Player(id: '17', name: 'Marshal Jim', isLeader: false),
    Player(id: '18', name: 'Trader Sam', isLeader: false),
    Player(id: '19', name: 'Prospector Dan', isLeader: false),
    Player(id: '20', name: 'Saloon Owner Lily', isLeader: false),
  ];
  void _showRoleRevealPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => RoleRevealPopup(
            roleName: _selectedRole,
            onComplete: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }

  String _getEventDisplayName(String eventType) {
    switch (eventType) {
      case 'kill_success':
        return 'Player Killed';
      case 'quiet_night':
        return 'Quiet Night';
      default:
        return 'Unknown Event';
    }
  }

  void _showEventSharePopup() {
    String playerName;
    String? playerRole;
    String eventDescription;
    bool isDeath = false;

    switch (_selectedEvent) {
      case 'kill_success':
        playerName = 'Gunman Pete';
        playerRole = null; // Don't reveal role in public events
        // Use MessageConfig for public event messages
        final content = MessageConfig.getPublicEventContent('player_killed');
        eventDescription = MessageConfig.formatMessage(
          content?.message ?? 'A player was killed.',
          {'playerName': playerName},
        );
        isDeath = true;
        break;
      case 'quiet_night':
        playerName = 'No One';
        playerRole = null;
        // Use MessageConfig for quiet night message
        final content = MessageConfig.getPublicEventContent('quiet_night');
        eventDescription = content?.message ?? 'The night was quiet.';
        break;
      default:
        playerName = 'Unknown Player';
        playerRole = null;
        eventDescription = 'Something mysterious happened in the night.';
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => EventSharePopup(
            eventDescription: eventDescription,
            playerName: playerName,
            playerRole: playerRole,
            isDeath: isDeath,
            events: [
              eventDescription,
            ], // Pass event as list for type determination
            onComplete: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }

  String _getPrivateEventDisplayName(String eventType) {
    switch (eventType) {
      case 'kill_success_private':
        return 'Kill Success (Gunman)';
      case 'kill_failed_private':
        return 'Kill Failed (Gunman)';
      case 'investigation_result':
        return 'Investigation Result (Sheriff)';
      case 'protection_result':
        return 'Protection Result (Doctor)';
      case 'protection_successful':
        return 'Successful Save (Doctor)';
      case 'block_result':
        return 'Block Result (Escort)';
      case 'peep_result':
        return 'Peep Result (Peeper)';
      default:
        return 'Unknown Private Event';
    }
  }

  String _getVoteResultDisplayName(String resultType) {
    switch (resultType) {
      case 'gunman_executed':
        return 'Gunman Executed';
      case 'sheriff_executed':
        return 'Sheriff Executed';
      case 'doctor_executed':
        return 'Doctor Executed';
      case 'jester_executed':
        return 'Jester Executed';
      case 'escort_executed':
        return 'Escort Executed';
      case 'chieftain_executed':
        return 'Chieftain Executed';
      case 'no_majority':
        return 'No Majority Vote';
      default:
        return 'Unknown Vote Result';
    }
  }

  void _showNightOutcomePopup() {
    String title;
    String message;

    switch (_selectedPrivateEvent) {
      case 'kill_success_private':
        final content = MessageConfig.getPrivateEventContent('kill_success');
        title = content?.title ?? 'Night Action Result';
        message = MessageConfig.formatMessage(
          content?.message ?? 'You successfully killed {targetName}.',
          {'targetName': 'Gunman Pete'},
        );
        break;
      case 'kill_failed_private':
        final content = MessageConfig.getPrivateEventContent('kill_failed');
        title = content?.title ?? 'Night Action Result';
        message = MessageConfig.formatMessage(
          content?.message ??
              'You tried to kill {targetName}, but they were protected.',
          {'targetName': 'Doc Smith'},
        );
        break;
      case 'investigation_result':
        final content = MessageConfig.getPrivateEventContent(
          'investigation_result',
        );
        title = content?.title ?? 'Investigation Result';
        message = MessageConfig.formatMessage(
          content?.message ??
              'You investigated {targetName}. They appear {result}.',
          {'targetName': 'Gunman Pete', 'result': 'Suspicious'},
        );
        break;
      case 'protection_result':
        final content = MessageConfig.getPrivateEventContent(
          'protection_result',
        );
        title = content?.title ?? 'Protection Result';
        message = MessageConfig.formatMessage(
          content?.message ?? 'You protected {targetName} tonight.',
          {'targetName': 'Doc Smith'},
        );
        break;
      case 'protection_successful':
        final content = MessageConfig.getPrivateEventContent(
          'protection_successful',
        );
        title = content?.title ?? 'Heroic Save!';
        message = MessageConfig.formatMessage(
          content?.message ??
              'You successfully saved {targetName} from an attack!',
          {'targetName': 'Doc Smith'},
        );
        break;
      case 'block_result':
        final content = MessageConfig.getPrivateEventContent('block_result');
        title = content?.title ?? 'Block Result';
        message = MessageConfig.formatMessage(
          content?.message ??
              'You blocked {targetName} from performing their night action.',
          {'targetName': 'Gunman Pete'},
        );
        break;
      case 'peep_result':
        final content = MessageConfig.getPrivateEventContent('peep_result');
        title = content?.title ?? 'Spy Result';
        message = MessageConfig.formatMessage(
          content?.message ?? 'You spied on {targetName}. {visitorsText}',
          {
            'targetName': 'Doc Smith',
            'visitorsText': 'They were visited by: Sheriff Jack.',
          },
        );
        break;
      default:
        title = 'Night Result';
        message = 'Something happened during the night.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NightOutcomePopup(
            title: title,
            message: message,
            onComplete: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _showVoteResultPopup() {
    String playerName;
    String? playerRole;
    int voteCount;

    switch (_selectedVoteResult) {
      case 'gunman_executed':
        playerName = 'Gunman Pete';
        playerRole = 'Gunman';
        voteCount = 7;
        break;
      case 'sheriff_executed':
        playerName = 'Sheriff Jack';
        playerRole = 'Sheriff';
        voteCount = 5;
        break;
      case 'doctor_executed':
        playerName = 'Doc Smith';
        playerRole = 'Doctor';
        voteCount = 6;
        break;
      case 'jester_executed':
        playerName = 'Jester Bob';
        playerRole = 'Jester';
        voteCount = 8;
        break;
      case 'escort_executed':
        playerName = 'Escort Belle';
        playerRole = 'Escort';
        voteCount = 4;
        break;
      case 'chieftain_executed':
        playerName = 'Chieftain Joe';
        playerRole = 'Chieftain';
        voteCount = 9;
        break;
      case 'no_majority':
        playerName = 'No One';
        playerRole = null;
        voteCount = 0;
        break;
      default:
        playerName = 'Unknown Player';
        playerRole = null;
        voteCount = 1;
    }

    if (_selectedVoteResult == 'no_majority') {
      // For no majority, show a different message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => VoteResultPopup(
              playerName: 'No one was executed - no majority vote reached.',
              playerRole: null,
              voteCount: 0,
              onComplete: () {
                Navigator.of(context).pop();
              },
            ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => VoteResultPopup(
              playerName: playerName,
              playerRole: playerRole,
              voteCount: voteCount,
              onComplete: () {
                Navigator.of(context).pop();
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'PHASE TESTING',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/backgrounds/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Phase Selection Row
            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPhaseButton('Role Reveal', 'role_reveal'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Night Phase', 'night'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Night Outcome', 'night_outcome'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Event Sharing', 'event_sharing'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Discussion', 'discussion'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Voting', 'voting'),
                    const SizedBox(width: 8),
                    _buildPhaseButton('Vote Results', 'vote_results'),
                  ],
                ),
              ),
            ),

            // Phase Content
            Expanded(child: _buildPhaseContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseButton(String label, String phase) {
    final isSelected = _selectedPhase == phase;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedPhase = phase),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF8B4513) : Colors.black54,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Rye',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_selectedPhase) {
      case 'discussion':
        return DiscussionPhaseWidget(
          players: _mockPlayers,
          remainingTime: 120, // 2 minutes
          currentUserId: '1',
          myRole: 'Sheriff',
        );
      case 'role_reveal':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ROLE REVEAL PHASE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Role Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
                child: DropdownButton<String>(
                  value: _selectedRole,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  underline: Container(),
                  items:
                      [
                        'Sheriff',
                        'Doctor',
                        'Gunman',
                        'Chieftain',
                        'Jester',
                        'Escort',
                        'Peeper',
                        'Gunslinger',
                      ].map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedRole = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showRoleRevealPopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SHOW ROLE REVEAL',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Role: $_selectedRole',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'night':
        return const Center(
          child: Text(
            'NIGHT PHASE\n(Coming Soon)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'night_outcome':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'NIGHT OUTCOME PHASE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Private Event Type Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
                child: DropdownButton<String>(
                  value: _selectedPrivateEvent,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  underline: Container(),
                  items:
                      [
                        'kill_success_private',
                        'kill_failed_private',
                        'investigation_result',
                        'protection_result',
                        'protection_successful',
                        'block_result',
                        'peep_result',
                      ].map((String event) {
                        return DropdownMenuItem<String>(
                          value: event,
                          child: Text(_getPrivateEventDisplayName(event)),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPrivateEvent = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showNightOutcomePopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SHOW PRIVATE EVENT',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Event: ${_getPrivateEventDisplayName(_selectedPrivateEvent)}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'event_sharing':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'EVENT SHARING PHASE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Event Type Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
                child: DropdownButton<String>(
                  value: _selectedEvent,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  underline: Container(),
                  items:
                      ['kill_success', 'quiet_night'].map((String event) {
                        return DropdownMenuItem<String>(
                          value: event,
                          child: Text(_getEventDisplayName(event)),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedEvent = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showEventSharePopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SHOW EVENT',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Event: ${_getEventDisplayName(_selectedEvent)}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'voting':
        return VotingPhaseWidget(
          players: _mockPlayers,
          remainingTime: 30, // 30 seconds for voting
          currentUserId: '1',
          myRole: 'Sheriff',
          onVoteChanged: (selectedPlayerId) {
            // Handle vote change (could be used for real-time updates)
            print('Vote changed to: $selectedPlayerId');
          },
        );
      case 'vote_results':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'VOTE RESULTS PHASE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Vote Result Scenario Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
                child: DropdownButton<String>(
                  value: _selectedVoteResult,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  underline: Container(),
                  items:
                      [
                        'gunman_executed',
                        'sheriff_executed',
                        'doctor_executed',
                        'jester_executed',
                        'escort_executed',
                        'chieftain_executed',
                        'no_majority',
                      ].map((String result) {
                        return DropdownMenuItem<String>(
                          value: result,
                          child: Text(_getVoteResultDisplayName(result)),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedVoteResult = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showVoteResultPopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SHOW VOTE RESULT',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Result: ${_getVoteResultDisplayName(_selectedVoteResult)}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      default:
        return const Center(
          child: Text(
            'SELECT A PHASE TO TEST',
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }
}
