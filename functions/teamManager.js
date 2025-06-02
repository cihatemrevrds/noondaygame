const admin = require('firebase-admin');
const db = admin.firestore();

// Define team structures
const teams = {
    Town: ['Doctor', 'Sheriff', 'Escort', 'Peeper', 'Gunslinger'],
    Bandit: ['Gunman', 'Chieftain'],
    Neutral: ['Jester']
};

// Get the team of a specific role
exports.getTeamByRole = (role) => {
    for (const [team, roles] of Object.entries(teams)) {
        if (roles.includes(role)) {
            return team;
        }
    }
    return null;
};

// Check win conditions for all teams
exports.checkWinConditions = async (req, res) => {
    try {
        const { lobbyCode } = req.body;

        if (!lobbyCode) {
            return res.status(400).json({ error: 'Missing lobbyCode' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];

        // Count alive players by team
        const aliveCount = {
            Town: 0,
            Bandit: 0,
            Neutral: 0,
            Total: 0
        };

        players.forEach(player => {
            if (player.isAlive) {
                aliveCount.Total++;
                const team = exports.getTeamByRole(player.role);
                if (team) {
                    aliveCount[team]++;
                }
            }
        });

        // Check win conditions
        let winningTeam = null;        // Town wins if all bandits are eliminated
        if (aliveCount.Bandit === 0 && aliveCount.Town > 0) {
            winningTeam = 'Town';
        }

        // Bandits win if they equal or outnumber the town
        if (aliveCount.Bandit > 0 && aliveCount.Bandit >= aliveCount.Town) {
            winningTeam = 'Bandit';
        }// Neutral solo win conditions
        const soloNeutralWinner = players.find(p => {
            if (!p.isAlive) return false;

            // Jester wins if voted out during day phase (handled separately in voting logic)
            // No other neutral solo win conditions in this game
            return false;

            // Jester wins if they are eliminated by town vote
            if (p.role === 'Jester' && !p.isAlive && p.killedBy === 'Vote') {
                return true;
            }

            // Executioner wins if their target is eliminated by town vote
            if (p.role === 'Executioner' && p.targetId) {
                const target = players.find(target => target.id === p.targetId);
                if (target && !target.isAlive && target.killedBy === 'Vote') {
                    return true;
                }
            }

            return false;
        });

        if (soloNeutralWinner) {
            winningTeam = soloNeutralWinner.role;
        }

        if (winningTeam) {
            await lobbyRef.update({
                status: 'ended',
                winningTeam: winningTeam,
                endedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            return res.status(200).json({
                message: 'Game ended',
                winningTeam: winningTeam
            });
        }

        return res.status(200).json({
            message: 'Game continues',
            aliveCount
        });
    } catch (error) {
        console.error('checkWinConditions error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};
