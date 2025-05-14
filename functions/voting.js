const admin = require('firebase-admin');
const db = admin.firestore();

// Submit a vote during day phase
exports.submitVote = async (req, res) => {
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
};

// Process votes at the end of day phase
exports.processVotes = async (req, res) => {
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

        // Count votes
        const voteCounts = {};
        Object.values(votes).forEach(targetId => {
            voteCounts[targetId] = (voteCounts[targetId] || 0) + 1;
        });

        // Find the player with the most votes
        let maxVotes = 0;
        let eliminatedId = null;
        for (const [targetId, count] of Object.entries(voteCounts)) {
            if (count > maxVotes) {
                maxVotes = count;
                eliminatedId = targetId;
            } else if (count === maxVotes) {
                eliminatedId = null; // Tie, no one is eliminated
            }
        }

        // Update players
        const updatedPlayers = players.map(p => {
            if (p.id === eliminatedId) {
                return { ...p, isAlive: false };
            }
            return p;
        });

        await lobbyRef.update({
            players: updatedPlayers,
            votes: {} // Clear votes for the next day
        });

        return res.status(200).json({
            message: eliminatedId ? "Player eliminated" : "Tie, no one eliminated",
            eliminatedId
        });
    } catch (error) {
        console.error("processVotes error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};
