# shellcheck shell=bash
#
# App config loaded by SSH entry points. Two sections:

# --- Host secrets (must already be set in the environment) ---
export API_CLICKUP_TOKEN="$API_CLICKUP_TOKEN"
export BOT_DISCORD_TOKEN="$BOT_DISCORD_TOKEN"
export API_CURSOR_TOKEN="$API_CURSOR_TOKEN"

# clickup/inbox_add.sh
export API_CLICKUP_BASE_URL="https://api.clickup.com"
export CLICKUP_INBOX_ID="900303726304"

# discord/
export BOT_DISCORD_GUILD_ID="1544070566997139519"
export BOT_DISCORD_VOICE_CHANNEL_ID="1544070567479746673"
