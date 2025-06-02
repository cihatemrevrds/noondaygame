const admin = require('firebase-admin');
const db = admin.firestore();

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
        }));

        await lobbyRef.update({
            players: updatedPlayers,
            status: 'started',
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.status(200).json({ message: 'Game started successfully' });
    } catch (error) {
        console.error('startGame error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Advance the game phase from day to night or night to day
exports.advancePhase = async (req, res) => {
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
        const dayCount = lobbyData.dayCount || 1;

        const newPhase = currentPhase === "night" ? "day" : "night";
        const newDayCount = currentPhase === "night" ? dayCount : dayCount + 1;

        // Reset night action data when moving to a new phase
        let roleDataUpdate = { ...lobbyData.roleData } || {};
        let updatedPlayers = [...players];

        // When transitioning from night to day, process night actions
        if (newPhase === 'day') {
            // First check who is blocked by prostitute
            const blockedPlayerId = roleDataUpdate.prostitute?.blockedId || null;

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
                            roleDataUpdate.doctor.protectedId === targetId;                        // Check if target is immune (add role-specific immunity checks here)
                        const isImmune = targetPlayer.role === 'ImmuneRole'; // Replace with actual immune roles

                        // Kill the target if they're not protected or immune
                        if (!isProtected && !isImmune) {
                            updatedPlayers[targetIndex] = {
                                ...targetPlayer,
                                isAlive: false,
                                killedBy: 'Gunman'
                            };
                        }
                    }
                }

                // Reset gunman target
                roleDataUpdate.gunman = {
                    ...roleDataUpdate.gunman,
                    targetId: null
                };
            }

            // Reset doctor's protection but keep track of self-protection use
            if (roleDataUpdate.doctor) {
                roleDataUpdate.doctor = {
                    ...roleDataUpdate.doctor,
                    protectedId: null
                };
            }

            // Reset prostitute's block
            if (roleDataUpdate.prostitute) {
                roleDataUpdate.prostitute = {
                    ...roleDataUpdate.prostitute,
                    blockedId: null
                };
            }
        }

        await lobbyRef.update({
            phase: newPhase,
            dayCount: newDayCount,
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            roleData: roleDataUpdate,
            players: updatedPlayers
        });

        // When moving to day phase, also check sheriff results if not blocked
        if (newPhase === 'day' && roleDataUpdate.sheriff && roleDataUpdate.sheriff.targetId) {
            const sheriffId = players.find(p => p.role === 'Sheriff' && p.isAlive)?.id;
            const isSheriffBlocked = sheriffId && sheriffId === roleDataUpdate.prostitute?.blockedId;

            // If sheriff was blocked, clear their investigation result
            if (isSheriffBlocked && roleDataUpdate.sheriff) {
                await lobbyRef.update({
                    'roleData.sheriff.result': null
                });
            }
        }

        return res.status(200).json({
            message: "Phase updated",
            newPhase,
            newDayCount
        });
    } catch (error) {
        console.error("advancePhase error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};
