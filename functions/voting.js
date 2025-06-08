const admin = require('firebase-admin');
const db = admin.firestore();

// Submit a vote during day phase
exports.submitVote = async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }

    try {
        const { lobbyCode, voterId, targetId } = req.body;

        if (!lobbyCode || !voterId) {
            return res.status(400).json({ error: "Missing lobbyCode or voterId" });
        }

        const lobbyRef = db.collection("lobbies").doc(lobbyCode.toUpperCase());
        const lobbyDoc = await lobbyRef.get();

        if (!lobbyDoc.exists) {
            return res.status(404).json({ error: "Lobby not found" });
        }

        const lobbyData = lobbyDoc.data();        // Check if it's voting phase
        if (lobbyData.gameState !== 'voting_phase') {
            return res.status(400).json({ error: "Not in voting phase" });
        }

        const currentVotes = lobbyData.votes || {};

        // Allow removing vote by passing null as targetId
        if (targetId === null) {
            delete currentVotes[voterId];
        } else {
            currentVotes[voterId] = targetId;
        }

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
        }        const lobbyData = lobbyDoc.data();
        const votes = lobbyData.votes || {};
        const players = lobbyData.players || [];
        const alivePlayers = players.filter(p => p.isAlive);
        const totalAlivePlayers = alivePlayers.length;
        
        // Minimum votes needed to hang someone: ceil(alive_players / 2)
        // Examples: 4 players -> 2 votes, 5 players -> 3 votes, 6 players -> 3 votes
        const requiredVotes = Math.ceil(totalAlivePlayers / 2);

        // Count votes for each player
        const voteCounts = {};
        Object.values(votes).forEach(targetId => {
            voteCounts[targetId] = (voteCounts[targetId] || 0) + 1;
        });

        // Find the player(s) with the highest vote count
        let maxVotes = 0;
        let playersWithMaxVotes = [];
        
        for (const [targetId, count] of Object.entries(voteCounts)) {
            if (count > maxVotes) {
                maxVotes = count;
                playersWithMaxVotes = [targetId];
            } else if (count === maxVotes) {
                playersWithMaxVotes.push(targetId);
            }
        }

        // Check if someone can be eliminated:
        // 1. Must have at least the required votes
        // 2. Must not be tied with another player
        let eliminatedId = null;
        if (maxVotes >= requiredVotes && playersWithMaxVotes.length === 1) {
            eliminatedId = playersWithMaxVotes[0];
        }// Update players
        const updatedPlayers = players.map(p => {
            if (p.id === eliminatedId) {
                return { ...p, isAlive: false, eliminatedBy: 'vote' };
            }
            return p;
        });        await lobbyRef.update({
            players: updatedPlayers,
            votes: {} // Clear votes for the next day
        });

        const eliminatedPlayer = eliminatedId ? players.find(p => p.id === eliminatedId) : null;
        const result = {
            message: eliminatedId ? "Player eliminated" : "No majority vote, no one eliminated",
            eliminatedId,
            eliminatedPlayer: eliminatedPlayer ? {
                id: eliminatedPlayer.id,
                name: eliminatedPlayer.name,
                role: eliminatedPlayer.role,
                voteCount: maxVotes
            } : null,
            voteCounts: voteCounts, // Include all vote counts for frontend display
            requiredVotes: requiredVotes,
            totalAlivePlayers: totalAlivePlayers
        };

        return res.status(200).json(result);
    } catch (error) {
        console.error("processVotes error:", error);
        return res.status(500).json({ error: "Internal Server Error" });
    }
};
