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
    } try {
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        } const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const doctor = players.find(p => p.id === userId);

        // Verify player is doctor and alive
        if (!doctor || doctor.role !== 'Doctor' || !doctor.isAlive) {
            return res.status(403).json({ error: 'You are not the doctor or not alive' });
        }        // If no target, just return success (allows removing target)
        if (!targetId) {
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                doctor: {
                    ...(lobbyData.roleData?.doctor || {}),
                    [userId]: {
                        ...(lobbyData.roleData?.doctor?.[userId] || {}),
                        protectedId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            }); return res.status(200).json({ message: 'Protection target removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Check if doctor is protecting themselves and has already used self-protection
        const doctorData = lobbyData.roleData?.doctor?.[userId] || {};
        if (targetId === userId && doctorData.selfProtectionUsed) {
            return res.status(400).json({ error: 'You cannot protect yourself more than once per game' });
        }

        // Store doctor's protection choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            doctor: {
                ...(lobbyData.roleData?.doctor || {}),
                [userId]: {
                    ...doctorData,
                    protectedId: targetId,
                    selfProtectionUsed: doctorData.selfProtectionUsed || (targetId === userId)
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
        console.log('🔫 gunmanKill called with:', req.body);
        const { lobbyCode, userId, targetId } = req.body; if (!lobbyCode || !userId) {
            console.log('❌ Missing required parameters:', { lobbyCode, userId });
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        console.log('🔍 Looking for lobby:', lobbyCode.toUpperCase());
        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            console.log('❌ Lobby not found:', lobbyCode.toUpperCase());
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        console.log('📊 Lobby data found. Game state:', lobbyData.gameState);

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            console.log('❌ Not in night_phase. Current state:', lobbyData.gameState);
            return res.status(400).json({ error: 'Not in night actions phase' });
        }

        const players = lobbyData.players || [];
        console.log('👥 Players in lobby:', players.length);
        const gunman = players.find(p => p.id === userId);
        console.log('🔫 Found gunman player:', gunman ? `${gunman.name} (${gunman.role})` : 'Not found');        // Verify player is gunman and alive
        if (!gunman || gunman.role !== 'Gunman' || !gunman.isAlive) {
            console.log('❌ Gunman validation failed:', {
                found: !!gunman,
                role: gunman?.role,
                isAlive: gunman?.isAlive
            });
            return res.status(403).json({ error: 'You are not the gunman or not alive' });
        }

        // Check if there's an alive chieftain - if so, gunman cannot act independently
        const aliveChieftain = players.find(p => p.role === 'Chieftain' && p.isAlive);
        if (aliveChieftain) {
            console.log('👑 Alive chieftain found, gunman cannot act independently');
            return res.status(403).json({ error: 'Chieftain is alive. You must wait for orders.' });
        }// If no target, just return success (allows removing target)
        if (!targetId) {
            console.log('🚫 Removing gunman target');
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                gunman: {
                    ...(lobbyData.roleData?.gunman || {}),
                    [userId]: {
                        ...(lobbyData.roleData?.gunman?.[userId] || {}),
                        targetId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            console.log('✅ Kill target removed successfully');
            return res.status(200).json({ message: 'Kill target removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        console.log('🎯 Target player:', target ? `${target.name} (${target.role})` : 'Not found');

        if (!target || !target.isAlive) {
            console.log('❌ Target not alive or not found');
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === userId) {
            console.log('❌ Self-targeting attempt');
            return res.status(400).json({ error: 'You cannot kill yourself' });
        }

        console.log('💾 Storing gunman kill choice in roleData');
        // Store gunman's kill choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            gunman: {
                ...(lobbyData.roleData?.gunman || {}),
                [userId]: {
                    ...(lobbyData.roleData?.gunman?.[userId] || {}),
                    targetId: targetId
                }
            }
        };

        console.log('📝 Updated roleData:', JSON.stringify(updatedRoleData, null, 2));

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        console.log('✅ Kill target selected successfully');
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
    } try {
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        } const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const sheriff = players.find(p => p.id === userId);

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
                    [userId]: {
                        ...(lobbyData.roleData?.sheriff?.[userId] || {}),
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
        const target = players.find(p => p.id === targetId);
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
        }        // Store sheriff's investigation result
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            sheriff: {
                ...(lobbyData.roleData?.sheriff || {}),
                [userId]: {
                    ...(lobbyData.roleData?.sheriff?.[userId] || {}),
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
    } try {
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        } const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const escort = players.find(p => p.id === userId);

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
                    [userId]: {
                        ...(lobbyData.roleData?.escort?.[userId] || {}),
                        blockedId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Block target removed' });
        }        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === userId) {
            return res.status(400).json({ error: 'You cannot block yourself' });
        }

        // Store escort's block choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            escort: {
                ...(lobbyData.roleData?.escort || {}),
                [userId]: {
                    ...(lobbyData.roleData?.escort?.[userId] || {}),
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
    } try {
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        } const lobbyData = lobbyDoc.data();

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            return res.status(400).json({ error: 'Not in night actions phase' });
        } const players = lobbyData.players || [];
        const peeper = players.find(p => p.id === userId);

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
                    [userId]: {
                        ...(lobbyData.roleData?.peeper?.[userId] || {}),
                        targetId: null,
                        result: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            return res.status(200).json({ message: 'Spy target removed' });
        }        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === userId) {
            return res.status(400).json({ error: 'You cannot spy on yourself' });
        }        // Store peeper's spy choice and result
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            peeper: {
                ...(lobbyData.roleData?.peeper || {}),
                [userId]: {
                    ...(lobbyData.roleData?.peeper?.[userId] || {}),
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

// Chieftain's action - give kill orders to gunmen during the night
exports.chieftainOrder = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        console.log('👑 chieftainOrder called with:', req.body);
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            console.log('❌ Missing required parameters:', { lobbyCode, userId });
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        console.log('🔍 Looking for lobby:', lobbyCode.toUpperCase());
        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            console.log('❌ Lobby not found:', lobbyCode.toUpperCase());
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        console.log('📊 Lobby data found. Game state:', lobbyData.gameState);

        // Check if it's night actions phase
        if (lobbyData.gameState !== 'night_phase') {
            console.log('❌ Not in night_phase. Current state:', lobbyData.gameState);
            return res.status(400).json({ error: 'Not in night actions phase' });
        }

        const players = lobbyData.players || [];
        console.log('👥 Players in lobby:', players.length);
        const chieftain = players.find(p => p.id === userId);
        console.log('👑 Found chieftain player:', chieftain ? `${chieftain.name} (${chieftain.role})` : 'Not found');

        // Verify player is chieftain and alive
        if (!chieftain || chieftain.role !== 'Chieftain' || !chieftain.isAlive) {
            console.log('❌ Chieftain validation failed:', {
                found: !!chieftain,
                role: chieftain?.role,
                isAlive: chieftain?.isAlive
            });
            return res.status(403).json({ error: 'You are not the chieftain or not alive' });
        }

        // Check if there are any alive gunmen
        const aliveGunmen = players.filter(p => p.role === 'Gunman' && p.isAlive);
        console.log('🔫 Alive gunmen count:', aliveGunmen.length);

        if (aliveGunmen.length === 0) {
            console.log('❌ No alive gunmen to give orders to');
            return res.status(400).json({ error: 'No alive gunmen to give orders to' });
        }

        // If no target, just return success (allows removing target)
        if (!targetId) {
            console.log('🚫 Removing chieftain target order');
            const updatedRoleData = {
                ...(lobbyData.roleData || {}),
                chieftain: {
                    ...(lobbyData.roleData?.chieftain || {}),
                    [userId]: {
                        ...(lobbyData.roleData?.chieftain?.[userId] || {}),
                        targetId: null
                    }
                }
            };

            await lobbyRef.update({
                roleData: updatedRoleData
            });

            console.log('✅ Chieftain order removed successfully');
            return res.status(200).json({ message: 'Kill order removed' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        console.log('🎯 Target player:', target ? `${target.name} (${target.role})` : 'Not found');

        if (!target || !target.isAlive) {
            console.log('❌ Target not alive or not found');
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent targeting other bandits
        const targetTeam = require('./teamManager').getTeamByRole(target.role);
        if (targetTeam === 'Bandit') {
            console.log('❌ Cannot target fellow bandit');
            return res.status(400).json({ error: 'You cannot target fellow bandits' });
        }

        console.log('💾 Storing chieftain kill order in roleData');
        // Store chieftain's kill order
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            chieftain: {
                ...(lobbyData.roleData?.chieftain || {}),
                [userId]: {
                    ...(lobbyData.roleData?.chieftain?.[userId] || {}),
                    targetId: targetId
                }
            }
        };

        console.log('📝 Updated roleData:', JSON.stringify(updatedRoleData, null, 2));

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        console.log('✅ Kill order given successfully');
        return res.status(200).json({ message: 'Kill order given successfully' });
    } catch (error) {
        console.error('chieftainOrder error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Gunslinger's action - kill a player (only once)
exports.gunslingerShoot = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, userId, targetId } = req.body;

        if (!lobbyCode || !userId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];
        const gunslinger = players.find(p => p.id === userId);

        // Verify player is gunslinger and alive
        if (!gunslinger || gunslinger.role !== 'Gunslinger' || !gunslinger.isAlive) {
            return res.status(403).json({ error: 'You are not the gunslinger or not alive' });
        }

        // Check if Gunslinger has already used their bullet
        if (lobbyData.roleData?.gunslinger?.[userId]?.usedBullet) {
            return res.status(400).json({ error: 'You have already used your bullet' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Update role data to mark bullet as used
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            gunslinger: {
                ...(lobbyData.roleData?.gunslinger || {}),
                [userId]: {
                    usedBullet: true,
                    targetId: targetId
                }
            }
        };

        // Mark target as killed
        const updatedPlayers = players.map(player => {
            if (player.id === targetId) {
                return { ...player, isAlive: false, killedBy: 'Gunslinger' };
            }
            return player;
        });

        // Add public event for night results
        const nightEvents = lobbyData.nightEvents || [];
        nightEvents.push(`${target.name} was killed by the Gunslinger.`);

        await lobbyRef.update({
            roleData: updatedRoleData,
            players: updatedPlayers,
            nightEvents: nightEvents
        });

        return res.status(200).json({ message: 'Shot fired successfully' });
    } catch (error) {
        console.error('gunslingerShoot error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};
