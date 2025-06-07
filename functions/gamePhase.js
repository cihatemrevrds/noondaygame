const admin = require('firebase-admin');
const functions = require('firebase-functions');
const MESSAGES = require('./messageConfig');
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

        const currentPhase = lobbyData.phase || "night";
        const currentGameState = lobbyData.gameState || "role_reveal";
        const dayCount = lobbyData.dayCount || 1;

        // Get game settings for timer durations
        const gameSettings = lobbyData.gameSettings || {};
        const discussionTime = (gameSettings.discussionTime || 60) * 1000; // Convert seconds to milliseconds
        const votingTime = (gameSettings.votingTime || 30) * 1000; // Convert seconds to milliseconds
        const nightTime = (gameSettings.nightTime || 45) * 1000; // Convert seconds to milliseconds

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
    const discussionTime = (gameSettings.discussionTime || 60) * 1000; // Convert seconds to milliseconds
    const votingTime = (gameSettings.votingTime || 30) * 1000; // Convert seconds to milliseconds
    const nightTime = (gameSettings.nightTime || 45) * 1000; // Convert seconds to milliseconds

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
        updateData.gameState = 'night_outcome';
        updateData.phaseTimeLimit = 10000; // 10 seconds for night outcome (fixed duration)
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

    let roleDataUpdate = { ...lobbyData.roleData } || {};
    let updatedPlayers = [...players];
    let nightEvents = []; // Public events - visible to everyone
    let privateEvents = {}; // Private events - visible only to specific players    // NIGHT ACTION ORDER OF OPERATIONS:
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
                    const targetPlayer = players.find(p => p.id === targetId);

                    if (targetPlayer) {
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
                        }                        // Private event - only the Peeper sees this
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

    console.log(`🔫 Found ${aliveGunmen.length} alive gunmen`);

    if (chieftainTarget && chieftainPlayer && aliveGunmen.length > 0) {
        // Chieftain gave orders and is not blocked - randomly select ONE gunman to execute
        const availableGunmen = aliveGunmen.filter(gunman => !blockedPlayerIds.includes(gunman.id));

        if (availableGunmen.length > 0) {
            const randomIndex = Math.floor(Math.random() * availableGunmen.length);
            const selectedGunman = availableGunmen[randomIndex];

            console.log(`👑 Chieftain ordered kill, randomly selected ${selectedGunman.name} to execute`);

            // Execute the chieftain's order with the selected gunman
            const targetIndex = updatedPlayers.findIndex(p => p.id === chieftainTarget);
            if (targetIndex !== -1) {
                const targetPlayer = updatedPlayers[targetIndex];

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
                }

                if (!isProtected) {
                    console.log(`💀 Killing target: ${targetPlayer.name}`);
                    updatedPlayers[targetIndex] = {
                        ...targetPlayer,
                        isAlive: false,
                        killedBy: 'Gunman',
                        eliminatedBy: selectedGunman.name
                    };                    // Public event - everyone sees this
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
                    };

                    // Chieftain gets failure notification
                    privateEvents[chieftainPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.ORDER_FAILED,
                        targetName: targetPlayer.name
                    };
                }
            }

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
    } else {
        // No chieftain orders OR chieftain is dead/blocked - gunmen act independently
        console.log(`🔫 Gunmen acting independently (no chieftain orders or chieftain blocked)`);

        if (roleDataUpdate.gunman) {
            for (const [gunmanUid, gunmanData] of Object.entries(roleDataUpdate.gunman)) {
                const gunmanPlayer = players.find(p => p.id === gunmanUid && p.role === 'Gunman' && p.isAlive);
                const isGunmanBlocked = blockedPlayerIds.includes(gunmanUid);

                if (gunmanPlayer && !isGunmanBlocked && gunmanData && gunmanData.targetId) {
                    const targetId = gunmanData.targetId;
                    const targetIndex = updatedPlayers.findIndex(p => p.id === targetId);

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
                        } if (!isProtected) {
                            updatedPlayers[targetIndex] = {
                                ...targetPlayer,
                                isAlive: false,
                                killedBy: 'Gunman',
                                eliminatedBy: gunmanPlayer.name
                            };                            nightEvents.push(`${targetPlayer.name} was killed by Bandits.`);

                            privateEvents[gunmanPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.KILL_SUCCESS,
                                targetName: targetPlayer.name
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
                            } privateEvents[gunmanPlayer.id] = {
                                type: MESSAGES.EVENT_TYPES.KILL_FAILED,
                                targetName: targetPlayer.name
                            };
                        }
                    }
                } else if (gunmanPlayer && isGunmanBlocked) {
                    privateEvents[gunmanPlayer.id] = {
                        type: MESSAGES.EVENT_TYPES.KILL_BLOCKED
                    };
                }
            }
        }
    }    // Reset role data for next night, preserving persistent data and multi-role structure
    const newRoleData = {};

    // 7. Process Gunslinger actions (independent of other kills)
    console.log('🔫 Processing Gunslinger actions...');
    if (roleDataUpdate.gunslinger) {
        for (const [gunslingerUid, gunslingerData] of Object.entries(roleDataUpdate.gunslinger)) {
            const gunslingerPlayer = players.find(p => p.id === gunslingerUid && p.role === 'Gunslinger' && p.isAlive);
            const isGunslingerBlocked = blockedPlayerIds.includes(gunslingerUid);

            if (gunslingerPlayer && !isGunslingerBlocked && gunslingerData && gunslingerData.targetId) {
                const targetId = gunslingerData.targetId;
                const targetIndex = updatedPlayers.findIndex(p => p.id === targetId);

                if (targetIndex !== -1) {
                    const targetPlayer = updatedPlayers[targetIndex];                    // Get gunslinger's current bullet data
                    const bulletsUsed = gunslingerData.bulletsUsed || 0;

                    // Check if gunslinger has bullets left (only 1 bullet total)
                    if (bulletsUsed < 1) {
                        // Check if target is still alive (may have been killed by gunman)
                        if (targetPlayer.isAlive) {
                            // Execute the kill
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

                            // Private event for gunslinger
                            privateEvents[gunslingerPlayer.id] = {
                                type: 'gunslinger_shot_success',
                                targetName: targetPlayer.name,
                                message: `You successfully shot ${targetPlayer.name}. Your identity has been revealed to everyone.`
                            };

                            console.log(`🎯 Gunslinger ${gunslingerPlayer.name} shot ${targetPlayer.name} - identity revealed`);
                        } else {
                            // Target was already killed, gunslinger wasted a bullet
                            const newBulletsUsed = bulletsUsed + 1;

                            if (!newRoleData.gunslinger) newRoleData.gunslinger = {};
                            newRoleData.gunslinger[gunslingerUid] = {
                                bulletsUsed: newBulletsUsed,
                                targetId: null
                            };

                            privateEvents[gunslingerPlayer.id] = {
                                type: 'gunslinger_shot_wasted',
                                targetName: targetPlayer.name,
                                message: `${targetPlayer.name} was already dead. You wasted your only bullet.`
                            };
                        }
                    }
                }
            } else if (gunslingerPlayer && isGunslingerBlocked) {
                // Gunslinger was blocked
                privateEvents[gunslingerPlayer.id] = {
                    type: MESSAGES.EVENT_TYPES.KILL_BLOCKED
                };
            }
        }
    }    // Reset gunman data for each gunman
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
