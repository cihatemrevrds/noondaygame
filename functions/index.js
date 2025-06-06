const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Import modules
const roleActions = require('./roleActions');
const gamePhase = require('./gamePhase');
const voting = require('./voting');
const teamManager = require('./teamManager');

// Expose role actions as cloud functions
exports.doctorProtect = functions.https.onRequest(roleActions.doctorProtect);
exports.gunmanKill = functions.https.onRequest(roleActions.gunmanKill);
exports.sheriffInvestigate = functions.https.onRequest(roleActions.sheriffInvestigate);
exports.escortBlock = functions.https.onRequest(roleActions.escortBlock);
exports.peeperSpy = functions.https.onRequest(roleActions.peeperSpy);
exports.chieftainOrder = functions.https.onRequest(roleActions.chieftainOrder);

// Expose game phase functions
exports.startGame = functions.https.onRequest(gamePhase.startGame);
exports.advancePhase = functions.https.onRequest(gamePhase.advancePhase);
exports.autoAdvancePhase = functions.https.onRequest(gamePhase.autoAdvancePhase);
exports.getGameState = functions.https.onRequest(gamePhase.getGameState);
exports.getRoleInfo = functions.https.onRequest(gamePhase.getRoleInfo);

// Expose voting functions
exports.submitVote = functions.https.onRequest(voting.submitVote);
exports.processVotes = functions.https.onRequest(voting.processVotes);

// Expose team management functions
exports.checkWinConditions = functions.https.onRequest(teamManager.checkWinConditions);

// Settings update function
exports.updateSettings = functions.https.onRequest(async (req, res) => {
    try {
        const { lobbyCode, hostId, settings } = req.body;

        if (!lobbyCode || !hostId || !settings) {
            return res.status(400).json({ error: "Missing lobbyCode, hostId, or settings" });
        }

        const lobbyRef = admin.firestore().collection("lobbies").doc(lobbyCode.toUpperCase());
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

