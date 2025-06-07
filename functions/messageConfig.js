// Event Type Keywords Configuration for Noonday Game
// This file only contains event type constants - no message content
// All message content is handled client-side in Flutter

const MESSAGES = {
    // Event Types (used for categorizing events - keywords only)
    EVENT_TYPES: {
        // Public events (shown to everyone)
        PLAYER_KILLED: "player_killed",
        QUIET_NIGHT: "quiet_night",

        // Private events (shown to specific players)
        PROTECTION_RESULT: "protection_result",
        PROTECTION_BLOCKED: "protection_blocked",
        PROTECTION_SUCCESSFUL: "protection_successful",
        INVESTIGATION_RESULT: "investigation_result",
        INVESTIGATION_BLOCKED: "investigation_blocked",
        BLOCK_RESULT: "block_result",
        PEEP_RESULT: "peep_result",
        PEEP_BLOCKED: "peep_blocked",
        KILL_SUCCESS: "kill_success",
        KILL_FAILED: "kill_failed",
        KILL_BLOCKED: "kill_blocked",
        ORDER_SUCCESS: "order_success",
        ORDER_FAILED: "order_failed",
        NOT_SELECTED: "not_selected"
    },

    // Investigation results (simple keywords)
    INVESTIGATION_RESULTS: {
        SUSPICIOUS: "Suspicious",
        INNOCENT: "Innocent"
    }
};

module.exports = MESSAGES;
