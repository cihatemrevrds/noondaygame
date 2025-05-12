const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

exports.startGame = functions.https.onRequest(async (req, res) => {
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
});  // ✅ startGame fonksiyonu burada kapanıyor

exports.advancePhase = functions.https.onRequest(async (req, res) => {
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

        if (lobbyData.hostUid !== hostId) {
            return res.status(403).json({ error: "Only host can advance the phase" });
        }

        const currentPhase = lobbyData.phase || "night";
        const dayCount = lobbyData.dayCount || 1;

        const newPhase = currentPhase === "night" ? "day" : "night";
        const newDayCount = currentPhase === "night" ? dayCount : dayCount + 1;

        await lobbyRef.update({
            phase: newPhase,
            dayCount: newDayCount,
            phaseStartedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return res.status(200).json({
            message: "Phase updated",
            newPhase,
            newDayCount
        });
    } catch (error) {
        console.error("advancePhase error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
});

exports.submitVote = functions.https.onRequest(async (req, res) => {
    try {
        const { lobbyCode, voterId, targetId } = req.body;

        if (!lobbyCode || !voterId || !targetId) {
            return res.status(400).json({ error: "Missing lobbyCode, voterId, or targetId" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();
        const currentVotes = lobbyData.votes || {};

        currentVotes[voterId] = targetId;

        await lobbyRef.update({
            votes: currentVotes
        });

        return res.status(200).json({ message: "Vote submitted" });
    } catch (error) {
        console.error("submitVote error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
});

exports.processVotes = functions.https.onRequest(async (req, res) => {
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
        const votes = lobbyData.votes || {};
        const players = lobbyData.players || [];

        // Oyları say
        const voteCounts = {};
        Object.values(votes).forEach(targetId => {
            voteCounts[targetId] = (voteCounts[targetId] || 0) + 1;
        });

        // En çok oyu alan kişiyi bul
        let maxVotes = 0;
        let eliminatedId = null;
        for (const [targetId, count] of Object.entries(voteCounts)) {
            if (count > maxVotes) {
                maxVotes = count;
                eliminatedId = targetId;
            } else if (count === maxVotes) {
                eliminatedId = null; // eşitlik varsa kimse elenmez
            }
        }

        // Oyuncuları güncelle
        const updatedPlayers = players.map(p => {
            if (p.id === eliminatedId) {
                return { ...p, isAlive: false };
            }
            return p;
        });

        await lobbyRef.update({
            players: updatedPlayers,
            votes: {} // yeni güne temiz başla
        });

        return res.status(200).json({
            message: eliminatedId ? "Player eliminated" : "Tie, no one eliminated",
            eliminatedId
        });
    } catch (error) {
        console.error("processVotes error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
});

exports.updateSettings = functions.https.onRequest(async (req, res) => {
    try {
        const { lobbyCode, hostId, settings } = req.body;

        if (!lobbyCode || !hostId || !settings) {
            return res.status(400).json({ error: "Missing lobbyCode, hostId, or settings" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();

        if (lobbyData.hostUid !== hostId) {
            return res.status(403).json({ error: "Only host can update settings" });
        }

        await lobbyRef.update({
            settings
        });

        return res.status(200).json({ message: "Settings updated" });
    } catch (error) {
        console.error("updateSettings error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
});

