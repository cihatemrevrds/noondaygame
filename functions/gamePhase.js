const admin = require('firebase-admin');
const functions = require('firebase-functions');
const MESSAGES = require('./messageConfig');
const teamManager = require('./teamManager');
const db = admin.firestore();

// Helper function to check win conditions with disable setting support
function checkWinConditionsIfEnabled(updatedPlayers, lobbyData) {
    // Check if win conditions are disabled for testing
    const gameSettings = lobbyData.gameSettings || {};
    if (gameSettings.disableWinConditions === true) {
        return { gameOver: false };
    }

    return teamManager.checkWinConditionsSync(updatedPlayers, lobbyData);
}

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

        // Check if the initial role distribution creates an immediate win condition
        const initialWinCondition = checkWinConditionsIfEnabled(initializedPlayers, lobbyData);
        if (initialWinCondition.gameOver) {
            return res.status(400).json({
                error: 'Invalid role distribution - game would end immediately',
                details: `${initialWinCondition.winner} would win with this role setup`,
                winCondition: initialWinCondition
            });
        }

        // Initialize role-specific data structures
        const initialRoleData = {};

        // Initialize Gunslinger data - they start with 0 bullets used
        const gunslingers = initializedPlayers.filter(p => p.role === 'Gunslinger');
        if (gunslingers.length > 0) {
            initialRoleData.gunslinger = {};
            gunslingers.forEach(player => {
                initialRoleData.gunslinger[player.id] = {
                    bulletsUsed: 0,
                    targetId: null
                };
            });
        }

        // Initialize Doctor data - they start with self-protection available
        const doctors = initializedPlayers.filter(p => p.role === 'Doctor');
        if (doctors.length > 0) {
            initialRoleData.doctor = {};
            doctors.forEach(player => {
                initialRoleData.doctor[player.id] = {
                    protectedId: null,
                    selfProtectionUsed: false
                };
            });
        }

        await lobbyRef.update({
            players: initializedPlayers,
            status: 'started',
            phase: 'night',
            dayCount: 1,
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
            gameState: 'role_reveal', // Players see their roles first
            phaseTimeLimit: 5000, // 5 seconds for role reveal (non-skippable)
            votes: {},
            roleData: initialRoleData,
            nightEvents: [], // Public events for event sharing phase
            privateEvents: {}, // Private individual results for night outcome phase
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
        const players = lobbyData.players || [];

        if (lobbyData.hostUid !== hostId) {
            return res.status(403).json({ error: "Only host can advance the phase" });
        }

        const currentPhase = lobbyData.phase || "night"; const currentGameState = lobbyData.gameState || "role_reveal";
        const dayCount = lobbyData.dayCount || 1;

        // Get game settings for timer durations
        const gameSettings = lobbyData.gameSettings || {};
        const discussionTime = (gameSettings.discussionTime || 90) * 1000; // Convert seconds to milliseconds
        const votingTime = (gameSettings.votingTime || 45) * 1000; // Convert seconds to milliseconds
        const nightTime = (gameSettings.nightTime || 60) * 1000; // Convert seconds to milliseconds

        let updateData = {};

        // Handle different game states - 7-phase system
        if (currentGameState === 'role_reveal') {
            // Move from role reveal to night phase
            updateData = {
                gameState: 'night_phase',
                phaseTimeLimit: nightTime, // Use lobby setting for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'night_phase') {
            // Process night actions and move to night outcome phase
            updateData = await processNightActions(lobbyData, players);

            // Check for game end conditions after night actions
            const updatedPlayers = updateData.players || players;
            const winCondition = checkWinConditionsIfEnabled(updatedPlayers, lobbyData);

            if (winCondition.gameOver) {
                // Game is over - update lobby status and end game
                updateData = {
                    ...updateData,
                    status: 'ended',
                    gameState: 'game_over',
                    phase: 'ended',
                    winCondition: winCondition,
                    endedAt: admin.firestore.FieldValue.serverTimestamp()
                };
            } else {
                // Game continues - proceed to night outcome phase
                updateData.gameState = 'night_outcome';
                updateData.phaseTimeLimit = 10000; // 10 seconds for night outcome
                updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
            }
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
                phaseTimeLimit: discussionTime, // Use lobby setting for discussion
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else if (currentGameState === 'discussion_phase') {
            // Move to voting phase
            updateData = {
                gameState: 'voting_phase',
                phaseTimeLimit: votingTime, // Use lobby setting for voting
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
            };            // If someone was eliminated, update players and check win conditions
            if (eliminatedPlayer) {
                const updatedPlayers = players.map(p => {
                    if (p.id === eliminatedPlayer.id) {
                        return { ...p, isAlive: false, eliminatedBy: 'vote' };
                    }
                    return p;
                });
                updateData.players = updatedPlayers;

                // Check for game end conditions after voting elimination
                const winCondition = checkWinConditionsIfEnabled(updatedPlayers, lobbyData);

                if (winCondition.gameOver) {
                    // Update lobby status and end game immediately
                    updateData = {
                        ...updateData,
                        status: 'ended',
                        gameState: 'game_over',
                        phase: 'ended',
                        winCondition: winCondition,
                        endedAt: admin.firestore.FieldValue.serverTimestamp()
                    };
                }
            }
        } else if (currentGameState === 'voting_outcome') {
            // Move from voting results to night
            updateData = {
                phase: 'night',
                gameState: 'night_phase',
                dayCount: dayCount + 1,
                phaseTimeLimit: nightTime, // Use lobby setting for night actions
                phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                votes: {},
                privateEvents: {} // Clear previous private events
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
            // Lobby was deleted - this is a normal cleanup scenario
            // Return success to prevent client-side errors and stop further requests
            console.log(`Auto-advance request for deleted lobby ${lobbyCode} - lobby was cleaned up`);
            return res.status(200).json({
                message: "Lobby not found - game has ended",
                lobbyDeleted: true
            });
        } const lobbyData = lobbyDoc.data();
        const phaseTimeLimit = lobbyData.phaseTimeLimit || 60000;
        const now = new Date();

        // Check if phase time has expired
        if (lobbyData.phaseStartedAt) {
            const phaseStartedAt = lobbyData.phaseStartedAt.toDate();
            if ((now - phaseStartedAt) >= phaseTimeLimit) {
                // Auto advance to next phase
                const result = await advanceToNextPhase(lobbyData, lobbyRef);
                return res.status(200).json(result);
            }
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
        } const lobbyData = lobbyDoc.data();
        const phaseTimeLimit = lobbyData.phaseTimeLimit || 60000;
        const now = new Date();

        let timeRemaining = 0;
        if (lobbyData.phaseStartedAt) {
            const phaseStartedAt = lobbyData.phaseStartedAt.toDate();
            timeRemaining = Math.max(0, phaseTimeLimit - (now - phaseStartedAt));
        }

        return res.status(200).json({
            phase: lobbyData.phase,
            gameState: lobbyData.gameState,
            dayCount: lobbyData.dayCount,
            timeRemaining: timeRemaining,
            nightEvents: lobbyData.nightEvents || [],
            privateEvents: lobbyData.privateEvents || {},
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
        const { roleName } = req.query;

        const roleDescriptions = {
            'Doctor': 'You can protect one player each night from being killed. You can only self-protect once per game. Town team.',
            'Sheriff': 'You investigate players at night to determine if they are suspicious or innocent. Chieftain appears innocent despite being a Bandit. Town team.',
            'Escort': 'You block another player from using their night ability. Target\'s role action won\'t be processed that night. Town team.',
            'Peeper': 'You spy on players at night to see who visited them. This gives valuable information about roles and actions. Town team.',
            'Gunslinger': 'You are a civilian with a gun. You have 1 bullet to shoot during the night. When you kill someone, your identity is revealed to everyone. Town team.',
            'Gunman': 'You kill players at night. Work with your Chieftain to eliminate the Town team. Bandit team.',
            'Chieftain': 'You choose which Gunman kills each night and who they target. Gunmen must follow your orders. Bandit team.',
            'Jester': 'You win if you get voted out during the day. Try to act suspicious but not too suspicious. Neutral team.'
        };

        if (roleName) {
            // Return specific role description
            const description = roleDescriptions[roleName];
            if (description) {
                return res.status(200).json({ role: roleName, description });
            } else {
                return res.status(404).json({ error: 'Role not found' });
            }
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

    // Get game settings for timer durations
    const gameSettings = lobbyData.gameSettings || {};
    const discussionTime = (gameSettings.discussionTime || 90) * 1000; // Convert seconds to milliseconds
    const votingTime = (gameSettings.votingTime || 45) * 1000; // Convert seconds to milliseconds
    const nightTime = (gameSettings.nightTime || 60) * 1000; // Convert seconds to milliseconds

    let updateData = {};

    // Handle different game states
    if (currentGameState === 'role_reveal') {
        // Move from role reveal to night phase
        updateData = {
            gameState: 'night_phase',
            phaseTimeLimit: nightTime, // Use lobby setting for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'night_phase') {
        // Process night actions and move to night outcome phase
        updateData = await processNightActions(lobbyData, players);

        // Check for game end conditions after night actions
        const updatedPlayers = updateData.players || players;
        const winCondition = checkWinConditionsIfEnabled(updatedPlayers, lobbyData);

        if (winCondition.gameOver) {
            // Game is over - update lobby status and end game
            updateData = {
                ...updateData,
                status: 'ended',
                gameState: 'game_over',
                phase: 'ended',
                winCondition: winCondition,
                endedAt: admin.firestore.FieldValue.serverTimestamp()
            };
        } else {
            // Game continues - proceed to night outcome phase
            updateData.gameState = 'night_outcome';
            updateData.phaseTimeLimit = 10000; // 10 seconds for night outcome (fixed duration)
            updateData.phaseStartedAt = admin.firestore.FieldValue.serverTimestamp();
        }
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
            phaseTimeLimit: discussionTime, // Use lobby setting for discussion
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        };
    } else if (currentGameState === 'discussion_phase') {
        // Move to voting phase
        updateData = {
            gameState: 'voting_phase',
            phaseTimeLimit: votingTime, // Use lobby setting for voting
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

        // If someone was eliminated, update players and check win conditions
        if (eliminatedPlayer) {
            const updatedPlayers = players.map(p => {
                if (p.id === eliminatedPlayer.id) {
                    return { ...p, isAlive: false, eliminatedBy: 'vote' };
                }
                return p;
            });
            updateData.players = updatedPlayers;            // Check for game end conditions after voting elimination
            const winCondition = checkWinConditionsIfEnabled(updatedPlayers, lobbyData);

            if (winCondition.gameOver) {
                // Update lobby status and end game
                updateData = {
                    ...updateData,
                    status: 'ended',
                    gameState: 'game_over',
                    phase: 'ended',
                    winCondition: winCondition,
                    endedAt: admin.firestore.FieldValue.serverTimestamp()
                };
            }
        }
    } else if (currentGameState === 'voting_outcome') {
        // Move from voting results to night
        updateData = {
            phase: 'night',
            gameState: 'night_phase',
            dayCount: dayCount + 1,
            phaseTimeLimit: nightTime, // Use lobby setting for night actions
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            votes: {},
            privateEvents: {} // Clear previous private events
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
    console.log('🌙 Starting processNightActions...');
    console.log('📊 Lobby roleData:', JSON.stringify(lobbyData.roleData, null, 2));
    console.log('👥 Players count:', players.length);

    // Check game settings for first night kill restriction
    const gameSettings = lobbyData.gameSettings || {};
    const allowFirstNightKill = gameSettings.allowFirstNightKill ?? false;
    const dayCount = lobbyData.dayCount || 1; const isFirstNight = dayCount === 1;

    console.log(`🌙 Day ${dayCount}, First night: ${isFirstNight}, Allow first night kill: ${allowFirstNightKill}`);

    // If it's the first night and first night kills are disabled, skip all kill actions
    if (isFirstNight && !allowFirstNightKill) {
        console.log('🚫 First night kills disabled - skipping all kill actions');

        // Still process non-kill actions (investigation, protection, blocking, spying)
        let roleDataUpdate = { ...lobbyData.roleData } || {};
        let updatedPlayers = [...players];
        let nightEvents = []; // Public events - visible to everyone
        let privateEvents = {}; // Private events - visible only to specific players

        // Process only non-kill actions on first night when kills are disabled
        return await processNonKillActions(lobbyData, players, roleDataUpdate, updatedPlayers, nightEvents, privateEvents);
    }

    let roleDataUpdate = { ...lobbyData.roleData } || {};
    let updatedPlayers = [...players];
    let nightEvents = []; // Public events - visible to everyone
    let privateEvents = {}; // Private events - visible only to specific players// NIGHT ACTION ORDER OF OPERATIONS:
    // 1. Escort blocking (processed first)
    // 2. Doctor protection (if not blocked)
    // 3. Sheriff investigation (if not blocked)
    // 4. Chieftain orders (if not blocked)
    // 5. Gunmen kills (following orders or independent choices, if not blocked)

    // 1. First check who is blocked by Escort (multiple escorts possible)
    const blockedPlayerIds = [];
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                blockedPlayerIds.push(escortData.blockedId);
            }
        }
    }

    // 2. Process Doctor protection (multiple doctors possible) - BEFORE investigations
    if (roleDataUpdate.doctor) {
        for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
            if (doctorData && doctorData.protectedId) {
                const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor' && p.isAlive);
                const isDoctorBlocked = blockedPlayerIds.includes(doctorUid); if (!isDoctorBlocked && doctorPlayer) {
                    const targetPlayer = players.find(p => p.id === doctorData.protectedId);
                    if (targetPlayer) {                        // Private event - only the Doctor sees this
                        privateEvents[doctorPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.PROTECTION_RESULT,
                            targetName: targetPlayer.name
                        };
                    }
                } else if (isDoctorBlocked && doctorPlayer) {                    // Private event - only the Doctor sees this
                    privateEvents[doctorPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.PROTECTION_BLOCKED
                    };
                }
            }
        }
    }

    // 3. Process Sheriff investigations (multiple sheriffs possible) - AFTER protection
    if (roleDataUpdate.sheriff) {
        for (const [sheriffUid, sheriffData] of Object.entries(roleDataUpdate.sheriff)) {
            if (sheriffData && sheriffData.targetId) {
                const sheriffPlayer = players.find(p => p.id === sheriffUid && p.role === 'Sheriff' && p.isAlive);
                const isSheriffBlocked = blockedPlayerIds.includes(sheriffUid);

                if (!isSheriffBlocked && sheriffPlayer) {
                    const targetId = sheriffData.targetId;
                    const targetPlayer = players.find(p => p.id === targetId); if (targetPlayer) {
                        const isSuspicious = targetPlayer.role === 'Gunman' || targetPlayer.role === 'Jester'; const result = isSuspicious ? MESSAGES.INVESTIGATION_RESULTS.SUSPICIOUS : MESSAGES.INVESTIGATION_RESULTS.INNOCENT;

                        // Private event - only the Sheriff sees this
                        privateEvents[sheriffPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.INVESTIGATION_RESULT,
                            targetName: targetPlayer.name,
                            targetRole: targetPlayer.role,
                            result: result
                        };
                    }
                } else if (isSheriffBlocked && sheriffPlayer) {                    // Private event - only the Sheriff sees this
                    privateEvents[sheriffPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.INVESTIGATION_BLOCKED
                    };
                }
            }
        }
    }

    // Process Peeper spying (multiple peepers possible)
    if (roleDataUpdate.peeper) {
        for (const [peeperUid, peeperData] of Object.entries(roleDataUpdate.peeper)) {
            if (peeperData && peeperData.targetId) {
                const peeperPlayer = players.find(p => p.id === peeperUid && p.role === 'Peeper' && p.isAlive);
                const isPeeperBlocked = blockedPlayerIds.includes(peeperUid);

                if (!isPeeperBlocked && peeperPlayer) {
                    const targetId = peeperData.targetId;
                    const targetPlayer = players.find(p => p.id === targetId); if (targetPlayer) {
                        // Determine who visited the target
                        let visitors = [];

                        // Check if any Gunman visited
                        if (roleDataUpdate.gunman) {
                            for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
                                if (gunmanData && gunmanData.targetId === targetId && !blockedPlayerIds.includes(gunmanUid)) {
                                    const gunmanPlayer = players.find(p => p.id === gunmanUid && p.role === 'Gunman');
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
                                    const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor');
                                    if (doctorPlayer) {
                                        visitors.push(doctorPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any Sheriff investigated
                        if (roleDataUpdate.sheriff) {
                            for (const [sheriffUid, sheriffData] of Object.entries(roleDataUpdate.sheriff)) {
                                if (sheriffData && sheriffData.targetId === targetId && !blockedPlayerIds.includes(sheriffUid)) {
                                    const sheriffPlayer = players.find(p => p.id === sheriffUid && p.role === 'Sheriff');
                                    if (sheriffPlayer) {
                                        visitors.push(sheriffPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any Escort visited (blocks count as visits)
                        if (roleDataUpdate.escort) {
                            for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
                                if (escortData && escortData.blockedId === targetId && !blockedPlayerIds.includes(escortUid)) {
                                    const escortPlayer = players.find(p => p.id === escortUid && p.role === 'Escort');
                                    if (escortPlayer) {
                                        visitors.push(escortPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any other Peeper spied on same target
                        if (roleDataUpdate.peeper) {
                            for (const [otherPeeperUid, otherPeeperData] of Object.entries(roleDataUpdate.peeper)) {
                                if (otherPeeperData && otherPeeperData.targetId === targetId &&
                                    otherPeeperUid !== peeperUid && !blockedPlayerIds.includes(otherPeeperUid)) {
                                    const otherPeeperPlayer = players.find(p => p.id === otherPeeperUid && p.role === 'Peeper');
                                    if (otherPeeperPlayer) {
                                        visitors.push(otherPeeperPlayer.name);
                                    }
                                }
                            }
                        }                        // Note: Chieftain doesn't visit targets - they only give orders to Gunmen
                        // Only the executing Gunman should appear as a visitor

                        // Check if any Gunslinger shot the target
                        if (roleDataUpdate.gunslinger) {
                            for (const [gunslingerUid, gunslingerData] of Object.entries(roleDataUpdate.gunslinger)) {
                                if (gunslingerData && gunslingerData.targetId === targetId && !blockedPlayerIds.includes(gunslingerUid)) {
                                    const gunslingerPlayer = players.find(p => p.id === gunslingerUid && p.role === 'Gunslinger');
                                    if (gunslingerPlayer) {
                                        visitors.push(gunslingerPlayer.name);
                                    }
                                }
                            }
                        }// Private event - only the Peeper sees this
                        privateEvents[peeperPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.PEEP_RESULT,
                            targetName: targetPlayer.name,
                            visitors: visitors
                        };
                    }
                } else if (isPeeperBlocked && peeperPlayer) {                    // Private event - only the Peeper sees this
                    privateEvents[peeperPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.PEEP_BLOCKED
                    };
                }
            }
        }
    }

    // 5. Process Escort blocking notifications (after actions processed)
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                const escortPlayer = players.find(p => p.id === escortUid && p.role === 'Escort' && p.isAlive);

                if (escortPlayer) {
                    const targetPlayer = players.find(p => p.id === escortData.blockedId); if (targetPlayer) {                        // Private event - only the Escort sees this
                        privateEvents[escortPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.BLOCK_RESULT,
                            targetName: targetPlayer.name
                        };
                    }
                }
            }
        }
    }

    // 6. Process Chieftain orders and Gunman kills (FINAL PHASE)
    console.log('🔫 Processing bandit team kills...');
    console.log('🔍 RoleData gunman section:', JSON.stringify(roleDataUpdate.gunman, null, 2));
    console.log('👑 RoleData chieftain section:', JSON.stringify(roleDataUpdate.chieftain, null, 2));

    // First check if any chieftain has given orders (if not blocked)
    let chieftainTarget = null;
    let chieftainPlayer = null;
    if (roleDataUpdate.chieftain) {
        for (const [chieftainUid, chieftainData] of Object.entries(roleDataUpdate.chieftain)) {
            if (chieftainData && chieftainData.targetId && !blockedPlayerIds.includes(chieftainUid)) {
                const foundChieftain = players.find(p => p.id === chieftainUid && p.role === 'Chieftain' && p.isAlive);
                if (foundChieftain) {
                    chieftainTarget = chieftainData.targetId;
                    chieftainPlayer = foundChieftain;
                    console.log(`👑 Chieftain ${chieftainPlayer.name} ordered kill on ${chieftainTarget} (not blocked)`);
                    break; // Only one chieftain can give orders
                }
            }
        }
    }    // Process kills based on chieftain orders or gunman choices
    // If Chieftain gives orders, randomly select ONE gunman to execute it
    // If Chieftain is blocked or dead, all gunmen act independently

    const aliveGunmen = Object.keys(roleDataUpdate.gunman || {})
        .map(gunmanUid => players.find(p => p.id === gunmanUid && p.role === 'Gunman' && p.isAlive))
        .filter(Boolean);

    console.log(`🔫 Found ${aliveGunmen.length} alive gunmen`); if (chieftainTarget && chieftainPlayer && aliveGunmen.length > 0) {
        // Check if first night kills are disabled
        if (isFirstNight && !allowFirstNightKill) {
            console.log(`🚫 First night kills disabled - blocking Chieftain order`);
            // Notify Chieftain that order was blocked due to first night restriction
            privateEvents[chieftainPlayer.id] = {
                type: 'first_night_kill_disabled',
                message: `Kill orders are disabled on the first night. Your target was not harmed.`
            };
        } else {
            // Normal Chieftain order processing
            // Chieftain gave orders and is not blocked - randomly select ONE gunman to execute
            const availableGunmen = aliveGunmen.filter(gunman => !blockedPlayerIds.includes(gunman.id));

            if (availableGunmen.length > 0) {
                const randomIndex = Math.floor(Math.random() * availableGunmen.length);
                const selectedGunman = availableGunmen[randomIndex];

                console.log(`👑 Chieftain ordered kill, randomly selected ${selectedGunman.name} to execute`);            // Execute the chieftain's order with the selected gunman
                const targetIndex = updatedPlayers.findIndex(p => p.id === chieftainTarget);
                if (targetIndex !== -1) {
                    const targetPlayer = updatedPlayers[targetIndex];

                    // Check if target is a Bandit (Gunman or Chieftain) - Bandits cannot kill other Bandits
                    if (targetPlayer.role === 'Gunman' || targetPlayer.role === 'Chieftain') {
                        console.log(`🚫 Bandit attempted to kill another Bandit - blocking kill`);

                        // Notify Chieftain that the target cannot be killed (they are a fellow Bandit)
                        privateEvents[chieftainPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.ORDER_FAILED,
                            targetName: targetPlayer.name,
                            message: `Your target ${targetPlayer.name} cannot be harmed by fellow Bandits.`
                        };

                        // Notify selected Gunman 
                        privateEvents[selectedGunman.id] = {
                            type: MESSAGES.EVENT_TYPES.KILL_FAILED,
                            targetName: targetPlayer.name,
                            message: `You cannot harm a fellow Bandit.`
                        };
                    } else {
                        // Normal kill processing for non-Bandit targets
                        // Check if target is protected by any doctor (if doctors are not blocked)
                        let isProtected = false;
                        if (roleDataUpdate.doctor) {
                            for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                if (doctorData && doctorData.protectedId === chieftainTarget && !blockedPlayerIds.includes(doctorUid)) {
                                    console.log(`🛡️ Target protected by doctor ${doctorUid}`);
                                    isProtected = true;
                                    break;
                                }
                            }
                        } if (!isProtected) {
                            console.log(`💀 Killing target: ${targetPlayer.name}`);
                            updatedPlayers[targetIndex] = {
                                ...targetPlayer,
                                isAlive: false,
                                killedBy: 'Gunman',
                                eliminatedBy: selectedGunman.name
                            };

                            // Public event - everyone sees this
                            nightEvents.push(`${targetPlayer.name} was killed by Bandits.`);

                            // Private event - only the selected Gunman sees this
                            privateEvents[selectedGunman.id] = {
                                type: MESSAGES.EVENT_TYPES.KILL_SUCCESS,
                                targetName: targetPlayer.name
                            };

                            // Chieftain gets success notification
                            privateEvents[chieftainPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.ORDER_SUCCESS,
                                targetName: targetPlayer.name
                            };

                            // Death notification for the victim
                            privateEvents[targetPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.PLAYER_DEATH,
                                killerTeam: 'Bandits',
                                victimRole: targetPlayer.role
                            };
                        } else {
                            // Target was protected                    // Find the doctor(s) who protected this target
                            if (roleDataUpdate.doctor) {
                                for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                    if (doctorData && doctorData.protectedId === chieftainTarget && !blockedPlayerIds.includes(doctorUid)) {
                                        const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor');
                                        if (doctorPlayer) {
                                            privateEvents[doctorPlayer.id] = {
                                                type: MESSAGES.EVENT_TYPES.PROTECTION_SUCCESSFUL,
                                                targetName: targetPlayer.name
                                            };
                                        }
                                    }
                                }
                            }                    // Selected Gunman gets failure notification
                            privateEvents[selectedGunman.id] = {
                                type: MESSAGES.EVENT_TYPES.KILL_FAILED,
                                targetName: targetPlayer.name
                            };                        // Chieftain gets failure notification
                            privateEvents[chieftainPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.ORDER_FAILED,
                                targetName: targetPlayer.name
                            };
                        }
                    } // Close the Bandit protection check
                } // Close the target found check

                // Other gunmen who weren't selected get informed they were not chosen
                aliveGunmen.forEach(gunman => {
                    if (gunman.id !== selectedGunman.id && !blockedPlayerIds.includes(gunman.id)) {
                        privateEvents[gunman.id] = {
                            type: MESSAGES.EVENT_TYPES.NOT_SELECTED
                        };
                    }
                });
            } else {
                // All gunmen are blocked, chieftain order fails
                privateEvents[chieftainPlayer.id] = {
                    type: MESSAGES.EVENT_TYPES.ORDER_FAILED
                };
            }
        } // Close the else block for first night check
    } else {
        // No chieftain orders OR chieftain is dead/blocked - gunmen act independently
        // BUT only ONE Bandit kill per night (randomly selected gunman)
        console.log(`🔫 Gunmen acting independently (no chieftain orders or chieftain blocked)`); if (roleDataUpdate.gunman) {
            // Check if it's first night and independent kills are restricted
            if (isFirstNight && !allowFirstNightKill) {
                console.log(`🚫 First night independent gunman kills disabled`);
                // Notify all gunmen with targets that independent kills are disabled on first night
                for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
                    if (gunmanData && gunmanData.targetId) {
                        const gunmanPlayer = players.find(p => p.id === gunmanUid && p.role === 'Gunman' && p.isAlive);
                        if (gunmanPlayer) {
                            const targetPlayer = players.find(p => p.id === gunmanData.targetId);
                            if (targetPlayer) {
                                privateEvents[gunmanPlayer.id] = {
                                    type: 'first_night_kill_disabled',
                                    message: `Independent kill actions are disabled on the first night. Your target ${targetPlayer.name} was not harmed.`
                                };
                            }
                        }
                    }
                }
            } else {
                // Normal independent gunman processing (not first night or first night kills allowed)
                // Collect all gunmen who have targets and are not blocked
                const availableGunmenWithTargets = [];
                for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
                    const gunmanPlayer = players.find(p => p.id === gunmanUid && p.role === 'Gunman' && p.isAlive);
                    const isGunmanBlocked = blockedPlayerIds.includes(gunmanUid);

                    if (gunmanPlayer && !isGunmanBlocked && gunmanData && gunmanData.targetId) {
                        availableGunmenWithTargets.push({
                            player: gunmanPlayer,
                            targetId: gunmanData.targetId
                        });
                    } else if (gunmanPlayer && isGunmanBlocked) {
                        privateEvents[gunmanPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.KILL_BLOCKED
                        };
                    }
                }

                console.log(`🎯 Found ${availableGunmenWithTargets.length} gunmen with targets and not blocked`);

                if (availableGunmenWithTargets.length > 0) {
                    // Randomly select ONE gunman to execute their kill
                    const randomIndex = Math.floor(Math.random() * availableGunmenWithTargets.length);
                    const selectedGunmanData = availableGunmenWithTargets[randomIndex];
                    const selectedGunman = selectedGunmanData.player;
                    const targetId = selectedGunmanData.targetId;

                    console.log(`🎲 Randomly selected ${selectedGunman.name} to execute independent kill`); const targetIndex = updatedPlayers.findIndex(p => p.id === targetId);
                    if (targetIndex !== -1) {
                        const targetPlayer = updatedPlayers[targetIndex];

                        // Check if target is a Bandit (Gunman or Chieftain) - Bandits cannot kill other Bandits
                        if (targetPlayer.role === 'Gunman' || targetPlayer.role === 'Chieftain') {
                            console.log(`🚫 Independent Bandit attempted to kill another Bandit - blocking kill`);

                            // Notify Gunman that the target cannot be killed (they are a fellow Bandit)
                            privateEvents[selectedGunman.id] = {
                                type: MESSAGES.EVENT_TYPES.KILL_FAILED,
                                targetName: targetPlayer.name,
                                message: `You cannot harm a fellow Bandit.`
                            };
                        } else {
                            // Normal kill processing for non-Bandit targets
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

                            if (!isProtected) {
                                updatedPlayers[targetIndex] = {
                                    ...targetPlayer,
                                    isAlive: false,
                                    killedBy: 'Gunman',
                                    eliminatedBy: selectedGunman.name
                                };

                                nightEvents.push(`${targetPlayer.name} was killed by Bandits.`);

                                privateEvents[selectedGunman.id] = {
                                    type: MESSAGES.EVENT_TYPES.KILL_SUCCESS,
                                    targetName: targetPlayer.name
                                };

                                // Death notification for the victim
                                privateEvents[targetPlayer.id] = {
                                    type: MESSAGES.EVENT_TYPES.PLAYER_DEATH,
                                    killerTeam: 'Bandits',
                                    victimRole: targetPlayer.role
                                };
                            } else {
                                // Find the doctor(s) who protected this target
                                if (roleDataUpdate.doctor) {
                                    for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                        if (doctorData && doctorData.protectedId === targetId && !blockedPlayerIds.includes(doctorUid)) {
                                            const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor');
                                            if (doctorPlayer) {
                                                privateEvents[doctorPlayer.id] = {
                                                    type: MESSAGES.EVENT_TYPES.PROTECTION_SUCCESSFUL,
                                                    targetName: targetPlayer.name
                                                };
                                            }
                                        }
                                    }
                                } privateEvents[selectedGunman.id] = {
                                    type: MESSAGES.EVENT_TYPES.KILL_FAILED,
                                    targetName: targetPlayer.name
                                };
                            }
                        } // Close the Bandit protection check
                    } // Close the target found check

                    // Notify other gunmen that they were not selected
                    availableGunmenWithTargets.forEach(gunmanData => {
                        if (gunmanData.player.id !== selectedGunman.id) {
                            privateEvents[gunmanData.player.id] = {
                                type: MESSAGES.EVENT_TYPES.NOT_SELECTED
                            };
                        }
                    });
                }
            }
        }
    }    // Reset role data for next night, preserving persistent data and multi-role structure
    const newRoleData = {};    // 7. Process Gunslinger actions (simultaneous with Gunman kills for mutual kill scenarios)
    console.log('🔫 Processing Gunslinger actions...');
    if (roleDataUpdate.gunslinger) {
        for (const [gunslingerUid, gunslingerData] of Object.entries(roleDataUpdate.gunslinger)) {
            // Check gunslinger status from ORIGINAL players (not updated, to allow mutual kills)
            const gunslingerPlayer = players.find(p => p.id === gunslingerUid && p.role === 'Gunslinger' && p.isAlive);
            const isGunslingerBlocked = blockedPlayerIds.includes(gunslingerUid);            // Process if gunslinger was originally alive and not blocked (allows mutual kills)
            if (gunslingerPlayer && !isGunslingerBlocked && gunslingerData && gunslingerData.targetId) {
                // Check if first night kills are disabled
                if (isFirstNight && !allowFirstNightKill) {
                    console.log(`🚫 First night kills disabled - blocking Gunslinger shot`);
                    // Notify Gunslinger that shot was blocked due to first night restriction
                    const targetPlayer = players.find(p => p.id === gunslingerData.targetId);
                    if (targetPlayer) {
                        privateEvents[gunslingerPlayer.id] = {
                            type: 'first_night_kill_disabled',
                            message: `Kill actions are disabled on the first night. Your target ${targetPlayer.name} was not harmed.`
                        };
                    }
                } else {
                    // Normal Gunslinger processing
                    const targetId = gunslingerData.targetId;
                    const targetIndex = updatedPlayers.findIndex(p => p.id === targetId);

                    if (targetIndex !== -1) {
                        const targetPlayer = updatedPlayers[targetIndex];

                        // Get gunslinger's current bullet data
                        const bulletsUsed = gunslingerData.bulletsUsed || 0;

                        // Check if gunslinger has bullets left (only 1 bullet total)
                        if (bulletsUsed < 1) {
                            // Execute the kill regardless of target's current status (allows mutual kills)
                            updatedPlayers[targetIndex] = {
                                ...targetPlayer,
                                isAlive: false,
                                killedBy: 'Gunslinger',
                                eliminatedBy: gunslingerPlayer.name
                            };

                            // Update gunslinger's bullet data (used their only bullet)
                            const newBulletsUsed = bulletsUsed + 1;

                            // Store updated gunslinger data for next night
                            if (!newRoleData.gunslinger) newRoleData.gunslinger = {};
                            newRoleData.gunslinger[gunslingerUid] = {
                                bulletsUsed: newBulletsUsed,
                                targetId: null // Reset target
                            };

                            // Public event - include Gunslinger identity revelation
                            nightEvents.push(`${targetPlayer.name} was killed by the Gunslinger.`);

                            // Private event for gunslinger (they get this even if they die)
                            privateEvents[gunslingerPlayer.id] = {
                                type: 'gunslinger_shot_success',
                                targetName: targetPlayer.name,
                                message: `You successfully shot ${targetPlayer.name}. Your identity has been revealed to everyone.`
                            };

                            // Death notification for the victim
                            privateEvents[targetPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.PLAYER_DEATH,
                                killerTeam: 'the Gunslinger',
                                victimRole: targetPlayer.role
                            }; console.log(`🎯 Gunslinger ${gunslingerPlayer.name} shot ${targetPlayer.name} - identity revealed`);
                        }
                    }
                } // Close the else block for first night check
            } else if (gunslingerPlayer && isGunslingerBlocked) {
                // Gunslinger was blocked
                privateEvents[gunslingerPlayer.id] = {
                    type: MESSAGES.EVENT_TYPES.KILL_BLOCKED
                };
            } else if (gunslingerData && gunslingerData.targetId) {
                // Gunslinger was dead/not found but had a target - preserve bullet count
                if (!newRoleData.gunslinger) newRoleData.gunslinger = {};
                newRoleData.gunslinger[gunslingerUid] = {
                    bulletsUsed: gunslingerData.bulletsUsed || 0, // Keep original bullet count
                    targetId: null // Reset target
                };
                console.log(`💀 Gunslinger ${gunslingerUid} was not found or dead - preserving bullet state`);
            }
        }
    }// Reset gunman data for each gunman
    const gunmanPlayers = players.filter(p => p.role === 'Gunman' && p.isAlive);
    if (gunmanPlayers.length > 0) {
        newRoleData.gunman = {};
        gunmanPlayers.forEach(player => {
            newRoleData.gunman[player.id] = { targetId: null };
        });
    }

    // Reset doctor data for each doctor, preserving selfProtectionUsed
    const doctorPlayers = players.filter(p => p.role === 'Doctor' && p.isAlive);
    if (doctorPlayers.length > 0) {
        newRoleData.doctor = {};
        doctorPlayers.forEach(player => {
            newRoleData.doctor[player.id] = {
                protectedId: null,
                selfProtectionUsed: roleDataUpdate.doctor?.[player.id]?.selfProtectionUsed || false
            };
        });
    }

    // Reset escort data for each escort
    const escortPlayers = players.filter(p => p.role === 'Escort' && p.isAlive);
    if (escortPlayers.length > 0) {
        newRoleData.escort = {};
        escortPlayers.forEach(player => {
            newRoleData.escort[player.id] = { blockedId: null };
        });
    }

    // Reset sheriff data for each sheriff
    const sheriffPlayers = players.filter(p => p.role === 'Sheriff' && p.isAlive);
    if (sheriffPlayers.length > 0) {
        newRoleData.sheriff = {};
        sheriffPlayers.forEach(player => {
            newRoleData.sheriff[player.id] = { targetId: null };
        });
    }

    // Reset peeper data for each peeper
    const peeperPlayers = players.filter(p => p.role === 'Peeper' && p.isAlive);
    if (peeperPlayers.length > 0) {
        newRoleData.peeper = {};
        peeperPlayers.forEach(player => {
            newRoleData.peeper[player.id] = { targetId: null };
        });
    }    // Reset chieftain data for each chieftain
    const chieftainPlayers = players.filter(p => p.role === 'Chieftain' && p.isAlive);
    if (chieftainPlayers.length > 0) {
        newRoleData.chieftain = {};
        chieftainPlayers.forEach(player => {
            newRoleData.chieftain[player.id] = { targetId: null };
        });
    }    // Reset gunslinger data for each gunslinger, preserving bullet count
    const gunslingerPlayers = players.filter(p => p.role === 'Gunslinger' && p.isAlive);
    if (gunslingerPlayers.length > 0) {
        if (!newRoleData.gunslinger) newRoleData.gunslinger = {};
        gunslingerPlayers.forEach(player => {
            // Only reset if not already set by processing above
            if (!newRoleData.gunslinger[player.id]) {
                newRoleData.gunslinger[player.id] = {
                    bulletsUsed: roleDataUpdate.gunslinger?.[player.id]?.bulletsUsed || 0,
                    targetId: null
                };
            }
        });
    }// If no public events occurred, add quiet night message
    if (nightEvents.length === 0) {
        nightEvents.push("The night was quiet. No one was harmed.");
    }

    return {
        players: updatedPlayers,
        roleData: newRoleData,
        nightEvents: nightEvents, // Public events for event sharing phase
        privateEvents: privateEvents // Private events for night outcome phase
    };
}

// Helper function to process only non-kill actions (for first night when kills are disabled)
async function processNonKillActions(lobbyData, players, roleDataUpdate, updatedPlayers, nightEvents, privateEvents) {
    console.log('🚫 Processing non-kill actions only (first night, kills disabled)');

    // NIGHT ACTION ORDER OF OPERATIONS (Non-kill actions only):
    // 1. Escort blocking (processed first)
    // 2. Doctor protection (if not blocked)
    // 3. Sheriff investigation (if not blocked)
    // 4. Peeper spying (if not blocked)

    // 1. First check who is blocked by Escort (multiple escorts possible)
    const blockedPlayerIds = [];
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                blockedPlayerIds.push(escortData.blockedId);
            }
        }
    }

    // 2. Process Doctor protection (multiple doctors possible) - BEFORE investigations
    if (roleDataUpdate.doctor) {
        for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
            if (doctorData && doctorData.protectedId) {
                const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor' && p.isAlive);
                const isDoctorBlocked = blockedPlayerIds.includes(doctorUid);

                if (!isDoctorBlocked && doctorPlayer) {
                    const targetPlayer = players.find(p => p.id === doctorData.protectedId);

                    if (targetPlayer) {
                        // Private event - only the Doctor sees this
                        privateEvents[doctorPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.PROTECTION_RESULT,
                            targetName: targetPlayer.name
                        };
                    }
                } else if (isDoctorBlocked && doctorPlayer) {
                    // Private event - only the Doctor sees this
                    privateEvents[doctorPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.PROTECTION_BLOCKED
                    };
                }
            }
        }
    }

    // 3. Process Sheriff investigations (multiple sheriffs possible) - AFTER protection
    if (roleDataUpdate.sheriff) {
        for (const [sheriffUid, sheriffData] of Object.entries(roleDataUpdate.sheriff)) {
            if (sheriffData && sheriffData.targetId) {
                const sheriffPlayer = players.find(p => p.id === sheriffUid && p.role === 'Sheriff' && p.isAlive);
                const isSheriffBlocked = blockedPlayerIds.includes(sheriffUid);

                if (!isSheriffBlocked && sheriffPlayer) {
                    const targetId = sheriffData.targetId;
                    const targetPlayer = players.find(p => p.id === targetId);

                    if (targetPlayer) {
                        const isSuspicious = targetPlayer.role === 'Gunman' || targetPlayer.role === 'Jester';
                        const result = isSuspicious ? MESSAGES.INVESTIGATION_RESULTS.SUSPICIOUS : MESSAGES.INVESTIGATION_RESULTS.INNOCENT;

                        // Private event - only the Sheriff sees this
                        privateEvents[sheriffPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.INVESTIGATION_RESULT,
                            targetName: targetPlayer.name,
                            targetRole: targetPlayer.role,
                            result: result
                        };
                    }
                } else if (isSheriffBlocked && sheriffPlayer) {
                    // Private event - only the Sheriff sees this
                    privateEvents[sheriffPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.INVESTIGATION_BLOCKED
                    };
                }
            }
        }
    }

    // 4. Process Peeper spying (multiple peepers possible)
    if (roleDataUpdate.peeper) {
        for (const [peeperUid, peeperData] of Object.entries(roleDataUpdate.peeper)) {
            if (peeperData && peeperData.targetId) {
                const peeperPlayer = players.find(p => p.id === peeperUid && p.role === 'Peeper' && p.isAlive);
                const isPeeperBlocked = blockedPlayerIds.includes(peeperUid);

                if (!isPeeperBlocked && peeperPlayer) {
                    const targetId = peeperData.targetId;
                    const targetPlayer = players.find(p => p.id === targetId); if (targetPlayer) {
                        // Determine who visited the target (only non-kill actions on first night)
                        let visitors = [];

                        // Check if any Doctor visited (non-kill action)
                        if (roleDataUpdate.doctor) {
                            for (const [doctorUid, doctorData] of Object.entries(roleDataUpdate.doctor)) {
                                if (doctorData && doctorData.protectedId === targetId && !blockedPlayerIds.includes(doctorUid)) {
                                    const doctorPlayer = players.find(p => p.id === doctorUid && p.role === 'Doctor');
                                    if (doctorPlayer) {
                                        visitors.push(doctorPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any Sheriff investigated (non-kill action)
                        if (roleDataUpdate.sheriff) {
                            for (const [sheriffUid, sheriffData] of Object.entries(roleDataUpdate.sheriff)) {
                                if (sheriffData && sheriffData.targetId === targetId && !blockedPlayerIds.includes(sheriffUid)) {
                                    const sheriffPlayer = players.find(p => p.id === sheriffUid && p.role === 'Sheriff');
                                    if (sheriffPlayer) {
                                        visitors.push(sheriffPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any Escort visited (blocks count as visits, non-kill action)
                        if (roleDataUpdate.escort) {
                            for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
                                if (escortData && escortData.blockedId === targetId && !blockedPlayerIds.includes(escortUid)) {
                                    const escortPlayer = players.find(p => p.id === escortUid && p.role === 'Escort');
                                    if (escortPlayer) {
                                        visitors.push(escortPlayer.name);
                                    }
                                }
                            }
                        }

                        // Check if any other Peeper spied on same target (non-kill action)
                        if (roleDataUpdate.peeper) {
                            for (const [otherPeeperUid, otherPeeperData] of Object.entries(roleDataUpdate.peeper)) {
                                if (otherPeeperData && otherPeeperData.targetId === targetId &&
                                    otherPeeperUid !== peeperUid && !blockedPlayerIds.includes(otherPeeperUid)) {
                                    const otherPeeperPlayer = players.find(p => p.id === otherPeeperUid && p.role === 'Peeper');
                                    if (otherPeeperPlayer) {
                                        visitors.push(otherPeeperPlayer.name);
                                    }
                                }
                            }
                        }

                        // Private event - only the Peeper sees this
                        privateEvents[peeperPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.PEEP_RESULT,
                            targetName: targetPlayer.name,
                            visitors: visitors
                        };
                    }
                } else if (isPeeperBlocked && peeperPlayer) {
                    // Private event - only the Peeper sees this
                    privateEvents[peeperPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.PEEP_BLOCKED
                    };
                }
            }
        }
    }    // 5. Process Escort blocking notifications (after actions processed)
    if (roleDataUpdate.escort) {
        for (const [escortUid, escortData] of Object.entries(roleDataUpdate.escort)) {
            if (escortData && escortData.blockedId) {
                const escortPlayer = players.find(p => p.id === escortUid && p.role === 'Escort' && p.isAlive);

                if (escortPlayer) {
                    const targetPlayer = players.find(p => p.id === escortData.blockedId);

                    if (targetPlayer) {
                        // Private event - only the Escort sees this
                        privateEvents[escortPlayer.id] = {
                            type: MESSAGES.EVENT_TYPES.BLOCK_RESULT,
                            targetName: targetPlayer.name
                        };
                    }
                }
            }
        }
    }

    // 6. Notify kill-role players that their actions were disabled on first night
    // Notify Gunmen who tried to kill
    if (roleDataUpdate.gunman) {
        for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
            if (gunmanData && gunmanData.targetId) {
                const gunmanPlayer = players.find(p => p.id === gunmanUid && p.role === 'Gunman' && p.isAlive);
                if (gunmanPlayer) {
                    const targetPlayer = players.find(p => p.id === gunmanData.targetId);
                    if (targetPlayer) {
                        privateEvents[gunmanPlayer.id] = {
                            type: 'first_night_kill_disabled',
                            message: `Kill actions are disabled on the first night. Your target ${targetPlayer.name} was not harmed.`
                        };
                    }
                }
            }
        }
    }

    // Notify Chieftains who tried to order kills
    if (roleDataUpdate.chieftain) {
        for (const [chieftainUid, chieftainData] of Object.entries(roleDataUpdate.chieftain)) {
            if (chieftainData && chieftainData.targetId) {
                const chieftainPlayer = players.find(p => p.id === chieftainUid && p.role === 'Chieftain' && p.isAlive);
                if (chieftainPlayer) {
                    const targetPlayer = players.find(p => p.id === chieftainData.targetId);
                    if (targetPlayer) {
                        privateEvents[chieftainPlayer.id] = {
                            type: 'first_night_kill_disabled',
                            message: `Kill orders are disabled on the first night. Your target ${targetPlayer.name} was not harmed.`
                        };
                    }
                }
            }
        }
    }

    // Notify Gunslingers who tried to shoot
    if (roleDataUpdate.gunslinger) {
        for (const [gunslingerUid, gunslingerData] of Object.entries(roleDataUpdate.gunslinger)) {
            if (gunslingerData && gunslingerData.targetId) {
                const gunslingerPlayer = players.find(p => p.id === gunslingerUid && p.role === 'Gunslinger' && p.isAlive);
                if (gunslingerPlayer) {
                    const targetPlayer = players.find(p => p.id === gunslingerData.targetId);
                    if (targetPlayer) {
                        privateEvents[gunslingerPlayer.id] = {
                            type: 'first_night_kill_disabled',
                            message: `Shooting is disabled on the first night. Your target ${targetPlayer.name} was not harmed. You still have your bullet.`
                        };
                    }
                }
            }
        }
    }

    // Reset role data for next night (non-kill roles only)
    const newRoleData = {};

    // Reset gunman data for each gunman (no kills processed, but reset for next night)
    const gunmanPlayers = players.filter(p => p.role === 'Gunman' && p.isAlive);
    if (gunmanPlayers.length > 0) {
        newRoleData.gunman = {};
        gunmanPlayers.forEach(player => {
            newRoleData.gunman[player.id] = { targetId: null };
        });
    }

    // Reset doctor data for each doctor, preserving selfProtectionUsed
    const doctorPlayers = players.filter(p => p.role === 'Doctor' && p.isAlive);
    if (doctorPlayers.length > 0) {
        newRoleData.doctor = {};
        doctorPlayers.forEach(player => {
            newRoleData.doctor[player.id] = {
                protectedId: null,
                selfProtectionUsed: roleDataUpdate.doctor?.[player.id]?.selfProtectionUsed || false
            };
        });
    }

    // Reset escort data for each escort
    const escortPlayers = players.filter(p => p.role === 'Escort' && p.isAlive);
    if (escortPlayers.length > 0) {
        newRoleData.escort = {};
        escortPlayers.forEach(player => {
            newRoleData.escort[player.id] = { blockedId: null };
        });
    }

    // Reset sheriff data for each sheriff
    const sheriffPlayers = players.filter(p => p.role === 'Sheriff' && p.isAlive);
    if (sheriffPlayers.length > 0) {
        newRoleData.sheriff = {};
        sheriffPlayers.forEach(player => {
            newRoleData.sheriff[player.id] = { targetId: null };
        });
    }

    // Reset peeper data for each peeper
    const peeperPlayers = players.filter(p => p.role === 'Peeper' && p.isAlive);
    if (peeperPlayers.length > 0) {
        newRoleData.peeper = {};
        peeperPlayers.forEach(player => {
            newRoleData.peeper[player.id] = { targetId: null };
        });
    }

    // Reset chieftain data for each chieftain (no kills processed, but reset for next night)
    const chieftainPlayers = players.filter(p => p.role === 'Chieftain' && p.isAlive);
    if (chieftainPlayers.length > 0) {
        newRoleData.chieftain = {};
        chieftainPlayers.forEach(player => {
            newRoleData.chieftain[player.id] = { targetId: null };
        });
    }

    // Reset gunslinger data for each gunslinger, preserving bullet count
    const gunslingerPlayers = players.filter(p => p.role === 'Gunslinger' && p.isAlive);
    if (gunslingerPlayers.length > 0) {
        if (!newRoleData.gunslinger) newRoleData.gunslinger = {};
        gunslingerPlayers.forEach(player => {
            newRoleData.gunslinger[player.id] = {
                bulletsUsed: roleDataUpdate.gunslinger?.[player.id]?.bulletsUsed || 0,
                targetId: null
            };
        });
    }

    // Add quiet night message for first night when kills are disabled
    nightEvents.push("The first night was peaceful. No one was harmed.");

    console.log('🚫 First night (kills disabled) processing complete');
    console.log('🌙 Private events generated:', Object.keys(privateEvents).length);

    return {
        players: updatedPlayers, // No player deaths on first night
        roleData: newRoleData,
        nightEvents: nightEvents, // Public events for event sharing phase
        privateEvents: privateEvents // Private events for night outcome phase
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
        } else if (count === maxVotes && count >= requiredVotes) {
            eliminatedId = null; // Tie, no one is eliminated
        }
    }

    if (eliminatedId) {
        const eliminatedPlayer = players.find(p => p.id === eliminatedId);
        return {
            ...eliminatedPlayer,
            voteCount: maxVotes
        };
    }

    return null;
}
