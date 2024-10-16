#!/bin/bash

STEAM_USER="cs2server"
CS2_DIR="/home/cs2server/serverfiles"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCH_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
MATCHZY_VERSION="0.8.6"
MATCHZY_URL="https://github.com/shobhit-pathak/MatchZy/releases/download/$MATCHZY_VERSION/MatchZy-$MATCHZY_VERSION.zip"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
METAMOD_URL="https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1314-linux.tar.gz"
COUNTER_STRIKE_SHARP_URL="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v281/counterstrikesharp-with-runtime-build-281-linux-71ae253.zip"

cd /home/$STEAM_USER

sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean

./cs2server stop
./cs2server update

# Download the latest MetaMod build
wget -q -O /tmp/metamod.tar.gz "$METAMOD_URL"

# Extract MetaMod to the csgo directory
tar -xzf /tmp/metamod.tar.gz -C "$CSGO_GAME_DIR"

# Remove the downloaded MetaMod tar.gz file
rm -f /tmp/metamod.tar.gz

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
wget -q -O /tmp/cssharp.zip "$COUNTER_STRIKE_SHARP_URL"

# Extract CounterStrikeSharp to the CS2 directory
unzip -qo /tmp/cssharp.zip -d "$CSGO_GAME_DIR"

rm -f /tmp/cssharp.zip

# Download the latest MatchZy build
wget -q -O /tmp/matchzy.zip "$MATCHZY_URL"

# Extract MatchZy to the CS2 directory
unzip -qo /tmp/matchzy.zip -d "$CSGO_GAME_DIR"

# Remove the downloaded MatchZy .zip file
rm -f /tmp/matchzy.zip

# Replace MatchZy admins entry with proper admin
sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

# Cange the knife round time to 69 seconds (nice)
sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

# Replace MatchZy server config with custom config from GamingHerd GitHub
wget -q -O "$MATCH_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
mv "$MATCH_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

./cs2server start -dedicated -usercon -maxplayers 10 +game_mode 1 +game_type 0

exit 0
