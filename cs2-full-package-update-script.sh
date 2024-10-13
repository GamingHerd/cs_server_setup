#!/bin/bash

AWS_REGION="us-east-1"
CS2_DIR="/home/steam/cs2"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_WHITELIST_FILE_PATH="$MATCHZY_DIR/whitelist.cfg"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCH_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
MATCHZY_VERSION="0.8.6"
METAMOD_FILE_NAME="mmsource-2.0.0-git1314-linux.tar.gz"
METAMOD_URL_PATH_VERSION="2.0"
COUNTER_STRIKE_SHARP_FILE_NAME="counterstrikesharp-with-runtime-build-279-linux-ad7f7bd.zip"
COUNTER_STRIKE_SHARP_FILE_URL="v279/$COUNTER_STRIKE_SHARP_FILE_NAME"

STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')
RCON_PASSWORD_JSON=$(aws secretsmanager get-secret-value --secret-id 'rcon-password' --region $AWS_REGION --query 'SecretString' --output text)
RCON_PASSWORD=$(echo "$RCON_PASSWORD_JSON" | jq -r '."rcon-password"')

sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean

# Kill existing CS2 process
sudo pkill -f '/home/steam/cs2/game/bin/linuxsteamrt64/cs2'

# Run SteamCMD
/usr/games/steamcmd +force_install_dir /home/steam/cs2 +login anonymous +app_update 730 validate +quit

cd "$CS2_DIR"

wget "https://mms.alliedmods.net/mmsdrop/$METAMOD_URL_PATH_VERSION/$METAMOD_FILE_NAME"

# Extract MetaMod to the CS2 directory
tar -xzvf "$METAMOD_FILE_NAME" -C "$CSGO_GAME_DIR"

# Remove the downloaded MetaMod tar.gz file
rm "$METAMOD_FILE_NAME"

METAMOD_GAMEINFO_ENTRY="                        Game    csgo/addons/metamod"

if grep -Fxq "$METAMOD_GAMEINFO_ENTRY" "$GAMEINFO_FILE_PATH"; then
  echo "The entry '$METAMOD_GAMEINFO_ENTRY' already exists in ${GAMEINFO_FILE_PATH}. No changes were made."
else
  awk -v new_entry="$METAMOD_GAMEINFO_ENTRY" '
      BEGIN { found=0; }
      // {
          if (found) {
              print new_entry;
              found=0;
          }
          print;
      }
      /Game_LowViolence/ { found=1; }
  ' "$GAMEINFO_FILE_PATH" >"$GAMEINFO_FILE_PATH.tmp" && mv "$GAMEINFO_FILE_PATH.tmp" "$GAMEINFO_FILE_PATH"

  echo "The file ${GAMEINFO_FILE_PATH} has been modified successfully. '$METAMOD_GAMEINFO_ENTRY' has been added."
fi

# Download the latest CounterStrikeSharp build
wget "https://github.com/roflmuffin/CounterStrikeSharp/releases/download/$COUNTER_STRIKE_SHARP_FILE_URL"

# Extract CounterStrikeSharp to the CS2 directory
unzip -o "$COUNTER_STRIKE_SHARP_FILE_NAME" -d "$CSGO_GAME_DIR"

rm "$COUNTER_STRIKE_SHARP_FILE_NAME"

# Download the latest MatchZy build
wget "https://github.com/shobhit-pathak/MatchZy/releases/download/$MATCHZY_VERSION/MatchZy-$MATCHZY_VERSION.zip"

# Extract MatchZy to the CS2 directory
unzip -o "MatchZy-$MATCHZY_VERSION.zip" -d "$CSGO_GAME_DIR"

# Remove the downloaded MatchZy .zip file
rm "MatchZy-$MATCHZY_VERSION.zip"

# Replace MatchZy admins entry with proper admin
sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

# Cange the knife round time to 69 seconds (nice)
sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

# Only whitelist admin for now until a match would Start
echo "$EAGLE_STEAM_ID" >"$MATCHZY_WHITELIST_FILE_PATH"

# Replace MatchZy server config with custom config from GamingHerd GitHub
wget -O "$MATCH_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
mv "$MATCH_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

# Overwrite the rcon password in the server.cfg file
echo "rcon_password $RCON_PASSWORD" >"$CSGO_GAME_DIR/cfg/server.cfg"
echo "tv_enable 1" >>"$CSGO_GAME_DIR/cfg/server.cfg"
echo "tv_advertise_watchable 1" >>"$CSGO_GAME_DIR/cfg/server.cfg"

# Start the CS2 server
nohup /home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated -console -usercon -nobots +map de_inferno +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" -maxplayers 11 >/dev/null 2>&1 &

disown

exit 0
