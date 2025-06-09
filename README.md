# 🌵 Noonday: A Western Social Deduction Game

**Noonday** is a real-time, multiplayer social deduction game set in a mysterious Western town. Players take on secret roles and must use logic, deception, and discussion to survive and win. The game is inspired by classics like *Werewolf* and *Town of Salem*, but reimagined with a Western theme and modern mobile experience.

---

## 🎯 Objective

The goal of the game depends on your team:

- **Town Team** must identify and eliminate all Bandits.
- **Bandit Team** must secretly kill or outvote the Town.
- **Neutral roles** have their own personal win conditions.

Survive each night, use your role's abilities wisely, and try to deceive or deduce your enemies through strategic discussion and voting.

---

## 🧑‍🤝‍🧑 Roles

### 🟦 Town Team
- **Sheriff**: Investigates players at night to determine if they're suspicious or innocent
- **Doctor**: Protects one player each night from being killed (can self-protect once)
- **Escort**: Blocks another player from using their night ability
- **Peeper**: Watches a player at night and sees who visits them
- **Gunslinger**: Has 1 bullet to shoot during night phase (identity revealed when used)

### 🔴 Bandit Team  
- **Gunman**: Kills one player each night (follows Chieftain's orders)
- **Chieftain**: Issues kill orders to Gunmen, appears innocent to Sheriff

### 🟪 Neutral Team
- **Jester**: Wins if voted out by the town during day phase

Each role has unique abilities that create strategic depth and exciting gameplay dynamics.

---

## 🎮 Game Phases

Noonday features a sophisticated **7-phase game loop**:

1. **Role Reveal** - Players learn their secret roles
2. **Night Phase** - Players with night abilities take actions
3. **Night Outcome** - Private results of night actions
4. **Event Sharing** - Public announcements of what occurred
5. **Discussion** - Strategic conversation and information sharing
6. **Voting** - Democratic elimination of suspected enemies
7. **Vote Results** - Outcome of the elimination vote

The game continues cycling through these phases until one team achieves victory.

---

## 🌐 Multiplayer

- **Player Range**: 4-20 players per game
- **Real-time synchronization** with Firebase backend
- **Automatic role balancing** recommendations based on player count
- **Host controls** for custom game pacing and settings

---

## 🔧 Technical Features

### Frontend (Flutter)
- **Cross-platform**: iOS, Android, and Web support
- **Real-time UI**: Live game state synchronization
- **Dark Western Theme**: Immersive visual design with period-appropriate styling
- **Responsive Design**: Optimized for mobile-first experience

### Backend (Firebase)
- **Cloud Functions**: Node.js-based game logic processing
- **Firestore Database**: Real-time multiplayer data synchronization  
- **Authentication**: Secure user management
- **Scalable Architecture**: Handles multiple concurrent games

### Advanced Game Systems
- **Private/Public Events**: Sophisticated information revelation system
- **Role-specific Actions**: Night abilities with blocking and protection mechanics
- **Win Condition Detection**: Automatic game termination when victory is achieved
- **Phase Timing Management**: Server-controlled phase durations with client synchronization

---

## 📱 Platform

Noonday is developed as a **mobile-first experience** using:
- **Flutter** for cross-platform UI
- **Firebase** for backend services
- **Node.js** for game logic
- **TypeScript/Dart** for type-safe development

---

## 🎲 Game Balance

The game includes **intelligent role balancing**:
- Recommended role configurations for each player count
- Win condition validation to prevent immediate game endings
- Team distribution analysis for fair gameplay
- Customizable role selection with host override capabilities

---

## 👥 Inspiration

Noonday combines the best elements of:
- **Werewolf/Mafia** - Classic social deduction mechanics
- **Town of Salem** - Role variety and complexity
- **Among Us** - Real-time multiplayer engagement

But enhanced with:
- **Rich Western atmosphere** and thematic immersion
- **Modern mobile UX** with intuitive touch interfaces  
- **Advanced role interactions** and strategic depth
- **Real-time synchronization** for seamless multiplayer experience

---

## 🚀 Current Status

**Production Ready Features:**
- ✅ Complete 7-phase game loop
- ✅ All 8 roles fully implemented with night actions
- ✅ Real-time multiplayer synchronization
- ✅ Host lobby management and game controls
- ✅ Private/public event system
- ✅ Win condition detection and game termination
- ✅ Cross-platform mobile and web deployment

The game is **feature-complete** and ready for multiplayer testing and deployment.

---

## 🎯 Getting Started

1. **Create or Join Lobby** - Host creates a game room, players join with lobby code
2. **Role Configuration** - Host selects roles (manual or recommended auto-balance)
3. **Game Launch** - Roles are secretly assigned, game begins
4. **Strategic Gameplay** - Use your role's abilities and social deduction skills
5. **Victory** - First team to eliminate their enemies wins!

---

**Stay sharp, partner. In Noonday, everyone's got secrets... and not everyone's making it out alive.** 🤠

