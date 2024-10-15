#!/bin/bash

AWS_REGION="us-east-1"
CS2_PROCESS='/home/steam/cs2/game/bin/linuxsteamrt64/cs2'

# Check if the CS2 process is running
if pgrep -f "$CS2_PROCESS" >/dev/null; then
  echo "CS2 server is already running. Exiting."
  exit 0
else
  echo "No existing CS2 process found. Continuing to start the server."
fi

# Fetch Steam Game Server Token from AWS Secrets Manager
STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')

# Start the CS2 server
nohup /home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated -usercon +map de_inferno +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" >/dev/null 2>&1 &

disown

exit 0
