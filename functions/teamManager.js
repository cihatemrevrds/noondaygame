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

// Helper function to check win conditions synchronously (for use in gamePhase.js)
exports.checkWinConditionsSync = (players, lobbyData) => {
    if (!players || players.length === 0) {
        return { gameOver: false };
    }

    // Check if win conditions are disabled for testing
    const gameSettings = lobbyData.gameSettings || {};
    if (gameSettings.disableWinConditions === true) {
        return { gameOver: false };
    }

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
    let winningTeam = null;
    let gameOver = false;
    let winType = null;

    // Town wins if all bandits are eliminated and there are still town members alive
    if (aliveCount.Bandit === 0 && aliveCount.Town > 0) {
        winningTeam = 'Town';
        gameOver = true;
        winType = 'elimination';
    }

    // Bandits win if they outnumber the town (not equal)
    if (aliveCount.Bandit > 0 && aliveCount.Bandit > aliveCount.Town) {
        winningTeam = 'Bandit';
        gameOver = true;
        winType = 'majority';
    }
    // Special Bandit win condition: If Bandits equal Town AND no Gunslinger alive
    else if (aliveCount.Bandit > 0 && aliveCount.Bandit === aliveCount.Town) {
        // Check if there's a living Gunslinger in Town
        const hasLivingGunslinger = players.some(p => 
            p.isAlive && p.role === 'Gunslinger'
        );
        
        if (!hasLivingGunslinger) {
            winningTeam = 'Bandit';
            gameOver = true;
            winType = 'no_gunslinger_parity';
        }
    }    // Check for Jester win condition - if Jester was voted out
    const jesterWinner = players.find(p => 
        p.role === 'Jester' && 
        !p.isAlive && 
        p.eliminatedBy === 'vote'
    );

    if (jesterWinner) {
        // Jester wins immediately when voted out - no other conditions needed
        winningTeam = 'Jester';
        gameOver = true;
        winType = 'jester_vote_out';
    }

    // Special case: If only neutral players remain alive (last man standing)
    if (!gameOver && aliveCount.Total > 0 && aliveCount.Town === 0 && aliveCount.Bandit === 0) {
        // Find the last remaining neutral player
        const lastNeutral = players.find(p => p.isAlive && exports.getTeamByRole(p.role) === 'Neutral');
        if (lastNeutral && aliveCount.Total === 1) {
            winningTeam = lastNeutral.role;
            gameOver = true;
            winType = 'last_standing';
        }
    }

    // Check for draw condition - if no players are alive
    if (!gameOver && aliveCount.Total === 0) {
        winningTeam = 'Draw';
        gameOver = true;
        winType = 'draw';
    }

    if (gameOver && winningTeam) {
        return {
            gameOver: true,
            winner: winningTeam,
            winType: winType,
            aliveCount: aliveCount,
            finalPlayers: players
        };
    }

    return { gameOver: false };
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

        // Check if win conditions are disabled for testing
        const gameSettings = lobbyData.gameSettings || {};
        if (gameSettings.disableWinConditions === true) {
            return res.status(200).json({
                message: 'Win conditions disabled for testing',
                gameOver: false,
                aliveCount: {}
            });
        }

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
        });        // Check win conditions
        let winningTeam = null;
        let gameOver = false;

        // Town wins if all bandits are eliminated and there are still town members alive
        if (aliveCount.Bandit === 0 && aliveCount.Town > 0) {
            winningTeam = 'Town';
            gameOver = true;
        }        // Bandits win if they outnumber the town (not equal)
        if (aliveCount.Bandit > 0 && aliveCount.Bandit > aliveCount.Town) {
            winningTeam = 'Bandit';
            gameOver = true;
        }
        // Special Bandit win condition: If Bandits equal Town AND no Gunslinger alive
        else if (aliveCount.Bandit > 0 && aliveCount.Bandit === aliveCount.Town) {
            // Check if there's a living Gunslinger in Town
            const hasLivingGunslinger = players.some(p => 
                p.isAlive && p.role === 'Gunslinger'
            );
            
            if (!hasLivingGunslinger) {
                winningTeam = 'Bandit';
                gameOver = true;
            }
        }

        // Check for Jester win condition - if Jester was voted out
        const jesterWinner = players.find(p => 
            p.role === 'Jester' && 
            !p.isAlive && 
            p.eliminatedBy === 'vote'
        );

        if (jesterWinner) {
            // Jester only wins if there were members from all 3 teams when voted out
            // Count how many different teams had alive players when Jester was voted
            let aliveTeamsWhenJesterVoted = 0;
            if (aliveCount.Town > 0) aliveTeamsWhenJesterVoted++;
            if (aliveCount.Bandit > 0) aliveTeamsWhenJesterVoted++;
            if (aliveCount.Neutral > 1) aliveTeamsWhenJesterVoted++; // >1 because Jester is now dead
            
            // Only award Jester win if all 3 teams were represented
            if (aliveTeamsWhenJesterVoted >= 3) {
                winningTeam = 'Jester';
                gameOver = true;
            }
        }        // Special case: If only neutral players remain alive (last man standing)
        if (!gameOver && aliveCount.Total > 0 && aliveCount.Town === 0 && aliveCount.Bandit === 0) {
            // Find the last remaining neutral player
            const lastNeutral = players.find(p => p.isAlive && exports.getTeamByRole(p.role) === 'Neutral');
            if (lastNeutral && aliveCount.Total === 1) {
                winningTeam = lastNeutral.role;
                gameOver = true;
            }
        }

        // Check for draw condition - if no players are alive
        if (!gameOver && aliveCount.Total === 0) {
            winningTeam = 'Draw';
            gameOver = true;
        }if (gameOver && winningTeam) {
            await lobbyRef.update({
                status: 'ended',
                winningTeam: winningTeam,
                endedAt: admin.firestore.FieldValue.serverTimestamp(),
                finalPlayerStates: players, // Store final player states for victory screen
                aliveCount: aliveCount // Store final alive count
            });

            return res.status(200).json({
                message: 'Game ended',
                winningTeam: winningTeam,
                gameOver: true,
                aliveCount: aliveCount,
                finalPlayers: players
            });
        }

        return res.status(200).json({
            message: 'Game continues',
            gameOver: false,
            aliveCount
        });
    } catch (error) {
        console.error('checkWinConditions error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};
