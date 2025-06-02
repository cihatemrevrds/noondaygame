const admin = require('firebase-admin');
const db = admin.firestore();

// Helper function to calculate day information phase time based on events
function calculateDayInfoTime(nightEvents) {
    const baseTime = 5000; // 5 seconds base time
    const eventTime = 5000; // 5 seconds per event
    return baseTime + (nightEvents.length * eventTime);
}

// Start the game
exports.startGame = async (req, res) => {
    // CORS headers ekle
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    // OPTIONS request için
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, hostId } = req.body;

        if (!lobbyCode || !hostId) {
            return res.status(400).json({ error: 'Missing lobbyCode or hostId' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        if (lobbyData.hostUid !== hostId) {
            return res.status(403).json({ error: 'Only the host can start the game' });
        }

        const players = lobbyData.players || [];
        const roleSettings = lobbyData.roles || {};

        let rolesPool = [];
        for (const [role, count] of Object.entries(roleSettings)) {
            rolesPool.push(...Array(count).fill(role));
        }

        if (rolesPool.length !== players.length) {
            return res
                .status(400)
                .json({ error: "Player count doesn't match total roles" });
        }

        rolesPool = rolesPool.sort(() => Math.random() - 0.5);

        const updatedPlayers = players.map((player, index) => ({
            ...player,
            role: rolesPool[index],
        }));        // Initialize all players as alive
        const initializedPlayers = updatedPlayers.map(player => ({
            ...player,
            isAlive: true,
            eliminatedBy: null,
            killedBy: null
        }));

        await lobbyRef.update({
            players: initializedPlayers,
            status: 'started',
            phase: 'night',
            dayCount: 1,
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            startedAt: admin.firestore.FieldValue.serverTimestamp(), gameState: 'role_reveal', // Players see their roles first
            phaseTimeLimit: 10000, // 10 seconds for role reveal
            votes: {},
            roleData: {},
            nightEvents: [],
            lastDayResult: null
        });

        return res.status(200).json({ message: 'Game started successfully' });
    } catch (error) {
        console.error('startGame error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Advance the game phase from day to night or night to day
exports.advancePhase = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, hostId } = req.body;

        if (!lobbyCode || !hostId) {
            return res.status(400).json({ error: "Missing lobbyCode or hostId" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || []; if (lobbyData.hostUid !== hostId) {
            return res.status(403).json({ error: "Only host can advance the phase" });
        }

        const currentPhase = lobbyData.phase || "night";
        const currentGameState = lobbyData.gameState || "role_reveal";
        const dayCount = lobbyData.dayCount || 1;

        let updateData = {};

        // Handle different game states
        if (currentGameState === 'role_reveal') {
            // Move from role reveal to night phase
            updateData = {
                gameState: 'night_actions',
                phaseTimeLimit: 30000, // 30 seconds for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'night_actions') {
            // Process night actions and move to day phase
            updateData = await processNightActions(lobbyData, players);
            updateData.phase = 'day';
            updateData.gameState = 'day_information';
            updateData.phaseTimeLimit = calculateDayInfoTime(updateData.nightEvents || []); // Dynamic timing based on events
            updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
            updateData.votes = {}; // Clear previous votes
        } else if (currentGameState === 'day_information') {
            // Move to discussion phase
            updateData = {
                gameState: 'day_discussion',
                phaseTimeLimit: 120000, // 2 minutes for discussion
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'day_discussion') {
            // Move to voting phase
            updateData = {
                gameState: 'day_voting',
                phaseTimeLimit: 30000, // 30 seconds for voting                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'day_voting') {
            // Process votes and show results for 5 seconds
            const eliminatedPlayer = await processVotes(lobbyData, players);

            updateData = {
                gameState: 'day_voting_result',
                phaseTimeLimit: 5000, // 5 seconds to show voting results
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastDayResult: eliminatedPlayer
            };

            // If someone was eliminated, update players
            if (eliminatedPlayer) {
                const updatedPlayers = players.map(p => {
                    if (p.id === eliminatedPlayer.id) {
                        return { ...p, isAlive: false, eliminatedBy: 'vote' };
                    }
                    return p;
                });
                updateData.players = updatedPlayers;
            }
        } else if (currentGameState === 'day_voting_result') {
            // Move from voting results to night
            updateData = {
                phase: 'night',
                gameState: 'night_actions',
                dayCount: dayCount + 1,
                phaseTimeLimit: 30000, // 30 seconds for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                votes: {}
            };
        }

        await lobbyRef.update(updateData);

        return res.status(200).json({
            message: "Phase updated",
            gameState: updateData.gameState,
            phase: updateData.phase || currentPhase,
            dayCount: updateData.dayCount || dayCount
        });
    } catch (error) {
        console.error("advancePhase error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};

// Auto advance phase when time expires
exports.autoAdvancePhase = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode } = req.body;

        if (!lobbyCode) {
            return res.status(400).json({ error: "Missing lobbyCode" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();
        const phaseStartedAt = lobbyData.phaseStartedAt?.toDate();
        const phaseTimeLimit = lobbyData.phaseTimeLimit || 60000;
        const now = new Date();

        // Check if phase time has expired
        if (phaseStartedAt && (now - phaseStartedAt) >= phaseTimeLimit) {
            // Auto advance to next phase
            return await advanceToNextPhase(lobbyData, lobbyRef);
        }

        return res.status(200).json({ message: "Phase time not expired yet" });
    } catch (error) {
        console.error("autoAdvancePhase error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};

// Get current game state information
exports.getGameState = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode } = req.query;

        if (!lobbyCode) {
            return res.status(400).json({ error: "Missing lobbyCode" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();
        const phaseStartedAt = lobbyData.phaseStartedAt?.toDate();
        const phaseTimeLimit = lobbyData.phaseTimeLimit || 60000;
        const now = new Date();
        const timeRemaining = Math.max(0, phaseTimeLimit - (now - phaseStartedAt));

        return res.status(200).json({
            phase: lobbyData.phase,
            gameState: lobbyData.gameState,
            dayCount: lobbyData.dayCount,
            timeRemaining: timeRemaining,
            nightEvents: lobbyData.nightEvents || [],
            lastDayResult: lobbyData.lastDayResult,
            players: lobbyData.players || [],
            votes: lobbyData.votes || {}
        });
    } catch (error) {
        console.error("getGameState error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};

// Get role information for display
exports.getRoleInfo = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { roleName } = req.query; const roleDescriptions = {
            'Doctor': 'You can protect one player each night from being killed. You can only self-protect once per game. Town team.',
            'Sheriff': 'You investigate players at night to determine if they are suspicious or innocent. Chieftain appears innocent despite being a Bandit. Town team.',
            'Escort': 'You block another player from using their night ability. Target\'s role action won\'t be processed that night. Town team.',
            'Peeper': 'You watch a player at night and see who visits them. You don\'t learn the roles of visitors, just that they visited. Town team.',
            'Gunslinger': 'You can kill a player during any phase (day or night). You have 2 bullets total. If you kill a Town member, you lose your second bullet. Town team.',
            'Gunman': 'You can kill one player each night. Your target can be overridden by Chieftain\'s orders. Bandit team.',
            'Chieftain': 'You issue kill orders to Gunman, overriding their choice. You appear innocent to Sheriff investigations. If no Gunman remains, you take over killing. Bandit team.',
            'Jester': 'You have no night ability. You win if voted out by the town during day phase. Neutral team.'
        };

        if (roleName && roleDescriptions[roleName]) {
            return res.status(200).json({
                role: roleName,
                description: roleDescriptions[roleName]
            });
        }

        // Return all role descriptions if no specific role requested
        return res.status(200).json({ roles: roleDescriptions });
    } catch (error) {
        console.error('getRoleInfo error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Helper function to advance to next phase (used by both manual and auto advance)
async function advanceToNextPhase(lobbyData, lobbyRef) {
    const players = lobbyData.players || [];
    const currentPhase = lobbyData.phase || "night";
    const currentGameState = lobbyData.gameState || "role_reveal";
    const dayCount = lobbyData.dayCount || 1;

    let updateData = {};

    // Handle different game states
    if (currentGameState === 'role_reveal') {
        // Move from role reveal to night phase
        updateData = {
            gameState: 'night_actions',
            phaseTimeLimit: 30000, // 30 seconds for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'night_actions') {
        // Process night actions and move to day phase
        updateData = await processNightActions(lobbyData, players);
        updateData.phase = 'day';
        updateData.gameState = 'day_information';
        updateData.phaseTimeLimit = calculateDayInfoTime(updateData.nightEvents || []); // Dynamic timing based on events
        updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
        updateData.votes = {}; // Clear previous votes
    } else if (currentGameState === 'day_information') {
        // Move to discussion phase
        updateData = {
            gameState: 'day_discussion',
            phaseTimeLimit: 120000, // 2 minutes for discussion
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'day_discussion') {
        // Move to voting phase
        updateData = {
            gameState: 'day_voting',
            phaseTimeLimit: 30000, // 30 seconds for voting
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'day_voting') {
        // Process votes and show results for 5 seconds
        const eliminatedPlayer = await processVotes(lobbyData, players);

        updateData = {
            gameState: 'day_voting_result',
            phaseTimeLimit: 5000, // 5 seconds to show voting results
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastDayResult: eliminatedPlayer
        };

        // If someone was eliminated, update players
        if (eliminatedPlayer) {
            const updatedPlayers = players.map(p => {
                if (p.id === eliminatedPlayer.id) {
                    return { ...p, isAlive: false, eliminatedBy: 'vote' };
                }
                return p;
            });
            updateData.players = updatedPlayers;
        }
    } else if (currentGameState === 'day_voting_result') {
        // Move from voting results to night
        updateData = {
            phase: 'night',
            gameState: 'night_actions',
            dayCount: dayCount + 1,
            phaseTimeLimit: 30000, // 30 seconds for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            votes: {}
        };
    }

    await lobbyRef.update(updateData);
    return {
        message: "Phase advanced automatically",
        gameState: updateData.gameState,
        phase: updateData.phase || currentPhase,
        dayCount: updateData.dayCount || dayCount
    };
}

// Helper function to process night actions
async function processNightActions(lobbyData, players) {
    let roleDataUpdate = { ...lobbyData.roleData } || {};
    let updatedPlayers = [...players];
    let nightEvents = [];    // First check who is blocked by Escort
    const blockedPlayerId = roleDataUpdate.escort?.blockedId || null;

    // Process night kills from Gunman if not blocked
    if (roleDataUpdate.gunman && roleDataUpdate.gunman.targetId) {
        const gunmanId = players.find(p => p.role === 'Gunman' && p.isAlive)?.id;
        const isGunmanBlocked = gunmanId && gunmanId === blockedPlayerId;

        if (!isGunmanBlocked) {
            const targetId = roleDataUpdate.gunman.targetId;
            const targetIndex = updatedPlayers.findIndex(p => p.id === targetId);

            if (targetIndex !== -1) {
                const targetPlayer = updatedPlayers[targetIndex];

                // Check if target is protected by doctor (if doctor is not blocked)
                const doctorId = players.find(p => p.role === 'Doctor' && p.isAlive)?.id;
                const isDoctorBlocked = doctorId && doctorId === blockedPlayerId;
                const isProtected = !isDoctorBlocked &&
                    roleDataUpdate.doctor &&
                    roleDataUpdate.doctor.protectedId === targetId;

                // Kill the target if they're not protected
                if (!isProtected) {
                    updatedPlayers[targetIndex] = {
                        ...targetPlayer,
                        isAlive: false,
                        killedBy: 'Gunman'
                    };
                    nightEvents.push(`${targetPlayer.name} was killed by the Gunman.`);
                } else {
                    nightEvents.push(`Someone was attacked but saved by the Doctor!`);
                }
            }
        } else {
            nightEvents.push(`The Gunman was blocked and could not act.`);
        }
    }

    // Preserve doctor's self-protection usage and other investigation results
    roleDataUpdate = {
        gunman: { targetId: null },
        doctor: {
            protectedId: null,
            selfProtectionUsed: roleDataUpdate.doctor?.selfProtectionUsed || false
        },
        escort: { blockedId: null },
        sheriff: {
            targetId: null,
            result: roleDataUpdate.sheriff?.result || null // Keep last investigation result 
        },
        peeper: {
            targetId: null,
            result: roleDataUpdate.peeper?.result || null // Keep last spy result
        }
    }; return {
        players: updatedPlayers,
        roleData: roleDataUpdate,
        nightEvents: nightEvents
    };
}

// Helper function to process votes
async function processVotes(lobbyData, players) {
    const votes = lobbyData.votes || {};
    const alivePlayers = players.filter(p => p.isAlive);
    const totalVotes = alivePlayers.length;
    const requiredVotes = Math.ceil(totalVotes / 2); // Majority needed

    // Count votes
    const voteCounts = {};
    Object.values(votes).forEach(targetId => {
        voteCounts[targetId] = (voteCounts[targetId] || 0) + 1;
    });

    // Find the player with the most votes
    let maxVotes = 0;
    let eliminatedId = null;

    for (const [targetId, count] of Object.entries(voteCounts)) {
        if (count > maxVotes && count >= requiredVotes) {
            maxVotes = count;
            eliminatedId = targetId;
        } else if (count === maxVotes) {
            eliminatedId = null; // Tie, no one is eliminated
        }
    }

    if (eliminatedId) {
        const eliminatedPlayer = players.find(p => p.id === eliminatedId);
        return eliminatedPlayer;
    }

    return null;
}
