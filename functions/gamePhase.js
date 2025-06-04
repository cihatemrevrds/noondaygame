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
        })); await lobbyRef.update({
            players: initializedPlayers, status: 'started',
            phase: 'night',
            dayCount: 1,
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            startedAt: admin.firestore.FieldValue.serverTimestamp(), gameState: 'role_reveal', // Players see their roles first
            phaseTimeLimit: 5000, // 5 seconds for role reveal (non-skippable)
            votes: {},
            roleData: {},
            nightEvents: [],
            nightOutcomes: {}, // Individual results for each player
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

        let updateData = {};        // Handle different game states - 7-phase system
        if (currentGameState === 'role_reveal') {
            // Move from role reveal to night phase
            updateData = {
                gameState: 'night_phase',
                phaseTimeLimit: 30000, // 30 seconds for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'night_phase') {
            // Process night actions and move to night outcome phase
            updateData = await processNightActions(lobbyData, players);
            updateData.gameState = 'night_outcome';
            updateData.phaseTimeLimit = 10000; // 10 seconds for night outcome
            updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
        } else if (currentGameState === 'night_outcome') {
            // Move to event sharing phase
            updateData = {
                phase: 'day',
                gameState: 'event_sharing',
                phaseTimeLimit: calculateDayInfoTime(lobbyData.nightEvents || []), // Dynamic timing based on events
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'event_sharing') {
            // Move to discussion phase
            updateData = {
                gameState: 'discussion_phase',
                phaseTimeLimit: 120000, // 2 minutes for discussion
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'discussion_phase') {
            // Move to voting phase
            updateData = {
                gameState: 'voting_phase',
                phaseTimeLimit: 30000, // 30 seconds for voting
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'voting_phase') {
            // Process votes and show results for 5 seconds
            const eliminatedPlayer = await processVotes(lobbyData, players);

            updateData = {
                gameState: 'voting_outcome',
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
        } else if (currentGameState === 'voting_outcome') {
            // Move from voting results to night
            updateData = {
                phase: 'night',
                gameState: 'night_phase',
                dayCount: dayCount + 1,
                phaseTimeLimit: 30000, // 30 seconds for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                votes: {},
                nightOutcomes: {} // Clear previous night outcomes
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

    let updateData = {};    // Handle different game states
    if (currentGameState === 'role_reveal') {
        // Move from role reveal to night phase
        updateData = {
            gameState: 'night_phase',
            phaseTimeLimit: 30000, // 30 seconds for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'night_phase') {
        // Process night actions and move to night outcome phase
        updateData = await processNightActions(lobbyData, players);
        updateData.gameState = 'night_outcome';
        updateData.phaseTimeLimit = 10000; // 10 seconds for night outcome
        updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (currentGameState === 'night_outcome') {
        // Move to event sharing phase
        updateData = {
            phase: 'day',
            gameState: 'event_sharing',
            phaseTimeLimit: calculateDayInfoTime(lobbyData.nightEvents || []), // Dynamic timing based on events
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'event_sharing') {
        // Move to discussion phase
        updateData = {
            gameState: 'discussion_phase',
            phaseTimeLimit: 120000, // 2 minutes for discussion
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'discussion_phase') {
        // Move to voting phase
        updateData = {
            gameState: 'voting_phase',
            phaseTimeLimit: 30000, // 30 seconds for voting
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'voting_phase') {
        // Process votes and show results for 5 seconds
        const eliminatedPlayer = await processVotes(lobbyData, players);

        updateData = {
            gameState: 'voting_outcome',
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
    } else if (currentGameState === 'voting_outcome') {
        // Move from voting results to night
        updateData = {
            phase: 'night',
            gameState: 'night_phase',
            dayCount: dayCount + 1,
            phaseTimeLimit: 30000, // 30 seconds for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            votes: {},
            nightOutcomes: {} // Clear previous night outcomes
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
    let nightEvents = [];
    let nightOutcomes = {};

    // First check who is blocked by Escort (multiple escorts possible)
    const blockedPlayerIds = [];
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                blockedPlayerIds.push(escortData.blockedId);
            }
        }
    }

    // Process Sheriff investigations (multiple sheriffs possible)
    if (roleDataUpdate.sheriff) {
        for (const [sheriffUid, sheriffData] of Object.entries(roleDataUpdate.sheriff)) {
            if (sheriffData && sheriffData.targetId) {
                const sheriffPlayer = players.find(p => p.uid === sheriffUid && p.role === 'Sheriff' && p.isAlive);
                const isSheriffBlocked = blockedPlayerIds.includes(sheriffUid);

                if (!isSheriffBlocked && sheriffPlayer) {
                    const targetId = sheriffData.targetId;
                    const targetPlayer = players.find(p => p.uid === targetId);

                    if (targetPlayer) {
                        const isSuspicious = targetPlayer.role === 'Gunman' || targetPlayer.role === 'Jester';
                        const result = isSuspicious ? 'Suspicious' : 'Innocent';

                        nightOutcomes[sheriffPlayer.uid] = {
                            type: 'investigation_result',
                            targetName: targetPlayer.name,
                            targetRole: targetPlayer.role,
                            result: result,
                            message: `You investigated ${targetPlayer.name}. They appear ${result}.`
                        };
                    }
                } else if (isSheriffBlocked && sheriffPlayer) {
                    nightOutcomes[sheriffPlayer.uid] = {
                        type: 'investigation_blocked',
                        message: 'You were blocked and could not investigate anyone.'
                    };
                }
            }
        }
    }    // Process Peeper spying (multiple peepers possible)
    if (roleDataUpdate.peeper) {
        for (const [peeperUid, peeperData] of Object.entries(roleDataUpdate.peeper)) {
            if (peeperData && peeperData.targetId) {
                const peeperPlayer = players.find(p => p.uid === peeperUid && p.role === 'Peeper' && p.isAlive);
                const isPeeperBlocked = blockedPlayerIds.includes(peeperUid);

                if (!isPeeperBlocked && peeperPlayer) {
                    const targetId = peeperData.targetId;
                    const targetPlayer = players.find(p => p.uid === targetId);

                    if (targetPlayer) {
                        // Determine who visited the target
                        let visitors = [];

                        // Check if any Gunman visited
                        if (roleDataUpdate.gunman) {
                            for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
                                if (gunmanData && gunmanData.targetId === targetId && !blockedPlayerIds.includes(gunmanUid)) {
                                    const gunmanPlayer = players.find(p => p.uid === gunmanUid && p.role === 'Gunman');
                                    if (gunmanPlayer) {
                                        visitors.push(gunmanPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any Doctor visited
                        if (roleDataUpdate.doctor) {
                            for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                if (doctorData && doctorData.protectedId === targetId && !blockedPlayerIds.includes(doctorUid)) {
                                    const doctorPlayer = players.find(p => p.uid === doctorUid && p.role === 'Doctor');
                                    if (doctorPlayer) {
                                        visitors.push(doctorPlayer.name);
                                    }
                                }
                            }
                        }

                        nightOutcomes[peeperPlayer.uid] = {
                            type: 'peep_result',
                            targetName: targetPlayer.name,
                            visitors: visitors,
                            message: visitors.length > 0
                                ? `You spied on ${targetPlayer.name}. They were visited by: ${visitors.join(', ')}.`
                                : `You spied on ${targetPlayer.name}. No one visited them tonight.`
                        };
                    }
                } else if (isPeeperBlocked && peeperPlayer) {
                    nightOutcomes[peeperPlayer.uid] = {
                        type: 'peep_blocked',
                        message: 'You were blocked and could not spy on anyone.'
                    };
                }
            }
        }
    }    // Process Doctor protection (multiple doctors possible)
    if (roleDataUpdate.doctor) {
        for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
            if (doctorData && doctorData.protectedId) {
                const doctorPlayer = players.find(p => p.uid === doctorUid && p.role === 'Doctor' && p.isAlive);
                const isDoctorBlocked = blockedPlayerIds.includes(doctorUid);

                if (!isDoctorBlocked && doctorPlayer) {
                    const targetPlayer = players.find(p => p.uid === doctorData.protectedId);
                    if (targetPlayer) {
                        nightOutcomes[doctorPlayer.uid] = {
                            type: 'protection_result',
                            targetName: targetPlayer.name,
                            message: `You protected ${targetPlayer.name} tonight.`
                        };
                    }
                } else if (isDoctorBlocked && doctorPlayer) {
                    nightOutcomes[doctorPlayer.uid] = {
                        type: 'protection_blocked',
                        message: 'You were blocked and could not protect anyone.'
                    };
                }
            }
        }
    }    // Process Escort blocking (multiple escorts possible)
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                const escortPlayer = players.find(p => p.uid === escortUid && p.role === 'Escort' && p.isAlive);
                if (escortPlayer) {
                    const targetPlayer = players.find(p => p.uid === escortData.blockedId);
                    if (targetPlayer) {
                        nightOutcomes[escortPlayer.uid] = {
                            type: 'block_result',
                            targetName: targetPlayer.name,
                            message: `You blocked ${targetPlayer.name} from performing their night action.`
                        };
                    }
                }
            }
        }
    }    // Process night kills from Gunman (multiple gunmen possible)
    if (roleDataUpdate.gunman) {
        for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
            if (gunmanData && gunmanData.targetId) {
                const gunmanPlayer = players.find(p => p.uid === gunmanUid && p.role === 'Gunman' && p.isAlive);
                const isGunmanBlocked = blockedPlayerIds.includes(gunmanUid);

                if (!isGunmanBlocked && gunmanPlayer) {
                    const targetId = gunmanData.targetId;
                    const targetIndex = updatedPlayers.findIndex(p => p.uid === targetId);

                    if (targetIndex !== -1) {
                        const targetPlayer = updatedPlayers[targetIndex];

                        // Check if target is protected by any doctor (if doctors are not blocked)
                        let isProtected = false;
                        if (roleDataUpdate.doctor) {
                            for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                if (doctorData && doctorData.protectedId === targetId && !blockedPlayerIds.includes(doctorUid)) {
                                    isProtected = true;
                                    break;
                                }
                            }
                        }

                        // Kill the target if they're not protected
                        if (!isProtected) {
                            updatedPlayers[targetIndex] = {
                                ...targetPlayer,
                                isAlive: false,
                                killedBy: 'Gunman',
                                eliminatedBy: gunmanPlayer.name
                            };
                            nightEvents.push(`${targetPlayer.name} was killed by the Gunman.`);

                            nightOutcomes[gunmanPlayer.uid] = {
                                type: 'kill_success',
                                targetName: targetPlayer.name,
                                message: `You successfully killed ${targetPlayer.name}.`
                            };
                        } else {
                            nightEvents.push(`Someone was attacked but saved by the Doctor!`);

                            nightOutcomes[gunmanPlayer.uid] = {
                                type: 'kill_failed',
                                targetName: targetPlayer.name,
                                message: `You tried to kill ${targetPlayer.name}, but they were protected.`
                            };
                        }
                    }
                } else if (isGunmanBlocked && gunmanPlayer) {
                    nightEvents.push(`The Gunman was blocked and could not act.`);

                    nightOutcomes[gunmanPlayer.uid] = {
                        type: 'kill_blocked',
                        message: 'You were blocked and could not kill anyone.'
                    };
                }
            }
        }
    }    // Reset role data for next night, preserving persistent data and multi-role structure
    const newRoleData = {};

    // Reset gunman data for each gunman
    const gunmanPlayers = players.filter(p => p.role === 'Gunman' && p.isAlive);
    if (gunmanPlayers.length > 0) {
        newRoleData.gunman = {};
        gunmanPlayers.forEach(player => {
            newRoleData.gunman[player.uid] = { targetId: null };
        });
    }

    // Reset doctor data for each doctor, preserving selfProtectionUsed
    const doctorPlayers = players.filter(p => p.role === 'Doctor' && p.isAlive);
    if (doctorPlayers.length > 0) {
        newRoleData.doctor = {};
        doctorPlayers.forEach(player => {
            newRoleData.doctor[player.uid] = {
                protectedId: null,
                selfProtectionUsed: roleDataUpdate.doctor?.[player.uid]?.selfProtectionUsed || false
            };
        });
    }

    // Reset escort data for each escort
    const escortPlayers = players.filter(p => p.role === 'Escort' && p.isAlive);
    if (escortPlayers.length > 0) {
        newRoleData.escort = {};
        escortPlayers.forEach(player => {
            newRoleData.escort[player.uid] = { blockedId: null };
        });
    }

    // Reset sheriff data for each sheriff
    const sheriffPlayers = players.filter(p => p.role === 'Sheriff' && p.isAlive);
    if (sheriffPlayers.length > 0) {
        newRoleData.sheriff = {};
        sheriffPlayers.forEach(player => {
            newRoleData.sheriff[player.uid] = { targetId: null };
        });
    }

    // Reset peeper data for each peeper
    const peeperPlayers = players.filter(p => p.role === 'Peeper' && p.isAlive);
    if (peeperPlayers.length > 0) {
        newRoleData.peeper = {};
        peeperPlayers.forEach(player => {
            newRoleData.peeper[player.uid] = { targetId: null };
        });
    }

    return {
        players: updatedPlayers,
        roleData: newRoleData,
        nightEvents: nightEvents,
        nightOutcomes: nightOutcomes
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
