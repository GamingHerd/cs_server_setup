#!/bin/bash

STEAM_USER="cs2server"
CS2_DIR="/home/$STEAM_USER/serverfiles"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
MATCHZY_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy_live_override.cfg"
MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH="/tmp/live_override.cfg"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCHZY_URL="https://github.com/shobhit-pathak/MatchZy/releases/download/0.8.6/MatchZy-0.8.6.zip"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
METAMOD_URL="https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1314-linux.tar.gz"
METAMOD_GAMEINFO_ENTRY="                        Game    csgo/addons/metamod"
COUNTER_STRIKE_SHARP_URL="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v284/counterstrikesharp-with-runtime-build-284-linux-5c9d38b.zip"

cd /home/cs2server

sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean

./cs2server stop
./cs2server update

# Install Metamod
echo "Installing metamod."
wget -q -O /tmp/metamod.tar.gz "$METAMOD_URL"
tar -xzf /tmp/metamod.tar.gz -C "$CSGO_GAME_DIR"
rm -f /tmp/metamod.tar.gz
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
echo "Completed installing metamod."

# Install CounterStrikeSharp
echo "Installing CounterStrikeSharp."
wget -q -O /tmp/cssharp.zip "$COUNTER_STRIKE_SHARP_URL"
unzip -qo /tmp/cssharp.zip -d "$CSGO_GAME_DIR"
rm -f /tmp/cssharp.zip
echo "Completed installing CounterStrikeSharp."

# Install MatchZy
echo "Installing MatchZy."
wget -q -O /tmp/matchzy.zip "$MATCHZY_URL"
unzip -qo /tmp/matchzy.zip -d "$CSGO_GAME_DIR"
rm -f /tmp/matchzy.zip
echo "Completed installing MatchZy."

# Update MatchZy admins
sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

# Set knife round time to 69 seconds (1.15 minutes)
sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

# Replace MatchZy server config with custom GamingHerd config
wget -q -O "$MATCHZY_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
mv "$MATCHZY_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

# Add MatchZy live_override.cfg
wget -q -O "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL"
mv "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$MATCHZY_DIR"

./cs2server start

exit 0
