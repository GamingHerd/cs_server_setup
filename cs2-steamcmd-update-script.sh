#!/bin/bash

AWS_REGION="us-east-1"

# Kill existing CS2 process
sudo pkill -f '/home/steam/cs2/game/bin/linuxsteamrt64/cs2'

sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean

# Run SteamCMD to update the game
/usr/games/steamcmd +force_install_dir /home/steam/cs2 +login anonymous +app_update 730 +quit

# Fetch Steam Game Server Token from AWS Secrets Manager
STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')

# Start the CS2 server
nohup /home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated -usercon +map de_inferno +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" >/dev/null 2>&1 &

disown

exit 0
