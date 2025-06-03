const admin = require('firebase-admin');
const db = admin.firestore();

// Import team manager for role checks
const teamManager = require('./teamManager');

// Doctor's action - protect a player during the night
exports.doctorProtect = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, doctorId, targetId } = req.body;

        if (!lobbyCode || !doctorId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_actions') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const doctor = players.find(p => p.uid === doctorId);

        // Verify player is doctor and alive
        if (!doctor || doctor.role !== 'Doctor' || !doctor.isAlive) {
            return res.status(403).json({ error: 'You are not the doctor or not alive' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                doctor: {
                    ...(lobbyData.roleData?.doctor || {}),
                    [doctorId]: {
                        ...(lobbyData.roleData?.doctor?.[doctorId] || {}),
                        protectedId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Protection target removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.uid === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Check if doctor is protecting themselves and has already used self-protection
        const doctorData = lobbyData.roleData?.doctor?.[doctorId] || {};
        if (targetId === doctorId && doctorData.selfProtectionUsed) {
            return res.status(400).json({ error: 'You cannot protect yourself more than once per game' });
        }

        // Store doctor's protection choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            doctor: {
                ...(lobbyData.roleData?.doctor || {}),
                [doctorId]: {
                    ...doctorData,
                    protectedId: targetId,
                    selfProtectionUsed: doctorData.selfProtectionUsed || (targetId === doctorId)
                }
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        return res.status(200).json({ message: 'Protection applied successfully' });
    } catch (error) {
        console.error('doctorProtect error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Gunman's action - kill a player during the night
exports.gunmanKill = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, gunmanId, targetId } = req.body;

        if (!lobbyCode || !gunmanId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_actions') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const gunman = players.find(p => p.uid === gunmanId);

        // Verify player is gunman and alive
        if (!gunman || gunman.role !== 'Gunman' || !gunman.isAlive) {
            return res.status(403).json({ error: 'You are not the gunman or not alive' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                gunman: {
                    ...(lobbyData.roleData?.gunman || {}),
                    [gunmanId]: {
                        ...(lobbyData.roleData?.gunman?.[gunmanId] || {}),
                        targetId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Kill target removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.uid === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === gunmanId) {
            return res.status(400).json({ error: 'You cannot kill yourself' });
        }        // Store gunman's kill choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            gunman: {
                ...(lobbyData.roleData?.gunman || {}),
                [gunmanId]: {
                    ...(lobbyData.roleData?.gunman?.[gunmanId] || {}),
                    targetId: targetId
                }
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        return res.status(200).json({ message: 'Kill target selected successfully' });
    } catch (error) {
        console.error('gunmanKill error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Sheriff's action - investigate a player during the night
exports.sheriffInvestigate = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, sheriffId, targetId } = req.body;

        if (!lobbyCode || !sheriffId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_actions') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const sheriff = players.find(p => p.uid === sheriffId);

        // Verify player is sheriff and alive
        if (!sheriff || sheriff.role !== 'Sheriff' || !sheriff.isAlive) {
            return res.status(403).json({ error: 'You are not the sheriff or not alive' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                sheriff: {
                    ...(lobbyData.roleData?.sheriff || {}),
                    [sheriffId]: {
                        ...(lobbyData.roleData?.sheriff?.[sheriffId] || {}),
                        targetId: null,
                        result: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Investigation target removed' });
        }        // Check if target is alive
        const target = players.find(p => p.uid === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Determine investigation result
        let result = 'innocent';
        const targetTeam = teamManager.getTeamByRole(target.role);

        // Bandits appear suspicious except for Chieftain who appears innocent
        if (targetTeam === 'Bandit' && target.role !== 'Chieftain') {
            result = 'suspicious';
        }

        // Some neutral roles appear suspicious
        if (targetTeam === 'Neutral' && target.role === 'Jester') {
            result = 'innocent'; // Jester appears innocent to Sheriff
        }

        // Store sheriff's investigation result
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            sheriff: {
                ...(lobbyData.roleData?.sheriff || {}),
                [sheriffId]: {
                    ...(lobbyData.roleData?.sheriff?.[sheriffId] || {}),
                    targetId: targetId,
                    result: result
                }
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        return res.status(200).json({
            message: 'Investigation complete',
            result: result
        });
    } catch (error) {
        console.error('sheriffInvestigate error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Escort's action - block a player from using their ability during the night
exports.escortBlock = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, escortId, targetId } = req.body;

        if (!lobbyCode || !escortId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_actions') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const escort = players.find(p => p.uid === escortId);

        // Verify player is escort and alive
        if (!escort || escort.role !== 'Escort' || !escort.isAlive) {
            return res.status(403).json({ error: 'You are not the escort or not alive' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                escort: {
                    ...(lobbyData.roleData?.escort || {}),
                    [escortId]: {
                        ...(lobbyData.roleData?.escort?.[escortId] || {}),
                        blockedId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Block target removed' });
        }        // Check if target is alive
        const target = players.find(p => p.uid === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === escortId) {
            return res.status(400).json({ error: 'You cannot block yourself' });
        }

        // Store escort's block choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            escort: {
                ...(lobbyData.roleData?.escort || {}),
                [escortId]: {
                    ...(lobbyData.roleData?.escort?.[escortId] || {}),
                    blockedId: targetId
                }
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        }); return res.status(200).json({
            message: 'Block action applied successfully'
        });
    } catch (error) {
        console.error('escortBlock error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Peeper's action - spy on a player to learn their role during the night
exports.peeperSpy = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, peeperId, targetId } = req.body;

        if (!lobbyCode || !peeperId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_actions') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const peeper = players.find(p => p.uid === peeperId);

        // Verify player is peeper and alive
        if (!peeper || peeper.role !== 'Peeper' || !peeper.isAlive) {
            return res.status(403).json({ error: 'You are not the peeper or not alive' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                peeper: {
                    ...(lobbyData.roleData?.peeper || {}),
                    [peeperId]: {
                        ...(lobbyData.roleData?.peeper?.[peeperId] || {}),
                        targetId: null,
                        result: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Spy target removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.uid === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === peeperId) {
            return res.status(400).json({ error: 'You cannot spy on yourself' });
        }        // Store peeper's spy choice and result
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            peeper: {
                ...(lobbyData.roleData?.peeper || {}),
                [peeperId]: {
                    ...(lobbyData.roleData?.peeper?.[peeperId] || {}),
                    targetId: targetId,
                    result: target.role // Peeper learns the exact role
                }
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        return res.status(200).json({
            message: 'Spy action applied successfully'
        });
    } catch (error) {
        console.error('peeperSpy error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};
