const admin = require('firebase-admin');
const db = admin.firestore();

// Import team manager for role checks
const teamManager = require('./teamManager');

// Doctor's action - protect a player during the night
exports.doctorProtect = async (req, res) => {
    try {
        const { lobbyCode, doctorId, targetId } = req.body;

        if (!lobbyCode || !doctorId || !targetId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];
        const doctor = players.find(p => p.id === doctorId);

        // Verify player is doctor and alive
        if (!doctor || doctor.role !== 'Doctor' || !doctor.isAlive) {
            return res.status(403).json({ error: 'You are not the doctor or not alive' });
        }

        // Check if we're in night phase
        if (lobbyData.phase !== 'night') {
            return res.status(400).json({ error: 'Action can only be performed at night' });
        }

        // Check if doctor is protecting themselves and has already used self-protection
        const doctorData = lobbyData.roleData?.doctor || {};
        if (targetId === doctorId && doctorData.selfProtectionUsed) {
            return res.status(400).json({ error: 'You cannot protect yourself more than once per game' });
        }

        // Store doctor's protection choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            doctor: {
                ...doctorData,
                protectedId: targetId,
                selfProtectionUsed: doctorData.selfProtectionUsed || (targetId === doctorId)
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
    try {
        const { lobbyCode, gunmanId, targetId } = req.body;

        if (!lobbyCode || !gunmanId || !targetId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];
        const gunman = players.find(p => p.id === gunmanId);

        // Verify player is gunman and alive
        if (!gunman || gunman.role !== 'Gunman' || !gunman.isAlive) {
            return res.status(403).json({ error: 'You are not the gunman or not alive' });
        }

        // Check if we're in night phase
        if (lobbyData.phase !== 'night') {
            return res.status(400).json({ error: 'Action can only be performed at night' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Store gunman's kill choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            gunman: {
                ...(lobbyData.roleData?.gunman || {}),
                targetId: targetId
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
    try {
        const { lobbyCode, sheriffId, targetId } = req.body;

        if (!lobbyCode || !sheriffId || !targetId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];
        const sheriff = players.find(p => p.id === sheriffId);

        // Verify player is sheriff and alive
        if (!sheriff || sheriff.role !== 'Sheriff' || !sheriff.isAlive) {
            return res.status(403).json({ error: 'You are not the sheriff or not alive' });
        }

        // Check if we're in night phase
        if (lobbyData.phase !== 'night') {
            return res.status(400).json({ error: 'Action can only be performed at night' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Determine investigation result
        let result = 'innocent';
        const targetTeam = teamManager.getTeamByRole(target.role);

        // Bandits appear suspicious except for Godfather who appears innocent
        if (targetTeam === 'Bandit' && target.role !== 'Godfather') {
            result = 'suspicious';
        }

        // Some neutral roles appear suspicious
        if (targetTeam === 'Neutral' && ['Serial Killer', 'Arsonist', 'Witch'].includes(target.role)) {
            result = 'suspicious';
        }

        // Store sheriff's investigation result
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            sheriff: {
                ...(lobbyData.roleData?.sheriff || {}),
                targetId: targetId,
                result: result
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

// Prostitute's action - block a player from using their ability during the night
exports.prostituteBlock = async (req, res) => {
    try {
        const { lobbyCode, prostituteId, targetId } = req.body;

        if (!lobbyCode || !prostituteId || !targetId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }

        const lobbyRef = db.collection('lobbies').doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: 'Lobby not found' });
        }

        const lobbyData = lobbyDoc.data();
        const players = lobbyData.players || [];
        const prostitute = players.find(p => p.id === prostituteId);

        // Verify player is prostitute and alive
        if (!prostitute || prostitute.role !== 'Prostitute' || !prostitute.isAlive) {
            return res.status(403).json({ error: 'You are not the prostitute or not alive' });
        }

        // Check if we're in night phase
        if (lobbyData.phase !== 'night') {
            return res.status(400).json({ error: 'Action can only be performed at night' });
        }

        // Check if target is alive
        const target = players.find(p => p.id === targetId);
        if (!target || !target.isAlive) {
            return res.status(400).json({ error: 'Target is not alive' });
        }

        // Prevent self-targeting
        if (targetId === prostituteId) {
            return res.status(400).json({ error: 'You cannot block yourself' });
        }

        // Store prostitute's block choice
        const updatedRoleData = {
            ...(lobbyData.roleData || {}),
            prostitute: {
                ...(lobbyData.roleData?.prostitute || {}),
                blockedId: targetId
            }
        };

        await lobbyRef.update({
            roleData: updatedRoleData
        });

        return res.status(200).json({
            message: 'Block action applied successfully'
        });
    } catch (error) {
        console.error('prostituteBlock error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};
