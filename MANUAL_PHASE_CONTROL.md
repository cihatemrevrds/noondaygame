# Manual Phase Control Feature Documentation

## Overview
The manual phase control feature allows the game host to manually control phase transitions in a multiplayer Flutter/Firebase game, providing an alternative to automatic timer-based phase progression.

## Implementation Details

### 1. Settings Integration
- **Location**: Game Settings Dialog (`lib/widgets/game_settings_dialog.dart`)
- **UI Component**: Toggle switch with touch_app icon
- **Default Value**: `false` (automatic mode)
- **Storage**: Firebase Firestore under `gameSettings.manualPhaseControl`

### 2. Phase Control Logic
- **File**: `lib/screens/game_screen.dart`
- **Variables**:
  - `_manualPhaseControl`: Boolean flag for control mode
  - `_nightPhaseDuration`, `_eventPhaseDuration`, `_dayPhaseDuration`: Phase durations
  - `_lobbyData`: Current lobby data including night events

### 3. Phase Transitions
**Automatic Mode** (default):
- Night Phase → Event Phase → Day Phase → Night Phase (continuous loop)
- Timer-based transitions using configured durations
- Events shown automatically with 5-second popups

**Manual Mode**:
- Same phase sequence but host-controlled
- No automatic timers activate
- Host sees "Advance to [Next Phase]" button
- Events still display but don't auto-advance

### 4. UI Components

#### Host Controls (Manual Mode Only)
```dart
// Manual advance button with phase-specific text
ElevatedButton(
  onPressed: _manualAdvancePhase,
  child: Text(_getManualAdvanceButtonText()),
)
```

#### Phase-Specific Button Text
- Night Phase: "Advance to Event Phase"
- Event Phase: "Advance to Day Phase" 
- Day Phase: "Advance to Night Phase"

### 5. Event System Integration
- **Night Events**: Fetched from Firebase `nightEvents` field
- **Event Display**: 5-second popups showing game events
- **Manual Control**: Events shown but phase doesn't auto-advance

## Firebase Schema Changes

### Lobby Document Structure
```json
{
  "gameSettings": {
    "votingTime": 30,
    "discussionTime": 60,
    "nightTime": 45,
    "allowFirstNightKill": false,
    "manualPhaseControl": false  // NEW FIELD
  },
  "nightEvents": [
    "Player A was killed by the Gunman.",
    "Someone was attacked but saved by the Doctor!"
  ],
  // ... other lobby fields
}
```

## Key Methods

### Phase Duration Management
```dart
Future<void> _fetchPhaseDurations() async {
  final lobbySettings = await _lobbyService.getLobbySettings(widget.lobbyCode);
  setState(() {
    _nightPhaseDuration = lobbySettings['nightPhaseDuration'] ?? 30;
    _eventPhaseDuration = lobbySettings['eventPhaseDuration'] ?? 5;
    _dayPhaseDuration = lobbySettings['dayPhaseDuration'] ?? 60;
    _manualPhaseControl = lobbySettings['manualPhaseControl'] ?? false;
  });
}
```

### Manual Phase Advancement
```dart
void _manualAdvancePhase() {
  if (!widget.isHost || !_manualPhaseControl) return;
  
  switch (_currentPhase) {
    case 'night':
      setState(() => _currentPhase = 'event');
      _startGameLoop();
      break;
    case 'event':
      setState(() => _currentPhase = 'day');
      _startGameLoop();
      break;
    case 'day':
      setState(() => _currentPhase = 'night');
      _startGameLoop();
      break;
  }
}
```

### Night Events Fetching
```dart
List<String> _fetchNightEvents() {
  if (_lobbyData != null && _lobbyData!.containsKey('nightEvents')) {
    final nightEvents = _lobbyData!['nightEvents'] as List<dynamic>?;
    if (nightEvents != null) {
      return nightEvents.map((event) => event.toString()).toList();
    }
  }
  return [];
}
```

## Usage Flow

### For Host
1. **Setup**: Enable "Manual Phase Control" in game settings
2. **Game Start**: Game begins in night phase
3. **Manual Control**: Use "Advance to [Phase]" button to progress
4. **Event Handling**: View night events before advancing to day phase

### For Players
- **No Change**: Experience identical to automatic mode
- **Synchronization**: All players see phase changes simultaneously
- **Events**: Same event popups and game flow

## Benefits

1. **Flexible Timing**: Host can adjust phase duration based on group needs
2. **Event Processing**: Host can ensure all events are read before advancing
3. **Discussion Control**: Host can extend discussion time as needed
4. **Educational**: Good for teaching new players the game flow
5. **Accessibility**: Accommodates different group paces and preferences

## Testing Status

✅ **Completed**:
- Manual phase control toggle in settings
- Phase duration fetching from Firebase
- Manual advance button implementation
- Night events integration from Firebase
- UI integration and phase-specific content
- Lobby settings persistence

✅ **Verified**:
- Compilation errors resolved
- Flutter app runs successfully
- Lobby creation and cleanup working
- Manual control UI displays correctly

## Files Modified

1. `lib/widgets/game_settings_dialog.dart` - Added manual control toggle
2. `lib/screens/lobby_room_page.dart` - Display manual control setting
3. `lib/services/lobby_service.dart` - Fetch manual control from gameSettings
4. `lib/screens/game_screen.dart` - Complete manual control implementation
5. `lib/screens/day_phase_screen.dart` - Fixed UI overflow issue

## Backward Compatibility

- **Default Behavior**: Automatic mode (existing behavior preserved)
- **Existing Games**: Continue working without changes
- **Settings Migration**: Missing setting defaults to `false`
